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
session id: 019f7799-e7bc-7f11-a92b-49e19120611b
--------
user
You are an adversarial senior R/Plumber reviewer. Review ONLY the diff of the current branch vs master for correctness, security, and contract-compliance bugs. Run `git diff origin/master...HEAD -- ':(exclude).planning/**'` to see the change set (feature #574: category-selected gene universes for functional clustering). Read the touched files in full where needed. Be skeptical and specific; find bugs, not style nits.

## What #574 does
`POST /api/jobs/clustering/submit` gains an optional `category_filter` JSON body array (e.g. `["Definitive"]`) that resolves the clustering gene universe from curated SysNDD confidence categories instead of an explicit `genes` array. New file `api/functions/clustering-gene-universe.R` holds the resolver + provenance helpers; the submit service `api/services/job-functional-submission-service.R` wires it in; the durable handler `.async_job_run_clustering` (`api/functions/async-job-handlers.R`) echoes provenance into the worker-run result meta.

## LOCKED design decisions — a violation of any of these is a BUG (report it):
1. **Entity-level resolution**: the universe = distinct `hgnc_id` from `ndd_entity_view` filtered `ndd_phenotype == 1` AND `category %in% selector`. A gene with ≥1 entity in a selected category qualifies even if it has other-category entities. It must NEVER use `select_network_gene_category()`.
2. **NULL/absent selector → the pre-#574 default** (all NDD genes via `generate_ndd_hgnc_ids()`), byte-identical for cache parity. `clustering_normalize_category_filter` returns NULL ONLY for a NULL arg; `character(0)` for supplied-but-empty (`[]`/`[""]`/`["  "]`) which must 400 (NOT fall through to default).
3. **Validation is live** against `ndd_entity_status_categories_list WHERE is_active = 1`. No hardcoded category strings; no category string interpolated into SQL (must use dbplyr `%in%` + an allowlist pre-check). The allowed active set must appear in the error MESSAGE (conditionMessage), not only a `detail` field.
4. **Guards**: unknown/inactive category → 400; supplied-empty → 400; resolved universe < 2 genes → 400; `genes` + non-empty `category_filter` → 400 (mutual exclusion).
5. **Selector-aware dedup, additively**: the normalized `category_filter` enters the durable payload AND the preflight dedup key ONLY for category selectors. Explicit-`genes` and no-arg submits must keep a BYTE-IDENTICAL payload/`request_hash` to pre-#574 (no `category_filter` key) — though ALL three kinds now additively gain a `provenance` key. No HTTP-409 was added; active-only dedup semantics unchanged.
6. **Provenance** persisted in payload: `selector {kind: explicit|category|all_ndd, category_filter}`, `resolved_gene_count`, `gene_list_sha256` (sha256 of sorted-unique hgnc ids, sort-order independent), an INTENDED `intended_fingerprint` (string cache fingerprint + score_threshold=400 + algorithm + seed=42), and a CACHED, FAIL-CLOSED `source_data_version` (on fetch error → HTTP 503 `PROVENANCE_UNAVAILABLE`, NEVER records NA). The result `meta` additionally carries an EFFECTIVE `effective_fingerprint = {weight_channel = attr(clusters,"weight_channel")}`, on BOTH the cache-hit response and the worker-run handler.
7. **Results are NEVER `public_ready`** (ephemeral job results). The fixed public snapshot GET is untouched (category GET stays `unsupported_parameter`).

## Focus your adversarial search on:
- Any path where a supplied-but-empty or whitespace-only `category_filter` silently becomes the all-NDD default (would be a serious bug).
- Any asymmetry between the cache-hit payload/meta path and the cache-miss (`create_job`) payload path (a field added to one but not the other).
- The fail-closed `source_data_version` / TTL cache (`clustering_cached_source_data_version`): can it ever cache or return an error/NA? Can a stale cached value be served past its TTL? Is the 503 short-circuit before any payload is built?
- The `.async_job_run_clustering` meta echo: does it match the cache-hit meta shape? Backward compatible for a legacy payload with no `provenance`?
- SQL injection / expression injection via category tokens (must be dbplyr-parametrized + allowlisted).
- `resolved_gene_count` vs `gene_list_sha256` consistency; dedup identity collisions between different selectors that resolve to the same current genes.
- The new integration test: does it genuinely assert (not vacuously), skip cleanly on an empty DB, and correctly bind `pool` for the NULL-branch assertion (the NULL branch calls `generate_ndd_hgnc_ids()` which uses the global `pool`, not the passed conn)?
- Anything worker-executed that would only fail at runtime (masked base functions: `config::get` masks `base::get`; `biomaRt::select` masks `dplyr::select` — verify `dplyr::` namespacing).
- Whether explicit/no-arg payloads are truly byte-identical (the `provenance` addition is expected; anything ELSE differing is a bug).

## Output
For each finding: severity (BLOCKER / HIGH / MEDIUM / LOW), file:line, the concrete failure scenario (inputs → wrong behavior), and the fix. Then a final line: **VERDICT: SHIP** or **VERDICT: NO-SHIP** with the blocker count. Only give SHIP if there are zero BLOCKER/HIGH findings.
codex
I’m reviewing only the requested branch diff, with special attention to the locked #574 invariants and runtime behavior. I’ll inspect the relevant implementation and tests before issuing a ship/no-ship verdict.
exec
/bin/bash -lc "pwd && sed -n '1,240p' /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md && git diff --stat origin/master...HEAD -- ':(exclude).planning/**' && git diff --name-only origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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
 AGENTS.md                                          |   2 +
 CHANGELOG.md                                       |  47 ++++
 api/bootstrap/load_modules.R                       |   6 +
 api/endpoints/jobs_endpoints.R                     |  35 ++-
 api/functions/async-job-handlers.R                 |  35 ++-
 api/functions/clustering-gene-universe.R           | 134 ++++++++++++
 api/services/job-functional-submission-service.R   | 164 ++++++++++----
 .../testthat/job-endpoint-services-fixtures.R      |  10 +
 .../test-integration-clustering-category-submit.R  | 183 ++++++++++++++++
 api/tests/testthat/test-unit-async-job-handlers.R  |   4 +
 api/tests/testthat/test-unit-async-job-worker.R    |   3 +
 .../testthat/test-unit-clustering-gene-universe.R  | 238 +++++++++++++++++++++
 .../testthat/test-unit-clustering-handler-meta.R   | 145 +++++++++++++
 .../testthat/test-unit-job-endpoint-services.R     | 193 ++++++++++++++++-
 api/version_spec.json                              |   2 +-
 app/package-lock.json                              |   4 +-
 app/package.json                                   |   2 +-
 documentation/08-development.qmd                   |  15 ++
 18 files changed, 1174 insertions(+), 48 deletions(-)
AGENTS.md
CHANGELOG.md
api/bootstrap/load_modules.R
api/endpoints/jobs_endpoints.R
api/functions/async-job-handlers.R
api/functions/clustering-gene-universe.R
api/services/job-functional-submission-service.R
api/tests/testthat/job-endpoint-services-fixtures.R
api/tests/testthat/test-integration-clustering-category-submit.R
api/tests/testthat/test-unit-async-job-handlers.R
api/tests/testthat/test-unit-async-job-worker.R
api/tests/testthat/test-unit-clustering-gene-universe.R
api/tests/testthat/test-unit-clustering-handler-meta.R
api/tests/testthat/test-unit-job-endpoint-services.R
api/version_spec.json
app/package-lock.json
app/package.json
documentation/08-development.qmd

codex
I’m using the SysNDD security-and-correctness review guide because this change accepts request-controlled selector values and persists durable job payloads.
exec
/bin/bash -lc "sed -n '1,260p' .agents/skills/sysndd-security-bug-scan/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-async-jobs/SKILL.md && sed -n '1,240p' .agents/skills/sysndd-api-testing/SKILL.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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

codex
I’m also using the repository’s diff-analysis guide to trace all affected call paths, rather than treating the new resolver in isolation.
exec
/bin/bash -lc "sed -n '1,260p' /home/bernt-popp/.understand-anything/repo/understand-anything-plugin/skills/understand-diff/SKILL.md && git diff --find-renames --find-copies --unified=80 origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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
index d3691475..9eccf745 100644
--- a/api/functions/async-job-handlers.R
+++ b/api/functions/async-job-handlers.R
@@ -1,198 +1,223 @@
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
diff --git a/api/functions/clustering-gene-universe.R b/api/functions/clustering-gene-universe.R
new file mode 100644
index 00000000..505ee3eb
--- /dev/null
+++ b/api/functions/clustering-gene-universe.R
@@ -0,0 +1,134 @@
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
+#' Cached, fail-closed read of the current analysis source-data version.
+#'
+#' D2 (#574) provenance helper: the clustering submit service calls this
+#' AFTER admission/dedup, only when it is actually about to build a durable
+#' payload. Refetches once `ttl_seconds` has elapsed since the last
+#' successful read. Deliberately does NOT wrap
+#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
+#' PROPAGATES to the caller (never cached, never coerced to NA), so a
+#' transient DB problem fails the submit closed (503) instead of recording
+#' broken provenance.
+#'
+#' @param conn DB connection/pool. Defaults to the package-global `pool`.
+#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
+#' @return character(1) source data version.
+#' @export
+clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
+  now <- Sys.time()
+  cached_at <- .clustering_source_data_version_cache$cached_at
+  if (!is.null(cached_at) &&
+        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
+    return(.clustering_source_data_version_cache$value)
+  }
+
+  value <- analysis_snapshot_source_data_version(conn = conn)
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
index 150c61e0..4cc138e2 100644
--- a/api/services/job-functional-submission-service.R
+++ b/api/services/job-functional-submission-service.R
@@ -1,240 +1,332 @@
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
+  # existing default all-NDD-genes universe. Presence is decided from the RAW
+  # request field, not a length check, so an explicitly-empty category_filter
+  # still reaches (and is rejected by) the resolver instead of silently
+  # falling through to the all-NDD default.
+  genes_in <- req$argsBody$genes
+  category_supplied <- !is.null(req$argsBody$category_filter)
+  has_genes <- !is.null(genes_in) && length(genes_in) > 0
+
+  if (has_genes && category_supplied) {
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
+    resolved_gene_count = length(genes_list),
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
+          gene_count = length(genes_list),
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
   res$setHeader("Retry-After", "5")
 
   list(
     job_id = result$job_id,
     status = result$status,
     estimated_seconds = result$estimated_seconds,
     status_url = paste0("/api/jobs/", result$job_id, "/status")
   )
 }
diff --git a/api/tests/testthat/job-endpoint-services-fixtures.R b/api/tests/testthat/job-endpoint-services-fixtures.R
index 103f4621..d2deaae1 100644
--- a/api/tests/testthat/job-endpoint-services-fixtures.R
+++ b/api/tests/testthat/job-endpoint-services-fixtures.R
@@ -1,50 +1,60 @@
 # tests/testthat/job-endpoint-services-fixtures.R
 #
 # Shared fixtures for the job-endpoint-service unit tests, split across two files
 # to keep each under the 600-line ceiling:
 #   - test-unit-job-endpoint-services.R              (functional + phenotype submission)
 #   - test-unit-job-endpoint-services-maintenance.R  (maintenance submission + query)
 # Both files EXPLICITLY source() this file at the top so they run standalone under a
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
index 00000000..1124c94b
--- /dev/null
+++ b/api/tests/testthat/test-integration-clustering-category-submit.R
@@ -0,0 +1,183 @@
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
+    old_pool <- if (exists("pool", envir = .GlobalEnv)) get("pool", envir = .GlobalEnv) else NULL
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
diff --git a/api/tests/testthat/test-unit-async-job-worker.R b/api/tests/testthat/test-unit-async-job-worker.R
index 792903e1..237528a0 100644
--- a/api/tests/testthat/test-unit-async-job-worker.R
+++ b/api/tests/testthat/test-unit-async-job-worker.R
@@ -1,98 +1,101 @@
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
index 00000000..ed850f29
--- /dev/null
+++ b/api/tests/testthat/test-unit-clustering-gene-universe.R
@@ -0,0 +1,238 @@
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
diff --git a/api/tests/testthat/test-unit-job-endpoint-services.R b/api/tests/testthat/test-unit-job-endpoint-services.R
index 3bb4b43f..49e3ac2a 100644
--- a/api/tests/testthat/test-unit-job-endpoint-services.R
+++ b/api/tests/testthat/test-unit-job-endpoint-services.R
@@ -1,269 +1,458 @@
 # tests/testthat/test-unit-job-endpoint-services.R
 #
 # Host-runnable unit tests for the PUBLIC clustering submission services extracted
 # from endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5): job-functional-
 # submission-service.R and job-phenotype-submission-service.R. The maintenance-
 # submission (job-maintenance-submission-service.R) and query-endpoint
 # (job-query-endpoint-service.R) services are covered in the sibling
 # test-unit-job-endpoint-services-maintenance.R. Shared fixtures live in
 # job-endpoint-services-fixtures.R (explicitly sourced below). Split this way to keep
 # every file under the 600-line ceiling (#535 S6).
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
 
 job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
   tables <- list(
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
   env$create_job <- function(operation, params) {
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
     stop("DB must not be touched when the throttle blocks")
   }
   create_job_called <- FALSE
   env$create_job <- function(...) {
     create_job_called <<- TRUE
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
   expect_false(create_job_called)
 })
 
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
+  env$create_job <- function(operation, params) {
+    captured <<- params
+    list(job_id = "j1", status = "accepted", estimated_seconds = 5)
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
+  create_job_called <- FALSE
+  env$create_job <- function(...) {
+    create_job_called <<- TRUE
+    NULL
+  }
+  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
+  res <- job_endpoint_fake_res()
+
+  out <- env$svc_job_submit_functional_clustering(req, res)
+
+  expect_equal(res$status, 503L)
+  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
+  expect_false(create_job_called)
+})
+
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
/bin/bash -lc "git diff origin/master...HEAD -- ':(exclude).planning/**' > /tmp/sysndd-574.diff && git diff origin/master...HEAD -- ':(exclude).planning/**' | sed -n '1,80p'
printf '\\n--- clustering universe ---\\n'
nl -ba api/functions/clustering-gene-universe.R
printf '\\n--- submit service ---\\n'
nl -ba api/services/job-functional-submission-service.R
printf '\\n--- handler slices ---\\n'
rg -n -C 18 'async_job_run_clustering|effective_fingerprint|provenance' api/functions/async-job-handlers.R
printf '\\n--- endpoint ---\\n'
nl -ba api/endpoints/jobs_endpoints.R
printf '\\n--- module ---\\n'
nl -ba api/bootstrap/load_modules.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
/bin/bash: line 1: /tmp/sysndd-574.diff: Read-only file system

--- clustering universe ---
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
    93	#' Cached, fail-closed read of the current analysis source-data version.
    94	#'
    95	#' D2 (#574) provenance helper: the clustering submit service calls this
    96	#' AFTER admission/dedup, only when it is actually about to build a durable
    97	#' payload. Refetches once `ttl_seconds` has elapsed since the last
    98	#' successful read. Deliberately does NOT wrap
    99	#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
   100	#' PROPAGATES to the caller (never cached, never coerced to NA), so a
   101	#' transient DB problem fails the submit closed (503) instead of recording
   102	#' broken provenance.
   103	#'
   104	#' @param conn DB connection/pool. Defaults to the package-global `pool`.
   105	#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
   106	#' @return character(1) source data version.
   107	#' @export
   108	clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
   109	  now <- Sys.time()
   110	  cached_at <- .clustering_source_data_version_cache$cached_at
   111	  if (!is.null(cached_at) &&
   112	        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
   113	    return(.clustering_source_data_version_cache$value)
   114	  }
   115	
   116	  value <- analysis_snapshot_source_data_version(conn = conn)
   117	
   118	  .clustering_source_data_version_cache$value <- value
   119	  .clustering_source_data_version_cache$cached_at <- now
   120	  value
   121	}
   122	
   123	# Assemble the clustering result `meta`: base fields + the cheap-path provenance
   124	# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
   125	# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
   126	# observed post-compute. Shared by the cache-hit path
   127	# (job-functional-submission-service.R) and the worker-run/durable handler
   128	# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
   129	# shapes cannot drift apart by hand-copied edits.
   130	clustering_result_meta <- function(base, provenance, weight_channel) {
   131	  c(base,
   132	    if (!is.null(provenance)) provenance else list(),
   133	    list(effective_fingerprint = list(weight_channel = weight_channel)))
   134	}

--- submit service ---
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
    61	  has_genes <- !is.null(genes_in) && length(genes_in) > 0
    62	
    63	  if (has_genes && category_supplied) {
    64	    stop_for_bad_request("Provide either genes or category_filter, not both")
    65	  }
    66	
    67	  # Extract algorithm parameter (default: leiden)
    68	  # Ensure we get a scalar value (JSON may pass arrays)
    69	  algorithm <- "leiden"
    70	  if (!is.null(req$argsBody$algorithm)) {
    71	    algo_input <- req$argsBody$algorithm
    72	    # Handle array input - always take first element if vector
    73	    if (is.list(algo_input) || length(algo_input) >= 1) {
    74	      algo_input <- algo_input[[1]]
    75	    }
    76	    algorithm <- tolower(as.character(algo_input))
    77	    if (!algorithm %in% c("leiden", "walktrap")) {
    78	      algorithm <- "leiden"
    79	    }
    80	  }
    81	
    82	  # Resolve the clustering gene universe + selector provenance (#574). The
    83	  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
    84	  # from before this feature: `clustering_resolve_category_universe(NULL)`
    85	  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
    86	  # so cache parity (memoise key = gene set + algorithm) is preserved.
    87	  selector_chr <- NULL
    88	  if (has_genes) {
    89	    genes_list <- as.character(unlist(genes_in))
    90	    kind <- "explicit"
    91	  } else if (category_supplied) {
    92	    universe <- clustering_resolve_category_universe(req$argsBody$category_filter)
    93	    genes_list <- universe$hgnc_ids
    94	    selector_chr <- universe$selector
    95	    kind <- "category"
    96	  } else {
    97	    universe <- clustering_resolve_category_universe(NULL)
    98	    genes_list <- universe$hgnc_ids
    99	    kind <- "all_ndd"
   100	  }
   101	
   102	  # Pre-fetch the STRING ID table because DB connections cannot cross the
   103	  # durable worker boundary.
   104	  string_id_table <- pool %>%
   105	    dplyr::tbl("non_alt_loci_set") %>%
   106	    dplyr::filter(!is.na(STRING_id)) %>%
   107	    dplyr::select(symbol, hgnc_id, STRING_id) %>%
   108	    dplyr::collect()
   109	
   110	  # Check for duplicate job (include algorithm in check). The selector is
   111	  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
   112	  # submits keep the pre-#574 dedup identity byte-identical.
   113	  dup_params <- list(genes = genes_list, algorithm = algorithm)
   114	  if (!is.null(selector_chr)) {
   115	    dup_params$category_filter <- selector_chr
   116	  }
   117	  dup_check <- check_duplicate_job("clustering", dup_params)
   118	  if (dup_check$duplicate) {
   119	    res$status <- 409
   120	    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
   121	    return(list(
   122	      error = "DUPLICATE_JOB",
   123	      message = "Identical job already running",
   124	      existing_job_id = dup_check$existing_job_id,
   125	      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
   126	    ))
   127	  }
   128	
   129	  # Cheap-path provenance (no expensive query yet). `selector_obj` records
   130	  # WHICH universe was resolved; `intended_fingerprint` records the STRING
   131	  # cache identity + fixed clustering params this submit intends to run
   132	  # with. The *effective* fingerprint (e.g. the STRING weight channel a
   133	  # computed result actually used) is only knowable from a computed result,
   134	  # so it is recorded separately in the cache-hit result meta below.
   135	  selector_obj <- list(kind = kind, category_filter = selector_chr)
   136	  intended_fingerprint <- list(
   137	    string_cache_fingerprint = analysis_string_cache_fingerprint(),
   138	    score_threshold = 400L,
   139	    algorithm = algorithm,
   140	    seed = 42L
   141	  )
   142	  gene_sha <- clustering_gene_list_sha256(genes_list)
   143	
   144	  # Source-data version: a CACHED, fail-closed read, fetched only now that a
   145	  # payload is actually about to be built -- its backing view runs global
   146	  # counts/joins, so it must never run before admission/dedup. A lookup
   147	  # failure must never silently record NA/broken provenance; fail the
   148	  # request closed instead.
   149	  src_ver <- tryCatch(
   150	    clustering_cached_source_data_version(conn = pool),
   151	    error = function(e) e
   152	  )
   153	  if (inherits(src_ver, "error")) {
   154	    res$status <- 503L
   155	    return(list(
   156	      error = "PROVENANCE_UNAVAILABLE",
   157	      message = "Snapshot source-data version unavailable; retry shortly."
   158	    ))
   159	  }
   160	
   161	  provenance <- list(
   162	    selector = selector_obj,
   163	    resolved_gene_count = length(genes_list),
   164	    gene_list_sha256 = gene_sha,
   165	    intended_fingerprint = intended_fingerprint,
   166	    source_data_version = src_ver
   167	  )
   168	
   169	  # Define category links (needed for result)
   170	  category_links <- tibble::tibble(
   171	    value = c(
   172	      "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
   173	      "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
   174	      "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
   175	    ),
   176	    link = c(
   177	      "https://www.ebi.ac.uk/QuickGO/term/",
   178	      "https://www.ebi.ac.uk/QuickGO/term/",
   179	      "https://disease-ontology.org/term/",
   180	      "https://www.ebi.ac.uk/QuickGO/term/",
   181	      "https://hpo.jax.org/browse/term/",
   182	      "http://www.ebi.ac.uk/interpro/entry/InterPro/",
   183	      "https://www.genome.jp/dbget-bin/www_bget?",
   184	      "https://www.uniprot.org/keywords/",
   185	      "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
   186	      "https://www.ebi.ac.uk/interpro/entry/pfam/",
   187	      "https://www.ncbi.nlm.nih.gov/search/all/?term=",
   188	      "https://www.ebi.ac.uk/QuickGO/term/",
   189	      "https://reactome.org/content/detail/R-",
   190	      "http://www.ebi.ac.uk/interpro/entry/smart/",
   191	      "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
   192	      "https://www.wikipathways.org/index.php/Pathway:"
   193	    )
   194	  )
   195	
   196	  # Cache-first: if the memoized function already has a cached result,
   197	  # return it immediately without submitting a durable worker job.
   198	  # The network_edges endpoint (graph) warms this cache on first load,
   199	  # so subsequent table requests resolve instantly.
   200	  cache_hit <- tryCatch(
   201	    memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
   202	    error = function(e) FALSE
   203	  )
   204	
   205	  if (cache_hit) {
   206	    cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)
   207	
   208	    categories <- cached_clusters %>%
   209	      dplyr::select(term_enrichment) %>%
   210	      tidyr::unnest(cols = c(term_enrichment)) %>%
   211	      dplyr::select(category) %>%
   212	      unique() %>%
   213	      dplyr::arrange(category) %>%
   214	      dplyr::mutate(
   215	        text = dplyr::case_when(
   216	          nchar(category) <= 5 ~ category,
   217	          nchar(category) > 5 ~ stringr::str_to_sentence(category)
   218	        )
   219	      ) %>%
   220	      dplyr::select(value = category, text) %>%
   221	      dplyr::left_join(category_links, by = c("value"))
   222	
   223	    # Splice the base cache-hit fields with `provenance` (already assembled
   224	    # above as selector/resolved_gene_count/gene_list_sha256/
   225	    # intended_fingerprint/source_data_version) via the shared
   226	    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
   227	    # re-listing the same fields as duplicate literals -- keeps this shape in
   228	    # lockstep with the worker-run handler's result meta by construction.
   229	    # `effective_fingerprint` is only knowable from the computed result
   230	    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
   231	    cache_result <- list(
   232	      clusters = cached_clusters,
   233	      categories = categories,
   234	      meta = clustering_result_meta(
   235	        list(
   236	          algorithm = algorithm,
   237	          gene_count = length(genes_list),
   238	          cluster_count = nrow(cached_clusters),
   239	          cache_hit = TRUE
   240	        ),
   241	        provenance,
   242	        attr(cached_clusters, "weight_channel")
   243	      )
   244	    )
   245	    cache_request_payload <- list(
   246	      genes = genes_list,
   247	      algorithm = algorithm,
   248	      category_links = category_links,
   249	      string_id_table = string_id_table,
   250	      provenance = provenance
   251	    )
   252	    if (!is.null(selector_chr)) {
   253	      cache_request_payload$category_filter <- selector_chr
   254	    }
   255	    completed_job <- async_job_service_store_completed(
   256	      job_type = "clustering",
   257	      request_payload = cache_request_payload,
   258	      result = cache_result,
   259	      submitted_by = req$user$user_id %||% NULL,
   260	      queue_name = "analysis",
   261	      priority = 50L
   262	    )
   263	    job_id <- completed_job$job_id[[1]]
   264	
   265	    res$status <- 202
   266	    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   267	    res$setHeader("Retry-After", "0")
   268	
   269	    return(list(
   270	      job_id = job_id,
   271	      status = "accepted",
   272	      estimated_seconds = 0,
   273	      status_url = paste0("/api/jobs/", job_id, "/status"),
   274	      meta = list(llm_generation = "snapshot_refresh_owned")
   275	    ))
   276	  }
   277	
   278	  # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
   279	  # "default" matches the queue create_job() enqueues on via async_job_service_submit.
   280	  if (async_job_capacity_exceeded(
   281	        tryCatch(
   282	          async_job_active_count("default"),
   283	          error = function(e) {
   284	            log_warn("async_job_active_count failed (capacity check fail-open): {e$message}")
   285	            0L
   286	          }
   287	        )
   288	      )) {
   289	    res$status <- 503
   290	    res$setHeader("Retry-After", "60")
   291	    return(list(
   292	      error = "CAPACITY_EXCEEDED",
   293	      message = "Analysis queue is at capacity. Please retry shortly.",
   294	      retry_after = 60
   295	    ))
   296	  }
   297	
   298	  # Cache miss - create async job
   299	  job_params <- list(
   300	    genes = genes_list,
   301	    algorithm = algorithm,
   302	    category_links = category_links,
   303	    string_id_table = string_id_table,
   304	    provenance = provenance
   305	  )
   306	  if (!is.null(selector_chr)) {
   307	    job_params$category_filter <- selector_chr
   308	  }
   309	  result <- create_job(
   310	    operation = "clustering",
   311	    params = job_params
   312	  )
   313	
   314	  # Check capacity
   315	  if (!is.null(result$error)) {
   316	    res$status <- 503
   317	    res$setHeader("Retry-After", as.character(result$retry_after))
   318	    return(result)
   319	  }
   320	
   321	  # Success - return HTTP 202 Accepted
   322	  res$status <- 202
   323	  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
   324	  res$setHeader("Retry-After", "5")
   325	
   326	  list(
   327	    job_id = result$job_id,
   328	    status = result$status,
   329	    estimated_seconds = result$estimated_seconds,
   330	    status_url = paste0("/api/jobs/", result$job_id, "/status")
   331	  )
   332	}

--- handler slices ---
4-# payload/progress/clustering helpers, the legacy-executor passthrough
5-# factory, the `async_job_handler_registry` list, and the
6-# `async_job_get_handler()` lookup.
7-#
8-# Family-specific handler definitions live in sibling files sourced BEFORE
9-# this one at every worker entrypoint, because the registry list below
10-# references handler functions by bare symbol and R evaluates a list()
11-# literal's elements eagerly at construction time:
12-#   - functions/async-job-network-layout-handlers.R (network_layout_prewarm)
13-#   - functions/async-job-analysis-snapshot-handlers.R (analysis_snapshot_refresh)
14-#   - functions/async-job-omim-apply.R (OMIM DB-write / additive-terms helpers)
15-#   - functions/async-job-force-apply-payload.R (force-apply payload-shape helpers)
16-#   - functions/async-job-provider-handlers.R (HGNC, PubTator, NDDScore,
17-#     disease-ontology mapping, OMIM update, force-apply-ontology)
18-#   - functions/async-job-maintenance-handlers.R (backup create/restore,
19-#     publication refresh/backfill)
20-# Restart the worker container after changing any of these (worker-executed
21-# code is sourced once at startup).
22:# NOTE: .async_job_run_clustering assembles its result meta via
23-# clustering_result_meta() (functions/clustering-gene-universe.R, #574). Every
24-# worker/API entrypoint sources that module via bootstrap_load_modules() before
25-# this file; a direct-source test env must source it too (as the async-job tests do).
26-
27-.async_job_after_success_noop <- function(result, job, payload, state, worker_config) {
28-  invisible(result)
29-}
30-.async_job_or <- function(value, fallback) {
31-  if (is.null(value) || length(value) == 0) {
32-    return(fallback)
33-  }
34-
35-  value
36-}
37-.async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
38-  if (!exists("create_async_job_progress_reporter", mode = "function")) {
39-    stop("create_async_job_progress_reporter() is required for durable async job handlers", call. = FALSE)
40-  }
--
80-    dplyr::select(category) |>
81-    unique() |>
82-    dplyr::arrange(category) |>
83-    dplyr::mutate(
84-      text = dplyr::case_when(
85-        nchar(category) <= 5 ~ category,
86-        nchar(category) > 5 ~ stringr::str_to_sentence(category)
87-      )
88-    ) |>
89-    dplyr::select(value = category, text)
90-
91-  if (!is.null(category_links)) {
92-    categories <- dplyr::left_join(categories, category_links, by = c("value"))
93-  }
94-
95-  categories
96-}
97-
98:.async_job_run_clustering <- function(job, payload, state, worker_config) {
99-  genes <- .async_job_payload_field(payload, "genes")
100-  algorithm <- .async_job_payload_scalar(payload, "algorithm")
101-  string_id_table <- .async_job_payload_field(payload, "string_id_table", required = FALSE)
102-  category_links <- .async_job_payload_field(payload, "category_links", required = FALSE)
103:  # #574 D3: the cheap-path selector/fingerprint provenance the submit
104-  # service (job-functional-submission-service.R) recorded in the payload.
105-  # Absent on legacy/explicit-genes payloads pre-dating #574 (required =
106-  # FALSE) so a worker-run job for those still completes normally.
107:  provenance <- .async_job_payload_field(payload, "provenance", required = FALSE)
108-  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
109-
110-  progress("cluster", "Running functional clustering...", current = 0, total = 1)
111-
112-  clusters <- gen_string_clust_obj(
113-    genes,
114-    algorithm = algorithm,
115-    string_id_table = string_id_table
116-  )
117-
118-  progress("complete", "Functional clustering complete", current = 1, total = 1)
119-
120-  # Mirror the cache-hit result meta shape (job-functional-submission-service.R)
121-  # via the shared `clustering_result_meta()` helper (clustering-gene-universe.R):
122-  # base fields (incl. cache_hit = FALSE, for shape parity with the cache-hit
123:  # path), then the request's cheap-path `provenance` (selector/
124-  # resolved_gene_count/gene_list_sha256/intended_fingerprint/
125:  # source_data_version) when present, then the `effective_fingerprint` --
126-  # only knowable now that `clusters` has actually been computed -- so a
127-  # silent exp+db -> combined-score STRING fallback on a worker-run job is
128-  # visible in the stored result too, not just a cache hit's.
129-  meta <- clustering_result_meta(
130-    list(
131-      algorithm = algorithm,
132-      gene_count = length(genes),
133-      cluster_count = nrow(clusters),
134-      cache_hit = FALSE
135-    ),
136:    provenance,
137-    attr(clusters, "weight_channel")
138-  )
139-
140-  list(
141-    clusters = clusters,
142-    categories = .async_job_functional_categories(clusters, category_links),
143-    meta = meta
144-  )
145-}
146-
147-.async_job_chain_llm <- function(result, job, cluster_type) {
148-  if (!exists("trigger_llm_batch_generation", mode = "function")) {
149-    return(invisible(result))
150-  }
151-
152-  llm_clusters <- result
153-
154-  if (is.list(result) && "clusters" %in% names(result) && !is.null(result[["clusters"]])) {
--
253-    rows_processed = nrow(disease_ontology_set),
254-    sources = c("MONDO", "OMIM"),
255-    output_file = paste0("data/disease_ontology_set.", format(Sys.Date(), "%Y-%m-%d"), ".csv")
256-  )
257-}
258-
259-.async_job_run_passthrough <- function(fn_name) {
260-  force(fn_name)
261-
262-  function(job, payload, state, worker_config) {
263-    fn <- base::get(fn_name, mode = "function")
264-    fn(.async_job_add_job_id(payload, job))
265-  }
266-}
267-
268-async_job_handler_registry <- list(
269-  clustering = list(
270-    cancel_mode = "best_effort",
271:    run = .async_job_run_clustering,
272-    after_success = function(result, job, payload, state, worker_config) {
273-      .async_job_chain_llm(result, job, cluster_type = "functional")
274-    }
275-  ),
276-  phenotype_clustering = list(
277-    cancel_mode = "best_effort",
278-    run = .async_job_run_phenotype_clustering,
279-    after_success = function(result, job, payload, state, worker_config) {
280-      .async_job_chain_llm(result, job, cluster_type = "phenotype")
281-    }
282-  ),
283-  ontology_update = list(
284-    cancel_mode = "non_interruptible",
285-    run = .async_job_run_ontology_update,
286-    after_success = .async_job_after_success_noop
287-  ),
288-  hgnc_update = list(
289-    cancel_mode = "non_interruptible",

--- endpoint ---
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

--- module ---
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
/bin/bash -lc 'nl -ba api/tests/testthat/test-integration-clustering-category-submit.R && nl -ba api/tests/testthat/test-unit-clustering-gene-universe.R && nl -ba api/tests/testthat/test-unit-clustering-handler-meta.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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
   158	    old_pool <- if (exists("pool", envir = .GlobalEnv)) get("pool", envir = .GlobalEnv) else NULL
   159	    assign("pool", conn, envir = .GlobalEnv)
   160	    withr::defer({
   161	      if (is.null(old_pool)) {
   162	        if (exists("pool", envir = .GlobalEnv)) rm(pool, envir = .GlobalEnv)
   163	      } else {
   164	        assign("pool", old_pool, envir = .GlobalEnv)
   165	      }
   166	    })
   167	
   168	    resolved <- clustering_resolve_category_universe(NULL, conn = conn)
   169	
   170	    # Meaningful, not tautological: compares against a DIRECT query against
   171	    # the real view, not against calling generate_ndd_hgnc_ids() a second
   172	    # time -- proves the NULL/default branch resolves the all-NDD universe
   173	    # correctly, independent of the resolver's own implementation.
   174	    direct <- DBI::dbGetQuery(
   175	      conn,
   176	      "SELECT DISTINCT hgnc_id FROM ndd_entity_view WHERE ndd_phenotype = 1"
   177	    )$hgnc_id
   178	
   179	    expect_setequal(resolved$hgnc_ids, direct)
   180	    expect_null(resolved$selector)
   181	    expect_identical(resolved$resolved_gene_count, length(direct))
   182	  })
   183	})
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
   113	testthat::skip_if_not_installed("RSQLite")
   114	
   115	# Source the code under test into a child env so the NULL-branch dependency
   116	# (`generate_ndd_hgnc_ids`) can be overridden per-test without touching
   117	# globalenv() or any other test file's bindings.
   118	.gene_universe_env <- function() {
   119	  e <- new.env(parent = globalenv())
   120	  source_api_file("core/errors.R", local = FALSE, envir = e)
   121	  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
   122	  e
   123	}
   124	
   125	# In-memory RSQLite fixture standing in for `pool`/a real DB connection.
   126	# `ev` = ndd_entity_view rows, `cats` = ndd_entity_status_categories_list rows.
   127	fake_conn <- function(ev, cats) {
   128	  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
   129	  DBI::dbWriteTable(con, "ndd_entity_view", as.data.frame(ev))
   130	  DBI::dbWriteTable(con, "ndd_entity_status_categories_list", as.data.frame(cats))
   131	  con
   132	}
   133	
   134	# Fixture: entity rows (one row per entity). TWO Definitive NDD genes so the
   135	# ["Definitive"] universe passes the >=2 guard.
   136	ev <- tibble::tribble(
   137	  ~entity_id, ~hgnc_id,  ~ndd_phenotype, ~category,
   138	  1L,        "HGNC:1",   1L,             "Definitive",   # gene 1: Definitive + Limited
   139	  2L,        "HGNC:1",   1L,             "Limited",
   140	  3L,        "HGNC:2",   1L,             "Limited",      # gene 2: Limited only
   141	  4L,        "HGNC:3",   0L,             "Definitive",   # gene 3: Definitive but NON-NDD
   142	  5L,        "HGNC:4",   1L,             "Moderate",     # gene 4: Moderate NDD (single -> too-small alone)
   143	  6L,        "HGNC:5",   1L,             "Definitive"    # gene 5: second Definitive NDD gene
   144	)
   145	cats <- tibble::tibble(
   146	  category = c("Definitive", "Moderate", "Limited", "Refuted", "not applicable"),
   147	  is_active = 1L
   148	)
   149	
   150	test_that("Definitive selects genes with any Definitive NDD entity (multi-entity gene included)", {
   151	  e <- .gene_universe_env()
   152	  con <- fake_conn(ev, cats)
   153	  withr::defer(DBI::dbDisconnect(con))
   154	
   155	  r <- e$clustering_resolve_category_universe("Definitive", conn = con)
   156	
   157	  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5")) # HGNC:2 Limited-only excluded; HGNC:3 non-NDD excluded
   158	  expect_identical(r$selector, "Definitive")
   159	  expect_identical(r$resolved_gene_count, 2L)
   160	})
   161	
   162	test_that("multi-value selector is a union across categories", {
   163	  e <- .gene_universe_env()
   164	  con <- fake_conn(ev, cats)
   165	  withr::defer(DBI::dbDisconnect(con))
   166	
   167	  r <- e$clustering_resolve_category_universe(c("Definitive", "Moderate"), conn = con)
   168	
   169	  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5", "HGNC:4"))
   170	})
   171	
   172	test_that("NULL selector returns all NDD genes, order-identical to generate_ndd_hgnc_ids()", {
   173	  e <- .gene_universe_env()
   174	  con <- fake_conn(ev, cats)
   175	  withr::defer(DBI::dbDisconnect(con))
   176	  e$generate_ndd_hgnc_ids <- function() {
   177	    tibble::tibble(hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5"))
   178	  }
   179	
   180	  r <- e$clustering_resolve_category_universe(NULL, conn = con)
   181	
   182	  expect_identical(r$hgnc_ids, c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5")) # arrange(entity_id)+distinct, ndd_phenotype==1
   183	  expect_null(r$selector)
   184	})
   185	
   186	test_that("unknown token is rejected 400 with the allowed set in the MESSAGE (not detail)", {
   187	  e <- .gene_universe_env()
   188	  con <- fake_conn(ev, cats)
   189	  withr::defer(DBI::dbDisconnect(con))
   190	
   191	  err <- tryCatch(
   192	    e$clustering_resolve_category_universe("Definative", conn = con),
   193	    error = function(err) err
   194	  )
   195	
   196	  expect_s3_class(err, "error_400")
   197	  expect_match(conditionMessage(err), "Definitive") # allowed set is in the message so it reaches clients
   198	})
   199	
   200	test_that("supplied-but-empty selector is 400 (NOT the all-NDD default)", {
   201	  e <- .gene_universe_env()
   202	  con <- fake_conn(ev, cats)
   203	  withr::defer(DBI::dbDisconnect(con))
   204	
   205	  expect_error(e$clustering_resolve_category_universe(list(), conn = con), class = "error_400")
   206	  expect_error(e$clustering_resolve_category_universe(list("   "), conn = con), class = "error_400")
   207	})
   208	
   209	test_that("a valid category resolving to < 2 genes is rejected 400 (no degenerate-graph job)", {
   210	  e <- .gene_universe_env()
   211	  con <- fake_conn(ev, cats)
   212	  withr::defer(DBI::dbDisconnect(con))
   213	
   214	  expect_error(e$clustering_resolve_category_universe("Refuted", conn = con), class = "error_400") # 0 genes
   215	  expect_error(e$clustering_resolve_category_universe("Moderate", conn = con), class = "error_400") # 1 gene
   216	})
   217	
   218	test_that("gene_list_sha256 is sort-order independent", {
   219	  e <- .gene_universe_env()
   220	
   221	  expect_identical(
   222	    e$clustering_gene_list_sha256(c("HGNC:3", "HGNC:1")),
   223	    e$clustering_gene_list_sha256(c("HGNC:1", "HGNC:3"))
   224	  )
   225	})
   226	
   227	test_that("clustering_normalize_category_filter: absent (NULL) vs supplied-but-empty are distinct", {
   228	  e <- .gene_universe_env()
   229	
   230	  expect_null(e$clustering_normalize_category_filter(NULL))
   231	  expect_identical(e$clustering_normalize_category_filter(list()), character(0))
   232	  expect_identical(e$clustering_normalize_category_filter(list("   ")), character(0))
   233	  expect_identical(e$clustering_normalize_category_filter(list("")), character(0))
   234	  expect_identical(
   235	    e$clustering_normalize_category_filter(c("Moderate", "Definitive", "Definitive")),
   236	    c("Definitive", "Moderate")
   237	  )
   238	})
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
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-job-endpoint-services.R | sed -n '1,460p' && nl -ba api/tests/testthat/job-endpoint-services-fixtures.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# tests/testthat/test-unit-job-endpoint-services.R
     2	#
     3	# Host-runnable unit tests for the PUBLIC clustering submission services extracted
     4	# from endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5): job-functional-
     5	# submission-service.R and job-phenotype-submission-service.R. The maintenance-
     6	# submission (job-maintenance-submission-service.R) and query-endpoint
     7	# (job-query-endpoint-service.R) services are covered in the sibling
     8	# test-unit-job-endpoint-services-maintenance.R. Shared fixtures live in
     9	# job-endpoint-services-fixtures.R (explicitly sourced below). Split this way to keep
    10	# every file under the 600-line ceiling (#535 S6).
    11	#
    12	# Each service is sourced directly into an isolated environment via sys.source()
    13	# (mirrors test-unit-job-status-result-mode.R), and every bare global name the service
    14	# body references (pool, dw, check_duplicate_job, create_job, async_job_capacity_exceeded,
    15	# async_job_active_count, async_job_service_store_completed, gen_string_clust_obj_mem,
    16	# gen_mca_clust_obj_mem, log_warn, ...) is stubbed in that environment, so the tests
    17	# exercise pure request/response logic without a live DB or mirai daemon pool.
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
    34	## job-functional-submission-service.R
    35	## -------------------------------------------------------------------##
    36	
    37	job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
    38	  tables <- list(
    39	    non_alt_loci_set = tibble::tibble(
    40	      symbol = c("A", "B"),
    41	      hgnc_id = c("HGNC:1", "HGNC:3"),
    42	      STRING_id = c("9606.P1", "9606.P2")
    43	    )
    44	  )
    45	  if (!is.null(ndd_entity_view)) {
    46	    tables$ndd_entity_view <- ndd_entity_view
    47	  }
    48	  job_endpoint_fake_pool(env, tables)
    49	}
    50	
    51	#' Default no-arg (all-NDD) universe stub for `clustering_resolve_category_universe()`
    52	#' (#574 D2): reads `ndd_phenotype == 1` rows straight off `env$pool`'s fake
    53	#' `ndd_entity_view`, mirroring what the real resolver's NULL branch
    54	#' (`generate_ndd_hgnc_ids()`) would compute -- without needing the real
    55	#' function (and its DB-query internals) sourced into these isolated envs.
    56	job_endpoint_stub_all_ndd_universe <- function(env) {
    57	  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
    58	    testthat::expect_null(category_filter)
    59	    tbl <- env$pool$tables$ndd_entity_view
    60	    hgnc_ids <- unique(dplyr::pull(dplyr::filter(tbl, ndd_phenotype == 1), hgnc_id))
    61	    list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids))
    62	  }
    63	}
    64	
    65	#' Cheap provenance stubs (#574 D2): every submit path that reaches past dedup
    66	#' now computes `intended_fingerprint`/`gene_list_sha256`/`source_data_version`
    67	#' regardless of selector kind, so any test reaching that far needs these
    68	#' three bare globals stubbed even when it does not care about their values.
    69	job_endpoint_stub_clustering_provenance <- function(env) {
    70	  env$analysis_string_cache_fingerprint <- function() "fp-test"
    71	  env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
    72	  env$clustering_cached_source_data_version <- function(...) "srcv-test"
    73	}
    74	
    75	test_that("functional clustering: default genes are drawn from ndd_entity_view when omitted", {
    76	  env <- job_endpoint_source_service("job-functional-submission-service.R")
    77	  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
    78	    entity_id = 1:3,
    79	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    80	    ndd_phenotype = c(1L, 0L, 1L)
    81	  ))
    82	  job_endpoint_stub_all_ndd_universe(env)
    83	  captured <- NULL
    84	  env$check_duplicate_job <- function(operation, params) {
    85	    captured <<- params
    86	    list(duplicate = TRUE, existing_job_id = "dup-1")
    87	  }
    88	  req <- list(argsBody = list(), user = list(user_id = NULL))
    89	  res <- job_endpoint_fake_res()
    90	
    91	  out <- env$svc_job_submit_functional_clustering(req, res)
    92	
    93	  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
    94	  expect_equal(captured$algorithm, "leiden")
    95	  expect_equal(res$status, 409)
    96	  expect_equal(out$error, "DUPLICATE_JOB")
    97	  expect_match(res$headers[["Location"]], "/api/jobs/dup-1/status")
    98	})
    99	
   100	job_endpoint_capture_functional_algorithm <- function(algorithm_body) {
   101	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   102	  env$pool <- job_endpoint_functional_pool(env)
   103	  captured <- NULL
   104	  env$check_duplicate_job <- function(operation, params) {
   105	    captured <<- params
   106	    list(duplicate = TRUE, existing_job_id = "dup-1")
   107	  }
   108	  req <- list(argsBody = list(genes = list("HGNC:9"), algorithm = algorithm_body), user = list(user_id = NULL))
   109	  env$svc_job_submit_functional_clustering(req, job_endpoint_fake_res())
   110	  captured$algorithm
   111	}
   112	
   113	test_that("functional clustering: algorithm input is coerced to a lowercase scalar, invalid falls back to leiden", {
   114	  expect_equal(job_endpoint_capture_functional_algorithm(list("WALKTRAP", "ignored")), "walktrap")
   115	  expect_equal(job_endpoint_capture_functional_algorithm("bogus"), "leiden")
   116	})
   117	
   118	test_that("functional clustering: cache hit stores a completed job without calling create_job", {
   119	  local_mocked_bindings(
   120	    has_cache = function(f) function(...) TRUE,
   121	    .package = "memoise"
   122	  )
   123	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   124	  env$pool <- job_endpoint_functional_pool(env)
   125	  job_endpoint_stub_clustering_provenance(env)
   126	  env$gen_string_clust_obj_mem <- function(genes, algorithm = "leiden") {
   127	    clusters <- tibble::tibble(term_enrichment = list(tibble::tibble(category = "HPO")))
   128	    # Set on the served membership, mirroring what the real STRING resolver
   129	    # attaches (#514 channel observability) -- the cache-hit meta must carry
   130	    # this through as `effective_fingerprint$weight_channel`.
   131	    attr(clusters, "weight_channel") <- "experimental_database"
   132	    clusters
   133	  }
   134	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   135	  store_args <- NULL
   136	  env$async_job_service_store_completed <- function(...) {
   137	    store_args <<- list(...)
   138	    tibble::tibble(job_id = "cached-job-1")
   139	  }
   140	  create_job_called <- FALSE
   141	  env$create_job <- function(...) {
   142	    create_job_called <<- TRUE
   143	  }
   144	  req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = 42L))
   145	  res <- job_endpoint_fake_res()
   146	
   147	  out <- env$svc_job_submit_functional_clustering(req, res)
   148	
   149	  expect_false(create_job_called)
   150	  expect_equal(res$status, 202)
   151	  expect_equal(res$headers[["Retry-After"]], "0")
   152	  expect_equal(out$job_id, "cached-job-1")
   153	  expect_equal(out$meta$llm_generation, "snapshot_refresh_owned")
   154	  expect_equal(store_args$submitted_by, 42L)
   155	
   156	  # #574 D2 review fix: the cache-hit `result` (the job's stored, served
   157	  # payload -- distinct from `out`, the submit response) must carry the full
   158	  # provenance block through `meta`, not just the two fields asserted above.
   159	  result_meta <- store_args$result$meta
   160	  expect_equal(result_meta$effective_fingerprint$weight_channel, "experimental_database")
   161	  expect_equal(result_meta$selector$kind, "explicit")
   162	  expect_equal(result_meta$gene_list_sha256, "sha-1") # job_endpoint_stub_clustering_provenance: paste0("sha-", length(genes))
   163	  expect_equal(result_meta$source_data_version, "srcv-test") # job_endpoint_stub_clustering_provenance stub token
   164	})
   165	
   166	test_that("functional clustering: capacity guard (503) then a cache miss under capacity (202)", {
   167	  req <- list(argsBody = list(genes = list("HGNC:1"), algorithm = "walktrap"), user = list(user_id = NULL))
   168	
   169	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   170	  env$pool <- job_endpoint_functional_pool(env)
   171	  job_endpoint_stub_clustering_provenance(env)
   172	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   173	  env$async_job_capacity_exceeded <- function(...) TRUE
   174	  env$async_job_active_count <- function(...) 99L
   175	  res <- job_endpoint_fake_res()
   176	  out <- env$svc_job_submit_functional_clustering(req, res)
   177	  expect_equal(res$status, 503)
   178	  expect_equal(res$headers[["Retry-After"]], "60")
   179	  expect_equal(out$error, "CAPACITY_EXCEEDED")
   180	
   181	  env$async_job_capacity_exceeded <- function(...) FALSE
   182	  create_job_operation <- NULL
   183	  create_job_params <- NULL
   184	  env$create_job <- function(operation, params) {
   185	    create_job_operation <<- operation
   186	    create_job_params <<- params
   187	    list(job_id = "new-job-1", status = "accepted", estimated_seconds = 30)
   188	  }
   189	  res <- job_endpoint_fake_res()
   190	  out <- env$svc_job_submit_functional_clustering(req, res)
   191	  expect_equal(res$status, 202)
   192	  expect_equal(res$headers[["Retry-After"]], "5")
   193	  expect_equal(out$job_id, "new-job-1")
   194	  expect_equal(create_job_operation, "clustering")
   195	  expect_setequal(
   196	    names(create_job_params),
   197	    # #574 D2: every submit path now carries a `provenance` block; explicit/
   198	    # no-arg submits still omit `category_filter` (asserted separately below).
   199	    c("genes", "algorithm", "category_links", "string_id_table", "provenance")
   200	  )
   201	  expect_false("category_filter" %in% names(create_job_params))
   202	})
   203	
   204	test_that("functional clustering: admission throttle runs FIRST, before any DB/cache work", {
   205	  # #535 S6 BLOCKER fix: a throttle block must short-circuit before the cache/dup/DB
   206	  # path so an abusive caller cannot bypass the limit or grow async_jobs via cache
   207	  # hits. The guard returning admitted=FALSE must return its response and touch nothing.
   208	  req <- list(argsBody = list(genes = list("HGNC:1")), user = list(user_id = NULL))
   209	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   210	  pool_touched <- FALSE
   211	  env$pool <- structure(list(), class = "trap_pool")
   212	  env$tbl.trap_pool <- function(src, from, ...) {
   213	    pool_touched <<- TRUE
   214	    stop("DB must not be touched when the throttle blocks")
   215	  }
   216	  create_job_called <- FALSE
   217	  env$create_job <- function(...) {
   218	    create_job_called <<- TRUE
   219	    NULL
   220	  }
   221	  env$async_job_submit_admission_guard <- function(req, res) {
   222	    res$status <- 429
   223	    res$setHeader("Retry-After", "42")
   224	    list(admitted = FALSE, response = list(error = "RATE_LIMITED", retry_after = 42L))
   225	  }
   226	  res <- job_endpoint_fake_res()
   227	  out <- env$svc_job_submit_functional_clustering(req, res)
   228	  expect_equal(res$status, 429)
   229	  expect_equal(out$error, "RATE_LIMITED")
   230	  expect_false(pool_touched)
   231	  expect_false(create_job_called)
   232	})
   233	
   234	## -------------------------------------------------------------------##
   235	## job-functional-submission-service.R: category_filter (#574 D2)
   236	## -------------------------------------------------------------------##
   237	
   238	test_that("functional clustering: genes and category_filter are mutually exclusive -> error_400", {
   239	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   240	  # stop_for_bad_request() lives in core/errors.R, not sourced by the isolated
   241	  # service env by default -- source it here so the real (non-stubbed)
   242	  # mutual-exclusion guard in the service body can raise it.
   243	  source_api_file("core/errors.R", local = FALSE, envir = env)
   244	  env$pool <- job_endpoint_functional_pool(env)
   245	  req <- list(
   246	    argsBody = list(genes = list("HGNC:1"), category_filter = list("Definitive")),
   247	    user = list(user_id = NULL)
   248	  )
   249	  res <- job_endpoint_fake_res()
   250	
   251	  expect_error(
   252	    env$svc_job_submit_functional_clustering(req, res),
   253	    class = "error_400"
   254	  )
   255	})
   256	
   257	test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
   258	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   259	  env$pool <- job_endpoint_functional_pool(env)
   260	  job_endpoint_stub_clustering_provenance(env)
   261	  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
   262	    expect_identical(category_filter, list("Definitive"))
   263	    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
   264	  }
   265	  env$check_duplicate_job <- function(operation, params) {
   266	    expect_true("category_filter" %in% names(params))
   267	    expect_identical(params$category_filter, "Definitive")
   268	    list(duplicate = FALSE)
   269	  }
   270	  env$async_job_capacity_exceeded <- function(...) FALSE
   271	  env$async_job_active_count <- function(...) 0L
   272	  captured <- NULL
   273	  env$create_job <- function(operation, params) {
   274	    captured <<- params
   275	    list(job_id = "j1", status = "accepted", estimated_seconds = 5)
   276	  }
   277	  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
   278	  res <- job_endpoint_fake_res()
   279	
   280	  out <- env$svc_job_submit_functional_clustering(req, res)
   281	
   282	  expect_equal(res$status, 202)
   283	  expect_identical(captured$category_filter, "Definitive")
   284	  expect_identical(captured$genes, c("HGNC:1", "HGNC:5"))
   285	  expect_identical(captured$provenance$selector$kind, "category")
   286	  expect_identical(captured$provenance$selector$category_filter, "Definitive")
   287	  expect_true(all(
   288	    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
   289	      names(captured$provenance)
   290	  ))
   291	})
   292	
   293	test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
   294	  # Explicit genes.
   295	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   296	  env$pool <- job_endpoint_functional_pool(env)
   297	  job_endpoint_stub_clustering_provenance(env)
   298	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   299	  env$async_job_capacity_exceeded <- function(...) FALSE
   300	  env$async_job_active_count <- function(...) 0L
   301	  captured_explicit <- NULL
   302	  env$create_job <- function(operation, params) {
   303	    captured_explicit <<- params
   304	    list(job_id = "j2", status = "accepted", estimated_seconds = 5)
   305	  }
   306	  req_explicit <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   307	  env$svc_job_submit_functional_clustering(req_explicit, job_endpoint_fake_res())
   308	
   309	  expect_false("category_filter" %in% names(captured_explicit))
   310	  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
   311	  expect_null(captured_explicit$provenance$selector$category_filter)
   312	
   313	  # No-arg (all-NDD default).
   314	  env2 <- job_endpoint_source_service("job-functional-submission-service.R")
   315	  env2$pool <- job_endpoint_functional_pool(env2, tibble::tibble(
   316	    entity_id = 1:2, hgnc_id = c("HGNC:1", "HGNC:2"), ndd_phenotype = c(1L, 1L)
   317	  ))
   318	  job_endpoint_stub_clustering_provenance(env2)
   319	  job_endpoint_stub_all_ndd_universe(env2)
   320	  env2$check_duplicate_job <- function(...) list(duplicate = FALSE)
   321	  env2$async_job_capacity_exceeded <- function(...) FALSE
   322	  env2$async_job_active_count <- function(...) 0L
   323	  captured_no_arg <- NULL
   324	  env2$create_job <- function(operation, params) {
   325	    captured_no_arg <<- params
   326	    list(job_id = "j3", status = "accepted", estimated_seconds = 5)
   327	  }
   328	  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
   329	  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())
   330	
   331	  expect_false("category_filter" %in% names(captured_no_arg))
   332	  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
   333	  expect_null(captured_no_arg$provenance$selector$category_filter)
   334	})
   335	
   336	test_that("functional clustering: request_hash is selector-aware for category_filter", {
   337	  # Pure-function coverage of the underlying dedup identity: sourced directly
   338	  # (not via the service env) since these are free functions in
   339	  # functions/async-job-service.R, not bare globals the service references.
   340	  hash_env <- new.env(parent = globalenv())
   341	  sys.source(file.path(get_api_dir(), "functions", "async-job-service.R"), envir = hash_env)
   342	
   343	  h <- function(genes, algo, cf) {
   344	    payload <- c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))
   345	    hash_env$async_job_service_request_hash(
   346	      "clustering",
   347	      hash_env$async_job_service_payload_json(payload)
   348	    )
   349	  }
   350	  g <- c("HGNC:1", "HGNC:5")
   351	
   352	  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
   353	  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
   354	  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
   355	})
   356	
   357	test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
   358	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   359	  env$pool <- job_endpoint_functional_pool(env)
   360	  env$analysis_string_cache_fingerprint <- function() "fp-test"
   361	  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
   362	  env$clustering_cached_source_data_version <- function(...) stop("boom")
   363	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   364	  create_job_called <- FALSE
   365	  env$create_job <- function(...) {
   366	    create_job_called <<- TRUE
   367	    NULL
   368	  }
   369	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   370	  res <- job_endpoint_fake_res()
   371	
   372	  out <- env$svc_job_submit_functional_clustering(req, res)
   373	
   374	  expect_equal(res$status, 503L)
   375	  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
   376	  expect_false(create_job_called)
   377	})
   378	
   379	## -------------------------------------------------------------------##
   380	## job-phenotype-submission-service.R
   381	## -------------------------------------------------------------------##
   382	
   383	job_endpoint_phenotype_single_entity_pool <- function(env) {
   384	  job_endpoint_fake_pool(env, list(
   385	    ndd_entity_view = tibble::tibble(
   386	      entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1",
   387	      ndd_phenotype = 1L, category = "Definitive"
   388	    ),
   389	    ndd_entity_review = tibble::tibble(
   390	      review_id = 1L, entity_id = 1L, is_primary = 1L, review_approved = 1L
   391	    ),
   392	    ndd_review_phenotype_connect = tibble::tibble(
   393	      review_id = 1L, entity_id = 1L, modifier_id = 1L,
   394	      phenotype_id = "HP:0000001", hpo_mode_of_inheritance_term_name = "AD"
   395	    ),
   396	    modifier_list = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
   397	    phenotype_list = tibble::tibble(phenotype_id = "HP:0000001", HPO_term = "Term1")
   398	  ))
   399	}
   400	
   401	test_that("phenotype clustering: review set is gated on is_primary AND review_approved", {
   402	  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
   403	  env$pool <- job_endpoint_fake_pool(env, list(
   404	    ndd_entity_view = tibble::tibble(
   405	      entity_id = c(1L, 2L), hgnc_id = c("HGNC:1", "HGNC:2"), symbol = c("GENE1", "GENE2"),
   406	      ndd_phenotype = c(1L, 1L), category = c("Definitive", "Definitive")
   407	    ),
   408	    # review_id 1: primary + approved (kept). review_id 2: primary but NOT
   409	    # approved (must be dropped). review_id 3: approved but NOT primary
   410	    # (must be dropped) — the #3/Codex-PR-2 guard this test protects.
   411	    ndd_entity_review = tibble::tibble(
   412	      review_id = c(1L, 2L, 3L), entity_id = c(1L, 1L, 2L),
   413	      is_primary = c(1L, 1L, 0L), review_approved = c(1L, 0L, 1L)
   414	    ),
   415	    ndd_review_phenotype_connect = tibble::tibble(
   416	      review_id = c(1L, 2L, 3L), entity_id = c(1L, 1L, 2L), modifier_id = c(1L, 1L, 1L),
   417	      phenotype_id = c("HP:0000001", "HP:0000002", "HP:0000001"),
   418	      hpo_mode_of_inheritance_term_name = c("AD", "AD", "AD")
   419	    ),
   420	    modifier_list = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
   421	    phenotype_list = tibble::tibble(
   422	      phenotype_id = c("HP:0000001", "HP:0000002"), HPO_term = c("Term1", "Term2")
   423	    )
   424	  ))
   425	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   426	  env$async_job_capacity_exceeded <- function(...) FALSE
   427	  env$async_job_active_count <- function(...) 0L
   428	  captured_params <- NULL
   429	  env$create_job <- function(operation, params) {
   430	    captured_params <<- params
   431	    list(job_id = "job-x", status = "accepted", estimated_seconds = 30)
   432	  }
   433	  req <- list(user = list(user_id = NULL))
   434	  res <- job_endpoint_fake_res()
   435	
   436	  env$svc_job_submit_phenotype_clustering(req, res)
   437	
   438	  # Only review_id 1 (primary + approved) survives the gather step; review 2
   439	  # (unapproved) and review 3 (not primary) must never reach the clustering
   440	  # input, even though review 2 is attached to the same (otherwise-included)
   441	  # entity_id as review 1.
   442	  expect_equal(captured_params$ndd_entity_review_tbl$review_id, 1L)
   443	})
   444	
   445	test_that("phenotype clustering: duplicate job returns 409 with Location", {
   446	  env <- job_endpoint_source_service("job-phenotype-submission-service.R")
   447	  env$pool <- job_endpoint_phenotype_single_entity_pool(env)
   448	  env$check_duplicate_job <- function(...) list(duplicate = TRUE, existing_job_id = "dup-pheno")
   449	  req <- list(user = list(user_id = NULL))
   450	  res <- job_endpoint_fake_res()
   451	
   452	  out <- env$svc_job_submit_phenotype_clustering(req, res)
   453	
   454	  expect_equal(res$status, 409)
   455	  expect_equal(out$error, "DUPLICATE_JOB")
   456	  expect_match(res$headers[["Location"]], "/api/jobs/dup-pheno/status")
   457	})
   458	
   459	test_that("phenotype clustering: cache hit stores a completed job without calling create_job", {
   460	  local_mocked_bindings(
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

exec
/bin/bash -lc "rg -n -C 8 'analysis_snapshot_source_data_version|generate_ndd_hgnc_ids|check_duplicate_job|create_job|async_job_service_store_completed' api/functions api/services | head -n 500" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/services/job-maintenance-submission-service.R-13-# DB credentials (#535 S2b): `hgnc_update` and `comparisons_update` no longer
api/services/job-maintenance-submission-service.R-14-# marshal a `db_config` into the job payload. Their durable handlers
api/services/job-maintenance-submission-service.R-15-# (.async_job_run_hgnc_update / comparisons_update_async) resolve DB creds at
api/services/job-maintenance-submission-service.R-16-# run time from the worker's runtime config via `async_job_db_connect()`, so no
api/services/job-maintenance-submission-service.R-17-# password is ever persisted in `async_jobs.request_payload_json`. They also
api/services/job-maintenance-submission-service.R-18-# dedupe via job-type single-flight (`async_job_service_duplicate_by_type()`),
api/services/job-maintenance-submission-service.R-19-# not a payload hash, so a full-table-replace maintenance job never runs
api/services/job-maintenance-submission-service.R-20-# concurrently — including across a deploy that changes its payload schema.
api/services/job-maintenance-submission-service.R:21:# `create_job()` submits only the operation and payload; registered durable
api/services/job-maintenance-submission-service.R-22-# handlers execute the work.
api/services/job-maintenance-submission-service.R-23-#
api/services/job-maintenance-submission-service.R-24-# This is an ENDPOINT service: it is sourced by the shared bootstrap loader
api/services/job-maintenance-submission-service.R-25-# (api/bootstrap/load_modules.R) like any other services/* file, and only ever
api/services/job-maintenance-submission-service.R-26-# submits durable jobs (`async_job_service_submit()`); the worker executes the
api/services/job-maintenance-submission-service.R-27-# registered handlers, never these svc_ functions.
api/services/job-maintenance-submission-service.R-28-
api/services/job-maintenance-submission-service.R-29-#' Submit a disease ontology update job (MONDO + OMIM).
--
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
api/services/job-maintenance-submission-service.R:65:  result <- create_job(
api/services/job-maintenance-submission-service.R-66-    operation = "ontology_update",
api/services/job-maintenance-submission-service.R-67-    params = list(
api/services/job-maintenance-submission-service.R-68-      hgnc_list = hgnc_list,
api/services/job-maintenance-submission-service.R-69-      mode_of_inheritance_list = mode_of_inheritance_list
api/services/job-maintenance-submission-service.R-70-    )
api/services/job-maintenance-submission-service.R-71-  )
api/services/job-maintenance-submission-service.R-72-
api/services/job-maintenance-submission-service.R-73-  # Check capacity
--
api/services/job-maintenance-submission-service.R-109-      message = "HGNC update job already running",
api/services/job-maintenance-submission-service.R-110-      existing_job_id = dup_check$existing_job_id,
api/services/job-maintenance-submission-service.R-111-      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
api/services/job-maintenance-submission-service.R-112-    ))
api/services/job-maintenance-submission-service.R-113-  }
api/services/job-maintenance-submission-service.R-114-
api/services/job-maintenance-submission-service.R-115-  # Create async job for HGNC update pipeline
api/services/job-maintenance-submission-service.R-116-  # gnomAD enrichment now uses bulk TSV download (~10s), Ensembl/STRINGdb are the bottleneck
api/services/job-maintenance-submission-service.R:117:  result <- create_job(
api/services/job-maintenance-submission-service.R-118-    operation = "hgnc_update",
api/services/job-maintenance-submission-service.R-119-    params = list()
api/services/job-maintenance-submission-service.R-120-  )
api/services/job-maintenance-submission-service.R-121-
api/services/job-maintenance-submission-service.R-122-  # Check capacity
api/services/job-maintenance-submission-service.R-123-  if (!is.null(result$error)) {
api/services/job-maintenance-submission-service.R-124-    res$status <- 503
api/services/job-maintenance-submission-service.R-125-    res$setHeader("Retry-After", as.character(result$retry_after))
--
api/services/job-maintenance-submission-service.R-158-      message = "Comparisons update job already running",
api/services/job-maintenance-submission-service.R-159-      existing_job_id = dup_check$existing_job_id,
api/services/job-maintenance-submission-service.R-160-      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
api/services/job-maintenance-submission-service.R-161-    ))
api/services/job-maintenance-submission-service.R-162-  }
api/services/job-maintenance-submission-service.R-163-
api/services/job-maintenance-submission-service.R-164-  # Create async job for comparisons update
api/services/job-maintenance-submission-service.R-165-  # Downloads from 7+ sources can take 5-30 minutes depending on network
api/services/job-maintenance-submission-service.R:166:  result <- create_job(
api/services/job-maintenance-submission-service.R-167-    operation = "comparisons_update",
api/services/job-maintenance-submission-service.R-168-    params = list()
api/services/job-maintenance-submission-service.R-169-  )
api/services/job-maintenance-submission-service.R-170-
api/services/job-maintenance-submission-service.R-171-  # Check capacity
api/services/job-maintenance-submission-service.R-172-  if (!is.null(result$error)) {
api/services/job-maintenance-submission-service.R-173-    res$status <- 503
api/services/job-maintenance-submission-service.R-174-    res$setHeader("Retry-After", as.character(result$retry_after))
--
api/services/admin-ontology-endpoint-service.R-1-# api/services/admin-ontology-endpoint-service.R
api/services/admin-ontology-endpoint-service.R-2-#
api/services/admin-ontology-endpoint-service.R-3-# Service layer for the Administrator ontology/HGNC/deprecated-entity family
api/services/admin-ontology-endpoint-service.R-4-# extracted from api/endpoints/admin_endpoints.R (issue #346, Wave 3).
api/services/admin-ontology-endpoint-service.R-5-#
api/services/admin-ontology-endpoint-service.R-6-# Endpoint shells keep their `require_role(req, res, "Administrator")` gate,
api/services/admin-ontology-endpoint-service.R-7-# route decorators, and formals byte-identical; the route bodies below are
api/services/admin-ontology-endpoint-service.R-8-# unchanged logic, only relocated. `force_apply_ontology`'s cheap
api/services/admin-ontology-endpoint-service.R:9:# `blocked_job_id` presence guard and the final `create_job()` submission stay
api/services/admin-ontology-endpoint-service.R-10-# inline in the endpoint (test-endpoint-admin.R asserts those substrings
api/services/admin-ontology-endpoint-service.R-11-# directly against admin_endpoints.R's source); this service supplies the
api/services/admin-ontology-endpoint-service.R-12-# heavier blocked-job lookup/validation between them.
api/services/admin-ontology-endpoint-service.R-13-#
api/services/admin-ontology-endpoint-service.R-14-# All DB-facing calls accept their collaborator as an injectable parameter
api/services/admin-ontology-endpoint-service.R-15-# (default = the real global function) so unit tests can supply fakes without
api/services/admin-ontology-endpoint-service.R-16-# a live database; see test-unit-admin-endpoint-services.R.
api/services/admin-ontology-endpoint-service.R-17-
api/services/admin-ontology-endpoint-service.R-18-#' PUT /admin/update_ontology_async body.
api/services/admin-ontology-endpoint-service.R-19-#'
api/services/admin-ontology-endpoint-service.R-20-#' Pre-fetches the tables the daemon worker cannot reach directly, then
api/services/admin-ontology-endpoint-service.R-21-#' submits (or returns the existing) `omim_update` durable job.
api/services/admin-ontology-endpoint-service.R-22-#'
api/services/admin-ontology-endpoint-service.R-23-#' @export
api/services/admin-ontology-endpoint-service.R-24-svc_admin_ontology_update_async <- function(req, res, pool,
api/services/admin-ontology-endpoint-service.R-25-                                             duplicate_check_fn = check_active_job_by_type,
api/services/admin-ontology-endpoint-service.R:26:                                             create_job_fn = create_job) {
api/services/admin-ontology-endpoint-service.R-27-  mode_of_inheritance_list <- pool %>%
api/services/admin-ontology-endpoint-service.R-28-    tbl("mode_of_inheritance_list") %>%
api/services/admin-ontology-endpoint-service.R-29-    dplyr::select(-is_active, -sort) %>%
api/services/admin-ontology-endpoint-service.R-30-    collect()
api/services/admin-ontology-endpoint-service.R-31-
api/services/admin-ontology-endpoint-service.R-32-  non_alt_loci_set <- pool %>%
api/services/admin-ontology-endpoint-service.R-33-    tbl("non_alt_loci_set") %>%
api/services/admin-ontology-endpoint-service.R-34-    dplyr::select(hgnc_id, symbol) %>%
--
api/services/admin-ontology-endpoint-service.R-50-  if (dup_check$duplicate) {
api/services/admin-ontology-endpoint-service.R-51-    return(list(
api/services/admin-ontology-endpoint-service.R-52-      job_id = dup_check$existing_job_id,
api/services/admin-ontology-endpoint-service.R-53-      status = "already_running",
api/services/admin-ontology-endpoint-service.R-54-      message = "An OMIM update job is already running"
api/services/admin-ontology-endpoint-service.R-55-    ))
api/services/admin-ontology-endpoint-service.R-56-  }
api/services/admin-ontology-endpoint-service.R-57-
api/services/admin-ontology-endpoint-service.R:58:  result <- create_job_fn(
api/services/admin-ontology-endpoint-service.R-59-    operation = "omim_update",
api/services/admin-ontology-endpoint-service.R-60-    params = list(
api/services/admin-ontology-endpoint-service.R-61-      mode_of_inheritance_list = mode_of_inheritance_list,
api/services/admin-ontology-endpoint-service.R-62-      non_alt_loci_set = non_alt_loci_set,
api/services/admin-ontology-endpoint-service.R-63-      ndd_entity_view = ndd_entity_view,
api/services/admin-ontology-endpoint-service.R-64-      disease_ontology_set_current = disease_ontology_set_current,
api/services/admin-ontology-endpoint-service.R-65-      ndd_entity = ndd_entity
api/services/admin-ontology-endpoint-service.R-66-    )
--
api/services/admin-ontology-endpoint-service.R-74-#'
api/services/admin-ontology-endpoint-service.R-75-#' Looks up the blocked job (full result mode is REQUIRED: summary mode omits
api/services/admin-ontology-endpoint-service.R-76-#' the parsed result_json, which would make every "was it blocked?" check
api/services/admin-ontology-endpoint-service.R-77-#' below fail with a false 409), checks the pending CSV exists and is not
api/services/admin-ontology-endpoint-service.R-78-#' stale (>48h), and assembles the `force_apply_ontology` job params.
api/services/admin-ontology-endpoint-service.R-79-#'
api/services/admin-ontology-endpoint-service.R-80-#' @return List with either `early_return` (a body the caller must return
api/services/admin-ontology-endpoint-service.R-81-#'   as-is, with `res$status` already set) or `params` (ready for
api/services/admin-ontology-endpoint-service.R:82:#'   `create_job(operation = "force_apply_ontology", params = ...)`).
api/services/admin-ontology-endpoint-service.R-83-#' @export
api/services/admin-ontology-endpoint-service.R-84-svc_admin_force_apply_ontology_prepare <- function(req, res, blocked_job_id, assigned_user_id,
api/services/admin-ontology-endpoint-service.R-85-                                                     pool, job_status_fn = get_job_status) {
api/services/admin-ontology-endpoint-service.R-86-  assigned_user_id <- if (!is.null(assigned_user_id) && assigned_user_id != "") {
api/services/admin-ontology-endpoint-service.R-87-    as.integer(assigned_user_id)
api/services/admin-ontology-endpoint-service.R-88-  } else {
api/services/admin-ontology-endpoint-service.R-89-    NULL
api/services/admin-ontology-endpoint-service.R-90-  }
--
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
api/services/backup-endpoint-service.R-26-    res$setHeader("Retry-After", as.character(result$retry_after))
api/services/backup-endpoint-service.R-27-    return(result)
api/services/backup-endpoint-service.R-28-  }
api/services/backup-endpoint-service.R-29-
api/services/backup-endpoint-service.R-30-  res$status <- 202
--
api/services/backup-endpoint-service.R-120-        message = "Failed to retrieve backup list",
api/services/backup-endpoint-service.R-121-        details = e$message
api/services/backup-endpoint-service.R-122-      )
api/services/backup-endpoint-service.R-123-    }
api/services/backup-endpoint-service.R-124-  )
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
api/services/backup-endpoint-service.R-135-      error = "BACKUP_IN_PROGRESS",
api/services/backup-endpoint-service.R-136-      message = "A backup operation is already running",
api/services/backup-endpoint-service.R-137-      existing_job_id = dup_check$existing_job_id
api/services/backup-endpoint-service.R-138-    ))
api/services/backup-endpoint-service.R-139-  }
api/services/backup-endpoint-service.R-140-
api/services/backup-endpoint-service.R-141-  backup_filename <- sprintf("manual_%s.sql", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"))
api/services/backup-endpoint-service.R-142-
api/services/backup-endpoint-service.R-143-  # No DB credential in the job payload (#535 P1-1): the durable handler
api/services/backup-endpoint-service.R-144-  # .async_job_run_backup_create resolves it from runtime config; execution is
api/services/backup-endpoint-service.R-145-  # delegated to the registered durable handler.
api/services/backup-endpoint-service.R:146:  result <- create_job(
api/services/backup-endpoint-service.R-147-    operation = "backup_create",
api/services/backup-endpoint-service.R-148-    params = list(
api/services/backup-endpoint-service.R-149-      backup_dir = "/backup",
api/services/backup-endpoint-service.R-150-      backup_filename = backup_filename
api/services/backup-endpoint-service.R-151-    )
api/services/backup-endpoint-service.R-152-  )
api/services/backup-endpoint-service.R-153-
api/services/backup-endpoint-service.R-154-  .svc_backup_job_response(res, result)
--
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
api/services/backup-endpoint-service.R-204-  # registered durable handler.
api/services/backup-endpoint-service.R:205:  result <- create_job(
api/services/backup-endpoint-service.R-206-    operation = "backup_restore",
api/services/backup-endpoint-service.R-207-    params = list(
api/services/backup-endpoint-service.R-208-      restore_file = backup_path,
api/services/backup-endpoint-service.R-209-      backup_dir = "/backup"
api/services/backup-endpoint-service.R-210-    )
api/services/backup-endpoint-service.R-211-  )
api/services/backup-endpoint-service.R-212-
api/services/backup-endpoint-service.R-213-  .svc_backup_job_response(res, result)
--
api/functions/job-manager.R-5-#' durable async job service instead of process-local state.
api/functions/job-manager.R-6-#'
api/functions/job-manager.R-7-#' @name job-manager
api/functions/job-manager.R-8-#' @author SysNDD Team
api/functions/job-manager.R-9-
api/functions/job-manager.R-10-# Load required packages for this module
api/functions/job-manager.R-11-# Note: uuid, digest, and durable async-job helpers are loaded at bootstrap.
api/functions/job-manager.R-12-
api/functions/job-manager.R:13:# NOTE: LLM batch generator loaded at END of file (after create_job is defined)
api/functions/job-manager.R-14-
api/functions/job-manager.R-15-## -------------------------------------------------------------------##
api/functions/job-manager.R-16-# Core Functions
api/functions/job-manager.R-17-## -------------------------------------------------------------------##
api/functions/job-manager.R-18-
api/functions/job-manager.R-19-#' Create a new async job
api/functions/job-manager.R-20-#'
api/functions/job-manager.R-21-#' Submits a durable job for execution by its registered worker handler.
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
--
api/functions/job-manager.R-334-    row.names = NULL
api/functions/job-manager.R-335-  )
api/functions/job-manager.R-336-
api/functions/job-manager.R-337-  rownames(result) <- NULL
api/functions/job-manager.R-338-  result
api/functions/job-manager.R-339-}
api/functions/job-manager.R-340-
api/functions/job-manager.R-341-## -------------------------------------------------------------------##
api/functions/job-manager.R:342:# Load LLM Batch Generator (AFTER create_job is defined)
api/functions/job-manager.R-343-## -------------------------------------------------------------------##
api/functions/job-manager.R-344-
api/functions/job-manager.R:345:# Load LLM batch generator - must be AFTER create_job definition
api/functions/job-manager.R:346:# because trigger_llm_batch_generation() calls create_job()
api/functions/job-manager.R-347-if (file.exists("functions/llm-batch-generator.R")) {
api/functions/job-manager.R-348-  message("[job-manager] Loading llm-batch-generator.R...")
api/functions/job-manager.R-349-  tryCatch(
api/functions/job-manager.R-350-    {
api/functions/job-manager.R-351-      source("functions/llm-batch-generator.R", local = FALSE)
api/functions/job-manager.R-352-      message("[job-manager] llm-batch-generator.R loaded successfully")
api/functions/job-manager.R-353-      message(
api/functions/job-manager.R-354-        "[job-manager] trigger_llm_batch_generation exists: ",
--
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
api/services/publication-admin-endpoint-service.R:300:#' @param submit_fn Injectable job submitter (default [create_job()]).
api/services/publication-admin-endpoint-service.R-301-#' @return List with job_id/status/etc (202), or the capacity error body (503).
api/services/publication-admin-endpoint-service.R-302-#' @export
api/services/publication-admin-endpoint-service.R-303-svc_publication_pubtator_update_submit <- function(req, res, query, max_pages, clear_old, q_hash,
api/services/publication-admin-endpoint-service.R:304:                                                     submit_fn = create_job) {
api/services/publication-admin-endpoint-service.R-305-  result <- submit_fn(
api/services/publication-admin-endpoint-service.R-306-    operation = "pubtator_update",
api/services/publication-admin-endpoint-service.R-307-    params = list(
api/services/publication-admin-endpoint-service.R-308-      query = query,
api/services/publication-admin-endpoint-service.R-309-      max_pages = max_pages,
api/services/publication-admin-endpoint-service.R-310-      clear_old = clear_old,
api/services/publication-admin-endpoint-service.R-311-      query_hash = q_hash
api/services/publication-admin-endpoint-service.R-312-    )
--
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
--
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
--
api/functions/clustering-gene-universe.R-79-      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2",
api/functions/clustering-gene-universe.R-80-      paste(selector, collapse = ","), length(hgnc_ids)
api/functions/clustering-gene-universe.R-81-    ))
api/functions/clustering-gene-universe.R-82-  }
api/functions/clustering-gene-universe.R-83-  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
api/functions/clustering-gene-universe.R-84-}
api/functions/clustering-gene-universe.R-85-
api/functions/clustering-gene-universe.R-86-# Module-level (survives across requests within the same process) cache for
api/functions/clustering-gene-universe.R:87:# `analysis_snapshot_source_data_version()`. That read joins/aggregates across
api/functions/clustering-gene-universe.R-88-# public tables and changes rarely (only when the snapshot builder's source
api/functions/clustering-gene-universe.R-89-# view moves), so a short-TTL process cache avoids paying that cost on every
api/functions/clustering-gene-universe.R-90-# clustering submit while still self-refreshing.
api/functions/clustering-gene-universe.R-91-.clustering_source_data_version_cache <- new.env(parent = emptyenv())
api/functions/clustering-gene-universe.R-92-
api/functions/clustering-gene-universe.R-93-#' Cached, fail-closed read of the current analysis source-data version.
api/functions/clustering-gene-universe.R-94-#'
api/functions/clustering-gene-universe.R-95-#' D2 (#574) provenance helper: the clustering submit service calls this
api/functions/clustering-gene-universe.R-96-#' AFTER admission/dedup, only when it is actually about to build a durable
api/functions/clustering-gene-universe.R-97-#' payload. Refetches once `ttl_seconds` has elapsed since the last
api/functions/clustering-gene-universe.R-98-#' successful read. Deliberately does NOT wrap
api/functions/clustering-gene-universe.R:99:#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
api/functions/clustering-gene-universe.R-100-#' PROPAGATES to the caller (never cached, never coerced to NA), so a
api/functions/clustering-gene-universe.R-101-#' transient DB problem fails the submit closed (503) instead of recording
api/functions/clustering-gene-universe.R-102-#' broken provenance.
api/functions/clustering-gene-universe.R-103-#'
api/functions/clustering-gene-universe.R-104-#' @param conn DB connection/pool. Defaults to the package-global `pool`.
api/functions/clustering-gene-universe.R-105-#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
api/functions/clustering-gene-universe.R-106-#' @return character(1) source data version.
api/functions/clustering-gene-universe.R-107-#' @export
api/functions/clustering-gene-universe.R-108-clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
api/functions/clustering-gene-universe.R-109-  now <- Sys.time()
api/functions/clustering-gene-universe.R-110-  cached_at <- .clustering_source_data_version_cache$cached_at
api/functions/clustering-gene-universe.R-111-  if (!is.null(cached_at) &&
api/functions/clustering-gene-universe.R-112-        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
api/functions/clustering-gene-universe.R-113-    return(.clustering_source_data_version_cache$value)
api/functions/clustering-gene-universe.R-114-  }
api/functions/clustering-gene-universe.R-115-
api/functions/clustering-gene-universe.R:116:  value <- analysis_snapshot_source_data_version(conn = conn)
api/functions/clustering-gene-universe.R-117-
api/functions/clustering-gene-universe.R-118-  .clustering_source_data_version_cache$value <- value
api/functions/clustering-gene-universe.R-119-  .clustering_source_data_version_cache$cached_at <- now
api/functions/clustering-gene-universe.R-120-  value
api/functions/clustering-gene-universe.R-121-}
api/functions/clustering-gene-universe.R-122-
api/functions/clustering-gene-universe.R-123-# Assemble the clustering result `meta`: base fields + the cheap-path provenance
api/functions/clustering-gene-universe.R-124-# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
--
api/services/admin-publication-refresh-endpoint-service.R-1-# api/services/admin-publication-refresh-endpoint-service.R
api/services/admin-publication-refresh-endpoint-service.R-2-#
api/services/admin-publication-refresh-endpoint-service.R-3-# Service layer for POST /admin/publications/refresh, extracted from
api/services/admin-publication-refresh-endpoint-service.R-4-# api/endpoints/admin_endpoints.R (issue #346, Wave 3).
api/services/admin-publication-refresh-endpoint-service.R-5-#
api/services/admin-publication-refresh-endpoint-service.R:6:# `create_job()` (functions/job-manager.R) is a durable-job compatibility
api/services/admin-publication-refresh-endpoint-service.R-7-# facade: it routes through `async_job_service_submit(job_type = operation,
api/services/admin-publication-refresh-endpoint-service.R-8-# request_payload = params)`. The real, currently-executed handler is
api/services/admin-publication-refresh-endpoint-service.R-9-# `.async_job_run_publication_refresh()` in functions/async-job-handlers.R
api/services/admin-publication-refresh-endpoint-service.R-10-# (registered in `async_job_handler_registry`), which already has the
api/services/admin-publication-refresh-endpoint-service.R-11-# publication_date_source fix, the same 350ms rate limit, and its own DB
api/services/admin-publication-refresh-endpoint-service.R-12-# connection lifecycle.
api/services/admin-publication-refresh-endpoint-service.R-13-#
api/services/admin-publication-refresh-endpoint-service.R-14-# `require_role(req, res, "Administrator")` stays inline in the endpoint
--
api/services/admin-publication-refresh-endpoint-service.R-98-  ceiling(length(pmids) * 0.4)
api/services/admin-publication-refresh-endpoint-service.R-99-}
api/services/admin-publication-refresh-endpoint-service.R-100-
api/services/admin-publication-refresh-endpoint-service.R-101-#' POST /admin/publications/refresh body.
api/services/admin-publication-refresh-endpoint-service.R-102-#'
api/services/admin-publication-refresh-endpoint-service.R-103-#' Supports three modes: explicit `pmids`, a `not_updated_since` date filter,
api/services/admin-publication-refresh-endpoint-service.R-104-#' or opt-in `all=true` full-corpus refresh. Submits the durable
api/services/admin-publication-refresh-endpoint-service.R-105-#' `publication_refresh` job (202) unless a duplicate is already running,
api/services/admin-publication-refresh-endpoint-service.R:106:#' capacity is exceeded (503, surfaced by `create_job_fn`), or no PMIDs
api/services/admin-publication-refresh-endpoint-service.R-107-#' resolve (400/200 per the original contract).
api/services/admin-publication-refresh-endpoint-service.R-108-#'
api/services/admin-publication-refresh-endpoint-service.R-109-#' @export
api/services/admin-publication-refresh-endpoint-service.R-110-svc_admin_publication_refresh_submit <- function(req, res,
api/services/admin-publication-refresh-endpoint-service.R-111-                                                   query_fn = db_execute_query,
api/services/admin-publication-refresh-endpoint-service.R:112:                                                   duplicate_check_fn = check_duplicate_job,
api/services/admin-publication-refresh-endpoint-service.R:113:                                                   create_job_fn = create_job) {
api/services/admin-publication-refresh-endpoint-service.R-114-  # CRITICAL: Extract request body BEFORE any async submission -- the request
api/services/admin-publication-refresh-endpoint-service.R-115-  # object cannot cross process/worker boundaries.
api/services/admin-publication-refresh-endpoint-service.R-116-  body <- req$body
api/services/admin-publication-refresh-endpoint-service.R-117-  pmids <- body$pmids
api/services/admin-publication-refresh-endpoint-service.R-118-  not_updated_since <- body$not_updated_since
api/services/admin-publication-refresh-endpoint-service.R-119-  refresh_all <- isTRUE(body$all)
api/services/admin-publication-refresh-endpoint-service.R-120-
api/services/admin-publication-refresh-endpoint-service.R-121-  date_check <- svc_admin_publication_refresh_validate_date(not_updated_since)
--
api/services/admin-publication-refresh-endpoint-service.R-150-      job_id = dup_check$existing_job_id,
api/services/admin-publication-refresh-endpoint-service.R-151-      status = "already_running",

exec
/bin/bash -lc "nl -ba api/services/job-functional-submission-service.R | sed -n '80,380p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
    80	  }
    81	
    82	  # Resolve the clustering gene universe + selector provenance (#574). The
    83	  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
    84	  # from before this feature: `clustering_resolve_category_universe(NULL)`
    85	  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
    86	  # so cache parity (memoise key = gene set + algorithm) is preserved.
    87	  selector_chr <- NULL
    88	  if (has_genes) {
    89	    genes_list <- as.character(unlist(genes_in))
    90	    kind <- "explicit"
    91	  } else if (category_supplied) {
    92	    universe <- clustering_resolve_category_universe(req$argsBody$category_filter)
    93	    genes_list <- universe$hgnc_ids
    94	    selector_chr <- universe$selector
    95	    kind <- "category"
    96	  } else {
    97	    universe <- clustering_resolve_category_universe(NULL)
    98	    genes_list <- universe$hgnc_ids
    99	    kind <- "all_ndd"
   100	  }
   101	
   102	  # Pre-fetch the STRING ID table because DB connections cannot cross the
   103	  # durable worker boundary.
   104	  string_id_table <- pool %>%
   105	    dplyr::tbl("non_alt_loci_set") %>%
   106	    dplyr::filter(!is.na(STRING_id)) %>%
   107	    dplyr::select(symbol, hgnc_id, STRING_id) %>%
   108	    dplyr::collect()
   109	
   110	  # Check for duplicate job (include algorithm in check). The selector is
   111	  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
   112	  # submits keep the pre-#574 dedup identity byte-identical.
   113	  dup_params <- list(genes = genes_list, algorithm = algorithm)
   114	  if (!is.null(selector_chr)) {
   115	    dup_params$category_filter <- selector_chr
   116	  }
   117	  dup_check <- check_duplicate_job("clustering", dup_params)
   118	  if (dup_check$duplicate) {
   119	    res$status <- 409
   120	    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
   121	    return(list(
   122	      error = "DUPLICATE_JOB",
   123	      message = "Identical job already running",
   124	      existing_job_id = dup_check$existing_job_id,
   125	      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
   126	    ))
   127	  }
   128	
   129	  # Cheap-path provenance (no expensive query yet). `selector_obj` records
   130	  # WHICH universe was resolved; `intended_fingerprint` records the STRING
   131	  # cache identity + fixed clustering params this submit intends to run
   132	  # with. The *effective* fingerprint (e.g. the STRING weight channel a
   133	  # computed result actually used) is only knowable from a computed result,
   134	  # so it is recorded separately in the cache-hit result meta below.
   135	  selector_obj <- list(kind = kind, category_filter = selector_chr)
   136	  intended_fingerprint <- list(
   137	    string_cache_fingerprint = analysis_string_cache_fingerprint(),
   138	    score_threshold = 400L,
   139	    algorithm = algorithm,
   140	    seed = 42L
   141	  )
   142	  gene_sha <- clustering_gene_list_sha256(genes_list)
   143	
   144	  # Source-data version: a CACHED, fail-closed read, fetched only now that a
   145	  # payload is actually about to be built -- its backing view runs global
   146	  # counts/joins, so it must never run before admission/dedup. A lookup
   147	  # failure must never silently record NA/broken provenance; fail the
   148	  # request closed instead.
   149	  src_ver <- tryCatch(
   150	    clustering_cached_source_data_version(conn = pool),
   151	    error = function(e) e
   152	  )
   153	  if (inherits(src_ver, "error")) {
   154	    res$status <- 503L
   155	    return(list(
   156	      error = "PROVENANCE_UNAVAILABLE",
   157	      message = "Snapshot source-data version unavailable; retry shortly."
   158	    ))
   159	  }
   160	
   161	  provenance <- list(
   162	    selector = selector_obj,
   163	    resolved_gene_count = length(genes_list),
   164	    gene_list_sha256 = gene_sha,
   165	    intended_fingerprint = intended_fingerprint,
   166	    source_data_version = src_ver
   167	  )
   168	
   169	  # Define category links (needed for result)
   170	  category_links <- tibble::tibble(
   171	    value = c(
   172	      "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
   173	      "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
   174	      "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
   175	    ),
   176	    link = c(
   177	      "https://www.ebi.ac.uk/QuickGO/term/",
   178	      "https://www.ebi.ac.uk/QuickGO/term/",
   179	      "https://disease-ontology.org/term/",
   180	      "https://www.ebi.ac.uk/QuickGO/term/",
   181	      "https://hpo.jax.org/browse/term/",
   182	      "http://www.ebi.ac.uk/interpro/entry/InterPro/",
   183	      "https://www.genome.jp/dbget-bin/www_bget?",
   184	      "https://www.uniprot.org/keywords/",
   185	      "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
   186	      "https://www.ebi.ac.uk/interpro/entry/pfam/",
   187	      "https://www.ncbi.nlm.nih.gov/search/all/?term=",
   188	      "https://www.ebi.ac.uk/QuickGO/term/",
   189	      "https://reactome.org/content/detail/R-",
   190	      "http://www.ebi.ac.uk/interpro/entry/smart/",
   191	      "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
   192	      "https://www.wikipathways.org/index.php/Pathway:"
   193	    )
   194	  )
   195	
   196	  # Cache-first: if the memoized function already has a cached result,
   197	  # return it immediately without submitting a durable worker job.
   198	  # The network_edges endpoint (graph) warms this cache on first load,
   199	  # so subsequent table requests resolve instantly.
   200	  cache_hit <- tryCatch(
   201	    memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
   202	    error = function(e) FALSE
   203	  )
   204	
   205	  if (cache_hit) {
   206	    cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)
   207	
   208	    categories <- cached_clusters %>%
   209	      dplyr::select(term_enrichment) %>%
   210	      tidyr::unnest(cols = c(term_enrichment)) %>%
   211	      dplyr::select(category) %>%
   212	      unique() %>%
   213	      dplyr::arrange(category) %>%
   214	      dplyr::mutate(
   215	        text = dplyr::case_when(
   216	          nchar(category) <= 5 ~ category,
   217	          nchar(category) > 5 ~ stringr::str_to_sentence(category)
   218	        )
   219	      ) %>%
   220	      dplyr::select(value = category, text) %>%
   221	      dplyr::left_join(category_links, by = c("value"))
   222	
   223	    # Splice the base cache-hit fields with `provenance` (already assembled
   224	    # above as selector/resolved_gene_count/gene_list_sha256/
   225	    # intended_fingerprint/source_data_version) via the shared
   226	    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
   227	    # re-listing the same fields as duplicate literals -- keeps this shape in
   228	    # lockstep with the worker-run handler's result meta by construction.
   229	    # `effective_fingerprint` is only knowable from the computed result
   230	    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
   231	    cache_result <- list(
   232	      clusters = cached_clusters,
   233	      categories = categories,
   234	      meta = clustering_result_meta(
   235	        list(
   236	          algorithm = algorithm,
   237	          gene_count = length(genes_list),
   238	          cluster_count = nrow(cached_clusters),
   239	          cache_hit = TRUE
   240	        ),
   241	        provenance,
   242	        attr(cached_clusters, "weight_channel")
   243	      )
   244	    )
   245	    cache_request_payload <- list(
   246	      genes = genes_list,
   247	      algorithm = algorithm,
   248	      category_links = category_links,
   249	      string_id_table = string_id_table,
   250	      provenance = provenance
   251	    )
   252	    if (!is.null(selector_chr)) {
   253	      cache_request_payload$category_filter <- selector_chr
   254	    }
   255	    completed_job <- async_job_service_store_completed(
   256	      job_type = "clustering",
   257	      request_payload = cache_request_payload,
   258	      result = cache_result,
   259	      submitted_by = req$user$user_id %||% NULL,
   260	      queue_name = "analysis",
   261	      priority = 50L
   262	    )
   263	    job_id <- completed_job$job_id[[1]]
   264	
   265	    res$status <- 202
   266	    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   267	    res$setHeader("Retry-After", "0")
   268	
   269	    return(list(
   270	      job_id = job_id,
   271	      status = "accepted",
   272	      estimated_seconds = 0,
   273	      status_url = paste0("/api/jobs/", job_id, "/status"),
   274	      meta = list(llm_generation = "snapshot_refresh_owned")
   275	    ))
   276	  }
   277	
   278	  # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
   279	  # "default" matches the queue create_job() enqueues on via async_job_service_submit.
   280	  if (async_job_capacity_exceeded(
   281	        tryCatch(
   282	          async_job_active_count("default"),
   283	          error = function(e) {
   284	            log_warn("async_job_active_count failed (capacity check fail-open): {e$message}")
   285	            0L
   286	          }
   287	        )
   288	      )) {
   289	    res$status <- 503
   290	    res$setHeader("Retry-After", "60")
   291	    return(list(
   292	      error = "CAPACITY_EXCEEDED",
   293	      message = "Analysis queue is at capacity. Please retry shortly.",
   294	      retry_after = 60
   295	    ))
   296	  }
   297	
   298	  # Cache miss - create async job
   299	  job_params <- list(
   300	    genes = genes_list,
   301	    algorithm = algorithm,
   302	    category_links = category_links,
   303	    string_id_table = string_id_table,
   304	    provenance = provenance
   305	  )
   306	  if (!is.null(selector_chr)) {
   307	    job_params$category_filter <- selector_chr
   308	  }
   309	  result <- create_job(
   310	    operation = "clustering",
   311	    params = job_params
   312	  )
   313	
   314	  # Check capacity
   315	  if (!is.null(result$error)) {
   316	    res$status <- 503
   317	    res$setHeader("Retry-After", as.character(result$retry_after))
   318	    return(result)
   319	  }
   320	
   321	  # Success - return HTTP 202 Accepted
   322	  res$status <- 202
   323	  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
   324	  res$setHeader("Retry-After", "5")
   325	
   326	  list(
   327	    job_id = result$job_id,
   328	    status = result$status,
   329	    estimated_seconds = result$estimated_seconds,
   330	    status_url = paste0("/api/jobs/", result$job_id, "/status")
   331	  )
   332	}

exec
/bin/bash -lc "nl -ba api/functions/async-job-handlers.R | sed -n '1,260p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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

exec
/bin/bash -lc "git diff origin/master...HEAD -- ':(exclude).planning/**' | sed -n '1,5p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
diff --git a/AGENTS.md b/AGENTS.md
index 7aa9b3e1..e9647c88 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -123,6 +123,8 @@ Analysis-snapshot **releases** are immutable, content-addressed, frozen exports

exec
/bin/bash -lc "rg -n -C 40 '"'^check_duplicate_job|check_duplicate_job <-|''^create_job|create_job <-'"' api/functions/job-manager.R api/functions/async-job-service.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/functions/job-manager.R-1-#' Job Manager Module
api/functions/job-manager.R-2-#'
api/functions/job-manager.R-3-#' Legacy compatibility facade for async API operations.
api/functions/job-manager.R-4-#' Public job submission, status, and history now route through the
api/functions/job-manager.R-5-#' durable async job service instead of process-local state.
api/functions/job-manager.R-6-#'
api/functions/job-manager.R-7-#' @name job-manager
api/functions/job-manager.R-8-#' @author SysNDD Team
api/functions/job-manager.R-9-
api/functions/job-manager.R-10-# Load required packages for this module
api/functions/job-manager.R-11-# Note: uuid, digest, and durable async-job helpers are loaded at bootstrap.
api/functions/job-manager.R-12-
api/functions/job-manager.R-13-# NOTE: LLM batch generator loaded at END of file (after create_job is defined)
api/functions/job-manager.R-14-
api/functions/job-manager.R-15-## -------------------------------------------------------------------##
api/functions/job-manager.R-16-# Core Functions
api/functions/job-manager.R-17-## -------------------------------------------------------------------##
api/functions/job-manager.R-18-
api/functions/job-manager.R-19-#' Create a new async job
api/functions/job-manager.R-20-#'
api/functions/job-manager.R-21-#' Submits a durable job for execution by its registered worker handler.
api/functions/job-manager.R-22-#'
api/functions/job-manager.R-23-#' @param operation Character string identifying the operation type
api/functions/job-manager.R-24-#'   (e.g., "clustering", "phenotype_clustering", "ontology_update")
api/functions/job-manager.R-25-#' @param params List of payload parameters for the registered handler.
api/functions/job-manager.R-26-#'
api/functions/job-manager.R-27-#' @return List with job_id, status="accepted", and estimated_seconds=30.
api/functions/job-manager.R-28-#'
api/functions/job-manager.R-29-#' @examples
api/functions/job-manager.R-30-#' \dontrun{
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
api/functions/job-manager.R-42-  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL
api/functions/job-manager.R-43-
api/functions/job-manager.R-44-  list(
api/functions/job-manager.R-45-    job_id = job_id,
api/functions/job-manager.R-46-    status = "accepted",
api/functions/job-manager.R-47-    estimated_seconds = 30
api/functions/job-manager.R-48-  )
api/functions/job-manager.R-49-}
api/functions/job-manager.R-50-
api/functions/job-manager.R-51-#' Get the status of a job
api/functions/job-manager.R-52-#'
api/functions/job-manager.R-53-#' Reads the persisted durable-job state and returns the polling response.
api/functions/job-manager.R-54-#'
api/functions/job-manager.R-55-#' @param job_id Character string - the UUID of the job
api/functions/job-manager.R-56-#' @param result_mode Character string - "summary" omits stored result JSON,
api/functions/job-manager.R-57-#'   "full" includes and parses it.
api/functions/job-manager.R-58-#'
api/functions/job-manager.R-59-#' @return List with either:
api/functions/job-manager.R-60-#'   - Not found: error="JOB_NOT_FOUND"
api/functions/job-manager.R-61-#'   - Running: status, step, estimated_seconds, retry_after=5
api/functions/job-manager.R-62-#'   - Completed: status, completed_at, result or error
api/functions/job-manager.R-63-#'
api/functions/job-manager.R-64-#' @examples
api/functions/job-manager.R-65-#' \dontrun{
api/functions/job-manager.R-66-#' status <- get_job_status("550e8400-e29b-41d4-a716-446655440000")
api/functions/job-manager.R-67-#' }
api/functions/job-manager.R-68-get_job_status <- function(job_id, result_mode = "summary") {
api/functions/job-manager.R-69-  result_mode <- as.character(result_mode[[1]] %||% "summary")
api/functions/job-manager.R-70-  if (!result_mode %in% c("summary", "full")) {
api/functions/job-manager.R-71-    stop("result_mode must be one of: summary, full", call. = FALSE)
api/functions/job-manager.R-72-  }
api/functions/job-manager.R-73-
api/functions/job-manager.R-74-  job <- async_job_service_status(
api/functions/job-manager.R-75-    job_id,
api/functions/job-manager.R-76-    include_result = identical(result_mode, "full")
--
api/functions/job-manager.R-186-#' \dontrun{
api/functions/job-manager.R-187-#' msg <- get_progress_message("clustering")
api/functions/job-manager.R-188-#' # Returns: "Fetching interaction data from STRING-db..."
api/functions/job-manager.R-189-#' }
api/functions/job-manager.R-190-get_progress_message <- function(operation) {
api/functions/job-manager.R-191-  messages <- list(
api/functions/job-manager.R-192-    clustering = "Fetching interaction data from STRING-db...",
api/functions/job-manager.R-193-    phenotype_clustering = "Running Multiple Correspondence Analysis...",
api/functions/job-manager.R-194-    ontology_update = "Downloading and processing ontology data from MONDO/OMIM...",
api/functions/job-manager.R-195-    omim_update = "Updating OMIM annotations from mim2gene.txt + JAX API...",
api/functions/job-manager.R-196-    hgnc_update = "Downloading HGNC data and enriching with gnomAD constraints...",
api/functions/job-manager.R-197-    backup_create = "Creating database backup...",
api/functions/job-manager.R-198-    backup_restore = "Restoring database from backup...",
api/functions/job-manager.R-199-    pubtator_update = "Fetching publications from PubTator API...",
api/functions/job-manager.R-200-    llm_generation = "Generating LLM summaries for clusters...",
api/functions/job-manager.R-201-    comparisons_update = "Refreshing comparisons data from external NDD databases..."
api/functions/job-manager.R-202-  )
api/functions/job-manager.R-203-
api/functions/job-manager.R-204-  messages[[operation]] %||% "Processing request..."
api/functions/job-manager.R-205-}
api/functions/job-manager.R-206-
api/functions/job-manager.R-207-#' Check for duplicate running jobs
api/functions/job-manager.R-208-#'
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
api/functions/job-manager.R-232-#' Same `(operation, params)` shape as [check_duplicate_job()] so it is a
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
api/functions/job-manager.R-245-
api/functions/job-manager.R-246-#' Compatibility no-op for the removed in-memory cleanup cycle
api/functions/job-manager.R-247-#'
api/functions/job-manager.R-248-#' @return Integer count of removed jobs (invisible).
api/functions/job-manager.R-249-#' @export
api/functions/job-manager.R-250-cleanup_old_jobs <- function() {
api/functions/job-manager.R-251-  invisible(0L)
api/functions/job-manager.R-252-}
api/functions/job-manager.R-253-
api/functions/job-manager.R-254-#' Compatibility no-op for the removed in-memory cleanup scheduler
api/functions/job-manager.R-255-#'
api/functions/job-manager.R-256-#' @param interval_seconds Interval between cleanup runs in seconds
api/functions/job-manager.R-257-#' @export
api/functions/job-manager.R-258-schedule_cleanup <- function(interval_seconds = 3600) {
api/functions/job-manager.R-259-  invisible(interval_seconds)
api/functions/job-manager.R-260-}
api/functions/job-manager.R-261-
api/functions/job-manager.R-262-#' Get Job History
api/functions/job-manager.R-263-#'
api/functions/job-manager.R-264-#' Returns recent durable jobs, sorted by submission time (newest first).
api/functions/job-manager.R-265-#'
api/functions/job-manager.R-266-#' @param limit Integer maximum number of jobs to return (default 20)

exec
/bin/bash -lc "rg -n -C 30 '"'^generate_ndd_hgnc_ids|generate_ndd_hgnc_ids <-'"' api/functions/analyses-functions.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
350-  # memoise round-trip), so the builder can expose it and gate on channel agreement.
351-  attr(clusters_tibble, "weight_channel") <- membership_weight_channel
352-
353-  # return result
354-  return(clusters_tibble)
355-}
356-
357-
358-#' A function to compute  enrichment with string-db and a HGNC list
359-#'
360-#' @param hgnc_list A comma separated list as concatenated text
361-#'
362-#' @return The enrichment tibble
363-#' @export
364-gen_string_enrich_tib <- function(hgnc_list) {
365-  # Get cached STRINGdb instance (singleton avoids repeated version API calls)
366-  string_db <- get_string_db(400L)
367-
368-  # compute enrichment and convert to tibble
369-  # Sort by FDR ascending so most significant terms appear first
370-  enrichment_tibble <- string_db$get_enrichment(hgnc_list) %>%
371-    tibble() %>%
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
   113	testthat::skip_if_not_installed("RSQLite")
   114	
   115	# Source the code under test into a child env so the NULL-branch dependency
   116	# (`generate_ndd_hgnc_ids`) can be overridden per-test without touching
   117	# globalenv() or any other test file's bindings.
   118	.gene_universe_env <- function() {
   119	  e <- new.env(parent = globalenv())
   120	  source_api_file("core/errors.R", local = FALSE, envir = e)
   121	  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
   122	  e
   123	}
   124	
   125	# In-memory RSQLite fixture standing in for `pool`/a real DB connection.
   126	# `ev` = ndd_entity_view rows, `cats` = ndd_entity_status_categories_list rows.
   127	fake_conn <- function(ev, cats) {
   128	  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
   129	  DBI::dbWriteTable(con, "ndd_entity_view", as.data.frame(ev))
   130	  DBI::dbWriteTable(con, "ndd_entity_status_categories_list", as.data.frame(cats))
   131	  con
   132	}
   133	
   134	# Fixture: entity rows (one row per entity). TWO Definitive NDD genes so the
   135	# ["Definitive"] universe passes the >=2 guard.
   136	ev <- tibble::tribble(
   137	  ~entity_id, ~hgnc_id,  ~ndd_phenotype, ~category,
   138	  1L,        "HGNC:1",   1L,             "Definitive",   # gene 1: Definitive + Limited
   139	  2L,        "HGNC:1",   1L,             "Limited",
   140	  3L,        "HGNC:2",   1L,             "Limited",      # gene 2: Limited only
   141	  4L,        "HGNC:3",   0L,             "Definitive",   # gene 3: Definitive but NON-NDD
   142	  5L,        "HGNC:4",   1L,             "Moderate",     # gene 4: Moderate NDD (single -> too-small alone)
   143	  6L,        "HGNC:5",   1L,             "Definitive"    # gene 5: second Definitive NDD gene
   144	)
   145	cats <- tibble::tibble(
   146	  category = c("Definitive", "Moderate", "Limited", "Refuted", "not applicable"),
   147	  is_active = 1L
   148	)
   149	
   150	test_that("Definitive selects genes with any Definitive NDD entity (multi-entity gene included)", {
   151	  e <- .gene_universe_env()
   152	  con <- fake_conn(ev, cats)
   153	  withr::defer(DBI::dbDisconnect(con))
   154	
   155	  r <- e$clustering_resolve_category_universe("Definitive", conn = con)
   156	
   157	  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5")) # HGNC:2 Limited-only excluded; HGNC:3 non-NDD excluded
   158	  expect_identical(r$selector, "Definitive")
   159	  expect_identical(r$resolved_gene_count, 2L)
   160	})
   161	
   162	test_that("multi-value selector is a union across categories", {
   163	  e <- .gene_universe_env()
   164	  con <- fake_conn(ev, cats)
   165	  withr::defer(DBI::dbDisconnect(con))
   166	
   167	  r <- e$clustering_resolve_category_universe(c("Definitive", "Moderate"), conn = con)
   168	
   169	  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5", "HGNC:4"))
   170	})
   171	
   172	test_that("NULL selector returns all NDD genes, order-identical to generate_ndd_hgnc_ids()", {
   173	  e <- .gene_universe_env()
   174	  con <- fake_conn(ev, cats)
   175	  withr::defer(DBI::dbDisconnect(con))
   176	  e$generate_ndd_hgnc_ids <- function() {
   177	    tibble::tibble(hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5"))
   178	  }
   179	
   180	  r <- e$clustering_resolve_category_universe(NULL, conn = con)
   181	
   182	  expect_identical(r$hgnc_ids, c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5")) # arrange(entity_id)+distinct, ndd_phenotype==1
   183	  expect_null(r$selector)
   184	})
   185	
   186	test_that("unknown token is rejected 400 with the allowed set in the MESSAGE (not detail)", {
   187	  e <- .gene_universe_env()
   188	  con <- fake_conn(ev, cats)
   189	  withr::defer(DBI::dbDisconnect(con))
   190	
   191	  err <- tryCatch(
   192	    e$clustering_resolve_category_universe("Definative", conn = con),
   193	    error = function(err) err
   194	  )
   195	
   196	  expect_s3_class(err, "error_400")
   197	  expect_match(conditionMessage(err), "Definitive") # allowed set is in the message so it reaches clients
   198	})
   199	
   200	test_that("supplied-but-empty selector is 400 (NOT the all-NDD default)", {
   201	  e <- .gene_universe_env()
   202	  con <- fake_conn(ev, cats)
   203	  withr::defer(DBI::dbDisconnect(con))
   204	
   205	  expect_error(e$clustering_resolve_category_universe(list(), conn = con), class = "error_400")
   206	  expect_error(e$clustering_resolve_category_universe(list("   "), conn = con), class = "error_400")
   207	})
   208	
   209	test_that("a valid category resolving to < 2 genes is rejected 400 (no degenerate-graph job)", {
   210	  e <- .gene_universe_env()
   211	  con <- fake_conn(ev, cats)
   212	  withr::defer(DBI::dbDisconnect(con))
   213	
   214	  expect_error(e$clustering_resolve_category_universe("Refuted", conn = con), class = "error_400") # 0 genes
   215	  expect_error(e$clustering_resolve_category_universe("Moderate", conn = con), class = "error_400") # 1 gene
   216	})
   217	
   218	test_that("gene_list_sha256 is sort-order independent", {
   219	  e <- .gene_universe_env()
   220	
   221	  expect_identical(
   222	    e$clustering_gene_list_sha256(c("HGNC:3", "HGNC:1")),
   223	    e$clustering_gene_list_sha256(c("HGNC:1", "HGNC:3"))
   224	  )
   225	})
   226	
   227	test_that("clustering_normalize_category_filter: absent (NULL) vs supplied-but-empty are distinct", {
   228	  e <- .gene_universe_env()
   229	
   230	  expect_null(e$clustering_normalize_category_filter(NULL))
   231	  expect_identical(e$clustering_normalize_category_filter(list()), character(0))
   232	  expect_identical(e$clustering_normalize_category_filter(list("   ")), character(0))
   233	  expect_identical(e$clustering_normalize_category_filter(list("")), character(0))
   234	  expect_identical(
   235	    e$clustering_normalize_category_filter(c("Moderate", "Definitive", "Definitive")),
   236	    c("Definitive", "Moderate")
   237	  )
   238	})

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
   158	    old_pool <- if (exists("pool", envir = .GlobalEnv)) get("pool", envir = .GlobalEnv) else NULL
   159	    assign("pool", conn, envir = .GlobalEnv)
   160	    withr::defer({
   161	      if (is.null(old_pool)) {
   162	        if (exists("pool", envir = .GlobalEnv)) rm(pool, envir = .GlobalEnv)
   163	      } else {
   164	        assign("pool", old_pool, envir = .GlobalEnv)
   165	      }
   166	    })
   167	
   168	    resolved <- clustering_resolve_category_universe(NULL, conn = conn)
   169	
   170	    # Meaningful, not tautological: compares against a DIRECT query against
   171	    # the real view, not against calling generate_ndd_hgnc_ids() a second
   172	    # time -- proves the NULL/default branch resolves the all-NDD universe
   173	    # correctly, independent of the resolver's own implementation.
   174	    direct <- DBI::dbGetQuery(
   175	      conn,
   176	      "SELECT DISTINCT hgnc_id FROM ndd_entity_view WHERE ndd_phenotype = 1"
   177	    )$hgnc_id
   178	
   179	    expect_setequal(resolved$hgnc_ids, direct)
   180	    expect_null(resolved$selector)
   181	    expect_identical(resolved$resolved_gene_count, length(direct))
   182	  })
   183	})

exec
/bin/bash -lc 'git diff --unified=20 origin/master...HEAD -- api/functions/async-job-handlers.R api/services/job-functional-submission-service.R api/functions/clustering-gene-universe.R api/tests/testthat/test-integration-clustering-category-submit.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
diff --git a/api/functions/async-job-handlers.R b/api/functions/async-job-handlers.R
index d3691475..9eccf745 100644
--- a/api/functions/async-job-handlers.R
+++ b/api/functions/async-job-handlers.R
@@ -2,40 +2,44 @@
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
@@ -79,60 +83,81 @@
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
   }
 
   trigger_llm_batch_generation(
     clusters = llm_clusters,
     cluster_type = cluster_type,
     parent_job_id = job$job_id[[1]]
   )
 
diff --git a/api/functions/clustering-gene-universe.R b/api/functions/clustering-gene-universe.R
new file mode 100644
index 00000000..505ee3eb
--- /dev/null
+++ b/api/functions/clustering-gene-universe.R
@@ -0,0 +1,134 @@
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
+#' Cached, fail-closed read of the current analysis source-data version.
+#'
+#' D2 (#574) provenance helper: the clustering submit service calls this
+#' AFTER admission/dedup, only when it is actually about to build a durable
+#' payload. Refetches once `ttl_seconds` has elapsed since the last
+#' successful read. Deliberately does NOT wrap
+#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
+#' PROPAGATES to the caller (never cached, never coerced to NA), so a
+#' transient DB problem fails the submit closed (503) instead of recording
+#' broken provenance.
+#'
+#' @param conn DB connection/pool. Defaults to the package-global `pool`.
+#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
+#' @return character(1) source data version.
+#' @export
+clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
+  now <- Sys.time()
+  cached_at <- .clustering_source_data_version_cache$cached_at
+  if (!is.null(cached_at) &&
+        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
+    return(.clustering_source_data_version_cache$value)
+  }
+
+  value <- analysis_snapshot_source_data_version(conn = conn)
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
index 150c61e0..4cc138e2 100644
--- a/api/services/job-functional-submission-service.R
+++ b/api/services/job-functional-submission-service.R
@@ -7,112 +7,182 @@
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
+  # existing default all-NDD-genes universe. Presence is decided from the RAW
+  # request field, not a length check, so an explicitly-empty category_filter
+  # still reaches (and is rejected by) the resolver instead of silently
+  # falling through to the all-NDD default.
+  genes_in <- req$argsBody$genes
+  category_supplied <- !is.null(req$argsBody$category_filter)
+  has_genes <- !is.null(genes_in) && length(genes_in) > 0
+
+  if (has_genes && category_supplied) {
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
+    resolved_gene_count = length(genes_list),
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
@@ -133,58 +203,75 @@ svc_job_submit_functional_clustering <- function(req, res) {
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
+          gene_count = length(genes_list),
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
       job_id = job_id,
       status = "accepted",
       estimated_seconds = 0,
       status_url = paste0("/api/jobs/", job_id, "/status"),
       meta = list(llm_generation = "snapshot_refresh_owned")
     ))
   }
 
@@ -192,48 +279,53 @@ svc_job_submit_functional_clustering <- function(req, res) {
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
   res$setHeader("Retry-After", "5")
 
   list(
     job_id = result$job_id,
     status = result$status,
     estimated_seconds = result$estimated_seconds,
     status_url = paste0("/api/jobs/", result$job_id, "/status")
   )
diff --git a/api/tests/testthat/test-integration-clustering-category-submit.R b/api/tests/testthat/test-integration-clustering-category-submit.R
new file mode 100644
index 00000000..1124c94b
--- /dev/null
+++ b/api/tests/testthat/test-integration-clustering-category-submit.R
@@ -0,0 +1,183 @@
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
+    old_pool <- if (exists("pool", envir = .GlobalEnv)) get("pool", envir = .GlobalEnv) else NULL
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
/bin/bash -lc "rg -n -C 30 '"'^analysis_snapshot_source_data_version|analysis_snapshot_source_data_version <-'"' api/functions api/tests/testthat" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/tests/testthat/test-unit-analysis-snapshot-repository.R-95-test_that("analysis_snapshot_public_current returns FALSE when the manifest read errors", {
api/tests/testthat/test-unit-analysis-snapshot-repository.R-96-  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-97-  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-98-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-99-  boom <- function(...) stop("db down")
api/tests/testthat/test-unit-analysis-snapshot-repository.R-100-  expect_false(
api/tests/testthat/test-unit-analysis-snapshot-repository.R-101-    analysis_snapshot_public_current("gene_network_edges", "h", manifest_fn = boom)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-102-  )
api/tests/testthat/test-unit-analysis-snapshot-repository.R-103-})
api/tests/testthat/test-unit-analysis-snapshot-repository.R-104-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-105-test_that("public snapshot reads include current source version for mismatch diagnostics", {
api/tests/testthat/test-unit-analysis-snapshot-repository.R-106-  env <- new.env(parent = globalenv())
api/tests/testthat/test-unit-analysis-snapshot-repository.R-107-  source(file.path("functions", "analysis-snapshot-repository.R"), local = env)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-108-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-109-  query_count <- 0L
api/tests/testthat/test-unit-analysis-snapshot-repository.R-110-  env$db_execute_query <- function(sql, params = list(), conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-repository.R-111-    query_count <<- query_count + 1L
api/tests/testthat/test-unit-analysis-snapshot-repository.R-112-    if (grepl("FROM analysis_snapshot_manifest", sql, fixed = TRUE)) {
api/tests/testthat/test-unit-analysis-snapshot-repository.R-113-      return(tibble::tibble(
api/tests/testthat/test-unit-analysis-snapshot-repository.R-114-        snapshot_id = 1L,
api/tests/testthat/test-unit-analysis-snapshot-repository.R-115-        analysis_type = "phenotype_clusters",
api/tests/testthat/test-unit-analysis-snapshot-repository.R-116-        parameter_hash = "hash",
api/tests/testthat/test-unit-analysis-snapshot-repository.R-117-        schema_version = "1.0",
api/tests/testthat/test-unit-analysis-snapshot-repository.R-118-        data_class = "curated_derived_analysis",
api/tests/testthat/test-unit-analysis-snapshot-repository.R-119-        source_data_version = "old-source",
api/tests/testthat/test-unit-analysis-snapshot-repository.R-120-        stale_after = Sys.time() + 3600
api/tests/testthat/test-unit-analysis-snapshot-repository.R-121-      ))
api/tests/testthat/test-unit-analysis-snapshot-repository.R-122-    }
api/tests/testthat/test-unit-analysis-snapshot-repository.R-123-    tibble::tibble()
api/tests/testthat/test-unit-analysis-snapshot-repository.R-124-  }
api/tests/testthat/test-unit-analysis-snapshot-repository.R:125:  env$analysis_snapshot_source_data_version <- function(conn = NULL) "new-source"
api/tests/testthat/test-unit-analysis-snapshot-repository.R-126-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-127-  snapshot <- env$analysis_snapshot_get_public("phenotype_clusters", "hash")
api/tests/testthat/test-unit-analysis-snapshot-repository.R-128-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-129-  expect_equal(snapshot$status_code, "source_version_mismatch")
api/tests/testthat/test-unit-analysis-snapshot-repository.R-130-  expect_equal(snapshot$manifest$current_source_data_version[[1]], "new-source")
api/tests/testthat/test-unit-analysis-snapshot-repository.R-131-  expect_equal(query_count, 1L)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-132-  expect_false("clusters" %in% names(snapshot))
api/tests/testthat/test-unit-analysis-snapshot-repository.R-133-})
api/tests/testthat/test-unit-analysis-snapshot-repository.R-134-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-135-test_that("snapshot API time strings preserve sub-second precision", {
api/tests/testthat/test-unit-analysis-snapshot-repository.R-136-  source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-137-  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-138-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-139-  timestamp <- as.POSIXct("2026-05-30 12:34:56.789", tz = "UTC")
api/tests/testthat/test-unit-analysis-snapshot-repository.R-140-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-141-  expect_equal(service_analysis_snapshot_time_string(timestamp), "2026-05-30T12:34:56.789Z")
api/tests/testthat/test-unit-analysis-snapshot-repository.R-142-})
api/tests/testthat/test-unit-analysis-snapshot-repository.R-143-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-144-test_that("manifest creation uses one checked-out pool connection for insert id lookup", {
api/tests/testthat/test-unit-analysis-snapshot-repository.R-145-  env <- new.env(parent = globalenv())
api/tests/testthat/test-unit-analysis-snapshot-repository.R-146-  source(file.path("functions", "analysis-snapshot-repository.R"), local = env)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-147-
api/tests/testthat/test-unit-analysis-snapshot-repository.R-148-  events <- character()
api/tests/testthat/test-unit-analysis-snapshot-repository.R-149-  fake_pool <- NULL
api/tests/testthat/test-unit-analysis-snapshot-repository.R-150-  checked_out <- structure(
api/tests/testthat/test-unit-analysis-snapshot-repository.R-151-    list(label = "checked-out"),
api/tests/testthat/test-unit-analysis-snapshot-repository.R-152-    class = "DBIConnection",
api/tests/testthat/test-unit-analysis-snapshot-repository.R-153-    pool_metadata = list(valid = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-154-  )
api/tests/testthat/test-unit-analysis-snapshot-repository.R-155-  fake_pool <- structure(
--
api/tests/testthat/test-unit-clustering-gene-universe.R-21-#
api/tests/testthat/test-unit-clustering-gene-universe.R-22-# These tests stub `analysis_snapshot_source_data_version()` directly -- no DB
api/tests/testthat/test-unit-clustering-gene-universe.R-23-# connection is ever opened -- so they are placed BEFORE the file-wide
api/tests/testthat/test-unit-clustering-gene-universe.R-24-# `skip_if_not_installed("RSQLite")` gate below and run unconditionally, even
api/tests/testthat/test-unit-clustering-gene-universe.R-25-# when {RSQLite} is unavailable.
api/tests/testthat/test-unit-clustering-gene-universe.R-26-
api/tests/testthat/test-unit-clustering-gene-universe.R-27-# Sources ONLY core/errors.R + the module under test into a fresh child env.
api/tests/testthat/test-unit-clustering-gene-universe.R-28-# A fresh env means a fresh `.clustering_source_data_version_cache` (it is
api/tests/testthat/test-unit-clustering-gene-universe.R-29-# created top-level by the sourced file), so there is nothing left over from
api/tests/testthat/test-unit-clustering-gene-universe.R-30-# a prior test -- `.reset_source_data_version_cache()` below is still applied
api/tests/testthat/test-unit-clustering-gene-universe.R-31-# defensively so the reset mechanism itself stays covered/documented.
api/tests/testthat/test-unit-clustering-gene-universe.R-32-.source_data_version_env <- function() {
api/tests/testthat/test-unit-clustering-gene-universe.R-33-  e <- new.env(parent = globalenv())
api/tests/testthat/test-unit-clustering-gene-universe.R-34-  source_api_file("core/errors.R", local = FALSE, envir = e)
api/tests/testthat/test-unit-clustering-gene-universe.R-35-  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
api/tests/testthat/test-unit-clustering-gene-universe.R-36-  e
api/tests/testthat/test-unit-clustering-gene-universe.R-37-}
api/tests/testthat/test-unit-clustering-gene-universe.R-38-
api/tests/testthat/test-unit-clustering-gene-universe.R-39-# Clears the module-level TTL cache env so cached state never leaks across
api/tests/testthat/test-unit-clustering-gene-universe.R-40-# assertions sharing the same sourced env `e`.
api/tests/testthat/test-unit-clustering-gene-universe.R-41-.reset_source_data_version_cache <- function(e) {
api/tests/testthat/test-unit-clustering-gene-universe.R-42-  cache_env <- e$.clustering_source_data_version_cache
api/tests/testthat/test-unit-clustering-gene-universe.R-43-  keys <- ls(cache_env, all.names = TRUE)
api/tests/testthat/test-unit-clustering-gene-universe.R-44-  if (length(keys) > 0L) rm(list = keys, envir = cache_env)
api/tests/testthat/test-unit-clustering-gene-universe.R-45-}
api/tests/testthat/test-unit-clustering-gene-universe.R-46-
api/tests/testthat/test-unit-clustering-gene-universe.R-47-test_that("clustering_cached_source_data_version: TTL hit avoids a second underlying fetch", {
api/tests/testthat/test-unit-clustering-gene-universe.R-48-  e <- .source_data_version_env()
api/tests/testthat/test-unit-clustering-gene-universe.R-49-  .reset_source_data_version_cache(e)
api/tests/testthat/test-unit-clustering-gene-universe.R-50-  calls <- 0L
api/tests/testthat/test-unit-clustering-gene-universe.R:51:  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
api/tests/testthat/test-unit-clustering-gene-universe.R-52-    calls <<- calls + 1L
api/tests/testthat/test-unit-clustering-gene-universe.R-53-    "v1"
api/tests/testthat/test-unit-clustering-gene-universe.R-54-  }
api/tests/testthat/test-unit-clustering-gene-universe.R-55-
api/tests/testthat/test-unit-clustering-gene-universe.R-56-  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R-57-  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R-58-
api/tests/testthat/test-unit-clustering-gene-universe.R-59-  expect_identical(first, "v1")
api/tests/testthat/test-unit-clustering-gene-universe.R-60-  expect_identical(second, "v1")
api/tests/testthat/test-unit-clustering-gene-universe.R-61-  expect_identical(calls, 1L) # second call served from cache, underlying fn NOT re-invoked
api/tests/testthat/test-unit-clustering-gene-universe.R-62-})
api/tests/testthat/test-unit-clustering-gene-universe.R-63-
api/tests/testthat/test-unit-clustering-gene-universe.R-64-test_that("clustering_cached_source_data_version: TTL expiry (ttl_seconds = 0) forces a refetch", {
api/tests/testthat/test-unit-clustering-gene-universe.R-65-  # `diff < ttl_seconds` is the staleness check; `diff` (elapsed seconds since
api/tests/testthat/test-unit-clustering-gene-universe.R-66-  # the last successful fetch) is always >= 0, so `ttl_seconds = 0` makes
api/tests/testthat/test-unit-clustering-gene-universe.R-67-  # `diff < 0` FALSE on every subsequent call -- deterministically always-stale,
api/tests/testthat/test-unit-clustering-gene-universe.R-68-  # regardless of clock resolution between the two calls.
api/tests/testthat/test-unit-clustering-gene-universe.R-69-  e <- .source_data_version_env()
api/tests/testthat/test-unit-clustering-gene-universe.R-70-  .reset_source_data_version_cache(e)
api/tests/testthat/test-unit-clustering-gene-universe.R-71-  calls <- 0L
api/tests/testthat/test-unit-clustering-gene-universe.R:72:  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
api/tests/testthat/test-unit-clustering-gene-universe.R-73-    calls <<- calls + 1L
api/tests/testthat/test-unit-clustering-gene-universe.R-74-    paste0("v", calls)
api/tests/testthat/test-unit-clustering-gene-universe.R-75-  }
api/tests/testthat/test-unit-clustering-gene-universe.R-76-
api/tests/testthat/test-unit-clustering-gene-universe.R-77-  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
api/tests/testthat/test-unit-clustering-gene-universe.R-78-  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
api/tests/testthat/test-unit-clustering-gene-universe.R-79-
api/tests/testthat/test-unit-clustering-gene-universe.R-80-  expect_identical(first, "v1")
api/tests/testthat/test-unit-clustering-gene-universe.R-81-  expect_identical(second, "v2")
api/tests/testthat/test-unit-clustering-gene-universe.R-82-  expect_identical(calls, 2L) # both calls hit the underlying fn -- cache never served a hit
api/tests/testthat/test-unit-clustering-gene-universe.R-83-})
api/tests/testthat/test-unit-clustering-gene-universe.R-84-
api/tests/testthat/test-unit-clustering-gene-universe.R-85-test_that("clustering_cached_source_data_version: an error propagates and never poisons the cache", {
api/tests/testthat/test-unit-clustering-gene-universe.R-86-  e <- .source_data_version_env()
api/tests/testthat/test-unit-clustering-gene-universe.R-87-  .reset_source_data_version_cache(e)
api/tests/testthat/test-unit-clustering-gene-universe.R:88:  e$analysis_snapshot_source_data_version <- function(conn = NULL) stop("boom")
api/tests/testthat/test-unit-clustering-gene-universe.R-89-
api/tests/testthat/test-unit-clustering-gene-universe.R-90-  expect_error(
api/tests/testthat/test-unit-clustering-gene-universe.R-91-    e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300),
api/tests/testthat/test-unit-clustering-gene-universe.R-92-    "boom"
api/tests/testthat/test-unit-clustering-gene-universe.R-93-  )
api/tests/testthat/test-unit-clustering-gene-universe.R-94-  # Nothing was written to the cache by the failed call.
api/tests/testthat/test-unit-clustering-gene-universe.R-95-  expect_null(e$.clustering_source_data_version_cache$value)
api/tests/testthat/test-unit-clustering-gene-universe.R-96-  expect_null(e$.clustering_source_data_version_cache$cached_at)
api/tests/testthat/test-unit-clustering-gene-universe.R-97-
api/tests/testthat/test-unit-clustering-gene-universe.R-98-  # Swap to a success stub: the NEXT call must refetch (not serve a stale/NA
api/tests/testthat/test-unit-clustering-gene-universe.R-99-  # value left over from the failed attempt) and the cache must now work.
api/tests/testthat/test-unit-clustering-gene-universe.R-100-  .reset_source_data_version_cache(e)
api/tests/testthat/test-unit-clustering-gene-universe.R-101-  calls <- 0L
api/tests/testthat/test-unit-clustering-gene-universe.R:102:  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
api/tests/testthat/test-unit-clustering-gene-universe.R-103-    calls <<- calls + 1L
api/tests/testthat/test-unit-clustering-gene-universe.R-104-    "v-success"
api/tests/testthat/test-unit-clustering-gene-universe.R-105-  }
api/tests/testthat/test-unit-clustering-gene-universe.R-106-
api/tests/testthat/test-unit-clustering-gene-universe.R-107-  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R-108-
api/tests/testthat/test-unit-clustering-gene-universe.R-109-  expect_identical(result, "v-success")
api/tests/testthat/test-unit-clustering-gene-universe.R-110-  expect_identical(calls, 1L)
api/tests/testthat/test-unit-clustering-gene-universe.R-111-})
api/tests/testthat/test-unit-clustering-gene-universe.R-112-
api/tests/testthat/test-unit-clustering-gene-universe.R-113-testthat::skip_if_not_installed("RSQLite")
api/tests/testthat/test-unit-clustering-gene-universe.R-114-
api/tests/testthat/test-unit-clustering-gene-universe.R-115-# Source the code under test into a child env so the NULL-branch dependency
api/tests/testthat/test-unit-clustering-gene-universe.R-116-# (`generate_ndd_hgnc_ids`) can be overridden per-test without touching
api/tests/testthat/test-unit-clustering-gene-universe.R-117-# globalenv() or any other test file's bindings.
api/tests/testthat/test-unit-clustering-gene-universe.R-118-.gene_universe_env <- function() {
api/tests/testthat/test-unit-clustering-gene-universe.R-119-  e <- new.env(parent = globalenv())
api/tests/testthat/test-unit-clustering-gene-universe.R-120-  source_api_file("core/errors.R", local = FALSE, envir = e)
api/tests/testthat/test-unit-clustering-gene-universe.R-121-  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
api/tests/testthat/test-unit-clustering-gene-universe.R-122-  e
api/tests/testthat/test-unit-clustering-gene-universe.R-123-}
api/tests/testthat/test-unit-clustering-gene-universe.R-124-
api/tests/testthat/test-unit-clustering-gene-universe.R-125-# In-memory RSQLite fixture standing in for `pool`/a real DB connection.
api/tests/testthat/test-unit-clustering-gene-universe.R-126-# `ev` = ndd_entity_view rows, `cats` = ndd_entity_status_categories_list rows.
api/tests/testthat/test-unit-clustering-gene-universe.R-127-fake_conn <- function(ev, cats) {
api/tests/testthat/test-unit-clustering-gene-universe.R-128-  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
api/tests/testthat/test-unit-clustering-gene-universe.R-129-  DBI::dbWriteTable(con, "ndd_entity_view", as.data.frame(ev))
api/tests/testthat/test-unit-clustering-gene-universe.R-130-  DBI::dbWriteTable(con, "ndd_entity_status_categories_list", as.data.frame(cats))
api/tests/testthat/test-unit-clustering-gene-universe.R-131-  con
api/tests/testthat/test-unit-clustering-gene-universe.R-132-}
--
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-97-  active_manifest_loader <- function(analysis_type, params, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-98-    switch(analysis_type,
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-99-      functional_clusters = tibble::tibble(snapshot_id = 42L, payload_hash = "new-functional-hash"),
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-100-      phenotype_clusters = tibble::tibble(snapshot_id = 39L, payload_hash = "phenotype-hash")
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-101-    )
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-102-  }
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-103-
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-104-  expect_equal(
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-105-    env$analysis_snapshot_dependency_status_code(
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-106-      manifest,
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-107-      active_manifest_loader = active_manifest_loader
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-108-    ),
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-109-    "dependency_snapshot_mismatch"
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-110-  )
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-111-})
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-112-
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-113-test_that("public correlation reads do not serve a dependency-mismatched manifest", {
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-114-  env <- new.env(parent = globalenv())
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-115-  env$db_execute_query <- function(...) {
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-116-    tibble::tibble(
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-117-      snapshot_id = 40L,
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-118-      analysis_type = "phenotype_functional_correlations",
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-119-      parameter_hash = "correlation-parameter-hash",
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-120-      public_ready = 1L,
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-121-      status = "public_ready",
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-122-      source_data_version = "source-v1",
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-123-      schema_version = NA_character_,
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-124-      stale_after = as.POSIXct("2099-01-01", tz = "UTC")
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-125-    )
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-126-  }
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R:127:  env$analysis_snapshot_source_data_version <- function(conn = NULL) "source-v1"
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-128-  env$analysis_snapshot_dependency_status_code <- function(manifest, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-129-    expect_equal(manifest$snapshot_id[[1]], 40L)
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-130-    "dependency_snapshot_mismatch"
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-131-  }
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-132-  source(file.path("functions", "analysis-snapshot-repository.R"), local = env)
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-133-
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-134-  result <- env$analysis_snapshot_get_public(
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-135-    "phenotype_functional_correlations",
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-136-    "correlation-parameter-hash"
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-137-  )
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-138-
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-139-  expect_equal(result$status_code, "dependency_snapshot_mismatch")
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-140-  expect_null(result$correlations)
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-141-})
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-142-
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-143-test_that("correlation endpoint metadata exposes dependency lineage", {
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-144-  source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-145-  source(file.path("services", "analysis-snapshot-service.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-146-
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-147-  snapshot <- list(
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-148-    manifest = tibble::tibble(
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-149-      snapshot_id = 40L,
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-150-      analysis_type = "phenotype_functional_correlations",
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-151-      parameter_hash = "correlation-parameter-hash",
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-152-      schema_version = "1.2",
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-153-      data_class = "curated_derived_analysis",
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-154-      generated_at = as.POSIXct("2026-07-16", tz = "UTC"),
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-155-      stale_after = as.POSIXct("2026-07-23", tz = "UTC"),
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-156-      source_data_version = "source-v1",
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R-157-      input_hash = "input-hash",
--
api/tests/testthat/test-unit-analysis-snapshot-builder.R-97-  env <- new.env(parent = globalenv())
api/tests/testthat/test-unit-analysis-snapshot-builder.R-98-  source(file.path("functions", "analysis-snapshot-presets.R"), local = env)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-99-  source(file.path("functions", "analysis-snapshot-builder.R"), local = env)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-100-
api/tests/testthat/test-unit-analysis-snapshot-builder.R-101-  refresh_conn <- structure(list(label = "refresh"), class = "DBIConnection")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-102-  events <- character()
api/tests/testthat/test-unit-analysis-snapshot-builder.R-103-  record_conn <- function(name, conn) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-104-    events <<- c(events, name)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-105-    expect_identical(conn, refresh_conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-106-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-107-
api/tests/testthat/test-unit-analysis-snapshot-builder.R-108-  env$get_db_connection <- function() {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-109-    events <<- c(events, "checkout")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-110-    refresh_conn
api/tests/testthat/test-unit-analysis-snapshot-builder.R-111-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-112-  env$db_with_transaction <- function(code, pool_obj = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-113-    expect_identical(pool_obj, refresh_conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-114-    events <<- c(events, "tx_start")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-115-    result <- code(pool_obj)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-116-    events <<- c(events, "tx_end")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-117-    result
api/tests/testthat/test-unit-analysis-snapshot-builder.R-118-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-119-  env$analysis_snapshot_acquire_lock <- function(analysis_type, parameter_hash, timeout_seconds = 30L, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-120-    record_conn("acquire", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-121-    TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-122-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-123-  env$analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-124-    record_conn("release", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-125-    TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-126-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R:127:  env$analysis_snapshot_source_data_version <- function(conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-128-    record_conn("source_version", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-129-    "source-v1"
api/tests/testthat/test-unit-analysis-snapshot-builder.R-130-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-131-  env$analysis_snapshot_build_payload <- function(analysis_type, params, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-132-    expect_identical(conn, refresh_conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-133-    events <<- c(events, "build_payload")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-134-    list(
api/tests/testthat/test-unit-analysis-snapshot-builder.R-135-      kind = "network",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-136-      nodes = tibble::tibble(),
api/tests/testthat/test-unit-analysis-snapshot-builder.R-137-      edges = tibble::tibble(),
api/tests/testthat/test-unit-analysis-snapshot-builder.R-138-      row_counts = list(nodes = 0L, edges = 0L)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-139-    )
api/tests/testthat/test-unit-analysis-snapshot-builder.R-140-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-141-  env$analysis_snapshot_create_manifest <- function(manifest, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-142-    record_conn("create_manifest", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-143-    expect_equal(manifest$source_data_version, "source-v1")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-144-    expect_s3_class(manifest$stale_after, "POSIXct")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-145-    expect_gt(as.numeric(manifest$stale_after), as.numeric(Sys.time()))
api/tests/testthat/test-unit-analysis-snapshot-builder.R-146-    42
api/tests/testthat/test-unit-analysis-snapshot-builder.R-147-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-148-  env$analysis_snapshot_insert_network_rows <- function(snapshot_id, rows, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-149-    record_conn("insert_network", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-150-    expect_equal(snapshot_id, 42)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-151-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-152-  env$analysis_snapshot_activate <- function(snapshot_id, analysis_type, parameter_hash, conn = NULL, ...) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-153-    record_conn("activate", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-154-    expect_equal(snapshot_id, 42)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-155-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-156-  env$analysis_snapshot_prune <- function(analysis_type, parameter_hash, keep_public_ready = 3L, keep_superseded_days = 14L, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-157-    record_conn("prune", conn)
--
api/tests/testthat/test-unit-analysis-snapshot-builder.R-206-        )
api/tests/testthat/test-unit-analysis-snapshot-builder.R-207-        checked_out
api/tests/testthat/test-unit-analysis-snapshot-builder.R-208-      },
api/tests/testthat/test-unit-analysis-snapshot-builder.R-209-      release = function(object) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-210-        expect_identical(object, checked_out)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-211-        events <<- c(events, "return")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-212-      }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-213-    ),
api/tests/testthat/test-unit-analysis-snapshot-builder.R-214-    class = "Pool"
api/tests/testthat/test-unit-analysis-snapshot-builder.R-215-  )
api/tests/testthat/test-unit-analysis-snapshot-builder.R-216-  record_conn <- function(name, conn) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-217-    events <<- c(events, name)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-218-    expect_identical(conn, checked_out)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-219-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-220-
api/tests/testthat/test-unit-analysis-snapshot-builder.R-221-  env$db_with_transaction <- function(code, pool_obj = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-222-    expect_identical(pool_obj, checked_out)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-223-    events <<- c(events, "tx_start")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-224-    result <- code(pool_obj)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-225-    events <<- c(events, "tx_end")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-226-    result
api/tests/testthat/test-unit-analysis-snapshot-builder.R-227-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-228-  env$analysis_snapshot_acquire_lock <- function(analysis_type, parameter_hash, timeout_seconds = 30L, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-229-    record_conn("acquire", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-230-    TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-231-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-232-  env$analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-233-    record_conn("release", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-234-    TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-235-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R:236:  env$analysis_snapshot_source_data_version <- function(conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-237-    record_conn("source_version", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-238-    "source-v1"
api/tests/testthat/test-unit-analysis-snapshot-builder.R-239-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-240-  env$analysis_snapshot_build_payload <- function(analysis_type, params, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-241-    record_conn("build_payload", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-242-    list(
api/tests/testthat/test-unit-analysis-snapshot-builder.R-243-      kind = "network",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-244-      nodes = tibble::tibble(),
api/tests/testthat/test-unit-analysis-snapshot-builder.R-245-      edges = tibble::tibble(),
api/tests/testthat/test-unit-analysis-snapshot-builder.R-246-      row_counts = list(nodes = 0L, edges = 0L)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-247-    )
api/tests/testthat/test-unit-analysis-snapshot-builder.R-248-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-249-  env$analysis_snapshot_create_manifest <- function(manifest, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-250-    record_conn("create_manifest", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-251-    42
api/tests/testthat/test-unit-analysis-snapshot-builder.R-252-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-253-  env$analysis_snapshot_insert_network_rows <- function(snapshot_id, rows, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-254-    record_conn("insert_network", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-255-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-256-  env$analysis_snapshot_activate <- function(snapshot_id, analysis_type, parameter_hash, conn = NULL, ...) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-257-    record_conn("activate", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-258-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-259-  env$analysis_snapshot_prune <- function(analysis_type, parameter_hash, keep_public_ready = 3L, keep_superseded_days = 14L, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-260-    record_conn("prune", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-261-    0L
api/tests/testthat/test-unit-analysis-snapshot-builder.R-262-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-263-  env$trigger_llm_batch_generation <- function(...) stop("network snapshots must not trigger LLM generation")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-264-
api/tests/testthat/test-unit-analysis-snapshot-builder.R-265-  result <- env$analysis_snapshot_refresh(
api/tests/testthat/test-unit-analysis-snapshot-builder.R-266-    "gene_network_edges",
--
api/tests/testthat/test-unit-analysis-snapshot-builder.R-273-    events,
api/tests/testthat/test-unit-analysis-snapshot-builder.R-274-    c(
api/tests/testthat/test-unit-analysis-snapshot-builder.R-275-      "checkout",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-276-      "acquire",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-277-      "source_version",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-278-      "build_payload",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-279-      "tx_start",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-280-      "create_manifest",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-281-      "insert_network",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-282-      "activate",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-283-      "prune",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-284-      "tx_end",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-285-      "release",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-286-      "return"
api/tests/testthat/test-unit-analysis-snapshot-builder.R-287-    )
api/tests/testthat/test-unit-analysis-snapshot-builder.R-288-  )
api/tests/testthat/test-unit-analysis-snapshot-builder.R-289-})
api/tests/testthat/test-unit-analysis-snapshot-builder.R-290-
api/tests/testthat/test-unit-analysis-snapshot-builder.R-291-test_that("cluster snapshot refresh delegates LLM summary generation to the worker-owned refresh path", {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-292-  env <- new.env(parent = globalenv())
api/tests/testthat/test-unit-analysis-snapshot-builder.R-293-  source(file.path("functions", "analysis-snapshot-presets.R"), local = env)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-294-  source(file.path("functions", "analysis-snapshot-builder.R"), local = env)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-295-
api/tests/testthat/test-unit-analysis-snapshot-builder.R-296-  events <- character()
api/tests/testthat/test-unit-analysis-snapshot-builder.R-297-  refresh_conn <- structure(list(label = "refresh"), class = "DBIConnection")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-298-  clusters <- tibble::tibble(cluster = 1L, identifiers = list(tibble::tibble(hgnc_id = "HGNC:1")))
api/tests/testthat/test-unit-analysis-snapshot-builder.R-299-  env$get_db_connection <- function() refresh_conn
api/tests/testthat/test-unit-analysis-snapshot-builder.R-300-  env$db_with_transaction <- function(code, pool_obj = NULL) code(pool_obj)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-301-  env$analysis_snapshot_acquire_lock <- function(...) TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-302-  env$analysis_snapshot_release_lock <- function(...) TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R:303:  env$analysis_snapshot_source_data_version <- function(...) "source-v1"
api/tests/testthat/test-unit-analysis-snapshot-builder.R-304-  env$analysis_snapshot_build_payload <- function(...) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-305-    list(
api/tests/testthat/test-unit-analysis-snapshot-builder.R-306-      kind = "clusters",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-307-      raw = clusters,
api/tests/testthat/test-unit-analysis-snapshot-builder.R-308-      clusters = tibble::tibble(),
api/tests/testthat/test-unit-analysis-snapshot-builder.R-309-      members = tibble::tibble(),
api/tests/testthat/test-unit-analysis-snapshot-builder.R-310-      row_counts = list(clusters = 1L, members = 1L)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-311-    )
api/tests/testthat/test-unit-analysis-snapshot-builder.R-312-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-313-  env$analysis_snapshot_create_manifest <- function(...) 77L
api/tests/testthat/test-unit-analysis-snapshot-builder.R-314-  env$analysis_snapshot_insert_cluster_rows <- function(...) NULL
api/tests/testthat/test-unit-analysis-snapshot-builder.R-315-  env$analysis_snapshot_activate <- function(...) NULL
api/tests/testthat/test-unit-analysis-snapshot-builder.R-316-  env$analysis_snapshot_prune <- function(...) 0L
api/tests/testthat/test-unit-analysis-snapshot-builder.R-317-  env$trigger_llm_batch_generation <- function(clusters, cluster_type, parent_job_id) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-318-    events <<- c(events, paste(cluster_type, parent_job_id, nrow(clusters), sep = ":"))
api/tests/testthat/test-unit-analysis-snapshot-builder.R-319-    list(job_id = "llm-job")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-320-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-321-
api/tests/testthat/test-unit-analysis-snapshot-builder.R-322-  phenotype_result <- env$analysis_snapshot_refresh("phenotype_clusters", list(), job_id = "phenotype-snapshot-job")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-323-  functional_result <- env$analysis_snapshot_refresh("functional_clusters", list(algorithm = "leiden"), job_id = "functional-snapshot-job")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-324-
api/tests/testthat/test-unit-analysis-snapshot-builder.R-325-  expect_equal(
api/tests/testthat/test-unit-analysis-snapshot-builder.R-326-    events,
api/tests/testthat/test-unit-analysis-snapshot-builder.R-327-    c("phenotype:phenotype-snapshot-job:1", "functional:functional-snapshot-job:1")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-328-  )
api/tests/testthat/test-unit-analysis-snapshot-builder.R-329-  expect_equal(phenotype_result$llm_generation$job_id, "llm-job")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-330-  expect_equal(functional_result$llm_generation$job_id, "llm-job")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-331-})
api/tests/testthat/test-unit-analysis-snapshot-builder.R-332-
api/tests/testthat/test-unit-analysis-snapshot-builder.R-333-test_that("cluster_hash is extracted from hash_filter and fits CHAR(64)", {
--
api/functions/analysis-snapshot-repository.R-506-#' Unlike `analysis_snapshot_public_exists()` (which only checks that a
api/functions/analysis-snapshot-repository.R-507-#' public-ready row exists), this returns TRUE only when that row is also
api/functions/analysis-snapshot-repository.R-508-#' *current* — its computed `status_code` is `"available"`, not `snapshot_stale`
api/functions/analysis-snapshot-repository.R-509-#' or `source_version_mismatch`. Used as the skip predicate by the startup
api/functions/analysis-snapshot-repository.R-510-#' bootstrap and the non-force admin refresh so a STALE or VERSION-MISMATCHED
api/functions/analysis-snapshot-repository.R-511-#' snapshot is re-enqueued (self-heals on restart) instead of being treated as
api/functions/analysis-snapshot-repository.R-512-#' "already present" and left serving a permanent 503. The #420/#440 self-heal
api/functions/analysis-snapshot-repository.R-513-#' only covered `snapshot_missing`; a snapshot that aged past `stale_after`
api/functions/analysis-snapshot-repository.R-514-#' (default 7 days) never refreshed on its own. See AGENTS.md "Public analysis
api/functions/analysis-snapshot-repository.R-515-#' endpoints".
api/functions/analysis-snapshot-repository.R-516-#'
api/functions/analysis-snapshot-repository.R-517-#' @param manifest_fn Injectable manifest read (default
api/functions/analysis-snapshot-repository.R-518-#'   `analysis_snapshot_public_manifest`) so this is unit-testable without a DB.
api/functions/analysis-snapshot-repository.R-519-#' @return TRUE only when a public-ready snapshot exists and is current.
api/functions/analysis-snapshot-repository.R-520-#' @export
api/functions/analysis-snapshot-repository.R-521-analysis_snapshot_public_current <- function(analysis_type,
api/functions/analysis-snapshot-repository.R-522-                                             parameter_hash,
api/functions/analysis-snapshot-repository.R-523-                                             conn = NULL,
api/functions/analysis-snapshot-repository.R-524-                                             manifest_fn = analysis_snapshot_public_manifest) {
api/functions/analysis-snapshot-repository.R-525-  manifest <- tryCatch(
api/functions/analysis-snapshot-repository.R-526-    manifest_fn(analysis_type, parameter_hash, conn = conn),
api/functions/analysis-snapshot-repository.R-527-    error = function(e) NULL
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
api/functions/analysis-snapshot-repository.R-545-}
api/functions/analysis-snapshot-repository.R-546-
api/functions/analysis-snapshot-repository.R-547-# analysis_snapshot_prune() was extracted to
api/functions/analysis-snapshot-repository.R-548-# functions/analysis-snapshot-prune-helpers.R (#573 round-3 CI1) to keep this
api/functions/analysis-snapshot-repository.R-549-# file under the 600-line ceiling. It is sourced immediately after this file in
api/functions/analysis-snapshot-repository.R-550-# both bootstrap/load_modules.R and bootstrap/setup_workers.R.

exec
/bin/bash -lc "rg -n 'generate_ndd_hgnc_ids' api/functions/analyses-functions.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
exec
/bin/bash -lc "git show origin/master:api/services/job-functional-submission-service.R | nl -ba | sed -n '35,280p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
380:generate_ndd_hgnc_ids <- function() {
392:  genes_from_entity_table <- generate_ndd_hgnc_ids()

 succeeded in 0ms:
    35	  # provoke — expensive work (a cache hit still writes a completed job row, and the
    36	  # duplicate/data fetch below touch the DB). Layered on the global capacity cap.
    37	  admission <- async_job_submit_admission_guard(req, res)
    38	  if (!isTRUE(admission$admitted)) {
    39	    return(admission$response)
    40	  }
    41	
    42	  # Extract request data before durable submission.
    43	
    44	  # Connection objects cannot cross process boundaries
    45	  genes_list <- NULL
    46	  if (!is.null(req$argsBody$genes)) {
    47	    genes_list <- req$argsBody$genes
    48	  }
    49	
    50	  # Extract algorithm parameter (default: leiden)
    51	  # Ensure we get a scalar value (JSON may pass arrays)
    52	  algorithm <- "leiden"
    53	  if (!is.null(req$argsBody$algorithm)) {
    54	    algo_input <- req$argsBody$algorithm
    55	    # Handle array input - always take first element if vector
    56	    if (is.list(algo_input) || length(algo_input) >= 1) {
    57	      algo_input <- algo_input[[1]]
    58	    }
    59	    algorithm <- tolower(as.character(algo_input))
    60	    if (!algorithm %in% c("leiden", "walktrap")) {
    61	      algorithm <- "leiden"
    62	    }
    63	  }
    64	
    65	  # If no genes provided, use default (all NDD genes)
    66	  # This matches current functional_clustering endpoint behavior
    67	  if (is.null(genes_list) || length(genes_list) == 0) {
    68	    genes_list <- pool %>%
    69	      dplyr::tbl("ndd_entity_view") %>%
    70	      dplyr::arrange(entity_id) %>%
    71	      dplyr::filter(ndd_phenotype == 1) %>%
    72	      dplyr::select(hgnc_id) %>%
    73	      dplyr::collect() %>%
    74	      unique() %>%
    75	      dplyr::pull(hgnc_id)
    76	  }
    77	
    78	  # Pre-fetch the STRING ID table because DB connections cannot cross the
    79	  # durable worker boundary.
    80	  string_id_table <- pool %>%
    81	    dplyr::tbl("non_alt_loci_set") %>%
    82	    dplyr::filter(!is.na(STRING_id)) %>%
    83	    dplyr::select(symbol, hgnc_id, STRING_id) %>%
    84	    dplyr::collect()
    85	
    86	  # Check for duplicate job (include algorithm in check)
    87	  dup_check <- check_duplicate_job("clustering", list(genes = genes_list, algorithm = algorithm))
    88	  if (dup_check$duplicate) {
    89	    res$status <- 409
    90	    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
    91	    return(list(
    92	      error = "DUPLICATE_JOB",
    93	      message = "Identical job already running",
    94	      existing_job_id = dup_check$existing_job_id,
    95	      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
    96	    ))
    97	  }
    98	
    99	  # Define category links (needed for result)
   100	  category_links <- tibble::tibble(
   101	    value = c(
   102	      "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
   103	      "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
   104	      "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
   105	    ),
   106	    link = c(
   107	      "https://www.ebi.ac.uk/QuickGO/term/",
   108	      "https://www.ebi.ac.uk/QuickGO/term/",
   109	      "https://disease-ontology.org/term/",
   110	      "https://www.ebi.ac.uk/QuickGO/term/",
   111	      "https://hpo.jax.org/browse/term/",
   112	      "http://www.ebi.ac.uk/interpro/entry/InterPro/",
   113	      "https://www.genome.jp/dbget-bin/www_bget?",
   114	      "https://www.uniprot.org/keywords/",
   115	      "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
   116	      "https://www.ebi.ac.uk/interpro/entry/pfam/",
   117	      "https://www.ncbi.nlm.nih.gov/search/all/?term=",
   118	      "https://www.ebi.ac.uk/QuickGO/term/",
   119	      "https://reactome.org/content/detail/R-",
   120	      "http://www.ebi.ac.uk/interpro/entry/smart/",
   121	      "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
   122	      "https://www.wikipathways.org/index.php/Pathway:"
   123	    )
   124	  )
   125	
   126	  # Cache-first: if the memoized function already has a cached result,
   127	  # return it immediately without submitting a durable worker job.
   128	  # The network_edges endpoint (graph) warms this cache on first load,
   129	  # so subsequent table requests resolve instantly.
   130	  cache_hit <- tryCatch(
   131	    memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
   132	    error = function(e) FALSE
   133	  )
   134	
   135	  if (cache_hit) {
   136	    cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)
   137	
   138	    categories <- cached_clusters %>%
   139	      dplyr::select(term_enrichment) %>%
   140	      tidyr::unnest(cols = c(term_enrichment)) %>%
   141	      dplyr::select(category) %>%
   142	      unique() %>%
   143	      dplyr::arrange(category) %>%
   144	      dplyr::mutate(
   145	        text = dplyr::case_when(
   146	          nchar(category) <= 5 ~ category,
   147	          nchar(category) > 5 ~ stringr::str_to_sentence(category)
   148	        )
   149	      ) %>%
   150	      dplyr::select(value = category, text) %>%
   151	      dplyr::left_join(category_links, by = c("value"))
   152	
   153	    cache_result <- list(
   154	      clusters = cached_clusters,
   155	      categories = categories,
   156	      meta = list(
   157	        algorithm = algorithm,
   158	        gene_count = length(genes_list),
   159	        cluster_count = nrow(cached_clusters),
   160	        cache_hit = TRUE
   161	      )
   162	    )
   163	    completed_job <- async_job_service_store_completed(
   164	      job_type = "clustering",
   165	      request_payload = list(
   166	        genes = genes_list,
   167	        algorithm = algorithm,
   168	        category_links = category_links,
   169	        string_id_table = string_id_table
   170	      ),
   171	      result = cache_result,
   172	      submitted_by = req$user$user_id %||% NULL,
   173	      queue_name = "analysis",
   174	      priority = 50L
   175	    )
   176	    job_id <- completed_job$job_id[[1]]
   177	
   178	    res$status <- 202
   179	    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   180	    res$setHeader("Retry-After", "0")
   181	
   182	    return(list(
   183	      job_id = job_id,
   184	      status = "accepted",
   185	      estimated_seconds = 0,
   186	      status_url = paste0("/api/jobs/", job_id, "/status"),
   187	      meta = list(llm_generation = "snapshot_refresh_owned")
   188	    ))
   189	  }
   190	
   191	  # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
   192	  # "default" matches the queue create_job() enqueues on via async_job_service_submit.
   193	  if (async_job_capacity_exceeded(
   194	        tryCatch(
   195	          async_job_active_count("default"),
   196	          error = function(e) {
   197	            log_warn("async_job_active_count failed (capacity check fail-open): {e$message}")
   198	            0L
   199	          }
   200	        )
   201	      )) {
   202	    res$status <- 503
   203	    res$setHeader("Retry-After", "60")
   204	    return(list(
   205	      error = "CAPACITY_EXCEEDED",
   206	      message = "Analysis queue is at capacity. Please retry shortly.",
   207	      retry_after = 60
   208	    ))
   209	  }
   210	
   211	  # Cache miss - create async job
   212	  result <- create_job(
   213	    operation = "clustering",
   214	    params = list(
   215	      genes = genes_list,
   216	      algorithm = algorithm,
   217	      category_links = category_links,
   218	      string_id_table = string_id_table
   219	    )
   220	  )
   221	
   222	  # Check capacity
   223	  if (!is.null(result$error)) {
   224	    res$status <- 503
   225	    res$setHeader("Retry-After", as.character(result$retry_after))
   226	    return(result)
   227	  }
   228	
   229	  # Success - return HTTP 202 Accepted
   230	  res$status <- 202
   231	  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
   232	  res$setHeader("Retry-After", "5")
   233	
   234	  list(
   235	    job_id = result$job_id,
   236	    status = result$status,
   237	    estimated_seconds = result$estimated_seconds,
   238	    status_url = paste0("/api/jobs/", result$job_id, "/status")
   239	  )
   240	}

exec
/bin/bash -lc "rg -n 'analysis_snapshot_source_data_version' api/functions" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/functions/clustering-gene-universe.R:87:# `analysis_snapshot_source_data_version()`. That read joins/aggregates across
api/functions/clustering-gene-universe.R:99:#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
api/functions/clustering-gene-universe.R:116:  value <- analysis_snapshot_source_data_version(conn = conn)
api/functions/analysis-snapshot-repository.R:327:    exists("analysis_snapshot_source_data_version", mode = "function")) {
api/functions/analysis-snapshot-repository.R:329:      analysis_snapshot_source_data_version(conn = conn),
api/functions/analysis-snapshot-repository.R:489:    exists("analysis_snapshot_source_data_version", mode = "function")) {
api/functions/analysis-snapshot-repository.R:491:      analysis_snapshot_source_data_version(conn = conn),
api/functions/analysis-snapshot-repository.R:536:analysis_snapshot_source_data_version <- function(conn = NULL) {
api/functions/analysis-snapshot-builder.R:492:    source_data_version <- analysis_snapshot_source_data_version(conn = refresh_conn)

exec
/bin/bash -lc "sed -n '1,260p' api/tests/testthat/test-unit-clustering-gene-universe.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
# Unit tests for the category-selected clustering gene-universe resolver (#574 D1).
#
# `clustering_resolve_category_universe()` resolves the gene set a clustering
# job runs on: either the current default (all NDD genes, via
# `generate_ndd_hgnc_ids()`) or a curated-category selection
# (`ndd_entity_view` entity rows filtered by `category %in% selector`, then
# distinct `hgnc_id`). This file is DB-free: the default branch's dependency
# (`generate_ndd_hgnc_ids()`) is overridden in a child environment, and the
# category branch's `conn` is a real in-memory RSQLite connection so the
# dbplyr pipeline (`tbl()` / `filter()` / `select()` / `collect()`) is
# exercised for real rather than mocked.
#
# Trap: do NOT stub `generate_ndd_hgnc_ids` via
# `testthat::local_mocked_bindings(..., .env = globalenv())` -- under
# testthat 3.3.2 that aborts with "No packages loaded with pkgload" because
# globalenv() has no package namespace. A child-env override sidesteps this.

## -------------------------------------------------------------------------##
## clustering_cached_source_data_version() TTL cache (#574 D2 review fix)
## -------------------------------------------------------------------------##
#
# These tests stub `analysis_snapshot_source_data_version()` directly -- no DB
# connection is ever opened -- so they are placed BEFORE the file-wide
# `skip_if_not_installed("RSQLite")` gate below and run unconditionally, even
# when {RSQLite} is unavailable.

# Sources ONLY core/errors.R + the module under test into a fresh child env.
# A fresh env means a fresh `.clustering_source_data_version_cache` (it is
# created top-level by the sourced file), so there is nothing left over from
# a prior test -- `.reset_source_data_version_cache()` below is still applied
# defensively so the reset mechanism itself stays covered/documented.
.source_data_version_env <- function() {
  e <- new.env(parent = globalenv())
  source_api_file("core/errors.R", local = FALSE, envir = e)
  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
  e
}

# Clears the module-level TTL cache env so cached state never leaks across
# assertions sharing the same sourced env `e`.
.reset_source_data_version_cache <- function(e) {
  cache_env <- e$.clustering_source_data_version_cache
  keys <- ls(cache_env, all.names = TRUE)
  if (length(keys) > 0L) rm(list = keys, envir = cache_env)
}

test_that("clustering_cached_source_data_version: TTL hit avoids a second underlying fetch", {
  e <- .source_data_version_env()
  .reset_source_data_version_cache(e)
  calls <- 0L
  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
    calls <<- calls + 1L
    "v1"
  }

  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)

  expect_identical(first, "v1")
  expect_identical(second, "v1")
  expect_identical(calls, 1L) # second call served from cache, underlying fn NOT re-invoked
})

test_that("clustering_cached_source_data_version: TTL expiry (ttl_seconds = 0) forces a refetch", {
  # `diff < ttl_seconds` is the staleness check; `diff` (elapsed seconds since
  # the last successful fetch) is always >= 0, so `ttl_seconds = 0` makes
  # `diff < 0` FALSE on every subsequent call -- deterministically always-stale,
  # regardless of clock resolution between the two calls.
  e <- .source_data_version_env()
  .reset_source_data_version_cache(e)
  calls <- 0L
  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
    calls <<- calls + 1L
    paste0("v", calls)
  }

  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)

  expect_identical(first, "v1")
  expect_identical(second, "v2")
  expect_identical(calls, 2L) # both calls hit the underlying fn -- cache never served a hit
})

test_that("clustering_cached_source_data_version: an error propagates and never poisons the cache", {
  e <- .source_data_version_env()
  .reset_source_data_version_cache(e)
  e$analysis_snapshot_source_data_version <- function(conn = NULL) stop("boom")

  expect_error(
    e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300),
    "boom"
  )
  # Nothing was written to the cache by the failed call.
  expect_null(e$.clustering_source_data_version_cache$value)
  expect_null(e$.clustering_source_data_version_cache$cached_at)

  # Swap to a success stub: the NEXT call must refetch (not serve a stale/NA
  # value left over from the failed attempt) and the cache must now work.
  .reset_source_data_version_cache(e)
  calls <- 0L
  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
    calls <<- calls + 1L
    "v-success"
  }

  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)

  expect_identical(result, "v-success")
  expect_identical(calls, 1L)
})

testthat::skip_if_not_installed("RSQLite")

# Source the code under test into a child env so the NULL-branch dependency
# (`generate_ndd_hgnc_ids`) can be overridden per-test without touching
# globalenv() or any other test file's bindings.
.gene_universe_env <- function() {
  e <- new.env(parent = globalenv())
  source_api_file("core/errors.R", local = FALSE, envir = e)
  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
  e
}

# In-memory RSQLite fixture standing in for `pool`/a real DB connection.
# `ev` = ndd_entity_view rows, `cats` = ndd_entity_status_categories_list rows.
fake_conn <- function(ev, cats) {
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  DBI::dbWriteTable(con, "ndd_entity_view", as.data.frame(ev))
  DBI::dbWriteTable(con, "ndd_entity_status_categories_list", as.data.frame(cats))
  con
}

# Fixture: entity rows (one row per entity). TWO Definitive NDD genes so the
# ["Definitive"] universe passes the >=2 guard.
ev <- tibble::tribble(
  ~entity_id, ~hgnc_id,  ~ndd_phenotype, ~category,
  1L,        "HGNC:1",   1L,             "Definitive",   # gene 1: Definitive + Limited
  2L,        "HGNC:1",   1L,             "Limited",
  3L,        "HGNC:2",   1L,             "Limited",      # gene 2: Limited only
  4L,        "HGNC:3",   0L,             "Definitive",   # gene 3: Definitive but NON-NDD
  5L,        "HGNC:4",   1L,             "Moderate",     # gene 4: Moderate NDD (single -> too-small alone)
  6L,        "HGNC:5",   1L,             "Definitive"    # gene 5: second Definitive NDD gene
)
cats <- tibble::tibble(
  category = c("Definitive", "Moderate", "Limited", "Refuted", "not applicable"),
  is_active = 1L
)

test_that("Definitive selects genes with any Definitive NDD entity (multi-entity gene included)", {
  e <- .gene_universe_env()
  con <- fake_conn(ev, cats)
  withr::defer(DBI::dbDisconnect(con))

  r <- e$clustering_resolve_category_universe("Definitive", conn = con)

  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5")) # HGNC:2 Limited-only excluded; HGNC:3 non-NDD excluded
  expect_identical(r$selector, "Definitive")
  expect_identical(r$resolved_gene_count, 2L)
})

test_that("multi-value selector is a union across categories", {
  e <- .gene_universe_env()
  con <- fake_conn(ev, cats)
  withr::defer(DBI::dbDisconnect(con))

  r <- e$clustering_resolve_category_universe(c("Definitive", "Moderate"), conn = con)

  expect_setequal(r$hgnc_ids, c("HGNC:1", "HGNC:5", "HGNC:4"))
})

test_that("NULL selector returns all NDD genes, order-identical to generate_ndd_hgnc_ids()", {
  e <- .gene_universe_env()
  con <- fake_conn(ev, cats)
  withr::defer(DBI::dbDisconnect(con))
  e$generate_ndd_hgnc_ids <- function() {
    tibble::tibble(hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5"))
  }

  r <- e$clustering_resolve_category_universe(NULL, conn = con)

  expect_identical(r$hgnc_ids, c("HGNC:1", "HGNC:2", "HGNC:4", "HGNC:5")) # arrange(entity_id)+distinct, ndd_phenotype==1
  expect_null(r$selector)
})

test_that("unknown token is rejected 400 with the allowed set in the MESSAGE (not detail)", {
  e <- .gene_universe_env()
  con <- fake_conn(ev, cats)
  withr::defer(DBI::dbDisconnect(con))

  err <- tryCatch(
    e$clustering_resolve_category_universe("Definative", conn = con),
    error = function(err) err
  )

  expect_s3_class(err, "error_400")
  expect_match(conditionMessage(err), "Definitive") # allowed set is in the message so it reaches clients
})

test_that("supplied-but-empty selector is 400 (NOT the all-NDD default)", {
  e <- .gene_universe_env()
  con <- fake_conn(ev, cats)
  withr::defer(DBI::dbDisconnect(con))

  expect_error(e$clustering_resolve_category_universe(list(), conn = con), class = "error_400")
  expect_error(e$clustering_resolve_category_universe(list("   "), conn = con), class = "error_400")
})

test_that("a valid category resolving to < 2 genes is rejected 400 (no degenerate-graph job)", {
  e <- .gene_universe_env()
  con <- fake_conn(ev, cats)
  withr::defer(DBI::dbDisconnect(con))

  expect_error(e$clustering_resolve_category_universe("Refuted", conn = con), class = "error_400") # 0 genes
  expect_error(e$clustering_resolve_category_universe("Moderate", conn = con), class = "error_400") # 1 gene
})

test_that("gene_list_sha256 is sort-order independent", {
  e <- .gene_universe_env()

  expect_identical(
    e$clustering_gene_list_sha256(c("HGNC:3", "HGNC:1")),
    e$clustering_gene_list_sha256(c("HGNC:1", "HGNC:3"))
  )
})

test_that("clustering_normalize_category_filter: absent (NULL) vs supplied-but-empty are distinct", {
  e <- .gene_universe_env()

  expect_null(e$clustering_normalize_category_filter(NULL))
  expect_identical(e$clustering_normalize_category_filter(list()), character(0))
  expect_identical(e$clustering_normalize_category_filter(list("   ")), character(0))
  expect_identical(e$clustering_normalize_category_filter(list("")), character(0))
  expect_identical(
    e$clustering_normalize_category_filter(c("Moderate", "Definitive", "Definitive")),
    c("Definitive", "Moderate")
  )
})

exec
/bin/bash -lc "rg -n 'check_duplicate_job|create_job <-|create_job\\(' api/functions/job-manager.R api/functions/async-job-service.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/functions/job-manager.R:31:#' result <- create_job(
api/functions/job-manager.R:36:create_job <- function(operation, params) {
api/functions/job-manager.R:221:#' dup <- check_duplicate_job("clustering", list(genes = c("BRCA1")))
api/functions/job-manager.R:226:check_duplicate_job <- function(operation, params) {
api/functions/job-manager.R:232:#' Same `(operation, params)` shape as [check_duplicate_job()] so it is a
api/functions/job-manager.R:346:# because trigger_llm_batch_generation() calls create_job()

exec
/bin/bash -lc "sed -n '1,240p' api/tests/testthat/test-unit-clustering-handler-meta.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
# Unit tests for the durable clustering handler's result `meta` (#574 D3).
#
# `.async_job_run_clustering()` (api/functions/async-job-handlers.R) is the
# worker-run (cache-miss) counterpart to the cache-hit path in
# `svc_job_submit_functional_clustering()` (job-functional-submission-service.R,
# #574 D2). D2 already stitches the request's cheap-path `provenance` list
# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
# source_data_version) plus an `effective_fingerprint` (the STRING
# `weight_channel` actually observed on the computed result) into the
# cache-hit result `meta`. D3 makes the durable handler mirror that SAME
# shape for a worker-run job, so a silent exp+db -> combined-score STRING
# fallback is visible in a freshly-computed job's stored result too, not
# just a cache hit's.
#
# DB-free: `gen_string_clust_obj` and its category-enrichment/progress-reporter
# collaborators are stubbed in a child environment. This file never opens a
# DB connection and always runs (no skip guard).
#
# Trap (documented in test-unit-clustering-gene-universe.R and repeated here):
# do NOT stub via `testthat::local_mocked_bindings(..., .env = globalenv())`
# -- under testthat 3.3.2 that aborts with "No packages loaded with
# pkgload" because globalenv() has no package namespace. A child-env
# override (source into a fresh `new.env(parent = globalenv())`, then
# reassign bindings on that env) sidesteps this entirely.

.clustering_handler_env <- function() {
  e <- new.env(parent = globalenv())
  # async-job-handlers.R's eagerly-built async_job_handler_registry list()
  # references handler functions from these sibling modules by bare symbol
  # (#346 Wave 4 split; see the file's own header comment), so they must be
  # sourced first or the list() construction fails with "object '...' not
  # found" -- mirrors test-unit-async-job-handlers.R.
  source_api_file("functions/async-job-force-apply-payload.R", local = FALSE, envir = e)
  source_api_file("functions/async-job-omim-apply.R", local = FALSE, envir = e)
  source_api_file("functions/async-job-provider-handlers.R", local = FALSE, envir = e)
  source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE, envir = e)
  source_api_file("functions/async-job-network-layout-handlers.R", local = FALSE, envir = e)
  source_api_file("functions/async-job-analysis-snapshot-handlers.R", local = FALSE, envir = e)
  # `.async_job_run_clustering()`'s result-`meta` assembly calls
  # `clustering_result_meta()` (#574 D3 fix wave 1), the shared helper defined
  # in clustering-gene-universe.R -- source it too or the handler errors with
  # "could not find function".
  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
  source_api_file("functions/async-job-handlers.R", local = FALSE, envir = e)

  # Stub the heavy clustering computation: returns a minimal tibble carrying
  # the SAME `weight_channel` attribute contract `gen_string_clust_obj` sets
  # (analyses-functions.R:351) so the handler's `effective_fingerprint`
  # extraction is exercised for real.
  e$gen_string_clust_obj <- function(genes, algorithm, string_id_table) {
    x <- tibble::tibble(cluster = 1L)
    attr(x, "weight_channel") <- "experimental_database"
    x
  }

  # `.async_job_functional_categories(clusters, category_links)` is called
  # unconditionally by the handler; stub it out so this test does not also
  # have to fabricate a `term_enrichment` column on the stub clusters tibble.
  e$.async_job_functional_categories <- function(clusters, category_links) {
    tibble::tibble()
  }

  # Bypasses `create_async_job_progress_reporter()` (a separate, unsourced
  # module in this DB-free test) -- see file header trap note.
  e$.async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
    function(...) invisible(NULL)
  }

  e
}

test_that(".async_job_run_clustering echoes payload provenance + effective_fingerprint into result meta", {
  e <- .clustering_handler_env()

  payload <- list(
    genes = c("HGNC:1", "HGNC:5"),
    algorithm = "leiden",
    string_id_table = NULL,
    category_links = NULL,
    provenance = list(
      selector = list(kind = "category", category_filter = "Definitive"),
      resolved_gene_count = 2L,
      gene_list_sha256 = "abc",
      intended_fingerprint = list(string_cache_fingerprint = "fp"),
      source_data_version = "srcv-1"
    )
  )

  result <- e$.async_job_run_clustering(
    job = list(job_id = "j1"),
    payload = payload,
    state = NULL,
    worker_config = NULL
  )

  meta <- result$meta

  expect_identical(meta$algorithm, "leiden")
  expect_identical(meta$gene_count, 2L)
  expect_identical(meta$cluster_count, 1L)
  # Shape parity with the cache-hit path's meta (job-functional-submission-
  # service.R), which always carries cache_hit = TRUE: a worker-run job must
  # carry cache_hit = FALSE so callers can distinguish the two without an
  # absent-field check.
  expect_identical(meta$cache_hit, FALSE)
  expect_identical(meta$selector$kind, "category")
  expect_identical(meta$gene_list_sha256, "abc")
  expect_identical(meta$source_data_version, "srcv-1")
  expect_identical(meta$intended_fingerprint$string_cache_fingerprint, "fp")
  expect_identical(meta$effective_fingerprint$weight_channel, "experimental_database")
})

test_that(".async_job_run_clustering: legacy payload with no provenance still returns a valid meta (backward compat)", {
  e <- .clustering_handler_env()

  payload <- list(
    genes = c("HGNC:1", "HGNC:5", "HGNC:9"),
    algorithm = "walktrap",
    string_id_table = NULL,
    category_links = NULL
    # No `provenance` field -- mirrors an explicit/no-arg pre-#574 submit.
  )

  result <- NULL
  expect_no_error({
    result <- e$.async_job_run_clustering(
      job = list(job_id = "j2"),
      payload = payload,
      state = NULL,
      worker_config = NULL
    )
  })

  meta <- result$meta

  expect_identical(meta$algorithm, "walktrap")
  expect_identical(meta$gene_count, 3L)
  expect_identical(meta$cluster_count, 1L)
  expect_identical(meta$effective_fingerprint$weight_channel, "experimental_database")
  # No provenance fields leaked in when the payload never carried them.
  expect_null(meta$selector)
  expect_null(meta$gene_list_sha256)
  expect_null(meta$source_data_version)
  expect_null(meta$intended_fingerprint)
})

exec
/bin/bash -lc "rg -n -C 20 'async_job_service_payload_json|async_job_service_request_hash|async_job_service_submit' api/functions/async-job-service.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
136-
137-.async_job_service_abort <- function(message, class = "async_job_service_validation_error", ...) {
138-  rlang::abort(message = message, class = class, ...)
139-}
140-
141-.async_job_service_non_empty_string <- function(value, field) {
142-  scalar <- .async_job_service_scalar(value, NULL)
143-
144-  if (is.null(scalar)) {
145-    .async_job_service_abort(sprintf("%s is required", field))
146-  }
147-
148-  scalar <- as.character(scalar)
149-  if (!nzchar(trimws(scalar))) {
150-    .async_job_service_abort(sprintf("%s is required", field))
151-  }
152-
153-  scalar
154-}
155-
156:async_job_service_payload_json <- function(request_payload) {
157-  if (is.character(request_payload) && length(request_payload) == 1L) {
158-    return(request_payload[[1]])
159-  }
160-
161-  as.character(
162-    jsonlite::toJSON(
163-      request_payload,
164-      auto_unbox = TRUE,
165-      null = "null",
166-      dataframe = "rows",
167-      POSIXt = "ISO8601"
168-    )
169-  )
170-}
171-
172:async_job_service_request_hash <- function(job_type, request_payload_json) {
173-  digest::digest(
174-    paste0(
175-      .async_job_service_non_empty_string(job_type, "job_type"),
176-      ":",
177-      as.character(.async_job_service_scalar(request_payload_json, ""))
178-    ),
179-    algo = "sha256",
180-    serialize = FALSE
181-  )
182-}
183-
184-.async_job_service_duplicate_row <- function(error, conn = NULL) {
185-  duplicate_job <- error$duplicate_job
186-  if (is.null(duplicate_job)) {
187-    duplicate_job <- tibble::tibble()
188-  }
189-
190-  if (nrow(duplicate_job) > 0) {
191-    return(duplicate_job)
192-  }
--
200-}
201-
202-#' Submit a durable async job and return its stored row
203-#'
204-#' @param job_type Character durable job type.
205-#' @param request_payload Named list or JSON payload string.
206-#' @param submitted_by Optional user id.
207-#' @param queue_name Character queue name. `NULL` (default) routes by job type via
208-#'   `async_job_queue_for_type()` (maintenance lane for heavy jobs, else default);
209-#'   an explicit value is honored as-is.
210-#' @param priority Integer queue priority. `NULL` (default) resolves by job type
211-#'   via `async_job_priority_for_type()` (interactive < maintenance < default); an
212-#'   explicit value is honored as-is.
213-#' @param max_attempts Integer maximum attempts.
214-#' @param scheduled_at Optional schedule time.
215-#' @param job_id Optional explicit job id for tests.
216-#' @param conn Optional DB connection or pool.
217-#'
218-#' @return List containing the stored job row and duplicate/create flags.
219-#' @export
220:async_job_service_submit <- function(
221-  job_type,
222-  request_payload,
223-  submitted_by = NULL,
224-  queue_name = NULL,
225-  priority = NULL,
226-  max_attempts = 1L,
227-  scheduled_at = Sys.time(),
228-  job_id = uuid::UUIDgenerate(),
229-  conn = NULL
230-) {
231-  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
232-  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
233-  # Default the lane + priority from the job type so heavy maintenance jobs never
234-  # head-of-line block interactive jobs (#486). Explicit overrides are honored.
235-  if (is.null(queue_name)) {
236-    queue_name <- async_job_queue_for_type(job_type)
237-  }
238-  if (is.null(priority)) {
239-    priority <- async_job_priority_for_type(job_type)
240-  }
241-  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
242:  payload_json <- async_job_service_payload_json(request_payload)
243:  request_hash <- async_job_service_request_hash(job_type, payload_json)
244-  submitted_at <- Sys.time()
245-
246-  stored_job <- tryCatch(
247-    {
248-      async_job_repository_create(
249-        list(
250-          job_id = job_id,
251-          job_type = job_type,
252-          queue_name = queue_name,
253-          priority = as.integer(priority),
254-          request_hash = request_hash,
255-          request_payload_json = payload_json,
256-          submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
257-          submitted_at = submitted_at,
258-          scheduled_at = scheduled_at,
259-          max_attempts = as.integer(max_attempts)
260-        ),
261-        conn = conn
262-      )
263-
--
293-#' @param completed_at Optional completion timestamp.
294-#' @param conn Optional DB connection or pool.
295-#'
296-#' @return Tibble with the stored completed job row.
297-#' @export
298-async_job_service_store_completed <- function(
299-  job_type,
300-  request_payload,
301-  result,
302-  submitted_by = NULL,
303-  queue_name = "default",
304-  priority = 100L,
305-  job_id = uuid::UUIDgenerate(),
306-  submitted_at = Sys.time(),
307-  completed_at = submitted_at,
308-  conn = NULL
309-) {
310-  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
311-  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
312-  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
313:  payload_json <- async_job_service_payload_json(request_payload)
314:  result_json <- async_job_service_payload_json(result)
315-
316-  async_job_repository_create(
317-    list(
318-      job_id = job_id,
319-      job_type = job_type,
320-      queue_name = queue_name,
321-      priority = as.integer(priority),
322-      status = "completed",
323:      request_hash = async_job_service_request_hash(job_type, payload_json),
324-      request_payload_json = payload_json,
325-      submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
326-      submitted_at = submitted_at,
327-      scheduled_at = submitted_at,
328-      started_at = submitted_at,
329-      completed_at = completed_at,
330-      progress_pct = 100,
331-      result_json = result_json
332-    ),
333-    conn = conn
334-  )
335-
336-  async_job_repository_get(job_id, include_result = TRUE, conn = conn)
337-}
338-
339-#' Find an active duplicate for a durable async job request
340-#'
341-#' @param job_type Character durable job type.
342-#' @param request_payload Named list or JSON payload string.
343-#' @param conn Optional DB connection or pool.
344-#'
345-#' @return Tibble with zero or one active duplicate row.
346-#' @export
347-async_job_service_find_duplicate <- function(job_type, request_payload, conn = NULL) {
348-  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
349:  payload_json <- async_job_service_payload_json(request_payload)
350-
351-  async_job_repository_find_active_duplicate(
352-    job_type = job_type,
353:    request_hash = async_job_service_request_hash(job_type, payload_json),
354-    conn = conn
355-  )
356-}
357-
358-#' Read current durable async job status
359-#'
360-#' @param job_id Character job id.
361-#' @param include_result Logical; include result_json when TRUE.
362-#' @param conn Optional DB connection or pool.
363-#'
364-#' @return Tibble with zero or one durable job row.
365-#' @export
366-async_job_service_status <- function(job_id, include_result = FALSE, conn = NULL) {
367-  async_job_repository_get(
368-    job_id = .async_job_service_non_empty_string(job_id, "job_id"),
369-    include_result = isTRUE(include_result),
370-    conn = conn
371-  )
372-}
373-

exec
/bin/bash -lc "nl -ba api/functions/job-manager.R | sed -n '1,90p;200,260p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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

exec
/bin/bash -lc "nl -ba api/functions/analyses-functions.R | sed -n '340,410p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-repository.R | sed -n '500,590p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
   340	      cluster_signature_hash = vapply(cluster_signature,
   341	        function(s) digest::digest(s, algo = "sha256"), character(1)))
   342	  }
   343	
   344	  # Memory cleanup before returning
   345	  # Remove large intermediate objects to help gc()
   346	  rm(string_db, subgraph, cluster_result, clusters_list)
   347	  gc(verbose = FALSE)
   348	
   349	  # #514: channel provenance travels with the membership tibble (survives the RDS
   350	  # memoise round-trip), so the builder can expose it and gate on channel agreement.
   351	  attr(clusters_tibble, "weight_channel") <- membership_weight_channel
   352	
   353	  # return result
   354	  return(clusters_tibble)
   355	}
   356	
   357	
   358	#' A function to compute  enrichment with string-db and a HGNC list
   359	#'
   360	#' @param hgnc_list A comma separated list as concatenated text
   361	#'
   362	#' @return The enrichment tibble
   363	#' @export
   364	gen_string_enrich_tib <- function(hgnc_list) {
   365	  # Get cached STRINGdb instance (singleton avoids repeated version API calls)
   366	  string_db <- get_string_db(400L)
   367	
   368	  # compute enrichment and convert to tibble
   369	  # Sort by FDR ascending so most significant terms appear first
   370	  enrichment_tibble <- string_db$get_enrichment(hgnc_list) %>%
   371	    tibble() %>%
   372	    select(-ncbiTaxonId, -inputGenes, -preferredNames) %>%
   373	    arrange(fdr)
   374	
   375	  # return result
   376	  return(enrichment_tibble)
   377	}
   378	
   379	
   380	generate_ndd_hgnc_ids <- function() {
   381	  pool %>%
   382	    dplyr::tbl("ndd_entity_view") %>%
   383	    dplyr::arrange(entity_id) %>%
   384	    dplyr::filter(ndd_phenotype == 1) %>%
   385	    dplyr::select(hgnc_id) %>%
   386	    dplyr::collect() %>%
   387	    unique()
   388	}
   389	
   390	
   391	generate_functional_clusters <- function(algorithm = "leiden") {
   392	  genes_from_entity_table <- generate_ndd_hgnc_ids()
   393	  gen_string_clust_obj_mem(
   394	    genes_from_entity_table$hgnc_id,
   395	    algorithm = algorithm
   396	  )
   397	}
   398	
   399	
   400	generate_functional_cluster_membership <- function(algorithm = "leiden") {
   401	  functional_clusters <- generate_functional_clusters(algorithm = algorithm)
   402	  if (is.null(functional_clusters) || nrow(functional_clusters) == 0L) {
   403	    return(tibble::tibble(cluster = character(), hgnc_id = character()))
   404	  }
   405	
   406	  functional_clusters %>%
   407	    dplyr::select(cluster, identifiers) %>%
   408	    tidyr::unnest(identifiers) %>%
   409	    dplyr::mutate(cluster = paste0("fc_", cluster)) %>%
   410	    dplyr::select(cluster, hgnc_id)

 succeeded in 0ms:
   500	  manifest$status_code <- analysis_snapshot_status_code(manifest)
   501	  manifest
   502	}
   503	
   504	#' Cheap "is the active public snapshot CURRENT?" probe.
   505	#'
   506	#' Unlike `analysis_snapshot_public_exists()` (which only checks that a
   507	#' public-ready row exists), this returns TRUE only when that row is also
   508	#' *current* — its computed `status_code` is `"available"`, not `snapshot_stale`
   509	#' or `source_version_mismatch`. Used as the skip predicate by the startup
   510	#' bootstrap and the non-force admin refresh so a STALE or VERSION-MISMATCHED
   511	#' snapshot is re-enqueued (self-heals on restart) instead of being treated as
   512	#' "already present" and left serving a permanent 503. The #420/#440 self-heal
   513	#' only covered `snapshot_missing`; a snapshot that aged past `stale_after`
   514	#' (default 7 days) never refreshed on its own. See AGENTS.md "Public analysis
   515	#' endpoints".
   516	#'
   517	#' @param manifest_fn Injectable manifest read (default
   518	#'   `analysis_snapshot_public_manifest`) so this is unit-testable without a DB.
   519	#' @return TRUE only when a public-ready snapshot exists and is current.
   520	#' @export
   521	analysis_snapshot_public_current <- function(analysis_type,
   522	                                             parameter_hash,
   523	                                             conn = NULL,
   524	                                             manifest_fn = analysis_snapshot_public_manifest) {
   525	  manifest <- tryCatch(
   526	    manifest_fn(analysis_type, parameter_hash, conn = conn),
   527	    error = function(e) NULL
   528	  )
   529	  if (is.null(manifest) ||
   530	    (is.data.frame(manifest) && nrow(manifest) == 0L)) {
   531	    return(FALSE)
   532	  }
   533	  identical(as.character(manifest$status_code)[1], "available")
   534	}
   535	
   536	analysis_snapshot_source_data_version <- function(conn = NULL) {
   537	  result <- db_execute_query(
   538	    "SELECT source_data_version
   539	       FROM mcp_public_analysis_source_version
   540	      LIMIT 1",
   541	    conn = conn
   542	  )
   543	
   544	  as.character(result$source_data_version[[1]])
   545	}
   546	
   547	# analysis_snapshot_prune() was extracted to
   548	# functions/analysis-snapshot-prune-helpers.R (#573 round-3 CI1) to keep this
   549	# file under the 600-line ceiling. It is sourced immediately after this file in
   550	# both bootstrap/load_modules.R and bootstrap/setup_workers.R.

exec
/bin/bash -lc 'git status --short && git log --oneline origin/master..HEAD' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-prompt.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-review.md
b1fd4ebe test(api): source clustering-gene-universe.R in async-job-worker test (#574)
b0d9e04a chore(release): v0.30.1 (#574 category-selected clustering universes)
7a399bb2 test(api): source clustering-gene-universe.R in async-job-handlers test (#574)
97f4b9ff Merge master (#576 Slice A) into slice D
e84a1be1 fix(api): make clustering NULL-universe integration test runnable + share result-meta helper (#574)
ab8b085b feat(api): echo clustering provenance in durable job meta + integration test + docs (#574)
4a3b7758 test(api): cover clustering source-data-version TTL cache + cache-hit provenance meta; splice meta (#574)
3fd107ff feat(api): category_filter on clustering submit with provenance + selector-aware dedup (#574)
46432eab feat(api): category-selected clustering gene-universe resolver (#574)
baac83e9 chore(planning): bring #573/#574 spec+plan+review docs into slice D worktree

exec
/bin/bash -lc "git diff --check origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-async-job-handlers.R | sed -n '1,220p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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

exec
/bin/bash -lc "rg -n -C 12 'gen_string_clust_obj_mem' api/functions/analyses-functions.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
exec
/bin/bash -lc "rg -n -C 15 'clustering_cached_source_data_version|source_data_version' api/tests/testthat/test-unit-clustering-gene-universe.R api/tests/testthat/test-unit-job-endpoint-services.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
158-  string_id_table = NULL,
159-  score_threshold = 400,
160-  # #514: folded into the memoise key so a methodology/data/channel change
161-  # self-invalidates the disk cache. Call-time default (memoise hashes it);
162-  # the body ignores it. Self-guarding so minimal/test envs without the
163-  # fingerprint module degrade to a constant NULL key component instead of erroring.
164-  .cache_fingerprint = if (exists("analysis_cache_fingerprint", mode = "function")) {
165-    analysis_cache_fingerprint("string")
166-  } else {
167-    NULL
168-  }
169-) {
170:  # Caching is handled by the memoise wrapper (gen_string_clust_obj_mem)
171-  # backed by cachem::cache_disk with Inf TTL. No file-based cache needed.
172-
173-  # Get cached STRINGdb instance (singleton avoids repeated version API calls)
174-  string_db <- get_string_db(score_threshold)
175-
176-  # Load gene table from database and filter to input HGNC list
177-  # If string_id_table is provided (for daemon context), use it; otherwise fetch from pool
178-  if (!is.null(string_id_table)) {
179-    sysndd_db_string_id_table <- string_id_table %>%
180-      filter(hgnc_id %in% hgnc_list)
181-  } else {
182-    sysndd_db_string_id_table <- pool %>%
--
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
393:  gen_string_clust_obj_mem(
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

 succeeded in 0ms:
api/tests/testthat/test-unit-job-endpoint-services.R-51-#' Default no-arg (all-NDD) universe stub for `clustering_resolve_category_universe()`
api/tests/testthat/test-unit-job-endpoint-services.R-52-#' (#574 D2): reads `ndd_phenotype == 1` rows straight off `env$pool`'s fake
api/tests/testthat/test-unit-job-endpoint-services.R-53-#' `ndd_entity_view`, mirroring what the real resolver's NULL branch
api/tests/testthat/test-unit-job-endpoint-services.R-54-#' (`generate_ndd_hgnc_ids()`) would compute -- without needing the real
api/tests/testthat/test-unit-job-endpoint-services.R-55-#' function (and its DB-query internals) sourced into these isolated envs.
api/tests/testthat/test-unit-job-endpoint-services.R-56-job_endpoint_stub_all_ndd_universe <- function(env) {
api/tests/testthat/test-unit-job-endpoint-services.R-57-  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
api/tests/testthat/test-unit-job-endpoint-services.R-58-    testthat::expect_null(category_filter)
api/tests/testthat/test-unit-job-endpoint-services.R-59-    tbl <- env$pool$tables$ndd_entity_view
api/tests/testthat/test-unit-job-endpoint-services.R-60-    hgnc_ids <- unique(dplyr::pull(dplyr::filter(tbl, ndd_phenotype == 1), hgnc_id))
api/tests/testthat/test-unit-job-endpoint-services.R-61-    list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids))
api/tests/testthat/test-unit-job-endpoint-services.R-62-  }
api/tests/testthat/test-unit-job-endpoint-services.R-63-}
api/tests/testthat/test-unit-job-endpoint-services.R-64-
api/tests/testthat/test-unit-job-endpoint-services.R-65-#' Cheap provenance stubs (#574 D2): every submit path that reaches past dedup
api/tests/testthat/test-unit-job-endpoint-services.R:66:#' now computes `intended_fingerprint`/`gene_list_sha256`/`source_data_version`
api/tests/testthat/test-unit-job-endpoint-services.R-67-#' regardless of selector kind, so any test reaching that far needs these
api/tests/testthat/test-unit-job-endpoint-services.R-68-#' three bare globals stubbed even when it does not care about their values.
api/tests/testthat/test-unit-job-endpoint-services.R-69-job_endpoint_stub_clustering_provenance <- function(env) {
api/tests/testthat/test-unit-job-endpoint-services.R-70-  env$analysis_string_cache_fingerprint <- function() "fp-test"
api/tests/testthat/test-unit-job-endpoint-services.R-71-  env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
api/tests/testthat/test-unit-job-endpoint-services.R:72:  env$clustering_cached_source_data_version <- function(...) "srcv-test"
api/tests/testthat/test-unit-job-endpoint-services.R-73-}
api/tests/testthat/test-unit-job-endpoint-services.R-74-
api/tests/testthat/test-unit-job-endpoint-services.R-75-test_that("functional clustering: default genes are drawn from ndd_entity_view when omitted", {
api/tests/testthat/test-unit-job-endpoint-services.R-76-  env <- job_endpoint_source_service("job-functional-submission-service.R")
api/tests/testthat/test-unit-job-endpoint-services.R-77-  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
api/tests/testthat/test-unit-job-endpoint-services.R-78-    entity_id = 1:3,
api/tests/testthat/test-unit-job-endpoint-services.R-79-    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
api/tests/testthat/test-unit-job-endpoint-services.R-80-    ndd_phenotype = c(1L, 0L, 1L)
api/tests/testthat/test-unit-job-endpoint-services.R-81-  ))
api/tests/testthat/test-unit-job-endpoint-services.R-82-  job_endpoint_stub_all_ndd_universe(env)
api/tests/testthat/test-unit-job-endpoint-services.R-83-  captured <- NULL
api/tests/testthat/test-unit-job-endpoint-services.R-84-  env$check_duplicate_job <- function(operation, params) {
api/tests/testthat/test-unit-job-endpoint-services.R-85-    captured <<- params
api/tests/testthat/test-unit-job-endpoint-services.R-86-    list(duplicate = TRUE, existing_job_id = "dup-1")
api/tests/testthat/test-unit-job-endpoint-services.R-87-  }
--
api/tests/testthat/test-unit-job-endpoint-services.R-148-
api/tests/testthat/test-unit-job-endpoint-services.R-149-  expect_false(create_job_called)
api/tests/testthat/test-unit-job-endpoint-services.R-150-  expect_equal(res$status, 202)
api/tests/testthat/test-unit-job-endpoint-services.R-151-  expect_equal(res$headers[["Retry-After"]], "0")
api/tests/testthat/test-unit-job-endpoint-services.R-152-  expect_equal(out$job_id, "cached-job-1")
api/tests/testthat/test-unit-job-endpoint-services.R-153-  expect_equal(out$meta$llm_generation, "snapshot_refresh_owned")
api/tests/testthat/test-unit-job-endpoint-services.R-154-  expect_equal(store_args$submitted_by, 42L)
api/tests/testthat/test-unit-job-endpoint-services.R-155-
api/tests/testthat/test-unit-job-endpoint-services.R-156-  # #574 D2 review fix: the cache-hit `result` (the job's stored, served
api/tests/testthat/test-unit-job-endpoint-services.R-157-  # payload -- distinct from `out`, the submit response) must carry the full
api/tests/testthat/test-unit-job-endpoint-services.R-158-  # provenance block through `meta`, not just the two fields asserted above.
api/tests/testthat/test-unit-job-endpoint-services.R-159-  result_meta <- store_args$result$meta
api/tests/testthat/test-unit-job-endpoint-services.R-160-  expect_equal(result_meta$effective_fingerprint$weight_channel, "experimental_database")
api/tests/testthat/test-unit-job-endpoint-services.R-161-  expect_equal(result_meta$selector$kind, "explicit")
api/tests/testthat/test-unit-job-endpoint-services.R-162-  expect_equal(result_meta$gene_list_sha256, "sha-1") # job_endpoint_stub_clustering_provenance: paste0("sha-", length(genes))
api/tests/testthat/test-unit-job-endpoint-services.R:163:  expect_equal(result_meta$source_data_version, "srcv-test") # job_endpoint_stub_clustering_provenance stub token
api/tests/testthat/test-unit-job-endpoint-services.R-164-})
api/tests/testthat/test-unit-job-endpoint-services.R-165-
api/tests/testthat/test-unit-job-endpoint-services.R-166-test_that("functional clustering: capacity guard (503) then a cache miss under capacity (202)", {
api/tests/testthat/test-unit-job-endpoint-services.R-167-  req <- list(argsBody = list(genes = list("HGNC:1"), algorithm = "walktrap"), user = list(user_id = NULL))
api/tests/testthat/test-unit-job-endpoint-services.R-168-
api/tests/testthat/test-unit-job-endpoint-services.R-169-  env <- job_endpoint_source_service("job-functional-submission-service.R")
api/tests/testthat/test-unit-job-endpoint-services.R-170-  env$pool <- job_endpoint_functional_pool(env)
api/tests/testthat/test-unit-job-endpoint-services.R-171-  job_endpoint_stub_clustering_provenance(env)
api/tests/testthat/test-unit-job-endpoint-services.R-172-  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
api/tests/testthat/test-unit-job-endpoint-services.R-173-  env$async_job_capacity_exceeded <- function(...) TRUE
api/tests/testthat/test-unit-job-endpoint-services.R-174-  env$async_job_active_count <- function(...) 99L
api/tests/testthat/test-unit-job-endpoint-services.R-175-  res <- job_endpoint_fake_res()
api/tests/testthat/test-unit-job-endpoint-services.R-176-  out <- env$svc_job_submit_functional_clustering(req, res)
api/tests/testthat/test-unit-job-endpoint-services.R-177-  expect_equal(res$status, 503)
api/tests/testthat/test-unit-job-endpoint-services.R-178-  expect_equal(res$headers[["Retry-After"]], "60")
--
api/tests/testthat/test-unit-job-endpoint-services.R-273-  env$create_job <- function(operation, params) {
api/tests/testthat/test-unit-job-endpoint-services.R-274-    captured <<- params
api/tests/testthat/test-unit-job-endpoint-services.R-275-    list(job_id = "j1", status = "accepted", estimated_seconds = 5)
api/tests/testthat/test-unit-job-endpoint-services.R-276-  }
api/tests/testthat/test-unit-job-endpoint-services.R-277-  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
api/tests/testthat/test-unit-job-endpoint-services.R-278-  res <- job_endpoint_fake_res()
api/tests/testthat/test-unit-job-endpoint-services.R-279-
api/tests/testthat/test-unit-job-endpoint-services.R-280-  out <- env$svc_job_submit_functional_clustering(req, res)
api/tests/testthat/test-unit-job-endpoint-services.R-281-
api/tests/testthat/test-unit-job-endpoint-services.R-282-  expect_equal(res$status, 202)
api/tests/testthat/test-unit-job-endpoint-services.R-283-  expect_identical(captured$category_filter, "Definitive")
api/tests/testthat/test-unit-job-endpoint-services.R-284-  expect_identical(captured$genes, c("HGNC:1", "HGNC:5"))
api/tests/testthat/test-unit-job-endpoint-services.R-285-  expect_identical(captured$provenance$selector$kind, "category")
api/tests/testthat/test-unit-job-endpoint-services.R-286-  expect_identical(captured$provenance$selector$category_filter, "Definitive")
api/tests/testthat/test-unit-job-endpoint-services.R-287-  expect_true(all(
api/tests/testthat/test-unit-job-endpoint-services.R:288:    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
api/tests/testthat/test-unit-job-endpoint-services.R-289-      names(captured$provenance)
api/tests/testthat/test-unit-job-endpoint-services.R-290-  ))
api/tests/testthat/test-unit-job-endpoint-services.R-291-})
api/tests/testthat/test-unit-job-endpoint-services.R-292-
api/tests/testthat/test-unit-job-endpoint-services.R-293-test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
api/tests/testthat/test-unit-job-endpoint-services.R-294-  # Explicit genes.
api/tests/testthat/test-unit-job-endpoint-services.R-295-  env <- job_endpoint_source_service("job-functional-submission-service.R")
api/tests/testthat/test-unit-job-endpoint-services.R-296-  env$pool <- job_endpoint_functional_pool(env)
api/tests/testthat/test-unit-job-endpoint-services.R-297-  job_endpoint_stub_clustering_provenance(env)
api/tests/testthat/test-unit-job-endpoint-services.R-298-  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
api/tests/testthat/test-unit-job-endpoint-services.R-299-  env$async_job_capacity_exceeded <- function(...) FALSE
api/tests/testthat/test-unit-job-endpoint-services.R-300-  env$async_job_active_count <- function(...) 0L
api/tests/testthat/test-unit-job-endpoint-services.R-301-  captured_explicit <- NULL
api/tests/testthat/test-unit-job-endpoint-services.R-302-  env$create_job <- function(operation, params) {
api/tests/testthat/test-unit-job-endpoint-services.R-303-    captured_explicit <<- params
--
api/tests/testthat/test-unit-job-endpoint-services.R-347-      hash_env$async_job_service_payload_json(payload)
api/tests/testthat/test-unit-job-endpoint-services.R-348-    )
api/tests/testthat/test-unit-job-endpoint-services.R-349-  }
api/tests/testthat/test-unit-job-endpoint-services.R-350-  g <- c("HGNC:1", "HGNC:5")
api/tests/testthat/test-unit-job-endpoint-services.R-351-
api/tests/testthat/test-unit-job-endpoint-services.R-352-  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
api/tests/testthat/test-unit-job-endpoint-services.R-353-  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
api/tests/testthat/test-unit-job-endpoint-services.R-354-  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
api/tests/testthat/test-unit-job-endpoint-services.R-355-})
api/tests/testthat/test-unit-job-endpoint-services.R-356-
api/tests/testthat/test-unit-job-endpoint-services.R-357-test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
api/tests/testthat/test-unit-job-endpoint-services.R-358-  env <- job_endpoint_source_service("job-functional-submission-service.R")
api/tests/testthat/test-unit-job-endpoint-services.R-359-  env$pool <- job_endpoint_functional_pool(env)
api/tests/testthat/test-unit-job-endpoint-services.R-360-  env$analysis_string_cache_fingerprint <- function() "fp-test"
api/tests/testthat/test-unit-job-endpoint-services.R-361-  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
api/tests/testthat/test-unit-job-endpoint-services.R:362:  env$clustering_cached_source_data_version <- function(...) stop("boom")
api/tests/testthat/test-unit-job-endpoint-services.R-363-  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
api/tests/testthat/test-unit-job-endpoint-services.R-364-  create_job_called <- FALSE
api/tests/testthat/test-unit-job-endpoint-services.R-365-  env$create_job <- function(...) {
api/tests/testthat/test-unit-job-endpoint-services.R-366-    create_job_called <<- TRUE
api/tests/testthat/test-unit-job-endpoint-services.R-367-    NULL
api/tests/testthat/test-unit-job-endpoint-services.R-368-  }
api/tests/testthat/test-unit-job-endpoint-services.R-369-  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
api/tests/testthat/test-unit-job-endpoint-services.R-370-  res <- job_endpoint_fake_res()
api/tests/testthat/test-unit-job-endpoint-services.R-371-
api/tests/testthat/test-unit-job-endpoint-services.R-372-  out <- env$svc_job_submit_functional_clustering(req, res)
api/tests/testthat/test-unit-job-endpoint-services.R-373-
api/tests/testthat/test-unit-job-endpoint-services.R-374-  expect_equal(res$status, 503L)
api/tests/testthat/test-unit-job-endpoint-services.R-375-  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
api/tests/testthat/test-unit-job-endpoint-services.R-376-  expect_false(create_job_called)
api/tests/testthat/test-unit-job-endpoint-services.R-377-})
--
api/tests/testthat/test-unit-clustering-gene-universe.R-4-# job runs on: either the current default (all NDD genes, via
api/tests/testthat/test-unit-clustering-gene-universe.R-5-# `generate_ndd_hgnc_ids()`) or a curated-category selection
api/tests/testthat/test-unit-clustering-gene-universe.R-6-# (`ndd_entity_view` entity rows filtered by `category %in% selector`, then
api/tests/testthat/test-unit-clustering-gene-universe.R-7-# distinct `hgnc_id`). This file is DB-free: the default branch's dependency
api/tests/testthat/test-unit-clustering-gene-universe.R-8-# (`generate_ndd_hgnc_ids()`) is overridden in a child environment, and the
api/tests/testthat/test-unit-clustering-gene-universe.R-9-# category branch's `conn` is a real in-memory RSQLite connection so the
api/tests/testthat/test-unit-clustering-gene-universe.R-10-# dbplyr pipeline (`tbl()` / `filter()` / `select()` / `collect()`) is
api/tests/testthat/test-unit-clustering-gene-universe.R-11-# exercised for real rather than mocked.
api/tests/testthat/test-unit-clustering-gene-universe.R-12-#
api/tests/testthat/test-unit-clustering-gene-universe.R-13-# Trap: do NOT stub `generate_ndd_hgnc_ids` via
api/tests/testthat/test-unit-clustering-gene-universe.R-14-# `testthat::local_mocked_bindings(..., .env = globalenv())` -- under
api/tests/testthat/test-unit-clustering-gene-universe.R-15-# testthat 3.3.2 that aborts with "No packages loaded with pkgload" because
api/tests/testthat/test-unit-clustering-gene-universe.R-16-# globalenv() has no package namespace. A child-env override sidesteps this.
api/tests/testthat/test-unit-clustering-gene-universe.R-17-
api/tests/testthat/test-unit-clustering-gene-universe.R-18-## -------------------------------------------------------------------------##
api/tests/testthat/test-unit-clustering-gene-universe.R:19:## clustering_cached_source_data_version() TTL cache (#574 D2 review fix)
api/tests/testthat/test-unit-clustering-gene-universe.R-20-## -------------------------------------------------------------------------##
api/tests/testthat/test-unit-clustering-gene-universe.R-21-#
api/tests/testthat/test-unit-clustering-gene-universe.R:22:# These tests stub `analysis_snapshot_source_data_version()` directly -- no DB
api/tests/testthat/test-unit-clustering-gene-universe.R-23-# connection is ever opened -- so they are placed BEFORE the file-wide
api/tests/testthat/test-unit-clustering-gene-universe.R-24-# `skip_if_not_installed("RSQLite")` gate below and run unconditionally, even
api/tests/testthat/test-unit-clustering-gene-universe.R-25-# when {RSQLite} is unavailable.
api/tests/testthat/test-unit-clustering-gene-universe.R-26-
api/tests/testthat/test-unit-clustering-gene-universe.R-27-# Sources ONLY core/errors.R + the module under test into a fresh child env.
api/tests/testthat/test-unit-clustering-gene-universe.R:28:# A fresh env means a fresh `.clustering_source_data_version_cache` (it is
api/tests/testthat/test-unit-clustering-gene-universe.R-29-# created top-level by the sourced file), so there is nothing left over from
api/tests/testthat/test-unit-clustering-gene-universe.R:30:# a prior test -- `.reset_source_data_version_cache()` below is still applied
api/tests/testthat/test-unit-clustering-gene-universe.R-31-# defensively so the reset mechanism itself stays covered/documented.
api/tests/testthat/test-unit-clustering-gene-universe.R:32:.source_data_version_env <- function() {
api/tests/testthat/test-unit-clustering-gene-universe.R-33-  e <- new.env(parent = globalenv())
api/tests/testthat/test-unit-clustering-gene-universe.R-34-  source_api_file("core/errors.R", local = FALSE, envir = e)
api/tests/testthat/test-unit-clustering-gene-universe.R-35-  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
api/tests/testthat/test-unit-clustering-gene-universe.R-36-  e
api/tests/testthat/test-unit-clustering-gene-universe.R-37-}
api/tests/testthat/test-unit-clustering-gene-universe.R-38-
api/tests/testthat/test-unit-clustering-gene-universe.R-39-# Clears the module-level TTL cache env so cached state never leaks across
api/tests/testthat/test-unit-clustering-gene-universe.R-40-# assertions sharing the same sourced env `e`.
api/tests/testthat/test-unit-clustering-gene-universe.R:41:.reset_source_data_version_cache <- function(e) {
api/tests/testthat/test-unit-clustering-gene-universe.R:42:  cache_env <- e$.clustering_source_data_version_cache
api/tests/testthat/test-unit-clustering-gene-universe.R-43-  keys <- ls(cache_env, all.names = TRUE)
api/tests/testthat/test-unit-clustering-gene-universe.R-44-  if (length(keys) > 0L) rm(list = keys, envir = cache_env)
api/tests/testthat/test-unit-clustering-gene-universe.R-45-}
api/tests/testthat/test-unit-clustering-gene-universe.R-46-
api/tests/testthat/test-unit-clustering-gene-universe.R:47:test_that("clustering_cached_source_data_version: TTL hit avoids a second underlying fetch", {
api/tests/testthat/test-unit-clustering-gene-universe.R:48:  e <- .source_data_version_env()
api/tests/testthat/test-unit-clustering-gene-universe.R:49:  .reset_source_data_version_cache(e)
api/tests/testthat/test-unit-clustering-gene-universe.R-50-  calls <- 0L
api/tests/testthat/test-unit-clustering-gene-universe.R:51:  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
api/tests/testthat/test-unit-clustering-gene-universe.R-52-    calls <<- calls + 1L
api/tests/testthat/test-unit-clustering-gene-universe.R-53-    "v1"
api/tests/testthat/test-unit-clustering-gene-universe.R-54-  }
api/tests/testthat/test-unit-clustering-gene-universe.R-55-
api/tests/testthat/test-unit-clustering-gene-universe.R:56:  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R:57:  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R-58-
api/tests/testthat/test-unit-clustering-gene-universe.R-59-  expect_identical(first, "v1")
api/tests/testthat/test-unit-clustering-gene-universe.R-60-  expect_identical(second, "v1")
api/tests/testthat/test-unit-clustering-gene-universe.R-61-  expect_identical(calls, 1L) # second call served from cache, underlying fn NOT re-invoked
api/tests/testthat/test-unit-clustering-gene-universe.R-62-})
api/tests/testthat/test-unit-clustering-gene-universe.R-63-
api/tests/testthat/test-unit-clustering-gene-universe.R:64:test_that("clustering_cached_source_data_version: TTL expiry (ttl_seconds = 0) forces a refetch", {
api/tests/testthat/test-unit-clustering-gene-universe.R-65-  # `diff < ttl_seconds` is the staleness check; `diff` (elapsed seconds since
api/tests/testthat/test-unit-clustering-gene-universe.R-66-  # the last successful fetch) is always >= 0, so `ttl_seconds = 0` makes
api/tests/testthat/test-unit-clustering-gene-universe.R-67-  # `diff < 0` FALSE on every subsequent call -- deterministically always-stale,
api/tests/testthat/test-unit-clustering-gene-universe.R-68-  # regardless of clock resolution between the two calls.
api/tests/testthat/test-unit-clustering-gene-universe.R:69:  e <- .source_data_version_env()
api/tests/testthat/test-unit-clustering-gene-universe.R:70:  .reset_source_data_version_cache(e)
api/tests/testthat/test-unit-clustering-gene-universe.R-71-  calls <- 0L
api/tests/testthat/test-unit-clustering-gene-universe.R:72:  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
api/tests/testthat/test-unit-clustering-gene-universe.R-73-    calls <<- calls + 1L
api/tests/testthat/test-unit-clustering-gene-universe.R-74-    paste0("v", calls)
api/tests/testthat/test-unit-clustering-gene-universe.R-75-  }
api/tests/testthat/test-unit-clustering-gene-universe.R-76-
api/tests/testthat/test-unit-clustering-gene-universe.R:77:  first <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
api/tests/testthat/test-unit-clustering-gene-universe.R:78:  second <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 0)
api/tests/testthat/test-unit-clustering-gene-universe.R-79-
api/tests/testthat/test-unit-clustering-gene-universe.R-80-  expect_identical(first, "v1")
api/tests/testthat/test-unit-clustering-gene-universe.R-81-  expect_identical(second, "v2")
api/tests/testthat/test-unit-clustering-gene-universe.R-82-  expect_identical(calls, 2L) # both calls hit the underlying fn -- cache never served a hit
api/tests/testthat/test-unit-clustering-gene-universe.R-83-})
api/tests/testthat/test-unit-clustering-gene-universe.R-84-
api/tests/testthat/test-unit-clustering-gene-universe.R:85:test_that("clustering_cached_source_data_version: an error propagates and never poisons the cache", {
api/tests/testthat/test-unit-clustering-gene-universe.R:86:  e <- .source_data_version_env()
api/tests/testthat/test-unit-clustering-gene-universe.R:87:  .reset_source_data_version_cache(e)
api/tests/testthat/test-unit-clustering-gene-universe.R:88:  e$analysis_snapshot_source_data_version <- function(conn = NULL) stop("boom")
api/tests/testthat/test-unit-clustering-gene-universe.R-89-
api/tests/testthat/test-unit-clustering-gene-universe.R-90-  expect_error(
api/tests/testthat/test-unit-clustering-gene-universe.R:91:    e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300),
api/tests/testthat/test-unit-clustering-gene-universe.R-92-    "boom"
api/tests/testthat/test-unit-clustering-gene-universe.R-93-  )
api/tests/testthat/test-unit-clustering-gene-universe.R-94-  # Nothing was written to the cache by the failed call.
api/tests/testthat/test-unit-clustering-gene-universe.R:95:  expect_null(e$.clustering_source_data_version_cache$value)
api/tests/testthat/test-unit-clustering-gene-universe.R:96:  expect_null(e$.clustering_source_data_version_cache$cached_at)
api/tests/testthat/test-unit-clustering-gene-universe.R-97-
api/tests/testthat/test-unit-clustering-gene-universe.R-98-  # Swap to a success stub: the NEXT call must refetch (not serve a stale/NA
api/tests/testthat/test-unit-clustering-gene-universe.R-99-  # value left over from the failed attempt) and the cache must now work.
api/tests/testthat/test-unit-clustering-gene-universe.R:100:  .reset_source_data_version_cache(e)
api/tests/testthat/test-unit-clustering-gene-universe.R-101-  calls <- 0L
api/tests/testthat/test-unit-clustering-gene-universe.R:102:  e$analysis_snapshot_source_data_version <- function(conn = NULL) {
api/tests/testthat/test-unit-clustering-gene-universe.R-103-    calls <<- calls + 1L
api/tests/testthat/test-unit-clustering-gene-universe.R-104-    "v-success"
api/tests/testthat/test-unit-clustering-gene-universe.R-105-  }
api/tests/testthat/test-unit-clustering-gene-universe.R-106-
api/tests/testthat/test-unit-clustering-gene-universe.R:107:  result <- e$clustering_cached_source_data_version(conn = NULL, ttl_seconds = 300)
api/tests/testthat/test-unit-clustering-gene-universe.R-108-
api/tests/testthat/test-unit-clustering-gene-universe.R-109-  expect_identical(result, "v-success")
api/tests/testthat/test-unit-clustering-gene-universe.R-110-  expect_identical(calls, 1L)
api/tests/testthat/test-unit-clustering-gene-universe.R-111-})
api/tests/testthat/test-unit-clustering-gene-universe.R-112-
api/tests/testthat/test-unit-clustering-gene-universe.R-113-testthat::skip_if_not_installed("RSQLite")
api/tests/testthat/test-unit-clustering-gene-universe.R-114-
api/tests/testthat/test-unit-clustering-gene-universe.R-115-# Source the code under test into a child env so the NULL-branch dependency
api/tests/testthat/test-unit-clustering-gene-universe.R-116-# (`generate_ndd_hgnc_ids`) can be overridden per-test without touching
api/tests/testthat/test-unit-clustering-gene-universe.R-117-# globalenv() or any other test file's bindings.
api/tests/testthat/test-unit-clustering-gene-universe.R-118-.gene_universe_env <- function() {
api/tests/testthat/test-unit-clustering-gene-universe.R-119-  e <- new.env(parent = globalenv())
api/tests/testthat/test-unit-clustering-gene-universe.R-120-  source_api_file("core/errors.R", local = FALSE, envir = e)
api/tests/testthat/test-unit-clustering-gene-universe.R-121-  source_api_file("functions/clustering-gene-universe.R", local = FALSE, envir = e)
api/tests/testthat/test-unit-clustering-gene-universe.R-122-  e

exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-async-job-worker.R | sed -n '1,200p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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
   101	      claim_token = "claim-progress"
   102	    ),
   103	    worker_config = list(lease_seconds = 90L, job_run_lease_seconds = 300L)
   104	  )
   105	  on.exit(runtime$async_job_worker_clear_claim_context(), add = TRUE)
   106	
   107	  reporter <- runtime$create_async_job_progress_reporter(
   108	    "job-progress",
   109	    throttle_seconds = 60
   110	  )
   111	
   112	  reporter("download", "Downloading source", current = 1, total = 4)
   113	  reporter("download", "Throttled update", current = 2, total = 4)
   114	  reporter("download", "Download complete", current = 4, total = 4)
   115	
   116	  expect_length(calls, 2L)
   117	  expect_equal(calls[[1]]$job_id, "job-progress")
   118	  expect_equal(calls[[1]]$claim_token, "claim-progress")
   119	  expect_equal(calls[[1]]$progress_pct, 25)
   120	  expect_equal(calls[[1]]$progress_message, "Downloading source")
   121	  expect_equal(calls[[2]]$progress_pct, 100)
   122	  expect_equal(calls[[2]]$progress_message, "Download complete")
   123	  expect_length(heartbeat_calls, 2L)
   124	  expect_equal(heartbeat_calls[[1]]$lease_seconds, 300L)
   125	  expect_equal(heartbeat_calls[[1]]$claim_token, "claim-progress")
   126	})
   127	
   128	test_that("async_job_worker_claim_once skips claims during drain and uses repository claim API otherwise", {
   129	  runtime <- load_async_job_worker_runtime()
   130	  state <- runtime$async_job_worker_state()
   131	
   132	  worker_config <- list(
   133	    worker_id = "worker-a",
   134	    hostname = "host-a",
   135	    lease_seconds = 60L,
   136	    idle_sleep_seconds = 0.1,
   137	    max_jobs_per_worker = 5L,
   138	    max_worker_lifetime_seconds = 600L,
   139	    queues = c("default", "bulk")
   140	  )
   141	
   142	  state$draining <- TRUE
   143	  expect_null(runtime$async_job_worker_claim_once(
   144	    state = state,
   145	    worker_config = worker_config,
   146	    claim_fn = function(...) {
   147	      stop("claim should not run while draining")
   148	    }
   149	  ))
   150	
   151	  claim_args <- NULL
   152	  state$draining <- FALSE
   153	  claimed <- runtime$async_job_worker_claim_once(
   154	    state = state,
   155	    worker_config = worker_config,
   156	    claim_fn = function(worker_id, worker_hostname, worker_pid, lease_seconds, queues, conn = NULL) {
   157	      claim_args <<- list(
   158	        worker_id = worker_id,
   159	        worker_hostname = worker_hostname,
   160	        worker_pid = worker_pid,
   161	        lease_seconds = lease_seconds,
   162	        queues = queues
   163	      )
   164	      tibble(
   165	        job_id = "job-claim",
   166	        job_type = "hgnc_update",
   167	        request_payload_json = "{}",
   168	        claim_token = "claim-claim"
   169	      )
   170	    }
   171	  )
   172	
   173	  expect_equal(claimed$job_id[[1]], "job-claim")
   174	  expect_equal(claim_args$worker_id, "worker-a")
   175	  expect_equal(claim_args$worker_hostname, "host-a")
   176	  expect_type(claim_args$worker_pid, "integer")
   177	  expect_equal(claim_args$lease_seconds, 60L)
   178	  expect_equal(claim_args$queues, c("default", "bulk"))
   179	})
   180	
   181	test_that("async_job_worker_heartbeat extends the lease with the current claim token", {
   182	  runtime <- load_async_job_worker_runtime()
   183	  heartbeat_call <- NULL
   184	
   185	  runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
   186	    heartbeat_call <<- list(
   187	      job_id = job_id,
   188	      lease_seconds = lease_seconds,
   189	      claim_token = claim_token
   190	    )
   191	    1L
   192	  }
   193	
   194	  rows <- runtime$async_job_worker_heartbeat(
   195	    claimed_job = tibble(job_id = "job-heartbeat", claim_token = "claim-heartbeat"),
   196	    worker_config = list(lease_seconds = 45L, job_run_lease_seconds = 120L)
   197	  )
   198	
   199	  expect_equal(rows, 1L)
   200	  expect_equal(heartbeat_call$job_id, "job-heartbeat")

exec
/bin/bash -lc "rg -n -C 8 'analysis_string_cache_fingerprint' api/functions" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/functions/analysis-cache-fingerprint.R-37-#' Composite of CLUSTER_LOGIC_VERSION, the selected STRING channel, and the exp+db
api/functions/analysis-cache-fingerprint.R-38-#' edge file identity (present:size:mtime | absent). Returned as a readable,
api/functions/analysis-cache-fingerprint.R-39-#' pipe-delimited string; memoise hashes it into the cache key. Every component is
api/functions/analysis-cache-fingerprint.R-40-#' wrapped so a transient error degrades to a sentinel token rather than breaking the
api/functions/analysis-cache-fingerprint.R-41-#' clustering call.
api/functions/analysis-cache-fingerprint.R-42-#'
api/functions/analysis-cache-fingerprint.R-43-#' @return character(1) fingerprint token.
api/functions/analysis-cache-fingerprint.R-44-#' @export
api/functions/analysis-cache-fingerprint.R:45:analysis_string_cache_fingerprint <- function() {
api/functions/analysis-cache-fingerprint.R-46-  channels <- tryCatch(
api/functions/analysis-cache-fingerprint.R-47-    paste(string_weight_channels(), collapse = ","),
api/functions/analysis-cache-fingerprint.R-48-    error = function(e) "channels_NA"
api/functions/analysis-cache-fingerprint.R-49-  )
api/functions/analysis-cache-fingerprint.R-50-  expdb <- tryCatch(
api/functions/analysis-cache-fingerprint.R-51-    {
api/functions/analysis-cache-fingerprint.R-52-      f <- string_expdb_edges_file()
api/functions/analysis-cache-fingerprint.R-53-      if (isTRUE(file.exists(f))) {
--
api/functions/analysis-cache-fingerprint.R-91-#' @export
api/functions/analysis-cache-fingerprint.R-92-analysis_cache_fingerprint <- function(kind = c("string", "phenotype")) {
api/functions/analysis-cache-fingerprint.R-93-  kind <- match.arg(kind)
api/functions/analysis-cache-fingerprint.R-94-  # NB: do NOT use get()/exists() with a bare name here — the `config` package
api/functions/analysis-cache-fingerprint.R-95-  # (loaded for DB config) masks base::get with a signature that has no `mode`
api/functions/analysis-cache-fingerprint.R-96-  # argument, so `get(fn, mode = "function")` raises "unused argument". Dispatch
api/functions/analysis-cache-fingerprint.R-97-  # to the concrete helpers directly; base::exists is not masked.
api/functions/analysis-cache-fingerprint.R-98-  if (identical(kind, "string")) {
api/functions/analysis-cache-fingerprint.R:99:    if (exists("analysis_string_cache_fingerprint", mode = "function")) {
api/functions/analysis-cache-fingerprint.R:100:      analysis_string_cache_fingerprint()
api/functions/analysis-cache-fingerprint.R-101-    } else {
api/functions/analysis-cache-fingerprint.R-102-      NULL
api/functions/analysis-cache-fingerprint.R-103-    }
api/functions/analysis-cache-fingerprint.R-104-  } else {
api/functions/analysis-cache-fingerprint.R-105-    if (exists("analysis_phenotype_cache_fingerprint", mode = "function")) {
api/functions/analysis-cache-fingerprint.R-106-      analysis_phenotype_cache_fingerprint()
api/functions/analysis-cache-fingerprint.R-107-    } else {
api/functions/analysis-cache-fingerprint.R-108-      NULL

exec
/bin/bash -lc "rg -n -C 20 'mcp_public_analysis_source_version' db api" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
db/migrations/044_mcp_public_read_projections.sql-129-JOIN `mcp_public_entity` e ON e.`entity_id` = c.`entity_id`
db/migrations/044_mcp_public_read_projections.sql-130-JOIN `variation_ontology_list` v ON v.`vario_id` = c.`vario_id`
db/migrations/044_mcp_public_read_projections.sql-131-JOIN `modifier_list` ml ON ml.`modifier_id` = c.`modifier_id`
db/migrations/044_mcp_public_read_projections.sql-132-WHERE c.`is_active` = 1 AND v.`is_active` = 1 AND COALESCE(v.`obsolete`, 0) = 0
db/migrations/044_mcp_public_read_projections.sql-133-  AND ml.`is_active` = 1 AND ml.`allowed_variation` = 1;
db/migrations/044_mcp_public_read_projections.sql-134-
db/migrations/044_mcp_public_read_projections.sql-135-CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
db/migrations/044_mcp_public_read_projections.sql-136-VIEW `mcp_public_review_publication` AS
db/migrations/044_mcp_public_read_projections.sql-137-SELECT rpj.`review_publication_id`, rpj.`review_id`, rpj.`entity_id`,
db/migrations/044_mcp_public_read_projections.sql-138-       rpj.`publication_id`, rpj.`publication_type`, p.`Title`, p.`Abstract`,
db/migrations/044_mcp_public_read_projections.sql-139-       p.`Publication_date`, p.`publication_date_source`, p.`Journal`, p.`Keywords`,
db/migrations/044_mcp_public_read_projections.sql-140-       p.`Lastname`, p.`Firstname`, r.`review_date` AS `curation_review_date`
db/migrations/044_mcp_public_read_projections.sql-141-FROM `ndd_review_publication_join` rpj
db/migrations/044_mcp_public_read_projections.sql-142-JOIN `mcp_public_review` r
db/migrations/044_mcp_public_read_projections.sql-143-  ON r.`review_id` = rpj.`review_id` AND r.`entity_id` = rpj.`entity_id`
db/migrations/044_mcp_public_read_projections.sql-144-JOIN `mcp_public_entity` e ON e.`entity_id` = rpj.`entity_id`
db/migrations/044_mcp_public_read_projections.sql-145-JOIN `publication` p ON p.`publication_id` = rpj.`publication_id`
db/migrations/044_mcp_public_read_projections.sql-146-WHERE rpj.`is_reviewed` = 1;
db/migrations/044_mcp_public_read_projections.sql-147-
db/migrations/044_mcp_public_read_projections.sql-148-CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
db/migrations/044_mcp_public_read_projections.sql:149:VIEW `mcp_public_analysis_source_version` AS
db/migrations/044_mcp_public_read_projections.sql-150-SELECT SHA2(CONCAT_WS('|',
db/migrations/044_mcp_public_read_projections.sql-151-  (SELECT COUNT(*) FROM `ndd_entity_view`),
db/migrations/044_mcp_public_read_projections.sql-152-  (SELECT COUNT(*) FROM `ndd_entity_review` r
db/migrations/044_mcp_public_read_projections.sql-153-    WHERE r.`is_primary` = 1 AND r.`review_approved` = 1),
db/migrations/044_mcp_public_read_projections.sql-154-  COALESCE((SELECT DATE_FORMAT(MAX(r.`review_date`), '%Y-%m-%dT%H:%i:%s.%f')
db/migrations/044_mcp_public_read_projections.sql-155-    FROM `ndd_entity_review` r
db/migrations/044_mcp_public_read_projections.sql-156-    WHERE r.`is_primary` = 1 AND r.`review_approved` = 1), 'none'),
db/migrations/044_mcp_public_read_projections.sql-157-  (SELECT COUNT(*) FROM `ndd_review_phenotype_connect` rpc
db/migrations/044_mcp_public_read_projections.sql-158-    JOIN `ndd_entity_review` r ON r.`review_id` = rpc.`review_id`
db/migrations/044_mcp_public_read_projections.sql-159-    WHERE rpc.`is_active` = 1 AND r.`is_primary` = 1 AND r.`review_approved` = 1),
db/migrations/044_mcp_public_read_projections.sql-160-  COALESCE((SELECT DATE_FORMAT(MAX(rpc.`phenotype_date`), '%Y-%m-%dT%H:%i:%s.%f')
db/migrations/044_mcp_public_read_projections.sql-161-    FROM `ndd_review_phenotype_connect` rpc
db/migrations/044_mcp_public_read_projections.sql-162-    JOIN `ndd_entity_review` r ON r.`review_id` = rpc.`review_id`
db/migrations/044_mcp_public_read_projections.sql-163-    WHERE rpc.`is_active` = 1 AND r.`is_primary` = 1 AND r.`review_approved` = 1), 'none'),
db/migrations/044_mcp_public_read_projections.sql-164-  (SELECT COUNT(*) FROM `ndd_entity_status` s
db/migrations/044_mcp_public_read_projections.sql-165-    WHERE s.`is_active` = 1 AND s.`status_approved` = 1),
db/migrations/044_mcp_public_read_projections.sql-166-  COALESCE((SELECT DATE_FORMAT(MAX(s.`status_date`), '%Y-%m-%dT%H:%i:%s.%f')
db/migrations/044_mcp_public_read_projections.sql-167-    FROM `ndd_entity_status` s
db/migrations/044_mcp_public_read_projections.sql-168-    WHERE s.`is_active` = 1 AND s.`status_approved` = 1), 'none')
db/migrations/044_mcp_public_read_projections.sql-169-), 256) AS `source_data_version`;
db/migrations/044_mcp_public_read_projections.sql-170-
db/migrations/044_mcp_public_read_projections.sql-171-CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
db/migrations/044_mcp_public_read_projections.sql-172-VIEW `mcp_public_analysis_manifest` AS
db/migrations/044_mcp_public_read_projections.sql-173-SELECT m.`snapshot_id`, m.`analysis_type`, m.`parameter_hash`, m.`schema_version`,
db/migrations/044_mcp_public_read_projections.sql-174-       m.`data_class`, m.`generated_at`, m.`activated_at`, m.`stale_after`,
db/migrations/044_mcp_public_read_projections.sql-175-       m.`source_data_version`, m.`parameters_json`, m.`payload_hash`,
db/migrations/044_mcp_public_read_projections.sql-176-       m.`algorithm_name`, m.`algorithm_version`, m.`row_counts_json`
db/migrations/044_mcp_public_read_projections.sql-177-FROM `analysis_snapshot_manifest` m
db/migrations/044_mcp_public_read_projections.sql:178:JOIN `mcp_public_analysis_source_version` sv
db/migrations/044_mcp_public_read_projections.sql-179-  ON m.`source_data_version` = sv.`source_data_version`
db/migrations/044_mcp_public_read_projections.sql-180-WHERE m.`public_ready` = 1 AND m.`status` = 'public_ready'
db/migrations/044_mcp_public_read_projections.sql-181-  AND m.`stale_after` IS NOT NULL AND m.`stale_after` > UTC_TIMESTAMP()
db/migrations/044_mcp_public_read_projections.sql-182-  AND m.`source_data_version` = sv.`source_data_version`
db/migrations/044_mcp_public_read_projections.sql-183-  AND m.`schema_version` = '1.2';
db/migrations/044_mcp_public_read_projections.sql-184-
db/migrations/044_mcp_public_read_projections.sql-185-CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
db/migrations/044_mcp_public_read_projections.sql-186-VIEW `mcp_public_analysis_network_node` AS
db/migrations/044_mcp_public_read_projections.sql-187-SELECT n.`snapshot_id`, n.`hgnc_id`, n.`symbol`, n.`cluster_id`, n.`category`,
db/migrations/044_mcp_public_read_projections.sql-188-       n.`degree`, n.`x`, n.`y`, n.`layout_x`, n.`layout_y`, n.`igraph_x`,
db/migrations/044_mcp_public_read_projections.sql-189-       n.`igraph_y`, n.`display_order`
db/migrations/044_mcp_public_read_projections.sql-190-FROM `analysis_snapshot_network_node` n
db/migrations/044_mcp_public_read_projections.sql-191-JOIN `mcp_public_analysis_manifest` m ON m.`snapshot_id` = n.`snapshot_id`;
db/migrations/044_mcp_public_read_projections.sql-192-
db/migrations/044_mcp_public_read_projections.sql-193-CREATE OR REPLACE ALGORITHM = UNDEFINED DEFINER = CURRENT_USER SQL SECURITY DEFINER
db/migrations/044_mcp_public_read_projections.sql-194-VIEW `mcp_public_analysis_network_edge` AS
db/migrations/044_mcp_public_read_projections.sql-195-SELECT e.`snapshot_id`, e.`edge_rank`, e.`source_hgnc_id`, e.`target_hgnc_id`,
db/migrations/044_mcp_public_read_projections.sql-196-       e.`confidence`
db/migrations/044_mcp_public_read_projections.sql-197-FROM `analysis_snapshot_network_edge` e
db/migrations/044_mcp_public_read_projections.sql-198-JOIN `mcp_public_analysis_manifest` m ON m.`snapshot_id` = e.`snapshot_id`;
--
api/scripts/verify-mcp-select-principal-fixtures.R-116-    paste(
api/scripts/verify-mcp-select-principal-fixtures.R-117-      "INSERT INTO analysis_snapshot_manifest",
api/scripts/verify-mcp-select-principal-fixtures.R-118-      "(analysis_type,parameter_hash,schema_version,data_class,status,public_ready,",
api/scripts/verify-mcp-select-principal-fixtures.R-119-      "generated_at,activated_at,stale_after,source_data_version,parameters_json,",
api/scripts/verify-mcp-select-principal-fixtures.R-120-      "input_hash,payload_hash,algorithm_name,algorithm_version,row_counts_json)",
api/scripts/verify-mcp-select-principal-fixtures.R-121-      "VALUES (?,?, '1.2',?,'public_ready',1,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6),",
api/scripts/verify-mcp-select-principal-fixtures.R-122-      "DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 1 DAY),?,?,",
api/scripts/verify-mcp-select-principal-fixtures.R-123-      "REPEAT('a',64),REPEAT('b',64),'live-fixture','1',JSON_OBJECT('rows',1))"
api/scripts/verify-mcp-select-principal-fixtures.R-124-    ),
api/scripts/verify-mcp-select-principal-fixtures.R-125-    list(
api/scripts/verify-mcp-select-principal-fixtures.R-126-      normalized$analysis_type, normalized$parameter_hash,
api/scripts/verify-mcp-select-principal-fixtures.R-127-      normalized$data_class, source_version, normalized$parameters_json
api/scripts/verify-mcp-select-principal-fixtures.R-128-    )
api/scripts/verify-mcp-select-principal-fixtures.R-129-  )
api/scripts/verify-mcp-select-principal-fixtures.R-130-  as.numeric(mcp_verify_query(conn, "SELECT LAST_INSERT_ID() AS id")$id[[1]])
api/scripts/verify-mcp-select-principal-fixtures.R-131-}
api/scripts/verify-mcp-select-principal-fixtures.R-132-
api/scripts/verify-mcp-select-principal-fixtures.R-133-mcp_verify_seed_analysis <- function(conn) {
api/scripts/verify-mcp-select-principal-fixtures.R-134-  source_version <- mcp_verify_query(
api/scripts/verify-mcp-select-principal-fixtures.R-135-    conn,
api/scripts/verify-mcp-select-principal-fixtures.R:136:    "SELECT source_data_version FROM mcp_public_analysis_source_version"
api/scripts/verify-mcp-select-principal-fixtures.R-137-  )$source_data_version[[1]]
api/scripts/verify-mcp-select-principal-fixtures.R-138-  presets <- analysis_snapshot_supported_presets()
api/scripts/verify-mcp-select-principal-fixtures.R-139-  ids <- list()
api/scripts/verify-mcp-select-principal-fixtures.R-140-  for (preset in presets) {
api/scripts/verify-mcp-select-principal-fixtures.R-141-    normalized <- analysis_snapshot_normalize_params(
api/scripts/verify-mcp-select-principal-fixtures.R-142-      preset$analysis_type,
api/scripts/verify-mcp-select-principal-fixtures.R-143-      preset$params
api/scripts/verify-mcp-select-principal-fixtures.R-144-    )
api/scripts/verify-mcp-select-principal-fixtures.R-145-    ids[[preset$analysis_type]] <- mcp_verify_insert_manifest(
api/scripts/verify-mcp-select-principal-fixtures.R-146-      conn,
api/scripts/verify-mcp-select-principal-fixtures.R-147-      normalized,
api/scripts/verify-mcp-select-principal-fixtures.R-148-      source_version
api/scripts/verify-mcp-select-principal-fixtures.R-149-    )
api/scripts/verify-mcp-select-principal-fixtures.R-150-  }
api/scripts/verify-mcp-select-principal-fixtures.R-151-
api/scripts/verify-mcp-select-principal-fixtures.R-152-  for (kind in c("functional", "phenotype")) {
api/scripts/verify-mcp-select-principal-fixtures.R-153-    type <- paste0(kind, "_clusters")
api/scripts/verify-mcp-select-principal-fixtures.R-154-    snapshot_id <- ids[[type]]
api/scripts/verify-mcp-select-principal-fixtures.R-155-    mcp_verify_exec(
api/scripts/verify-mcp-select-principal-fixtures.R-156-      conn,
--
api/functions/mcp-readonly-contract.R-52-    ),
api/functions/mcp-readonly-contract.R-53-    mcp_public_analysis_network_node = c(
api/functions/mcp-readonly-contract.R-54-      "snapshot_id", "hgnc_id", "symbol", "cluster_id", "category", "degree",
api/functions/mcp-readonly-contract.R-55-      "x", "y", "layout_x", "layout_y", "igraph_x", "igraph_y", "display_order"
api/functions/mcp-readonly-contract.R-56-    ),
api/functions/mcp-readonly-contract.R-57-    mcp_public_analysis_network_edge = c(
api/functions/mcp-readonly-contract.R-58-      "snapshot_id", "edge_rank", "source_hgnc_id", "target_hgnc_id", "confidence"
api/functions/mcp-readonly-contract.R-59-    ),
api/functions/mcp-readonly-contract.R-60-    mcp_public_analysis_cluster = c(
api/functions/mcp-readonly-contract.R-61-      "snapshot_id", "cluster_kind", "cluster_id", "cluster_hash", "cluster_size",
api/functions/mcp-readonly-contract.R-62-      "label", "metadata_json"
api/functions/mcp-readonly-contract.R-63-    ),
api/functions/mcp-readonly-contract.R-64-    mcp_public_analysis_cluster_member = c(
api/functions/mcp-readonly-contract.R-65-      "snapshot_id", "cluster_kind", "cluster_id", "member_rank", "entity_id",
api/functions/mcp-readonly-contract.R-66-      "hgnc_id", "symbol"
api/functions/mcp-readonly-contract.R-67-    ),
api/functions/mcp-readonly-contract.R-68-    mcp_public_analysis_correlation = c(
api/functions/mcp-readonly-contract.R-69-      "snapshot_id", "row_rank", "correlation_kind", "x_key", "y_key", "value",
api/functions/mcp-readonly-contract.R-70-      "abs_value", "metadata_json"
api/functions/mcp-readonly-contract.R-71-    ),
api/functions/mcp-readonly-contract.R:72:    mcp_public_analysis_source_version = "source_data_version",
api/functions/mcp-readonly-contract.R-73-    mcp_public_llm_cluster_summary = c(
api/functions/mcp-readonly-contract.R-74-      "cache_id", "snapshot_id", "cluster_type", "cluster_number", "cluster_hash",
api/functions/mcp-readonly-contract.R-75-      "model_name", "prompt_version", "summary_json", "tags", "created_at", "validated_at"
api/functions/mcp-readonly-contract.R-76-    ),
api/functions/mcp-readonly-contract.R-77-    mcp_public_nddscore_release = c(
api/functions/mcp-readonly-contract.R-78-      "release_id", "score_schema_version", "version", "release_created_at", "n_genes",
api/functions/mcp-readonly-contract.R-79-      "n_hpo_predictions", "n_hpo_terms", "n_features", "hpo_threshold",
api/functions/mcp-readonly-contract.R-80-      "calibration_method", "ndd_model_created_at", "phenotype_model_created_at",
api/functions/mcp-readonly-contract.R-81-      "inheritance_model_created_at", "ndd_performance_json", "phenotype_performance_json",
api/functions/mcp-readonly-contract.R-82-      "inheritance_performance_json", "data_versions_json", "artifact_hashes_json",
api/functions/mcp-readonly-contract.R-83-      "zenodo_record_url", "version_doi", "concept_doi", "source_record_id",
api/functions/mcp-readonly-contract.R-84-      "import_completed_at", "activated_at"
api/functions/mcp-readonly-contract.R-85-    ),
api/functions/mcp-readonly-contract.R-86-    mcp_public_nddscore_gene_prediction = c(
api/functions/mcp-readonly-contract.R-87-      "release_id", "hgnc_id", "gene_symbol", "ensembl_gene_id", "ndd_score",
api/functions/mcp-readonly-contract.R-88-      "ndd_score_std", "ndd_score_iqr", "bag_agreement", "rank", "percentile",
api/functions/mcp-readonly-contract.R-89-      "risk_tier", "confidence_tier", "known_sysndd_gene", "model_split",
api/functions/mcp-readonly-contract.R-90-      "inheritance_ad_probability", "inheritance_ar_probability",
api/functions/mcp-readonly-contract.R-91-      "inheritance_xld_probability", "inheritance_xlr_probability", "top_inheritance_mode",
api/functions/mcp-readonly-contract.R-92-      "called_inheritance_modes", "n_predicted_hpo", "top_hpo_predictions_json",
--
api/functions/mcp-readonly-contract.R-119-    mcp_public_phenotype = "phenotype_list",
api/functions/mcp-readonly-contract.R-120-    mcp_public_variation = "variation_ontology_list",
api/functions/mcp-readonly-contract.R-121-    mcp_public_comparison = c(
api/functions/mcp-readonly-contract.R-122-      "ndd_entity", "ndd_entity_status", "ndd_entity_status_categories_list",
api/functions/mcp-readonly-contract.R-123-      "disease_ontology_set", "mode_of_inheritance_list", "non_alt_loci_set",
api/functions/mcp-readonly-contract.R-124-      "ndd_database_comparison"
api/functions/mcp-readonly-contract.R-125-    ),
api/functions/mcp-readonly-contract.R-126-    mcp_public_comparison_metadata = "comparisons_metadata",
api/functions/mcp-readonly-contract.R-127-    mcp_public_review = c("ndd_entity_review", "mcp_public_entity"),
api/functions/mcp-readonly-contract.R-128-    mcp_public_review_phenotype = c(
api/functions/mcp-readonly-contract.R-129-      "ndd_review_phenotype_connect", "mcp_public_review", "mcp_public_entity",
api/functions/mcp-readonly-contract.R-130-      "phenotype_list", "modifier_list"
api/functions/mcp-readonly-contract.R-131-    ),
api/functions/mcp-readonly-contract.R-132-    mcp_public_review_variation = c(
api/functions/mcp-readonly-contract.R-133-      "ndd_review_variation_ontology_connect", "mcp_public_review", "mcp_public_entity",
api/functions/mcp-readonly-contract.R-134-      "variation_ontology_list", "modifier_list"
api/functions/mcp-readonly-contract.R-135-    ),
api/functions/mcp-readonly-contract.R-136-    mcp_public_review_publication = c(
api/functions/mcp-readonly-contract.R-137-      "ndd_review_publication_join", "mcp_public_review", "mcp_public_entity", "publication"
api/functions/mcp-readonly-contract.R-138-    ),
api/functions/mcp-readonly-contract.R:139:    mcp_public_analysis_source_version = c(
api/functions/mcp-readonly-contract.R-140-      "ndd_entity_view", "ndd_entity_review", "ndd_review_phenotype_connect",
api/functions/mcp-readonly-contract.R-141-      "ndd_entity_status"
api/functions/mcp-readonly-contract.R-142-    ),
api/functions/mcp-readonly-contract.R-143-    mcp_public_analysis_manifest = c(
api/functions/mcp-readonly-contract.R:144:      "analysis_snapshot_manifest", "mcp_public_analysis_source_version"
api/functions/mcp-readonly-contract.R-145-    ),
api/functions/mcp-readonly-contract.R-146-    mcp_public_analysis_network_node = c(
api/functions/mcp-readonly-contract.R-147-      "analysis_snapshot_network_node", "mcp_public_analysis_manifest"
api/functions/mcp-readonly-contract.R-148-    ),
api/functions/mcp-readonly-contract.R-149-    mcp_public_analysis_network_edge = c(
api/functions/mcp-readonly-contract.R-150-      "analysis_snapshot_network_edge", "mcp_public_analysis_manifest"
api/functions/mcp-readonly-contract.R-151-    ),
api/functions/mcp-readonly-contract.R-152-    mcp_public_analysis_cluster = c(
api/functions/mcp-readonly-contract.R-153-      "analysis_snapshot_cluster", "mcp_public_analysis_manifest"
api/functions/mcp-readonly-contract.R-154-    ),
api/functions/mcp-readonly-contract.R-155-    mcp_public_analysis_cluster_member = c(
api/functions/mcp-readonly-contract.R-156-      "analysis_snapshot_cluster_member", "mcp_public_analysis_manifest"
api/functions/mcp-readonly-contract.R-157-    ),
api/functions/mcp-readonly-contract.R-158-    mcp_public_analysis_correlation = c(
api/functions/mcp-readonly-contract.R-159-      "analysis_snapshot_correlation", "mcp_public_analysis_manifest"
api/functions/mcp-readonly-contract.R-160-    ),
api/functions/mcp-readonly-contract.R-161-    mcp_public_llm_cluster_summary = c(
api/functions/mcp-readonly-contract.R-162-      "llm_cluster_summary_cache", "mcp_public_analysis_cluster",
api/functions/mcp-readonly-contract.R-163-      "mcp_public_analysis_manifest"
api/functions/mcp-readonly-contract.R-164-    ),
--
api/functions/mcp-readonly-contract.R-245-    stop("Canonical view normalization requires the current schema", call. = FALSE)
api/functions/mcp-readonly-contract.R-246-  }
api/functions/mcp-readonly-contract.R-247-  sql <- tolower(gsub("`", "", as.character(sql), fixed = TRUE))
api/functions/mcp-readonly-contract.R-248-  sql <- gsub(paste0(tolower(schema), "."), "", sql, fixed = TRUE)
api/functions/mcp-readonly-contract.R-249-  gsub("[[:space:]]+", "", trimws(sql), perl = TRUE)
api/functions/mcp-readonly-contract.R-250-}
api/functions/mcp-readonly-contract.R-251-
api/functions/mcp-readonly-contract.R-252-mcp_readonly_canonical_view_hash <- function(sql, schema) {
api/functions/mcp-readonly-contract.R-253-  normalized <- mcp_readonly_normalize_canonical_view_sql(sql, schema)
api/functions/mcp-readonly-contract.R-254-  as.character(openssl::sha256(charToRaw(normalized)))
api/functions/mcp-readonly-contract.R-255-}
api/functions/mcp-readonly-contract.R-256-
api/functions/mcp-readonly-contract.R-257-mcp_readonly_canonical_view_hashes <- function() {
api/functions/mcp-readonly-contract.R-258-  hashes <- c(
api/functions/mcp-readonly-contract.R-259-    mcp_public_analysis_cluster = "853a6521dbaf99a7569374644cc7503841d598b92bbee803b0c9a3ff0ca4f56a",
api/functions/mcp-readonly-contract.R-260-    mcp_public_analysis_cluster_member = "b664babbc5d55d4b12ed0e05d0c1a672ca13eb8d2c9658030998d349c7d9c562",
api/functions/mcp-readonly-contract.R-261-    mcp_public_analysis_correlation = "6e81875730ffc3062c81f6f45379f998ffb5f32146e9cdb9e049d677523e187e",
api/functions/mcp-readonly-contract.R-262-    mcp_public_analysis_manifest = "daf5d311338e979c5970cd547f4cf9615ae45635d6f29e6b99afee2162322e1d",
api/functions/mcp-readonly-contract.R-263-    mcp_public_analysis_network_edge = "45b2c219da158450bcdff204591cb57b3da712c08a2502c1207c5c8af0d4f640",
api/functions/mcp-readonly-contract.R-264-    mcp_public_analysis_network_node = "38294db942b51382336302c8aa1d43b5ff5a9434d0f069e348e5bb3fad096c25",
api/functions/mcp-readonly-contract.R:265:    mcp_public_analysis_source_version = "376a60bcd3a61422cd8609fe8943f498869d83684d518e969713269f74ccfb92",
api/functions/mcp-readonly-contract.R-266-    mcp_public_comparison = "9d6096f779f12c7e486cc405d6152483f0a84aa6d583314fc9b67ab2a31b96e8",
api/functions/mcp-readonly-contract.R-267-    mcp_public_comparison_metadata = "9d0398d0ac250b386970e26400ba6948b5acfcd8ab582fe4e812ea1a8fb91070",
api/functions/mcp-readonly-contract.R-268-    mcp_public_disease = "5122a87d4e5dd70433ca063ea6e553464245addbd1cd704a7de0af0eec4b21e1",
api/functions/mcp-readonly-contract.R-269-    mcp_public_entity = "3bb1727c4b96e22bfca80515e27cbf05ab740e2f932315d123ceb182022dcfdd",
api/functions/mcp-readonly-contract.R-270-    mcp_public_gene = "815c29add03b5df33aee541f5e307c6b5651ed635cc952267a8680e0d7eda2bb",
api/functions/mcp-readonly-contract.R-271-    mcp_public_hgnc_symbol = "53e707bf34951a9aa55cd027597735f36081853142f3c59f0f51cb5f533a3d35",
api/functions/mcp-readonly-contract.R-272-    mcp_public_llm_cluster_summary = "60a1c566be84d00354a61a06594545c0c0353f913e35d6f9faa6ff57b1cf4588",
api/functions/mcp-readonly-contract.R-273-    mcp_public_nddscore_gene_prediction = "968386c07100f86d9face99bb4776c5480ada3a2f21c221b3791e1399a0ed229",
api/functions/mcp-readonly-contract.R-274-    mcp_public_nddscore_hpo_prediction = "8d1ab672bfb2869b140cd85c53ae3b3bb17d47ce6c8d94b658ae744ca3595044",
api/functions/mcp-readonly-contract.R-275-    mcp_public_nddscore_release = "c676fd86a3e2b08c670f504f66b2ca85b85a00fb29e17436304a1f0423cbb6d3",
api/functions/mcp-readonly-contract.R-276-    mcp_public_phenotype = "8ebcec9600ad762d5e8a9bd67e355108c6ad25b8c23d47f61e5c63ce3da22055",
api/functions/mcp-readonly-contract.R-277-    mcp_public_review = "945fc423eb3c74587f900945173fc08d9951a33f25331bf7a6643346210bbcec",
api/functions/mcp-readonly-contract.R-278-    mcp_public_review_phenotype = "beacd69fae52ab8d5ca707366de21bc58fa366cc7a9cc0e07bd26e2a2b3a761b",
api/functions/mcp-readonly-contract.R-279-    mcp_public_review_publication = "a62902387e780323d65466eef1913d0739551a0c3e7dfb17a163e4dcb3a044be",
api/functions/mcp-readonly-contract.R-280-    mcp_public_review_variation = "a37114e422c2ec3ab1be4f544fbda443647339eb50e8ad4d0cf9271d62dd712b",
api/functions/mcp-readonly-contract.R-281-    mcp_public_variation = "4d9b49ea8940e4d5293a8623184571363bdbea2bf1656589db324591381d3365"
api/functions/mcp-readonly-contract.R-282-  )
api/functions/mcp-readonly-contract.R-283-  hashes[mcp_readonly_projection_names()]
api/functions/mcp-readonly-contract.R-284-}
--
api/functions/analysis-snapshot-repository.R-519-#' @return TRUE only when a public-ready snapshot exists and is current.
api/functions/analysis-snapshot-repository.R-520-#' @export
api/functions/analysis-snapshot-repository.R-521-analysis_snapshot_public_current <- function(analysis_type,
api/functions/analysis-snapshot-repository.R-522-                                             parameter_hash,
api/functions/analysis-snapshot-repository.R-523-                                             conn = NULL,
api/functions/analysis-snapshot-repository.R-524-                                             manifest_fn = analysis_snapshot_public_manifest) {
api/functions/analysis-snapshot-repository.R-525-  manifest <- tryCatch(
api/functions/analysis-snapshot-repository.R-526-    manifest_fn(analysis_type, parameter_hash, conn = conn),
api/functions/analysis-snapshot-repository.R-527-    error = function(e) NULL
api/functions/analysis-snapshot-repository.R-528-  )
api/functions/analysis-snapshot-repository.R-529-  if (is.null(manifest) ||
api/functions/analysis-snapshot-repository.R-530-    (is.data.frame(manifest) && nrow(manifest) == 0L)) {
api/functions/analysis-snapshot-repository.R-531-    return(FALSE)
api/functions/analysis-snapshot-repository.R-532-  }
api/functions/analysis-snapshot-repository.R-533-  identical(as.character(manifest$status_code)[1], "available")
api/functions/analysis-snapshot-repository.R-534-}
api/functions/analysis-snapshot-repository.R-535-
api/functions/analysis-snapshot-repository.R-536-analysis_snapshot_source_data_version <- function(conn = NULL) {
api/functions/analysis-snapshot-repository.R-537-  result <- db_execute_query(
api/functions/analysis-snapshot-repository.R-538-    "SELECT source_data_version
api/functions/analysis-snapshot-repository.R:539:       FROM mcp_public_analysis_source_version
api/functions/analysis-snapshot-repository.R-540-      LIMIT 1",
api/functions/analysis-snapshot-repository.R-541-    conn = conn
api/functions/analysis-snapshot-repository.R-542-  )
api/functions/analysis-snapshot-repository.R-543-
api/functions/analysis-snapshot-repository.R-544-  as.character(result$source_data_version[[1]])
api/functions/analysis-snapshot-repository.R-545-}
api/functions/analysis-snapshot-repository.R-546-
api/functions/analysis-snapshot-repository.R-547-# analysis_snapshot_prune() was extracted to
api/functions/analysis-snapshot-repository.R-548-# functions/analysis-snapshot-prune-helpers.R (#573 round-3 CI1) to keep this
api/functions/analysis-snapshot-repository.R-549-# file under the 600-line ceiling. It is sourced immediately after this file in
api/functions/analysis-snapshot-repository.R-550-# both bootstrap/load_modules.R and bootstrap/setup_workers.R.
--
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-8-source_api_file("functions/analysis-snapshot-repository.R", local = FALSE)
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-9-source_api_file("functions/analysis-snapshot-builder.R", local = FALSE)
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-10-source_api_file("functions/analyses-functions.R", local = FALSE)
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-11-source_api_file("functions/analysis-phenotype-functions.R", local = FALSE)
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-12-source_api_file("functions/analysis-cluster-validation.R", local = FALSE)
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-13-
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-14-# The default local/PR test DB (sysndd_db_test) starts empty, so this DB-schema
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-15-# test skips gracefully unless the snapshot tables are present (repo convention,
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-16-# mirrors test-integration-entity-rename.R / test-unit-metadata-refresh.R). It
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-17-# still runs for real against an initialized DB.
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-18-skip_if_missing_analysis_snapshot_schema <- function(conn) {
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-19-  required_tables <- c(
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-20-    "analysis_snapshot_manifest",
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-21-    "analysis_snapshot_cluster",
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-22-    "analysis_snapshot_cluster_member",
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-23-    # analysis_snapshot_refresh() also reads the source-data-version view, which
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-24-    # is created by the full migration set (a real initialized DB) but NOT by the
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-25-    # partial ensure_test_analysis_snapshot_manifest_schema() helper that a sibling
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-26-    # test may leave behind. Without this sentinel the guard passes on a
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-27-    # partial schema and the refresh then fails on the missing view.
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R:28:    "mcp_public_analysis_source_version"
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-29-  )
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-30-  missing_tables <- required_tables[!vapply(
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-31-    required_tables,
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-32-    function(table) DBI::dbExistsTable(conn, table),
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-33-    logical(1)
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-34-  )]
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-35-  if (length(missing_tables) > 0) {
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-36-    testthat::skip(paste(
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-37-      "Test database schema is not initialized; missing table(s):",
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-38-      paste(missing_tables, collapse = ", ")
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-39-    ))
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-40-  }
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-41-}
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-42-
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-43-# testthat::local_mocked_bindings() cannot mock bindings that live in the global
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-44-# environment: repo functions are source()d into globalenv, which has no package
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-45-# namespace, so testthat (>= 3.2) aborts with "No packages loaded with pkgload".
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-46-# Stub the global binding directly instead and restore it when the calling frame
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-47-# exits, so a mock never leaks into a later test file sharing this R session.
api/tests/testthat/test-unit-analysis-snapshot-validation-build.R-48-stub_global_binding <- function(name, value, frame = parent.frame()) {
--
api/tests/testthat/helper-mcp-select-principal.R-52-    ),
api/tests/testthat/helper-mcp-select-principal.R-53-    mcp_public_analysis_network_node = c(
api/tests/testthat/helper-mcp-select-principal.R-54-      "snapshot_id", "hgnc_id", "symbol", "cluster_id", "category", "degree",
api/tests/testthat/helper-mcp-select-principal.R-55-      "x", "y", "layout_x", "layout_y", "igraph_x", "igraph_y", "display_order"
api/tests/testthat/helper-mcp-select-principal.R-56-    ),
api/tests/testthat/helper-mcp-select-principal.R-57-    mcp_public_analysis_network_edge = c(
api/tests/testthat/helper-mcp-select-principal.R-58-      "snapshot_id", "edge_rank", "source_hgnc_id", "target_hgnc_id", "confidence"
api/tests/testthat/helper-mcp-select-principal.R-59-    ),
api/tests/testthat/helper-mcp-select-principal.R-60-    mcp_public_analysis_cluster = c(
api/tests/testthat/helper-mcp-select-principal.R-61-      "snapshot_id", "cluster_kind", "cluster_id", "cluster_hash", "cluster_size",
api/tests/testthat/helper-mcp-select-principal.R-62-      "label", "metadata_json"
api/tests/testthat/helper-mcp-select-principal.R-63-    ),
api/tests/testthat/helper-mcp-select-principal.R-64-    mcp_public_analysis_cluster_member = c(
api/tests/testthat/helper-mcp-select-principal.R-65-      "snapshot_id", "cluster_kind", "cluster_id", "member_rank", "entity_id",
api/tests/testthat/helper-mcp-select-principal.R-66-      "hgnc_id", "symbol"
api/tests/testthat/helper-mcp-select-principal.R-67-    ),
api/tests/testthat/helper-mcp-select-principal.R-68-    mcp_public_analysis_correlation = c(
api/tests/testthat/helper-mcp-select-principal.R-69-      "snapshot_id", "row_rank", "correlation_kind", "x_key", "y_key", "value",
api/tests/testthat/helper-mcp-select-principal.R-70-      "abs_value", "metadata_json"
api/tests/testthat/helper-mcp-select-principal.R-71-    ),
api/tests/testthat/helper-mcp-select-principal.R:72:    mcp_public_analysis_source_version = "source_data_version",
api/tests/testthat/helper-mcp-select-principal.R-73-    mcp_public_llm_cluster_summary = c(
api/tests/testthat/helper-mcp-select-principal.R-74-      "cache_id", "snapshot_id", "cluster_type", "cluster_number", "cluster_hash",
api/tests/testthat/helper-mcp-select-principal.R-75-      "model_name", "prompt_version", "summary_json", "tags", "created_at", "validated_at"
api/tests/testthat/helper-mcp-select-principal.R-76-    ),
api/tests/testthat/helper-mcp-select-principal.R-77-    mcp_public_nddscore_release = c(
api/tests/testthat/helper-mcp-select-principal.R-78-      "release_id", "score_schema_version", "version", "release_created_at",
api/tests/testthat/helper-mcp-select-principal.R-79-      "n_genes", "n_hpo_predictions", "n_hpo_terms", "n_features", "hpo_threshold",
api/tests/testthat/helper-mcp-select-principal.R-80-      "calibration_method", "ndd_model_created_at", "phenotype_model_created_at",
api/tests/testthat/helper-mcp-select-principal.R-81-      "inheritance_model_created_at", "ndd_performance_json",
api/tests/testthat/helper-mcp-select-principal.R-82-      "phenotype_performance_json", "inheritance_performance_json",
api/tests/testthat/helper-mcp-select-principal.R-83-      "data_versions_json", "artifact_hashes_json", "zenodo_record_url", "version_doi",
api/tests/testthat/helper-mcp-select-principal.R-84-      "concept_doi", "source_record_id", "import_completed_at", "activated_at"
api/tests/testthat/helper-mcp-select-principal.R-85-    ),
api/tests/testthat/helper-mcp-select-principal.R-86-    mcp_public_nddscore_gene_prediction = c(
api/tests/testthat/helper-mcp-select-principal.R-87-      "release_id", "hgnc_id", "gene_symbol", "ensembl_gene_id", "ndd_score",
api/tests/testthat/helper-mcp-select-principal.R-88-      "ndd_score_std", "ndd_score_iqr", "bag_agreement", "rank", "percentile",
api/tests/testthat/helper-mcp-select-principal.R-89-      "risk_tier", "confidence_tier", "known_sysndd_gene", "model_split",
api/tests/testthat/helper-mcp-select-principal.R-90-      "inheritance_ad_probability", "inheritance_ar_probability",
api/tests/testthat/helper-mcp-select-principal.R-91-      "inheritance_xld_probability", "inheritance_xlr_probability",
api/tests/testthat/helper-mcp-select-principal.R-92-      "top_inheritance_mode", "called_inheritance_modes", "n_predicted_hpo",
api/tests/testthat/helper-mcp-select-principal.R-93-      "top_hpo_predictions_json", "shap_clinical", "shap_constraint",
api/tests/testthat/helper-mcp-select-principal.R-94-      "shap_expression", "shap_network", "shap_conservation", "shap_other",
api/tests/testthat/helper-mcp-select-principal.R-95-      "dominant_shap_group", "top_features_json", "prediction_note"
api/tests/testthat/helper-mcp-select-principal.R-96-    ),
api/tests/testthat/helper-mcp-select-principal.R-97-    mcp_public_nddscore_hpo_prediction = c(
api/tests/testthat/helper-mcp-select-principal.R-98-      "release_id", "hgnc_id", "gene_symbol", "phenotype_id", "phenotype_name",
api/tests/testthat/helper-mcp-select-principal.R-99-      "probability", "rank_for_gene", "passes_default_threshold", "term_auc_roc",
api/tests/testthat/helper-mcp-select-principal.R-100-      "term_auc_pr", "term_training_support"
api/tests/testthat/helper-mcp-select-principal.R-101-    )
api/tests/testthat/helper-mcp-select-principal.R-102-  )
api/tests/testthat/helper-mcp-select-principal.R-103-}
api/tests/testthat/helper-mcp-select-principal.R-104-
api/tests/testthat/helper-mcp-select-principal.R-105-mcp_select_expected_dependencies <- function() {
api/tests/testthat/helper-mcp-select-principal.R-106-  list(
api/tests/testthat/helper-mcp-select-principal.R-107-    mcp_public_analysis_manifest = c(
api/tests/testthat/helper-mcp-select-principal.R:108:      "analysis_snapshot_manifest", "mcp_public_analysis_source_version"
api/tests/testthat/helper-mcp-select-principal.R-109-    ),
api/tests/testthat/helper-mcp-select-principal.R-110-    mcp_public_analysis_network_node = c(
api/tests/testthat/helper-mcp-select-principal.R-111-      "analysis_snapshot_network_node", "mcp_public_analysis_manifest"
api/tests/testthat/helper-mcp-select-principal.R-112-    ),
api/tests/testthat/helper-mcp-select-principal.R-113-    mcp_public_analysis_network_edge = c(
api/tests/testthat/helper-mcp-select-principal.R-114-      "analysis_snapshot_network_edge", "mcp_public_analysis_manifest"
api/tests/testthat/helper-mcp-select-principal.R-115-    ),
api/tests/testthat/helper-mcp-select-principal.R-116-    mcp_public_analysis_cluster = c(
api/tests/testthat/helper-mcp-select-principal.R-117-      "analysis_snapshot_cluster", "mcp_public_analysis_manifest"
api/tests/testthat/helper-mcp-select-principal.R-118-    ),
api/tests/testthat/helper-mcp-select-principal.R-119-    mcp_public_analysis_cluster_member = c(
api/tests/testthat/helper-mcp-select-principal.R-120-      "analysis_snapshot_cluster_member", "mcp_public_analysis_manifest"
api/tests/testthat/helper-mcp-select-principal.R-121-    ),
api/tests/testthat/helper-mcp-select-principal.R-122-    mcp_public_analysis_correlation = c(
api/tests/testthat/helper-mcp-select-principal.R-123-      "analysis_snapshot_correlation", "mcp_public_analysis_manifest"
api/tests/testthat/helper-mcp-select-principal.R-124-    ),
api/tests/testthat/helper-mcp-select-principal.R-125-    mcp_public_llm_cluster_summary = c(
api/tests/testthat/helper-mcp-select-principal.R-126-      "llm_cluster_summary_cache", "mcp_public_analysis_cluster",
api/tests/testthat/helper-mcp-select-principal.R-127-      "mcp_public_analysis_manifest"
api/tests/testthat/helper-mcp-select-principal.R-128-    ),
--
api/tests/testthat/test-mcp-select-principal-projections.R-75-  expect_true(all(!grepl("create or replace|definer|sql security", definitions)))
api/tests/testthat/test-mcp-select-principal-projections.R-76-  expect_match(
api/tests/testthat/test-mcp-select-principal-projections.R-77-    definitions[["mcp_public_analysis_manifest"]],
api/tests/testthat/test-mcp-select-principal-projections.R-78-    "m.source_data_version=sv.source_data_version",
api/tests/testthat/test-mcp-select-principal-projections.R-79-    fixed = TRUE
api/tests/testthat/test-mcp-select-principal-projections.R-80-  )
api/tests/testthat/test-mcp-select-principal-projections.R-81-})
api/tests/testthat/test-mcp-select-principal-projections.R-82-
api/tests/testthat/test-mcp-select-principal-projections.R-83-test_that("trusted normalization matches MySQL canonical VIEW_DEFINITION", {
api/tests/testthat/test-mcp-select-principal-projections.R-84-  source(contract_path, local = FALSE)
api/tests/testthat/test-mcp-select-principal-projections.R-85-  trusted <- mcp_readonly_trusted_view_definitions(migration_path)
api/tests/testthat/test-mcp-select-principal-projections.R-86-  stored <- paste0(
api/tests/testthat/test-mcp-select-principal-projections.R-87-    "select `m`.`snapshot_id` AS `snapshot_id`,`m`.`analysis_type` AS `analysis_type`,",
api/tests/testthat/test-mcp-select-principal-projections.R-88-    "`m`.`parameter_hash` AS `parameter_hash`,`m`.`schema_version` AS `schema_version`,",
api/tests/testthat/test-mcp-select-principal-projections.R-89-    "`m`.`data_class` AS `data_class`,`m`.`generated_at` AS `generated_at`,",
api/tests/testthat/test-mcp-select-principal-projections.R-90-    "`m`.`activated_at` AS `activated_at`,`m`.`stale_after` AS `stale_after`,",
api/tests/testthat/test-mcp-select-principal-projections.R-91-    "`m`.`source_data_version` AS `source_data_version`,`m`.`parameters_json` AS `parameters_json`,",
api/tests/testthat/test-mcp-select-principal-projections.R-92-    "`m`.`payload_hash` AS `payload_hash`,`m`.`algorithm_name` AS `algorithm_name`,",
api/tests/testthat/test-mcp-select-principal-projections.R-93-    "`m`.`algorithm_version` AS `algorithm_version`,`m`.`row_counts_json` AS `row_counts_json` ",
api/tests/testthat/test-mcp-select-principal-projections.R-94-    "from (`verify_a`.`analysis_snapshot_manifest` `m` join ",
api/tests/testthat/test-mcp-select-principal-projections.R:95:    "`verify_a`.`mcp_public_analysis_source_version` `sv` on((`m`.`source_data_version` = ",
api/tests/testthat/test-mcp-select-principal-projections.R-96-    "`verify_a`.`sv`.`source_data_version`))) where ((`m`.`public_ready` = 1) and ",
api/tests/testthat/test-mcp-select-principal-projections.R-97-    "(`m`.`status` = 'public_ready') and (`m`.`stale_after` is not null) and ",
api/tests/testthat/test-mcp-select-principal-projections.R-98-    "(`m`.`stale_after` > utc_timestamp()) and (`m`.`source_data_version` = ",
api/tests/testthat/test-mcp-select-principal-projections.R-99-    "`verify_a`.`sv`.`source_data_version`) and (`m`.`schema_version` = '1.2'))"
api/tests/testthat/test-mcp-select-principal-projections.R-100-  )
api/tests/testthat/test-mcp-select-principal-projections.R-101-
api/tests/testthat/test-mcp-select-principal-projections.R-102-  expect_identical(
api/tests/testthat/test-mcp-select-principal-projections.R-103-    mcp_readonly_normalize_view_sql(stored, schema = "verify_a"),
api/tests/testthat/test-mcp-select-principal-projections.R-104-    trusted[["mcp_public_analysis_manifest"]]
api/tests/testthat/test-mcp-select-principal-projections.R-105-  )
api/tests/testthat/test-mcp-select-principal-projections.R-106-
api/tests/testthat/test-mcp-select-principal-projections.R-107-  malicious <- sub("'public_ready'", "'pending'", stored, fixed = TRUE)
api/tests/testthat/test-mcp-select-principal-projections.R-108-  expect_false(identical(
api/tests/testthat/test-mcp-select-principal-projections.R-109-    mcp_readonly_normalize_view_sql(malicious, schema = "verify_a"),
api/tests/testthat/test-mcp-select-principal-projections.R-110-    trusted[["mcp_public_analysis_manifest"]]
api/tests/testthat/test-mcp-select-principal-projections.R-111-  ))
api/tests/testthat/test-mcp-select-principal-projections.R-112-})
api/tests/testthat/test-mcp-select-principal-projections.R-113-
api/tests/testthat/test-mcp-select-principal-projections.R-114-test_that("canonical hashes preserve predicate grouping on MySQL 8.4", {
api/tests/testthat/test-mcp-select-principal-projections.R-115-  source(contract_path, local = FALSE)
--
api/tests/testthat/test-mcp-analysis-repository.R-7-
api/tests/testthat/test-mcp-analysis-repository.R-8-restore_mcp_binding <- function(name, old_value) {
api/tests/testthat/test-mcp-analysis-repository.R-9-  if (is.null(old_value)) {
api/tests/testthat/test-mcp-analysis-repository.R-10-    if (exists(name, envir = .GlobalEnv, inherits = FALSE)) rm(list = name, envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-repository.R-11-  } else {
api/tests/testthat/test-mcp-analysis-repository.R-12-    assign(name, old_value, envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-repository.R-13-  }
api/tests/testthat/test-mcp-analysis-repository.R-14-}
api/tests/testthat/test-mcp-analysis-repository.R-15-
api/tests/testthat/test-mcp-analysis-repository.R-16-test_that("analysis source version reads the public projection singleton", {
api/tests/testthat/test-mcp-analysis-repository.R-17-  source("../../functions/analysis-snapshot-repository.R")
api/tests/testthat/test-mcp-analysis-repository.R-18-  sql_seen <- character()
api/tests/testthat/test-mcp-analysis-repository.R-19-  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
api/tests/testthat/test-mcp-analysis-repository.R-20-  assign("db_execute_query", function(sql, params = list(), conn = NULL) {
api/tests/testthat/test-mcp-analysis-repository.R-21-    sql_seen <<- c(sql_seen, sql)
api/tests/testthat/test-mcp-analysis-repository.R-22-    tibble::tibble(source_data_version = "source-v1")
api/tests/testthat/test-mcp-analysis-repository.R-23-  }, envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-repository.R-24-  withr::defer(restore_mcp_binding("db_execute_query", old_query))
api/tests/testthat/test-mcp-analysis-repository.R-25-
api/tests/testthat/test-mcp-analysis-repository.R-26-  expect_equal(analysis_snapshot_source_data_version(), "source-v1")
api/tests/testthat/test-mcp-analysis-repository.R:27:  expect_true(any(grepl("mcp_public_analysis_source_version", sql_seen, fixed = TRUE)))
api/tests/testthat/test-mcp-analysis-repository.R-28-  expect_false(any(grepl("ndd_entity_view|ndd_entity_review", sql_seen)))
api/tests/testthat/test-mcp-analysis-repository.R-29-})
api/tests/testthat/test-mcp-analysis-repository.R-30-
api/tests/testthat/test-mcp-analysis-repository.R-31-test_that("MCP LLM summary reader uses the filtered projection and bound values", {
api/tests/testthat/test-mcp-analysis-repository.R-32-  source_mcp_analysis_repository()
api/tests/testthat/test-mcp-analysis-repository.R-33-  calls <- list()
api/tests/testthat/test-mcp-analysis-repository.R-34-  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
api/tests/testthat/test-mcp-analysis-repository.R-35-  assign("db_execute_query", function(sql, params = list(), conn = NULL) {
api/tests/testthat/test-mcp-analysis-repository.R-36-    calls[[length(calls) + 1L]] <<- list(sql = sql, params = params)
api/tests/testthat/test-mcp-analysis-repository.R-37-    tibble::tibble()
api/tests/testthat/test-mcp-analysis-repository.R-38-  }, envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-repository.R-39-  withr::defer(restore_mcp_binding("db_execute_query", old_query))
api/tests/testthat/test-mcp-analysis-repository.R-40-
api/tests/testthat/test-mcp-analysis-repository.R-41-  mcp_analysis_repo_get_cached_llm_summaries(
api/tests/testthat/test-mcp-analysis-repository.R-42-    "functional", cluster_hashes = c("hash-a", "hash-b"), cluster_numbers = 3L
api/tests/testthat/test-mcp-analysis-repository.R-43-  )
api/tests/testthat/test-mcp-analysis-repository.R-44-
api/tests/testthat/test-mcp-analysis-repository.R-45-  expect_match(calls[[1]]$sql, "FROM mcp_public_llm_cluster_summary", fixed = TRUE)
api/tests/testthat/test-mcp-analysis-repository.R-46-  expect_false(grepl("llm_cluster_summary_cache", calls[[1]]$sql, fixed = TRUE))
api/tests/testthat/test-mcp-analysis-repository.R-47-  expect_true(all(c("functional", "hash-a", "hash-b", 3L) %in% unlist(calls[[1]]$params)))

exec
/bin/bash -lc "nl -ba api/functions/async-job-service.R | sed -n '339,430p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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
   356	}
   357	
   358	#' Read current durable async job status
   359	#'
   360	#' @param job_id Character job id.
   361	#' @param include_result Logical; include result_json when TRUE.
   362	#' @param conn Optional DB connection or pool.
   363	#'
   364	#' @return Tibble with zero or one durable job row.
   365	#' @export
   366	async_job_service_status <- function(job_id, include_result = FALSE, conn = NULL) {
   367	  async_job_repository_get(
   368	    job_id = .async_job_service_non_empty_string(job_id, "job_id"),
   369	    include_result = isTRUE(include_result),
   370	    conn = conn
   371	  )
   372	}
   373	
   374	#' Return durable async job history
   375	#'
   376	#' @param limit Integer history limit.
   377	#' @param include_result Logical; include result_json in history rows.
   378	#' @param conn Optional DB connection or pool.
   379	#'
   380	#' @return Tibble of recent durable jobs.
   381	#' @export
   382	async_job_service_history <- function(limit = 20L, include_result = FALSE, conn = NULL) {
   383	  args <- list(
   384	    limit = max(1L, as.integer(.async_job_service_scalar(limit, 20L))),
   385	    conn = conn
   386	  )
   387	  if (isTRUE(include_result)) {
   388	    args$include_result <- TRUE
   389	  }
   390	  do.call(async_job_repository_history, args)
   391	}
   392	
   393	#' Request durable async job cancellation and return the refreshed row
   394	#'
   395	#' @param job_id Character job id.
   396	#' @param cancelled_by Optional user id.
   397	#' @param conn Optional DB connection or pool.
   398	#'
   399	#' @return Tibble with zero or one durable job row after cancellation.
   400	#' @export
   401	async_job_service_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
   402	  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
   403	
   404	  async_job_repository_cancel(
   405	    job_id = job_id,
   406	    cancelled_by = if (is.null(cancelled_by)) NULL else as.integer(cancelled_by),
   407	    conn = conn
   408	  )
   409	
   410	  async_job_repository_get(job_id, conn = conn)
   411	}
   412	
   413	#' Legacy duplicate response wrapper for endpoints not migrated yet
   414	#'
   415	#' @inheritParams async_job_service_find_duplicate
   416	#'
   417	#' @return List shaped like the previous duplicate helper.
   418	#' @export
   419	async_job_service_duplicate <- function(job_type, request_payload, conn = NULL) {
   420	  duplicate <- async_job_service_find_duplicate(
   421	    job_type = job_type,
   422	    request_payload = request_payload,
   423	    conn = conn
   424	  )
   425	
   426	  if (nrow(duplicate) == 0) {
   427	    return(list(duplicate = FALSE))
   428	  }
   429	
   430	  list(

exec
/bin/bash -lc "rg -n -C 25 '"'^async_job_service_duplicate <-|async_job_service_duplicate'"\\s*<-' api/functions" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/functions/async-job-service.R-394-#'
api/functions/async-job-service.R-395-#' @param job_id Character job id.
api/functions/async-job-service.R-396-#' @param cancelled_by Optional user id.
api/functions/async-job-service.R-397-#' @param conn Optional DB connection or pool.
api/functions/async-job-service.R-398-#'
api/functions/async-job-service.R-399-#' @return Tibble with zero or one durable job row after cancellation.
api/functions/async-job-service.R-400-#' @export
api/functions/async-job-service.R-401-async_job_service_cancel <- function(job_id, cancelled_by = NULL, conn = NULL) {
api/functions/async-job-service.R-402-  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
api/functions/async-job-service.R-403-
api/functions/async-job-service.R-404-  async_job_repository_cancel(
api/functions/async-job-service.R-405-    job_id = job_id,
api/functions/async-job-service.R-406-    cancelled_by = if (is.null(cancelled_by)) NULL else as.integer(cancelled_by),
api/functions/async-job-service.R-407-    conn = conn
api/functions/async-job-service.R-408-  )
api/functions/async-job-service.R-409-
api/functions/async-job-service.R-410-  async_job_repository_get(job_id, conn = conn)
api/functions/async-job-service.R-411-}
api/functions/async-job-service.R-412-
api/functions/async-job-service.R-413-#' Legacy duplicate response wrapper for endpoints not migrated yet
api/functions/async-job-service.R-414-#'
api/functions/async-job-service.R-415-#' @inheritParams async_job_service_find_duplicate
api/functions/async-job-service.R-416-#'
api/functions/async-job-service.R-417-#' @return List shaped like the previous duplicate helper.
api/functions/async-job-service.R-418-#' @export
api/functions/async-job-service.R:419:async_job_service_duplicate <- function(job_type, request_payload, conn = NULL) {
api/functions/async-job-service.R-420-  duplicate <- async_job_service_find_duplicate(
api/functions/async-job-service.R-421-    job_type = job_type,
api/functions/async-job-service.R-422-    request_payload = request_payload,
api/functions/async-job-service.R-423-    conn = conn
api/functions/async-job-service.R-424-  )
api/functions/async-job-service.R-425-
api/functions/async-job-service.R-426-  if (nrow(duplicate) == 0) {
api/functions/async-job-service.R-427-    return(list(duplicate = FALSE))
api/functions/async-job-service.R-428-  }
api/functions/async-job-service.R-429-
api/functions/async-job-service.R-430-  list(
api/functions/async-job-service.R-431-    duplicate = TRUE,
api/functions/async-job-service.R-432-    existing_job_id = duplicate$job_id[[1]]
api/functions/async-job-service.R-433-  )
api/functions/async-job-service.R-434-}
api/functions/async-job-service.R-435-
api/functions/async-job-service.R-436-#' Find an active job of a given type (job-type single-flight).
api/functions/async-job-service.R-437-#'
api/functions/async-job-service.R-438-#' @param job_type Character job type.
api/functions/async-job-service.R-439-#' @param conn Optional DB connection or pool.
api/functions/async-job-service.R-440-#' @return Tibble with zero or one active duplicate row of that job_type.
api/functions/async-job-service.R-441-#' @export
api/functions/async-job-service.R-442-async_job_service_find_active_by_type <- function(job_type, conn = NULL) {
api/functions/async-job-service.R-443-  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
api/functions/async-job-service.R-444-  async_job_repository_find_active_by_type(job_type = job_type, conn = conn)

exec
/bin/bash -lc "rg -n -C 20 'find_active_duplicate' api/functions/async-job-repository.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
106-    paste(rep("?", length(insert_values)), collapse = ", "),
107-    ")"
108-  )
109-
110-  params <- .async_job_normalize_params(insert_values)
111-
112-  tryCatch(
113-    {
114-      db_execute_statement(sql, params, conn = conn)
115-    },
116-    db_statement_error = function(e) {
117-      is_duplicate <- grepl(
118-        "idx_async_jobs_active_request_hash",
119-        e$message,
120-        fixed = TRUE
121-      )
122-      if (!is_duplicate) {
123-        stop(e)
124-      }
125-
126:      duplicate <- async_job_repository_find_active_duplicate(
127-        job_type = .async_job_scalar(job$job_type),
128-        request_hash = .async_job_scalar(job$request_hash),
129-        conn = conn
130-      )
131-
132-      abort(
133-        message = "Active async job with matching request hash already exists",
134-        class = "async_job_duplicate_error",
135-        job_id = if (nrow(duplicate) > 0) duplicate$job_id[[1]] else NULL,
136-        duplicate_job = duplicate
137-      )
138-    }
139-  )
140-
141-  .async_job_scalar(job$job_id)
142-}
143-
144-#' Get a durable async job row
145-#'
146-#' @param job_id Character job identifier.
--
156-  )
157-
158-  db_execute_query(sql, list(job_id), conn = conn)
159-}
160-
161-#' Find an active duplicate by job_type and durable request hash
162-#'
163-#' @param job_type Character job type.
164-#' @param request_hash Character durable request hash.
165-#' @param conn Optional connection or pool for dependency injection.
166-#'
167-#' @return Tibble with zero or one active duplicate row.
168-#' @export
169-# "Active" = in-flight OR retryable-failed. Shared by the hash-keyed duplicate
170-# lookup and the job-type single-flight lookup so they stay identical.
171-.async_job_active_status_sql <- paste(
172-  "(status IN ('queued', 'running', 'cancel_requested')",
173-  "OR (status = 'failed' AND attempt_count < max_attempts AND next_attempt_at IS NOT NULL))"
174-)
175-
176:async_job_repository_find_active_duplicate <- function(job_type, request_hash, conn = NULL) {
177-  sql <- paste(
178-    .async_job_build_select(FALSE),
179-    "FROM async_jobs WHERE job_type = ? AND request_hash = ?",
180-    "AND", .async_job_active_status_sql,
181-    "ORDER BY submitted_at DESC LIMIT 1"
182-  )
183-
184-  db_execute_query(sql, list(job_type, request_hash), conn = conn)
185-}
186-
187-#' Find an active job of a given type, independent of request payload/hash.
188-#'
189-#' Job-type single-flight for destructive maintenance families (#535 S2b): a
190-#' new submission must dedupe against ANY in-flight (or retryable-failed) job of
191-#' the same type, even across a payload-schema change (e.g. dropping db_config),
192:#' which the hash-based `find_active_duplicate` cannot do because the hash
193-#' changes with the payload.
194-#'
195-#' @param job_type Character job type.
196-#' @param conn Optional connection or pool for dependency injection.
197-#' @return Tibble with zero or one active row of that job_type.
198-#' @export
199-async_job_repository_find_active_by_type <- function(job_type, conn = NULL) {
200-  sql <- paste(
201-    .async_job_build_select(FALSE),
202-    "FROM async_jobs WHERE job_type = ?",
203-    "AND", .async_job_active_status_sql,
204-    "ORDER BY submitted_at DESC LIMIT 1"
205-  )
206-
207-  db_execute_query(sql, list(job_type), conn = conn)
208-}
209-
210-#' Claim the next eligible queued or scheduled-retry job
211-#'
212-#' @param worker_id Character worker identifier.

exec
/bin/bash -lc "git show origin/master:api/functions/job-manager.R | nl -ba | sed -n '200,245p'; git show origin/master:api/functions/async-job-service.R | nl -ba | sed -n '330,400p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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
   356	}
   357	
   358	#' Read current durable async job status
   359	#'
   360	#' @param job_id Character job id.
   361	#' @param include_result Logical; include result_json when TRUE.
   362	#' @param conn Optional DB connection or pool.
   363	#'
   364	#' @return Tibble with zero or one durable job row.
   365	#' @export
   366	async_job_service_status <- function(job_id, include_result = FALSE, conn = NULL) {
   367	  async_job_repository_get(
   368	    job_id = .async_job_service_non_empty_string(job_id, "job_id"),
   369	    include_result = isTRUE(include_result),
   370	    conn = conn
   371	  )
   372	}
   373	
   374	#' Return durable async job history
   375	#'
   376	#' @param limit Integer history limit.
   377	#' @param include_result Logical; include result_json in history rows.
   378	#' @param conn Optional DB connection or pool.
   379	#'
   380	#' @return Tibble of recent durable jobs.
   381	#' @export
   382	async_job_service_history <- function(limit = 20L, include_result = FALSE, conn = NULL) {
   383	  args <- list(
   384	    limit = max(1L, as.integer(.async_job_service_scalar(limit, 20L))),
   385	    conn = conn
   386	  )
   387	  if (isTRUE(include_result)) {
   388	    args$include_result <- TRUE
   389	  }
   390	  do.call(async_job_repository_history, args)
   391	}
   392	
   393	#' Request durable async job cancellation and return the refreshed row
   394	#'
   395	#' @param job_id Character job id.
   396	#' @param cancelled_by Optional user id.
   397	#' @param conn Optional DB connection or pool.
   398	#'
   399	#' @return Tibble with zero or one durable job row after cancellation.
   400	#' @export

exec
/bin/bash -lc "rg -n -C 8 'clustering|request_hash' api/tests/testthat/test-unit-async-job-service.R api/tests/testthat/test-unit-job-manager.R api/tests/testthat | head -n 600" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
rg: api/tests/testthat/test-unit-job-manager.R: No such file or directory (os error 2)
api/tests/testthat/test-unit-async-job-service.R-31-  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
api/tests/testthat/test-unit-async-job-service.R-32-    get_call <<- list(job_id = job_id, include_result = include_result)
api/tests/testthat/test-unit-async-job-service.R-33-    tibble::tibble(
api/tests/testthat/test-unit-async-job-service.R-34-      job_id = job_id,
api/tests/testthat/test-unit-async-job-service.R-35-      job_type = created_job$job_type,
api/tests/testthat/test-unit-async-job-service.R-36-      queue_name = created_job$queue_name,
api/tests/testthat/test-unit-async-job-service.R-37-      priority = created_job$priority,
api/tests/testthat/test-unit-async-job-service.R-38-      status = "queued",
api/tests/testthat/test-unit-async-job-service.R:39:      request_hash = created_job$request_hash,
api/tests/testthat/test-unit-async-job-service.R-40-      request_payload_json = created_job$request_payload_json,
api/tests/testthat/test-unit-async-job-service.R-41-      submitted_by = created_job$submitted_by,
api/tests/testthat/test-unit-async-job-service.R-42-      submitted_at = created_job$submitted_at,
api/tests/testthat/test-unit-async-job-service.R-43-      scheduled_at = created_job$scheduled_at,
api/tests/testthat/test-unit-async-job-service.R-44-      attempt_count = 0L,
api/tests/testthat/test-unit-async-job-service.R-45-      max_attempts = created_job$max_attempts
api/tests/testthat/test-unit-async-job-service.R-46-    )
api/tests/testthat/test-unit-async-job-service.R-47-  }
--
api/tests/testthat/test-unit-async-job-service.R-66-  expect_equal(created_job$submitted_by, 42L)
api/tests/testthat/test-unit-async-job-service.R-67-  expect_equal(created_job$max_attempts, 3L)
api/tests/testthat/test-unit-async-job-service.R-68-  expect_equal(created_job$scheduled_at, scheduled_at)
api/tests/testthat/test-unit-async-job-service.R-69-  expect_equal(
api/tests/testthat/test-unit-async-job-service.R-70-    jsonlite::fromJSON(created_job$request_payload_json, simplifyVector = TRUE),
api/tests/testthat/test-unit-async-job-service.R-71-    list(genes = c("GENE1", "GENE2"), algorithm = "walktrap")
api/tests/testthat/test-unit-async-job-service.R-72-  )
api/tests/testthat/test-unit-async-job-service.R-73-  expect_equal(
api/tests/testthat/test-unit-async-job-service.R:74:    created_job$request_hash,
api/tests/testthat/test-unit-async-job-service.R:75:    runtime$async_job_service_request_hash(
api/tests/testthat/test-unit-async-job-service.R-76-      "comparisons_update",
api/tests/testthat/test-unit-async-job-service.R-77-      created_job$request_payload_json
api/tests/testthat/test-unit-async-job-service.R-78-    )
api/tests/testthat/test-unit-async-job-service.R-79-  )
api/tests/testthat/test-unit-async-job-service.R-80-  expect_equal(get_call, list(job_id = "job-submit", include_result = FALSE))
api/tests/testthat/test-unit-async-job-service.R-81-})
api/tests/testthat/test-unit-async-job-service.R-82-
api/tests/testthat/test-unit-async-job-service.R-83-test_that("async_job_service_submit returns the duplicate job when the repository rejects a concurrent create", {
--
api/tests/testthat/test-unit-async-job-service.R-107-  expect_false(result$created)
api/tests/testthat/test-unit-async-job-service.R-108-  expect_equal(result$job, duplicate_row)
api/tests/testthat/test-unit-async-job-service.R-109-})
api/tests/testthat/test-unit-async-job-service.R-110-
api/tests/testthat/test-unit-async-job-service.R-111-test_that("async_job_service_find_duplicate hashes the request payload before querying the repository", {
api/tests/testthat/test-unit-async-job-service.R-112-  runtime <- load_async_job_service_runtime()
api/tests/testthat/test-unit-async-job-service.R-113-  captured <- NULL
api/tests/testthat/test-unit-async-job-service.R-114-
api/tests/testthat/test-unit-async-job-service.R:115:  runtime$async_job_repository_find_active_duplicate <- function(job_type, request_hash, conn = NULL) {
api/tests/testthat/test-unit-async-job-service.R:116:    captured <<- list(job_type = job_type, request_hash = request_hash)
api/tests/testthat/test-unit-async-job-service.R-117-    tibble::tibble(job_id = "job-existing", status = "running")
api/tests/testthat/test-unit-async-job-service.R-118-  }
api/tests/testthat/test-unit-async-job-service.R-119-
api/tests/testthat/test-unit-async-job-service.R-120-  result <- runtime$async_job_service_find_duplicate(
api/tests/testthat/test-unit-async-job-service.R:121:    job_type = "clustering",
api/tests/testthat/test-unit-async-job-service.R-122-    request_payload = list(genes = c("A", "B"), algorithm = "leiden")
api/tests/testthat/test-unit-async-job-service.R-123-  )
api/tests/testthat/test-unit-async-job-service.R-124-
api/tests/testthat/test-unit-async-job-service.R-125-  expect_equal(result$job_id[[1]], "job-existing")
api/tests/testthat/test-unit-async-job-service.R:126:  expect_equal(captured$job_type, "clustering")
api/tests/testthat/test-unit-async-job-service.R-127-  expect_equal(
api/tests/testthat/test-unit-async-job-service.R:128:    captured$request_hash,
api/tests/testthat/test-unit-async-job-service.R:129:    runtime$async_job_service_request_hash(
api/tests/testthat/test-unit-async-job-service.R:130:      "clustering",
api/tests/testthat/test-unit-async-job-service.R-131-      runtime$async_job_service_payload_json(
api/tests/testthat/test-unit-async-job-service.R-132-        list(genes = c("A", "B"), algorithm = "leiden")
api/tests/testthat/test-unit-async-job-service.R-133-      )
api/tests/testthat/test-unit-async-job-service.R-134-    )
api/tests/testthat/test-unit-async-job-service.R-135-  )
api/tests/testthat/test-unit-async-job-service.R-136-})
api/tests/testthat/test-unit-async-job-service.R-137-
api/tests/testthat/test-unit-async-job-service.R-138-test_that("find_active_by_type is job-type scoped and payload-hash independent (#535 S2b HIGH-4)", {
--
api/tests/testthat/test-unit-async-job-service.R-217-  runtime <- load_async_job_service_runtime()
api/tests/testthat/test-unit-async-job-service.R-218-
api/tests/testthat/test-unit-async-job-service.R-219-  expect_equal(runtime$async_job_queue_for_type("publication_date_backfill"), "maintenance")
api/tests/testthat/test-unit-async-job-service.R-220-  expect_equal(runtime$async_job_queue_for_type("omim_update"), "maintenance")
api/tests/testthat/test-unit-async-job-service.R-221-  expect_equal(runtime$async_job_queue_for_type("disease_ontology_mapping_refresh"), "maintenance")
api/tests/testthat/test-unit-async-job-service.R-222-  expect_equal(runtime$async_job_queue_for_type("nddscore_import"), "maintenance")
api/tests/testthat/test-unit-async-job-service.R-223-
api/tests/testthat/test-unit-async-job-service.R-224-  expect_equal(runtime$async_job_queue_for_type("llm_generation"), "default")
api/tests/testthat/test-unit-async-job-service.R:225:  expect_equal(runtime$async_job_queue_for_type("clustering"), "default")
api/tests/testthat/test-unit-async-job-service.R:226:  expect_equal(runtime$async_job_queue_for_type("phenotype_clustering"), "default")
api/tests/testthat/test-unit-async-job-service.R-227-  # Unknown / unclassified job types default to the interactive lane.
api/tests/testthat/test-unit-async-job-service.R-228-  expect_equal(runtime$async_job_queue_for_type("some_new_job"), "default")
api/tests/testthat/test-unit-async-job-service.R-229-})
api/tests/testthat/test-unit-async-job-service.R-230-
api/tests/testthat/test-unit-async-job-service.R-231-test_that("interactive jobs outrank maintenance jobs in claim priority", {
api/tests/testthat/test-unit-async-job-service.R-232-  runtime <- load_async_job_service_runtime()
api/tests/testthat/test-unit-async-job-service.R-233-
api/tests/testthat/test-unit-async-job-service.R-234-  interactive <- runtime$async_job_priority_for_type("llm_generation")
api/tests/testthat/test-unit-async-job-service.R-235-  maintenance <- runtime$async_job_priority_for_type("publication_date_backfill")
api/tests/testthat/test-unit-async-job-service.R-236-  other <- runtime$async_job_priority_for_type("some_new_job")
api/tests/testthat/test-unit-async-job-service.R-237-
api/tests/testthat/test-unit-async-job-service.R-238-  # Lower number = claimed first (claim query orders priority ASC).
api/tests/testthat/test-unit-async-job-service.R-239-  expect_lt(interactive, maintenance)
api/tests/testthat/test-unit-async-job-service.R-240-  expect_lt(maintenance, other)
api/tests/testthat/test-unit-async-job-service.R:241:  expect_equal(runtime$async_job_priority_for_type("clustering"), interactive)
api/tests/testthat/test-unit-async-job-service.R-242-  expect_equal(runtime$async_job_priority_for_type("omim_update"), maintenance)
api/tests/testthat/test-unit-async-job-service.R-243-})
api/tests/testthat/test-unit-async-job-service.R-244-
api/tests/testthat/test-unit-async-job-service.R-245-test_that("async_job_service_submit defaults queue + priority from the job type", {
api/tests/testthat/test-unit-async-job-service.R-246-  runtime <- load_async_job_service_runtime()
api/tests/testthat/test-unit-async-job-service.R-247-  created_job <- NULL
api/tests/testthat/test-unit-async-job-service.R-248-
api/tests/testthat/test-unit-async-job-service.R-249-  runtime$async_job_repository_create <- function(job, conn = NULL) {
--
api/tests/testthat/test-unit-async-job-service.R-31-  runtime$async_job_repository_get <- function(job_id, include_result = FALSE, conn = NULL) {
api/tests/testthat/test-unit-async-job-service.R-32-    get_call <<- list(job_id = job_id, include_result = include_result)
api/tests/testthat/test-unit-async-job-service.R-33-    tibble::tibble(
api/tests/testthat/test-unit-async-job-service.R-34-      job_id = job_id,
api/tests/testthat/test-unit-async-job-service.R-35-      job_type = created_job$job_type,
api/tests/testthat/test-unit-async-job-service.R-36-      queue_name = created_job$queue_name,
api/tests/testthat/test-unit-async-job-service.R-37-      priority = created_job$priority,
api/tests/testthat/test-unit-async-job-service.R-38-      status = "queued",
api/tests/testthat/test-unit-async-job-service.R:39:      request_hash = created_job$request_hash,
api/tests/testthat/test-unit-async-job-service.R-40-      request_payload_json = created_job$request_payload_json,
api/tests/testthat/test-unit-async-job-service.R-41-      submitted_by = created_job$submitted_by,
api/tests/testthat/test-unit-async-job-service.R-42-      submitted_at = created_job$submitted_at,
api/tests/testthat/test-unit-async-job-service.R-43-      scheduled_at = created_job$scheduled_at,
api/tests/testthat/test-unit-async-job-service.R-44-      attempt_count = 0L,
api/tests/testthat/test-unit-async-job-service.R-45-      max_attempts = created_job$max_attempts
api/tests/testthat/test-unit-async-job-service.R-46-    )
api/tests/testthat/test-unit-async-job-service.R-47-  }
--
api/tests/testthat/test-unit-async-job-service.R-66-  expect_equal(created_job$submitted_by, 42L)
api/tests/testthat/test-unit-async-job-service.R-67-  expect_equal(created_job$max_attempts, 3L)
api/tests/testthat/test-unit-async-job-service.R-68-  expect_equal(created_job$scheduled_at, scheduled_at)
api/tests/testthat/test-unit-async-job-service.R-69-  expect_equal(
api/tests/testthat/test-unit-async-job-service.R-70-    jsonlite::fromJSON(created_job$request_payload_json, simplifyVector = TRUE),
api/tests/testthat/test-unit-async-job-service.R-71-    list(genes = c("GENE1", "GENE2"), algorithm = "walktrap")
api/tests/testthat/test-unit-async-job-service.R-72-  )
api/tests/testthat/test-unit-async-job-service.R-73-  expect_equal(
api/tests/testthat/test-unit-async-job-service.R:74:    created_job$request_hash,
api/tests/testthat/test-unit-async-job-service.R:75:    runtime$async_job_service_request_hash(
api/tests/testthat/test-unit-async-job-service.R-76-      "comparisons_update",
api/tests/testthat/test-unit-async-job-service.R-77-      created_job$request_payload_json
api/tests/testthat/test-unit-async-job-service.R-78-    )
api/tests/testthat/test-unit-async-job-service.R-79-  )
api/tests/testthat/test-unit-async-job-service.R-80-  expect_equal(get_call, list(job_id = "job-submit", include_result = FALSE))
api/tests/testthat/test-unit-async-job-service.R-81-})
api/tests/testthat/test-unit-async-job-service.R-82-
api/tests/testthat/test-unit-async-job-service.R-83-test_that("async_job_service_submit returns the duplicate job when the repository rejects a concurrent create", {
--
api/tests/testthat/test-unit-async-job-service.R-107-  expect_false(result$created)
api/tests/testthat/test-unit-async-job-service.R-108-  expect_equal(result$job, duplicate_row)
api/tests/testthat/test-unit-async-job-service.R-109-})
api/tests/testthat/test-unit-async-job-service.R-110-
api/tests/testthat/test-unit-async-job-service.R-111-test_that("async_job_service_find_duplicate hashes the request payload before querying the repository", {
api/tests/testthat/test-unit-async-job-service.R-112-  runtime <- load_async_job_service_runtime()
api/tests/testthat/test-unit-async-job-service.R-113-  captured <- NULL
api/tests/testthat/test-unit-async-job-service.R-114-
api/tests/testthat/test-unit-async-job-service.R:115:  runtime$async_job_repository_find_active_duplicate <- function(job_type, request_hash, conn = NULL) {
api/tests/testthat/test-unit-async-job-service.R:116:    captured <<- list(job_type = job_type, request_hash = request_hash)
api/tests/testthat/test-unit-async-job-service.R-117-    tibble::tibble(job_id = "job-existing", status = "running")
api/tests/testthat/test-unit-async-job-service.R-118-  }
api/tests/testthat/test-unit-async-job-service.R-119-
api/tests/testthat/test-unit-async-job-service.R-120-  result <- runtime$async_job_service_find_duplicate(
api/tests/testthat/test-unit-async-job-service.R:121:    job_type = "clustering",
api/tests/testthat/test-unit-async-job-service.R-122-    request_payload = list(genes = c("A", "B"), algorithm = "leiden")
api/tests/testthat/test-unit-async-job-service.R-123-  )
api/tests/testthat/test-unit-async-job-service.R-124-
api/tests/testthat/test-unit-async-job-service.R-125-  expect_equal(result$job_id[[1]], "job-existing")
api/tests/testthat/test-unit-async-job-service.R:126:  expect_equal(captured$job_type, "clustering")
api/tests/testthat/test-unit-async-job-service.R-127-  expect_equal(
api/tests/testthat/test-unit-async-job-service.R:128:    captured$request_hash,
api/tests/testthat/test-unit-async-job-service.R:129:    runtime$async_job_service_request_hash(
api/tests/testthat/test-unit-async-job-service.R:130:      "clustering",
api/tests/testthat/test-unit-async-job-service.R-131-      runtime$async_job_service_payload_json(
api/tests/testthat/test-unit-async-job-service.R-132-        list(genes = c("A", "B"), algorithm = "leiden")
api/tests/testthat/test-unit-async-job-service.R-133-      )
api/tests/testthat/test-unit-async-job-service.R-134-    )
api/tests/testthat/test-unit-async-job-service.R-135-  )
api/tests/testthat/test-unit-async-job-service.R-136-})
api/tests/testthat/test-unit-async-job-service.R-137-
api/tests/testthat/test-unit-async-job-service.R-138-test_that("find_active_by_type is job-type scoped and payload-hash independent (#535 S2b HIGH-4)", {
--
api/tests/testthat/test-unit-async-job-service.R-217-  runtime <- load_async_job_service_runtime()
api/tests/testthat/test-unit-async-job-service.R-218-
api/tests/testthat/test-unit-async-job-service.R-219-  expect_equal(runtime$async_job_queue_for_type("publication_date_backfill"), "maintenance")
api/tests/testthat/test-unit-async-job-service.R-220-  expect_equal(runtime$async_job_queue_for_type("omim_update"), "maintenance")
api/tests/testthat/test-unit-async-job-service.R-221-  expect_equal(runtime$async_job_queue_for_type("disease_ontology_mapping_refresh"), "maintenance")
api/tests/testthat/test-unit-async-job-service.R-222-  expect_equal(runtime$async_job_queue_for_type("nddscore_import"), "maintenance")
api/tests/testthat/test-unit-async-job-service.R-223-
api/tests/testthat/test-unit-async-job-service.R-224-  expect_equal(runtime$async_job_queue_for_type("llm_generation"), "default")
api/tests/testthat/test-unit-async-job-service.R:225:  expect_equal(runtime$async_job_queue_for_type("clustering"), "default")
api/tests/testthat/test-unit-async-job-service.R:226:  expect_equal(runtime$async_job_queue_for_type("phenotype_clustering"), "default")
api/tests/testthat/test-unit-async-job-service.R-227-  # Unknown / unclassified job types default to the interactive lane.
api/tests/testthat/test-unit-async-job-service.R-228-  expect_equal(runtime$async_job_queue_for_type("some_new_job"), "default")
api/tests/testthat/test-unit-async-job-service.R-229-})
api/tests/testthat/test-unit-async-job-service.R-230-
api/tests/testthat/test-unit-async-job-service.R-231-test_that("interactive jobs outrank maintenance jobs in claim priority", {
api/tests/testthat/test-unit-async-job-service.R-232-  runtime <- load_async_job_service_runtime()
api/tests/testthat/test-unit-async-job-service.R-233-
api/tests/testthat/test-unit-async-job-service.R-234-  interactive <- runtime$async_job_priority_for_type("llm_generation")
api/tests/testthat/test-unit-async-job-service.R-235-  maintenance <- runtime$async_job_priority_for_type("publication_date_backfill")
api/tests/testthat/test-unit-async-job-service.R-236-  other <- runtime$async_job_priority_for_type("some_new_job")
api/tests/testthat/test-unit-async-job-service.R-237-
api/tests/testthat/test-unit-async-job-service.R-238-  # Lower number = claimed first (claim query orders priority ASC).
api/tests/testthat/test-unit-async-job-service.R-239-  expect_lt(interactive, maintenance)
api/tests/testthat/test-unit-async-job-service.R-240-  expect_lt(maintenance, other)
api/tests/testthat/test-unit-async-job-service.R:241:  expect_equal(runtime$async_job_priority_for_type("clustering"), interactive)
api/tests/testthat/test-unit-async-job-service.R-242-  expect_equal(runtime$async_job_priority_for_type("omim_update"), maintenance)
api/tests/testthat/test-unit-async-job-service.R-243-})
api/tests/testthat/test-unit-async-job-service.R-244-
api/tests/testthat/test-unit-async-job-service.R-245-test_that("async_job_service_submit defaults queue + priority from the job type", {
api/tests/testthat/test-unit-async-job-service.R-246-  runtime <- load_async_job_service_runtime()
api/tests/testthat/test-unit-async-job-service.R-247-  created_job <- NULL
api/tests/testthat/test-unit-async-job-service.R-248-
api/tests/testthat/test-unit-async-job-service.R-249-  runtime$async_job_repository_create <- function(job, conn = NULL) {
--
api/tests/testthat/job-endpoint-services-fixtures.R-13-# the environment the service was sourced into (S3 dispatch finds it there). This needs
api/tests/testthat/job-endpoint-services-fixtures.R-14-# no test DB / RSQLite, so every test is a real PASS on host R.
api/tests/testthat/job-endpoint-services-fixtures.R-15-
api/tests/testthat/job-endpoint-services-fixtures.R-16-library(dplyr)
api/tests/testthat/job-endpoint-services-fixtures.R-17-library(tidyr)
api/tests/testthat/job-endpoint-services-fixtures.R-18-
api/tests/testthat/job-endpoint-services-fixtures.R-19-#' Source a service file into a fresh child-of-globalenv environment.
api/tests/testthat/job-endpoint-services-fixtures.R-20-#'
api/tests/testthat/job-endpoint-services-fixtures.R:21:#' The two public clustering submit services now call `async_job_submit_admission_guard()`
api/tests/testthat/job-endpoint-services-fixtures.R-22-#' FIRST (#535 S6) before any DB/cache work; stub it to "admit" by default so these
api/tests/testthat/job-endpoint-services-fixtures.R-23-#' isolated tests exercise the downstream request/response logic. A test can override
api/tests/testthat/job-endpoint-services-fixtures.R-24-#' `env$async_job_submit_admission_guard` to exercise the throttle-block path.
api/tests/testthat/job-endpoint-services-fixtures.R-25-#'
api/tests/testthat/job-endpoint-services-fixtures.R:26:#' Also sources `functions/clustering-gene-universe.R` (#574 D1/D3) into `env` so
api/tests/testthat/job-endpoint-services-fixtures.R:27:#' `clustering_result_meta()` -- the shared result-`meta` assembly helper used by
api/tests/testthat/job-endpoint-services-fixtures.R-28-#' `job-functional-submission-service.R`'s cache-hit path -- is available for real
api/tests/testthat/job-endpoint-services-fixtures.R-29-#' (a pure list-assembly function, safe to source unstubbed). Individual tests still
api/tests/testthat/job-endpoint-services-fixtures.R-30-#' stub the DB/cache-touching siblings from that same file
api/tests/testthat/job-endpoint-services-fixtures.R:31:#' (`clustering_resolve_category_universe`, `analysis_string_cache_fingerprint`,
api/tests/testthat/job-endpoint-services-fixtures.R:32:#' `clustering_gene_list_sha256`, `clustering_cached_source_data_version`) as needed;
api/tests/testthat/job-endpoint-services-fixtures.R-33-#' this sourcing only supplies defaults those stubs override.
api/tests/testthat/job-endpoint-services-fixtures.R-34-job_endpoint_source_service <- function(filename) {
api/tests/testthat/job-endpoint-services-fixtures.R-35-  env <- new.env(parent = globalenv())
api/tests/testthat/job-endpoint-services-fixtures.R-36-  env$async_job_submit_admission_guard <- function(req, res) list(admitted = TRUE)
api/tests/testthat/job-endpoint-services-fixtures.R:37:  sys.source(file.path(get_api_dir(), "functions", "clustering-gene-universe.R"), envir = env)
api/tests/testthat/job-endpoint-services-fixtures.R-38-  sys.source(file.path(get_api_dir(), "services", filename), envir = env)
api/tests/testthat/job-endpoint-services-fixtures.R-39-  env
api/tests/testthat/job-endpoint-services-fixtures.R-40-}
api/tests/testthat/job-endpoint-services-fixtures.R-41-
api/tests/testthat/job-endpoint-services-fixtures.R-42-#' Register `tbl.fake_pool` in `env` and build a fake pool over `tables`.
api/tests/testthat/job-endpoint-services-fixtures.R-43-job_endpoint_fake_pool <- function(env, tables) {
api/tests/testthat/job-endpoint-services-fixtures.R-44-  env$tbl.fake_pool <- function(src, from, ...) src$tables[[from]]
api/tests/testthat/job-endpoint-services-fixtures.R-45-  structure(list(tables = tables), class = "fake_pool")
--
api/tests/testthat/test-unit-clustering-empty-tibble.R:1:# tests/testthat/test-unit-clustering-empty-tibble.R
api/tests/testthat/test-unit-clustering-empty-tibble.R:2:# Unit tests for empty tibble handling in clustering functions
api/tests/testthat/test-unit-clustering-empty-tibble.R-3-#
api/tests/testthat/test-unit-clustering-empty-tibble.R-4-# These tests verify that defensive guards against empty tibbles work correctly
api/tests/testthat/test-unit-clustering-empty-tibble.R-5-# and prevent "subscript out of bounds" errors when rowwise operations are
api/tests/testthat/test-unit-clustering-empty-tibble.R-6-# performed on empty tibbles with list-columns.
api/tests/testthat/test-unit-clustering-empty-tibble.R-7-#
api/tests/testthat/test-unit-clustering-empty-tibble.R-8-# Background:
api/tests/testthat/test-unit-clustering-empty-tibble.R:9:# When gene sets produce zero STRING interactions, the clustering pipeline
api/tests/testthat/test-unit-clustering-empty-tibble.R-10-# creates empty tibbles. Without guards, rowwise() operations on these empty
api/tests/testthat/test-unit-clustering-empty-tibble.R-11-# tibbles crash when accessing list-column elements.
api/tests/testthat/test-unit-clustering-empty-tibble.R-12-
api/tests/testthat/test-unit-clustering-empty-tibble.R-13-# =============================================================================
api/tests/testthat/test-unit-clustering-empty-tibble.R-14-# Setup
api/tests/testthat/test-unit-clustering-empty-tibble.R-15-# =============================================================================
api/tests/testthat/test-unit-clustering-empty-tibble.R-16-
api/tests/testthat/test-unit-clustering-empty-tibble.R-17-library(testthat)
--
api/tests/testthat/test-unit-clustering-empty-tibble.R-39-  expect_equal(nrow(empty_result), 0)
api/tests/testthat/test-unit-clustering-empty-tibble.R-40-  expect_true(all(c("cluster", "cluster_size", "identifiers", "hash_filter") %in% names(empty_result)))
api/tests/testthat/test-unit-clustering-empty-tibble.R-41-  expect_type(empty_result$cluster, "integer")
api/tests/testthat/test-unit-clustering-empty-tibble.R-42-  expect_type(empty_result$cluster_size, "integer")
api/tests/testthat/test-unit-clustering-empty-tibble.R-43-  expect_type(empty_result$identifiers, "list")
api/tests/testthat/test-unit-clustering-empty-tibble.R-44-  expect_type(empty_result$hash_filter, "character")
api/tests/testthat/test-unit-clustering-empty-tibble.R-45-})
api/tests/testthat/test-unit-clustering-empty-tibble.R-46-
api/tests/testthat/test-unit-clustering-empty-tibble.R:47:test_that("empty functional_clustering response has correct structure", {
api/tests/testthat/test-unit-clustering-empty-tibble.R:48:  # Simulate the empty response returned by functional_clustering endpoint
api/tests/testthat/test-unit-clustering-empty-tibble.R-49-  # when gen_string_clust_obj returns empty tibble
api/tests/testthat/test-unit-clustering-empty-tibble.R-50-  empty_response <- list(
api/tests/testthat/test-unit-clustering-empty-tibble.R-51-    categories = tibble(value = character(), text = character(), link = character()),
api/tests/testthat/test-unit-clustering-empty-tibble.R-52-    clusters = tibble(
api/tests/testthat/test-unit-clustering-empty-tibble.R-53-      cluster = integer(),
api/tests/testthat/test-unit-clustering-empty-tibble.R-54-      cluster_size = integer(),
api/tests/testthat/test-unit-clustering-empty-tibble.R-55-      identifiers = list(),
api/tests/testthat/test-unit-clustering-empty-tibble.R-56-      hash_filter = character()
--
api/tests/testthat/test-unit-clustering-empty-tibble.R-80-  expect_equal(empty_response$meta$cluster_count, 0L)
api/tests/testthat/test-unit-clustering-empty-tibble.R-81-})
api/tests/testthat/test-unit-clustering-empty-tibble.R-82-
api/tests/testthat/test-unit-clustering-empty-tibble.R-83-# =============================================================================
api/tests/testthat/test-unit-clustering-empty-tibble.R-84-# Rowwise Guard Pattern Tests
api/tests/testthat/test-unit-clustering-empty-tibble.R-85-# =============================================================================
api/tests/testthat/test-unit-clustering-empty-tibble.R-86-
api/tests/testthat/test-unit-clustering-empty-tibble.R-87-test_that("rowwise guard preserves column structure on empty tibble", {
api/tests/testthat/test-unit-clustering-empty-tibble.R:88:  # Create empty tibble with list-column (similar to clustering pipeline)
api/tests/testthat/test-unit-clustering-empty-tibble.R-89-  empty_tibble <- tibble(
api/tests/testthat/test-unit-clustering-empty-tibble.R-90-    cluster = integer(),
api/tests/testthat/test-unit-clustering-empty-tibble.R-91-    identifiers = list(),
api/tests/testthat/test-unit-clustering-empty-tibble.R-92-    hash_filter = character()
api/tests/testthat/test-unit-clustering-empty-tibble.R-93-  )
api/tests/testthat/test-unit-clustering-empty-tibble.R-94-
api/tests/testthat/test-unit-clustering-empty-tibble.R-95-  # Apply the guarded rowwise pattern
api/tests/testthat/test-unit-clustering-empty-tibble.R-96-  result <- empty_tibble %>%
--
api/tests/testthat/test-unit-clustering-empty-tibble.R-289-  # These are the columns that pagination and enrichment steps expect
api/tests/testthat/test-unit-clustering-empty-tibble.R-290-  expected_cols <- c("cluster", "cluster_size", "identifiers", "hash_filter")
api/tests/testthat/test-unit-clustering-empty-tibble.R-291-
api/tests/testthat/test-unit-clustering-empty-tibble.R-292-  expect_true(all(expected_cols %in% names(empty_result)))
api/tests/testthat/test-unit-clustering-empty-tibble.R-293-  expect_equal(length(names(empty_result)), length(expected_cols))
api/tests/testthat/test-unit-clustering-empty-tibble.R-294-})
api/tests/testthat/test-unit-clustering-empty-tibble.R-295-
api/tests/testthat/test-unit-clustering-empty-tibble.R-296-test_that("empty functional clusters can be safely unnested", {
api/tests/testthat/test-unit-clustering-empty-tibble.R:297:  # Verify that empty clustering results can pass through
api/tests/testthat/test-unit-clustering-empty-tibble.R-298-  # the category generation pipeline without error
api/tests/testthat/test-unit-clustering-empty-tibble.R-299-  empty_clusters <- tibble(
api/tests/testthat/test-unit-clustering-empty-tibble.R-300-    cluster = integer(),
api/tests/testthat/test-unit-clustering-empty-tibble.R-301-    cluster_size = integer(),
api/tests/testthat/test-unit-clustering-empty-tibble.R-302-    identifiers = list(),
api/tests/testthat/test-unit-clustering-empty-tibble.R-303-    hash_filter = character()
api/tests/testthat/test-unit-clustering-empty-tibble.R-304-  )
api/tests/testthat/test-unit-clustering-empty-tibble.R-305-
--
api/tests/testthat/test-unit-async-job-worker.R-3-library(jsonlite)
api/tests/testthat/test-unit-async-job-worker.R-4-library(tibble)
api/tests/testthat/test-unit-async-job-worker.R-5-
api/tests/testthat/test-unit-async-job-worker.R-6-async_job_worker_runtime_paths <- function() {
api/tests/testthat/test-unit-async-job-worker.R-7-  api_dir <- get_api_dir()
api/tests/testthat/test-unit-async-job-worker.R-8-  c(
api/tests/testthat/test-unit-async-job-worker.R-9-    file.path(api_dir, "functions", "async-job-progress.R"),
api/tests/testthat/test-unit-async-job-worker.R-10-    # .async_job_phenotype_matrix() calls phenotype_mca_prep_matrix() (#508 MCA hygiene);
api/tests/testthat/test-unit-async-job-worker.R:11:    # load it here so the durable phenotype-clustering handler test resolves it the way
api/tests/testthat/test-unit-async-job-worker.R-12-    # load_modules.R does in production (prep is sourced before async-job-handlers.R).
api/tests/testthat/test-unit-async-job-worker.R-13-    file.path(api_dir, "functions", "analysis-phenotype-mca-prep.R"),
api/tests/testthat/test-unit-async-job-worker.R-14-    # #346 Wave 4: async_job_handler_registry binds provider/maintenance handler
api/tests/testthat/test-unit-async-job-worker.R-15-    # functions by bare symbol inside an eagerly-evaluated list(), so both
api/tests/testthat/test-unit-async-job-worker.R-16-    # extracted modules must be sourced before async-job-handlers.R here too.
api/tests/testthat/test-unit-async-job-worker.R-17-    file.path(api_dir, "functions", "async-job-provider-handlers.R"),
api/tests/testthat/test-unit-async-job-worker.R-18-    file.path(api_dir, "functions", "async-job-maintenance-handlers.R"),
api/tests/testthat/test-unit-async-job-worker.R:19:    # .async_job_run_clustering assembles its result meta via clustering_result_meta()
api/tests/testthat/test-unit-async-job-worker.R-20-    # (#574); source it before async-job-handlers.R as load_modules.R does in production.
api/tests/testthat/test-unit-async-job-worker.R:21:    file.path(api_dir, "functions", "clustering-gene-universe.R"),
api/tests/testthat/test-unit-async-job-worker.R-22-    file.path(api_dir, "functions", "async-job-handlers.R"),
api/tests/testthat/test-unit-async-job-worker.R-23-    file.path(api_dir, "functions", "async-job-worker.R"),
api/tests/testthat/test-unit-async-job-worker.R-24-    file.path(api_dir, "functions", "job-progress.R")
api/tests/testthat/test-unit-async-job-worker.R-25-  )
api/tests/testthat/test-unit-async-job-worker.R-26-}
api/tests/testthat/test-unit-async-job-worker.R-27-
api/tests/testthat/test-unit-async-job-worker.R-28-load_async_job_worker_runtime <- function() {
api/tests/testthat/test-unit-async-job-worker.R-29-  runtime_env <- new.env(parent = globalenv())
--
api/tests/testthat/test-unit-async-job-worker.R-528-    },
api/tests/testthat/test-unit-async-job-worker.R-529-    sleep_fn = function(seconds) invisible(seconds),
api/tests/testthat/test-unit-async-job-worker.R-530-    now_fn = function() as.POSIXct("2026-04-23 12:00:00", tz = "UTC")
api/tests/testthat/test-unit-async-job-worker.R-531-  )
api/tests/testthat/test-unit-async-job-worker.R-532-
api/tests/testthat/test-unit-async-job-worker.R-533-  expect_equal(call_order, c("recover", "claim"))
api/tests/testthat/test-unit-async-job-worker.R-534-})
api/tests/testthat/test-unit-async-job-worker.R-535-
api/tests/testthat/test-unit-async-job-worker.R:536:test_that("clustering durable handler preserves executor result shape and chains LLM generation", {
api/tests/testthat/test-unit-async-job-worker.R-537-  skip_if_not_installed("dplyr")
api/tests/testthat/test-unit-async-job-worker.R-538-  skip_if_not_installed("tidyr")
api/tests/testthat/test-unit-async-job-worker.R-539-  skip_if_not_installed("stringr")
api/tests/testthat/test-unit-async-job-worker.R-540-
api/tests/testthat/test-unit-async-job-worker.R-541-  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-542-  progress_calls <- list()
api/tests/testthat/test-unit-async-job-worker.R-543-
api/tests/testthat/test-unit-async-job-worker.R-544-  clusters <- tibble::tibble(
--
api/tests/testthat/test-unit-async-job-worker.R-572-        message = message,
api/tests/testthat/test-unit-async-job-worker.R-573-        current = current,
api/tests/testthat/test-unit-async-job-worker.R-574-        total = total
api/tests/testthat/test-unit-async-job-worker.R-575-      )
api/tests/testthat/test-unit-async-job-worker.R-576-      invisible(NULL)
api/tests/testthat/test-unit-async-job-worker.R-577-    }
api/tests/testthat/test-unit-async-job-worker.R-578-  }
api/tests/testthat/test-unit-async-job-worker.R-579-
api/tests/testthat/test-unit-async-job-worker.R:580:  handler <- runtime$async_job_get_handler("clustering")
api/tests/testthat/test-unit-async-job-worker.R-581-  result <- handler$run(
api/tests/testthat/test-unit-async-job-worker.R:582:    job = tibble::tibble(job_id = "job-clustering"),
api/tests/testthat/test-unit-async-job-worker.R-583-    payload = list(
api/tests/testthat/test-unit-async-job-worker.R-584-      genes = c("GENE1", "GENE2"),
api/tests/testthat/test-unit-async-job-worker.R-585-      algorithm = "walktrap",
api/tests/testthat/test-unit-async-job-worker.R-586-      string_id_table = tibble::tibble(symbol = c("GENE1", "GENE2"), STRING_id = c("s1", "s2")),
api/tests/testthat/test-unit-async-job-worker.R-587-      category_links = tibble::tibble(
api/tests/testthat/test-unit-async-job-worker.R-588-        value = c("HPO", "Process"),
api/tests/testthat/test-unit-async-job-worker.R-589-        link = c("https://hpo.test/", "https://process.test/")
api/tests/testthat/test-unit-async-job-worker.R-590-      )
api/tests/testthat/test-unit-async-job-worker.R-591-    ),
api/tests/testthat/test-unit-async-job-worker.R-592-    state = runtime$async_job_worker_state(),
api/tests/testthat/test-unit-async-job-worker.R:593:    worker_config = list(worker_id = "worker-clustering")
api/tests/testthat/test-unit-async-job-worker.R-594-  )
api/tests/testthat/test-unit-async-job-worker.R-595-
api/tests/testthat/test-unit-async-job-worker.R-596-  expect_equal(result$clusters, clusters)
api/tests/testthat/test-unit-async-job-worker.R-597-  expect_equal(result$categories$value, c("HPO", "Process"))
api/tests/testthat/test-unit-async-job-worker.R-598-  expect_equal(result$categories$link, c("https://hpo.test/", "https://process.test/"))
api/tests/testthat/test-unit-async-job-worker.R-599-  expect_equal(result$meta$algorithm, "walktrap")
api/tests/testthat/test-unit-async-job-worker.R-600-  expect_equal(result$meta$gene_count, 2L)
api/tests/testthat/test-unit-async-job-worker.R-601-  expect_equal(result$meta$cluster_count, 1L)
--
api/tests/testthat/test-unit-async-job-worker.R-603-  expect_equal(vapply(progress_calls, `[[`, character(1), "step"), c("cluster", "complete"))
api/tests/testthat/test-unit-async-job-worker.R-604-  expect_equal(progress_calls[[1]]$current, 0)
api/tests/testthat/test-unit-async-job-worker.R-605-  expect_equal(progress_calls[[1]]$total, 1)
api/tests/testthat/test-unit-async-job-worker.R-606-  expect_equal(progress_calls[[2]]$current, 1)
api/tests/testthat/test-unit-async-job-worker.R-607-  expect_equal(progress_calls[[2]]$total, 1)
api/tests/testthat/test-unit-async-job-worker.R-608-
api/tests/testthat/test-unit-async-job-worker.R-609-  handler$after_success(
api/tests/testthat/test-unit-async-job-worker.R-610-    result = result,
api/tests/testthat/test-unit-async-job-worker.R:611:    job = tibble::tibble(job_id = "job-clustering"),
api/tests/testthat/test-unit-async-job-worker.R-612-    payload = list(),
api/tests/testthat/test-unit-async-job-worker.R-613-    state = runtime$async_job_worker_state(),
api/tests/testthat/test-unit-async-job-worker.R:614:    worker_config = list(worker_id = "worker-clustering")
api/tests/testthat/test-unit-async-job-worker.R-615-  )
api/tests/testthat/test-unit-async-job-worker.R-616-
api/tests/testthat/test-unit-async-job-worker.R-617-  expect_equal(llm_call$cluster_type, "functional")
api/tests/testthat/test-unit-async-job-worker.R:618:  expect_equal(llm_call$parent_job_id, "job-clustering")
api/tests/testthat/test-unit-async-job-worker.R-619-  expect_equal(llm_call$clusters, clusters)
api/tests/testthat/test-unit-async-job-worker.R-620-})
api/tests/testthat/test-unit-async-job-worker.R-621-
api/tests/testthat/test-unit-async-job-worker.R:622:test_that("phenotype clustering durable handler restores identifiers and chains LLM generation", {
api/tests/testthat/test-unit-async-job-worker.R-623-  skip_if_not_installed("dplyr")
api/tests/testthat/test-unit-async-job-worker.R-624-  skip_if_not_installed("tidyr")
api/tests/testthat/test-unit-async-job-worker.R-625-
api/tests/testthat/test-unit-async-job-worker.R-626-  runtime <- load_async_job_worker_runtime()
api/tests/testthat/test-unit-async-job-worker.R-627-  progress_calls <- list()
api/tests/testthat/test-unit-async-job-worker.R-628-
api/tests/testthat/test-unit-async-job-worker.R-629-  runtime$gen_mca_clust_obj <- function(data_frame) {
api/tests/testthat/test-unit-async-job-worker.R-630-    expect_equal(rownames(data_frame), c("11", "22"))
--
api/tests/testthat/test-unit-async-job-worker.R-654-        message = message,
api/tests/testthat/test-unit-async-job-worker.R-655-        current = current,
api/tests/testthat/test-unit-async-job-worker.R-656-        total = total
api/tests/testthat/test-unit-async-job-worker.R-657-      )
api/tests/testthat/test-unit-async-job-worker.R-658-      invisible(NULL)
api/tests/testthat/test-unit-async-job-worker.R-659-    }
api/tests/testthat/test-unit-async-job-worker.R-660-  }
api/tests/testthat/test-unit-async-job-worker.R-661-
api/tests/testthat/test-unit-async-job-worker.R:662:  handler <- runtime$async_job_get_handler("phenotype_clustering")
api/tests/testthat/test-unit-async-job-worker.R-663-  result <- handler$run(
api/tests/testthat/test-unit-async-job-worker.R-664-    job = tibble::tibble(job_id = "job-phenotype"),
api/tests/testthat/test-unit-async-job-worker.R-665-    payload = list(
api/tests/testthat/test-unit-async-job-worker.R-666-      ndd_entity_view_tbl = tibble::tibble(
api/tests/testthat/test-unit-async-job-worker.R-667-        entity_id = c(11L, 22L),
api/tests/testthat/test-unit-async-job-worker.R-668-        hgnc_id = c("HGNC:11", "HGNC:22"),
api/tests/testthat/test-unit-async-job-worker.R-669-        symbol = c("GENE11", "GENE22"),
api/tests/testthat/test-unit-async-job-worker.R-670-        hpo_mode_of_inheritance_term_name = c("Autosomal dominant", "Autosomal dominant"),
--
api/tests/testthat/test-unit-clustering-submit-throttle.R:1:# Tests for the per-caller clustering submit throttle (#535 S6).
api/tests/testthat/test-unit-clustering-submit-throttle.R-2-# Pure logic (injectable clock + store); no DB.
api/tests/testthat/test-unit-clustering-submit-throttle.R-3-
api/tests/testthat/test-unit-clustering-submit-throttle.R-4-staged_api_dir <- Sys.getenv("SYSNDD_API_DIR", "")
api/tests/testthat/test-unit-clustering-submit-throttle.R-5-if (nzchar(staged_api_dir)) {
api/tests/testthat/test-unit-clustering-submit-throttle.R-6-  api_dir <- staged_api_dir
api/tests/testthat/test-unit-clustering-submit-throttle.R-7-} else if (exists("get_api_dir")) {
api/tests/testthat/test-unit-clustering-submit-throttle.R-8-  api_dir <- get_api_dir()
api/tests/testthat/test-unit-clustering-submit-throttle.R-9-} else {
api/tests/testthat/test-unit-clustering-submit-throttle.R-10-  api_dir <- normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
api/tests/testthat/test-unit-clustering-submit-throttle.R:11:  if (!file.exists(file.path(api_dir, "functions", "clustering-submit-throttle.R"))) {
api/tests/testthat/test-unit-clustering-submit-throttle.R-12-    api_dir <- normalizePath(file.path(getwd()), mustWork = FALSE)
api/tests/testthat/test-unit-clustering-submit-throttle.R-13-  }
api/tests/testthat/test-unit-clustering-submit-throttle.R-14-}
api/tests/testthat/test-unit-clustering-submit-throttle.R-15-source(file.path(api_dir, "functions", "per-caller-throttle.R"), local = FALSE)
api/tests/testthat/test-unit-clustering-submit-throttle.R:16:source(file.path(api_dir, "functions", "clustering-submit-throttle.R"), local = FALSE)
api/tests/testthat/test-unit-clustering-submit-throttle.R-17-
api/tests/testthat/test-unit-clustering-submit-throttle.R-18-test_that("allows up to max_n submissions in the window, then throttles", {
api/tests/testthat/test-unit-clustering-submit-throttle.R-19-  st <- new.env(parent = emptyenv())
api/tests/testthat/test-unit-clustering-submit-throttle.R-20-  for (i in 1:3) {
api/tests/testthat/test-unit-clustering-submit-throttle.R-21-    r <- async_job_submit_rate_limit("1.2.3.4", now = 1000, max_n = 3L, window_s = 60L, store = st)
api/tests/testthat/test-unit-clustering-submit-throttle.R-22-    expect_true(r$allowed)
api/tests/testthat/test-unit-clustering-submit-throttle.R-23-    expect_equal(r$count, i)
api/tests/testthat/test-unit-clustering-submit-throttle.R-24-  }
--
api/tests/testthat/test-unit-async-job-payload-scrub.R-1-# tests/testthat/test-unit-async-job-payload-scrub.R
api/tests/testthat/test-unit-async-job-payload-scrub.R-2-# #535 P1-1 + S2b: the historical-payload scrub is TERMINAL + non-retryable
api/tests/testthat/test-unit-async-job-payload-scrub.R-3-# scoped, job-type AGNOSTIC, DUAL-PATH ($.db_config.password AND
api/tests/testthat/test-unit-async-job-payload-scrub.R-4-# $.db_config.db_password via JSON_REPLACE), idempotent, and recomputes
api/tests/testthat/test-unit-async-job-payload-scrub.R:5:# request_hash so it no longer encodes the password. The statement-shape test is
api/tests/testthat/test-unit-async-job-payload-scrub.R-6-# host-runnable; the redaction/idempotency tests need the test DB.
api/tests/testthat/test-unit-async-job-payload-scrub.R-7-
api/tests/testthat/test-unit-async-job-payload-scrub.R-8-library(testthat)
api/tests/testthat/test-unit-async-job-payload-scrub.R-9-
api/tests/testthat/test-unit-async-job-payload-scrub.R-10-source_api_file("functions/async-job-payload-scrub.R", local = FALSE)
api/tests/testthat/test-unit-async-job-payload-scrub.R-11-
api/tests/testthat/test-unit-async-job-payload-scrub.R-12-test_that("scrub statement is family-agnostic, terminal-scoped, both paths, idempotent, recomputes hash", {
api/tests/testthat/test-unit-async-job-payload-scrub.R-13-  s <- async_job_payload_scrub_statement()
api/tests/testthat/test-unit-async-job-payload-scrub.R-14-  # Both credential JSON paths: canonical families store $.db_config.password;
api/tests/testthat/test-unit-async-job-payload-scrub.R-15-  # pubtator/llm store $.db_config.db_password (#535 S2b).
api/tests/testthat/test-unit-async-job-payload-scrub.R-16-  expect_true(grepl("$.db_config.password", s, fixed = TRUE))
api/tests/testthat/test-unit-async-job-payload-scrub.R-17-  expect_true(grepl("$.db_config.db_password", s, fixed = TRUE))
api/tests/testthat/test-unit-async-job-payload-scrub.R-18-  # Job-type agnostic: no longer backup-only (all families were migrated, so it
api/tests/testthat/test-unit-async-job-payload-scrub.R-19-  # is now safe to scrub every terminal row).
api/tests/testthat/test-unit-async-job-payload-scrub.R-20-  expect_false(grepl("job_type IN ('backup_create'", s, fixed = TRUE))
api/tests/testthat/test-unit-async-job-payload-scrub.R-21-  expect_true(grepl("status IN ('completed','failed','cancelled')", s, fixed = TRUE))
api/tests/testthat/test-unit-async-job-payload-scrub.R:22:  expect_true(grepl("active_request_hash IS NULL", s, fixed = TRUE))  # avoid unique-index collision (M1)
api/tests/testthat/test-unit-async-job-payload-scrub.R:23:  expect_true(grepl("SHA2(CONCAT(job_type", s, fixed = TRUE))   # request_hash recompute (H6)
api/tests/testthat/test-unit-async-job-payload-scrub.R-24-  # JSON_REPLACE (not JSON_SET): never CREATE an absent key, only redact existing.
api/tests/testthat/test-unit-async-job-payload-scrub.R-25-  expect_true(grepl("JSON_REPLACE", s, fixed = TRUE))
api/tests/testthat/test-unit-async-job-payload-scrub.R-26-  expect_false(grepl("JSON_SET", s, fixed = TRUE))
api/tests/testthat/test-unit-async-job-payload-scrub.R-27-  expect_true(grepl("<> '***REDACTED***'", s, fixed = TRUE))    # idempotency guard (M3)
api/tests/testthat/test-unit-async-job-payload-scrub.R-28-})
api/tests/testthat/test-unit-async-job-payload-scrub.R-29-
api/tests/testthat/test-unit-async-job-payload-scrub.R-30-test_that("scrub redacts a seeded terminal backup row once and is idempotent (DB)", {
api/tests/testthat/test-unit-async-job-payload-scrub.R-31-  skip_if_no_test_db()
api/tests/testthat/test-unit-async-job-payload-scrub.R-32-  with_test_db_transaction({
api/tests/testthat/test-unit-async-job-payload-scrub.R-33-    con <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-payload-scrub.R-34-    db_execute_statement(
api/tests/testthat/test-unit-async-job-payload-scrub.R-35-      paste0(
api/tests/testthat/test-unit-async-job-payload-scrub.R:36:        "INSERT INTO async_jobs (job_id, job_type, status, request_hash, request_payload_json) ",
api/tests/testthat/test-unit-async-job-payload-scrub.R-37-        "VALUES ('scrub-test-1','backup_create','completed', REPEAT('a',64), ",
api/tests/testthat/test-unit-async-job-payload-scrub.R-38-        "JSON_OBJECT('db_config', JSON_OBJECT('password','leaky','host','h','user','u','port',3306,'dbname','d'), ",
api/tests/testthat/test-unit-async-job-payload-scrub.R-39-        "'backup_dir','/backup'))"
api/tests/testthat/test-unit-async-job-payload-scrub.R-40-      ),
api/tests/testthat/test-unit-async-job-payload-scrub.R-41-      list(), conn = con
api/tests/testthat/test-unit-async-job-payload-scrub.R-42-    )
api/tests/testthat/test-unit-async-job-payload-scrub.R-43-
api/tests/testthat/test-unit-async-job-payload-scrub.R-44-    n1 <- async_job_scrub_payload_credentials(conn = con)
api/tests/testthat/test-unit-async-job-payload-scrub.R-45-    n2 <- async_job_scrub_payload_credentials(conn = con)
api/tests/testthat/test-unit-async-job-payload-scrub.R-46-    expect_equal(n1, 1L)   # redacts the seeded row
api/tests/testthat/test-unit-async-job-payload-scrub.R-47-    expect_equal(n2, 0L)   # idempotent: nothing left to do
api/tests/testthat/test-unit-async-job-payload-scrub.R-48-
api/tests/testthat/test-unit-async-job-payload-scrub.R-49-    row <- DBI::dbGetQuery(
api/tests/testthat/test-unit-async-job-payload-scrub.R-50-      con,
api/tests/testthat/test-unit-async-job-payload-scrub.R-51-      paste0("SELECT JSON_UNQUOTE(JSON_EXTRACT(request_payload_json,'$.db_config.password')) AS pw, ",
api/tests/testthat/test-unit-async-job-payload-scrub.R:52:             "request_hash FROM async_jobs WHERE job_id='scrub-test-1'")
api/tests/testthat/test-unit-async-job-payload-scrub.R-53-    )
api/tests/testthat/test-unit-async-job-payload-scrub.R-54-    expect_equal(row$pw, "***REDACTED***")
api/tests/testthat/test-unit-async-job-payload-scrub.R:55:    expect_equal(nchar(row$request_hash), 64L)          # still a valid sha256
api/tests/testthat/test-unit-async-job-payload-scrub.R:56:    expect_false(identical(row$request_hash, paste(rep("a", 64), collapse = "")))  # recomputed
api/tests/testthat/test-unit-async-job-payload-scrub.R-57-  })
api/tests/testthat/test-unit-async-job-payload-scrub.R-58-})
api/tests/testthat/test-unit-async-job-payload-scrub.R-59-
api/tests/testthat/test-unit-async-job-payload-scrub.R-60-test_that("scrub leaves a QUEUED backup row (non-terminal) untouched (DB)", {
api/tests/testthat/test-unit-async-job-payload-scrub.R-61-  skip_if_no_test_db()
api/tests/testthat/test-unit-async-job-payload-scrub.R-62-  with_test_db_transaction({
api/tests/testthat/test-unit-async-job-payload-scrub.R-63-    con <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-payload-scrub.R-64-    db_execute_statement(
api/tests/testthat/test-unit-async-job-payload-scrub.R-65-      paste0(
api/tests/testthat/test-unit-async-job-payload-scrub.R:66:        "INSERT INTO async_jobs (job_id, job_type, status, request_hash, request_payload_json) ",
api/tests/testthat/test-unit-async-job-payload-scrub.R-67-        "VALUES ('scrub-queued-1','backup_create','queued', REPEAT('b',64), ",
api/tests/testthat/test-unit-async-job-payload-scrub.R-68-        "JSON_OBJECT('db_config', JSON_OBJECT('password','leaky'), 'backup_dir','/backup'))"
api/tests/testthat/test-unit-async-job-payload-scrub.R-69-      ),
api/tests/testthat/test-unit-async-job-payload-scrub.R-70-      list(), conn = con
api/tests/testthat/test-unit-async-job-payload-scrub.R-71-    )
api/tests/testthat/test-unit-async-job-payload-scrub.R-72-    n <- async_job_scrub_payload_credentials(conn = con)
api/tests/testthat/test-unit-async-job-payload-scrub.R-73-    row <- DBI::dbGetQuery(
api/tests/testthat/test-unit-async-job-payload-scrub.R-74-      con,
api/tests/testthat/test-unit-async-job-payload-scrub.R-75-      "SELECT JSON_UNQUOTE(JSON_EXTRACT(request_payload_json,'$.db_config.password')) AS pw FROM async_jobs WHERE job_id='scrub-queued-1'"
api/tests/testthat/test-unit-async-job-payload-scrub.R-76-    )
api/tests/testthat/test-unit-async-job-payload-scrub.R-77-    expect_equal(row$pw, "leaky")  # queued row must NOT be scrubbed (its handler may still run)
api/tests/testthat/test-unit-async-job-payload-scrub.R-78-    expect_equal(n, 0L)
api/tests/testthat/test-unit-async-job-payload-scrub.R-79-  })
api/tests/testthat/test-unit-async-job-payload-scrub.R-80-})
api/tests/testthat/test-unit-async-job-payload-scrub.R-81-
api/tests/testthat/test-unit-async-job-payload-scrub.R:82:test_that("scrub leaves a RETRYABLE-failed backup row (active_request_hash non-NULL) untouched (DB)", {
api/tests/testthat/test-unit-async-job-payload-scrub.R-83-  skip_if_no_test_db()
api/tests/testthat/test-unit-async-job-payload-scrub.R-84-  with_test_db_transaction({
api/tests/testthat/test-unit-async-job-payload-scrub.R-85-    con <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-payload-scrub.R:86:    # attempt_count < max_attempts AND next_attempt_at set -> active_request_hash
api/tests/testthat/test-unit-async-job-payload-scrub.R:87:    # is the generated request_hash (non-NULL). Scrubbing two such rows that
api/tests/testthat/test-unit-async-job-payload-scrub.R:88:    # differ only by password could collide on UNIQUE(job_type, active_request_hash).
api/tests/testthat/test-unit-async-job-payload-scrub.R-89-    db_execute_statement(
api/tests/testthat/test-unit-async-job-payload-scrub.R-90-      paste0(
api/tests/testthat/test-unit-async-job-payload-scrub.R:91:        "INSERT INTO async_jobs (job_id, job_type, status, request_hash, ",
api/tests/testthat/test-unit-async-job-payload-scrub.R-92-        "attempt_count, max_attempts, next_attempt_at, request_payload_json) ",
api/tests/testthat/test-unit-async-job-payload-scrub.R-93-        "VALUES ('scrub-retry-1','backup_create','failed', REPEAT('c',64), ",
api/tests/testthat/test-unit-async-job-payload-scrub.R-94-        "0, 3, NOW(6), JSON_OBJECT('db_config', JSON_OBJECT('password','leaky')))"
api/tests/testthat/test-unit-async-job-payload-scrub.R-95-      ),
api/tests/testthat/test-unit-async-job-payload-scrub.R-96-      list(), conn = con
api/tests/testthat/test-unit-async-job-payload-scrub.R-97-    )
api/tests/testthat/test-unit-async-job-payload-scrub.R-98-    n <- async_job_scrub_payload_credentials(conn = con)
api/tests/testthat/test-unit-async-job-payload-scrub.R-99-    row <- DBI::dbGetQuery(
api/tests/testthat/test-unit-async-job-payload-scrub.R-100-      con,
api/tests/testthat/test-unit-async-job-payload-scrub.R:101:      "SELECT JSON_UNQUOTE(JSON_EXTRACT(request_payload_json,'$.db_config.password')) AS pw, active_request_hash FROM async_jobs WHERE job_id='scrub-retry-1'"
api/tests/testthat/test-unit-async-job-payload-scrub.R-102-    )
api/tests/testthat/test-unit-async-job-payload-scrub.R:103:    expect_false(is.na(row$active_request_hash))  # retryable -> active hash present
api/tests/testthat/test-unit-async-job-payload-scrub.R-104-    expect_equal(row$pw, "leaky")                 # retryable row must NOT be scrubbed
api/tests/testthat/test-unit-async-job-payload-scrub.R-105-    expect_equal(n, 0L)
api/tests/testthat/test-unit-async-job-payload-scrub.R-106-  })
api/tests/testthat/test-unit-async-job-payload-scrub.R-107-})
api/tests/testthat/test-unit-async-job-payload-scrub.R-108-
api/tests/testthat/test-unit-async-job-payload-scrub.R-109-test_that("scrub redacts a NON-backup terminal row on the db_password path and recomputes hash (DB)", {
api/tests/testthat/test-unit-async-job-payload-scrub.R-110-  # #535 S2b MEDIUM-2: pubtator/llm families persisted the credential under
api/tests/testthat/test-unit-async-job-payload-scrub.R-111-  # $.db_config.db_password, and are now scrubbable (job-type agnostic).
api/tests/testthat/test-unit-async-job-payload-scrub.R-112-  skip_if_no_test_db()
api/tests/testthat/test-unit-async-job-payload-scrub.R-113-  with_test_db_transaction({
api/tests/testthat/test-unit-async-job-payload-scrub.R-114-    con <- getOption(".test_db_con")
api/tests/testthat/test-unit-async-job-payload-scrub.R-115-    db_execute_statement(
api/tests/testthat/test-unit-async-job-payload-scrub.R-116-      paste0(
api/tests/testthat/test-unit-async-job-payload-scrub.R:117:        "INSERT INTO async_jobs (job_id, job_type, status, request_hash, request_payload_json) ",
api/tests/testthat/test-unit-async-job-payload-scrub.R-118-        "VALUES ('scrub-llm-1','llm_generation','completed', REPEAT('d',64), ",
api/tests/testthat/test-unit-async-job-payload-scrub.R-119-        "JSON_OBJECT('db_config', JSON_OBJECT('db_password','leaky','db_host','h','db_user','u',",
api/tests/testthat/test-unit-async-job-payload-scrub.R-120-        "'db_port',3306,'db_name','d'), 'cluster_type','functional'))"
api/tests/testthat/test-unit-async-job-payload-scrub.R-121-      ),
api/tests/testthat/test-unit-async-job-payload-scrub.R-122-      list(), conn = con
api/tests/testthat/test-unit-async-job-payload-scrub.R-123-    )
api/tests/testthat/test-unit-async-job-payload-scrub.R-124-
api/tests/testthat/test-unit-async-job-payload-scrub.R-125-    n1 <- async_job_scrub_payload_credentials(conn = con)
api/tests/testthat/test-unit-async-job-payload-scrub.R-126-    n2 <- async_job_scrub_payload_credentials(conn = con)
api/tests/testthat/test-unit-async-job-payload-scrub.R-127-    expect_equal(n1, 1L)   # db_password-path row is redacted
api/tests/testthat/test-unit-async-job-payload-scrub.R-128-    expect_equal(n2, 0L)   # idempotent
api/tests/testthat/test-unit-async-job-payload-scrub.R-129-
api/tests/testthat/test-unit-async-job-payload-scrub.R-130-    row <- DBI::dbGetQuery(
api/tests/testthat/test-unit-async-job-payload-scrub.R-131-      con,
api/tests/testthat/test-unit-async-job-payload-scrub.R-132-      paste0("SELECT JSON_UNQUOTE(JSON_EXTRACT(request_payload_json,'$.db_config.db_password')) AS pw, ",
api/tests/testthat/test-unit-async-job-payload-scrub.R-133-             "JSON_UNQUOTE(JSON_EXTRACT(request_payload_json,'$.cluster_type')) AS ct, ",
api/tests/testthat/test-unit-async-job-payload-scrub.R:134:             "request_hash FROM async_jobs WHERE job_id='scrub-llm-1'")
api/tests/testthat/test-unit-async-job-payload-scrub.R-135-    )
api/tests/testthat/test-unit-async-job-payload-scrub.R-136-    expect_equal(row$pw, "***REDACTED***")

exec
/bin/bash -lc "nl -ba api/tests/testthat/test-integration-clustering-category-submit.R | sed -n '120,190p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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
   158	    old_pool <- if (exists("pool", envir = .GlobalEnv)) get("pool", envir = .GlobalEnv) else NULL
   159	    assign("pool", conn, envir = .GlobalEnv)
   160	    withr::defer({
   161	      if (is.null(old_pool)) {
   162	        if (exists("pool", envir = .GlobalEnv)) rm(pool, envir = .GlobalEnv)
   163	      } else {
   164	        assign("pool", old_pool, envir = .GlobalEnv)
   165	      }
   166	    })
   167	
   168	    resolved <- clustering_resolve_category_universe(NULL, conn = conn)
   169	
   170	    # Meaningful, not tautological: compares against a DIRECT query against
   171	    # the real view, not against calling generate_ndd_hgnc_ids() a second
   172	    # time -- proves the NULL/default branch resolves the all-NDD universe
   173	    # correctly, independent of the resolver's own implementation.
   174	    direct <- DBI::dbGetQuery(
   175	      conn,
   176	      "SELECT DISTINCT hgnc_id FROM ndd_entity_view WHERE ndd_phenotype = 1"
   177	    )$hgnc_id
   178	
   179	    expect_setequal(resolved$hgnc_ids, direct)
   180	    expect_null(resolved$selector)
   181	    expect_identical(resolved$resolved_gene_count, length(direct))
   182	  })
   183	})

exec
/bin/bash -lc "rg -n -C 5 '\\bget\\(' api/tests/testthat/test-integration-clustering-category-submit.R api/tests/testthat/setup.R api/tests/testthat/helper-*.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/tests/testthat/test-integration-clustering-category-submit.R-153-    # forward `conn` to it (see clustering-gene-universe.R). Bind the global
api/tests/testthat/test-integration-clustering-category-submit.R-154-    # `pool` to this transaction's connection for the duration of the call so
api/tests/testthat/test-integration-clustering-category-submit.R-155-    # the NULL/default branch is exercised for real against the live view,
api/tests/testthat/test-integration-clustering-category-submit.R-156-    # then restore whatever `pool` held before (mirrors the
api/tests/testthat/test-integration-clustering-category-submit.R-157-    # test-unit-panels-endpoint.R / test-unit-endpoint-functions.R idiom).
api/tests/testthat/test-integration-clustering-category-submit.R:158:    old_pool <- if (exists("pool", envir = .GlobalEnv)) get("pool", envir = .GlobalEnv) else NULL
api/tests/testthat/test-integration-clustering-category-submit.R-159-    assign("pool", conn, envir = .GlobalEnv)
api/tests/testthat/test-integration-clustering-category-submit.R-160-    withr::defer({
api/tests/testthat/test-integration-clustering-category-submit.R-161-      if (is.null(old_pool)) {
api/tests/testthat/test-integration-clustering-category-submit.R-162-        if (exists("pool", envir = .GlobalEnv)) rm(pool, envir = .GlobalEnv)
api/tests/testthat/test-integration-clustering-category-submit.R-163-      } else {
--
api/tests/testthat/helper-db.R-1-# tests/testthat/helper-db.R
api/tests/testthat/helper-db.R-2-# Database connection helpers for tests
api/tests/testthat/helper-db.R-3-#
api/tests/testthat/helper-db.R-4-# These functions provide isolated test database access with proper cleanup.
api/tests/testthat/helper-db.R:5:# Uses config::get() to load sysndd_db_test configuration.
api/tests/testthat/helper-db.R-6-
api/tests/testthat/helper-db.R-7-#' Get test database connection
api/tests/testthat/helper-db.R-8-#'
api/tests/testthat/helper-db.R-9-#' Creates a DBI connection to the test database.
api/tests/testthat/helper-db.R-10-#' Caller is responsible for disconnecting.
--
api/tests/testthat/helper-db.R-354-  if (is.null(config_path)) {
api/tests/testthat/helper-db.R-355-    stop("config.yml not found and MYSQL_HOST env not set. ",
api/tests/testthat/helper-db.R-356-         "Tried paths: ", paste(possible_paths, collapse = ", "))
api/tests/testthat/helper-db.R-357-  }
api/tests/testthat/helper-db.R-358-
api/tests/testthat/helper-db.R:359:  config <- config::get("sysndd_db_test", file = config_path)
api/tests/testthat/helper-db.R-360-
api/tests/testthat/helper-db.R-361-  if (is.null(key)) {
api/tests/testthat/helper-db.R-362-    return(config)
api/tests/testthat/helper-db.R-363-  }
api/tests/testthat/helper-db.R-364-

exec
/bin/bash -lc "rg -n -C 20 'async_job_service_store_completed' api/functions/async-job-service.R api/services/job-functional-submission-service.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
exec
/bin/bash -lc "rg -n -C 10 '"'^clustering_result_meta|category_filter|provenance'"' api/functions/clustering-gene-universe.R api/services/job-functional-submission-service.R api/functions/async-job-handlers.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/services/job-functional-submission-service.R-1-# api/services/job-functional-submission-service.R
api/services/job-functional-submission-service.R-2-#
api/services/job-functional-submission-service.R-3-# Body of `POST /api/jobs/clustering/submit`, extracted from
api/services/job-functional-submission-service.R-4-# endpoints/jobs_endpoints.R (issue #346, Wave 3, Task 5). Public endpoint —
api/services/job-functional-submission-service.R-5-# no role gate. The endpoint shell delegates the entire handler body here;
api/services/job-functional-submission-service.R-6-# `svc_job_submit_functional_clustering()` mutates `res` (status + headers)
api/services/job-functional-submission-service.R-7-# exactly as the inline handler used to, and returns the JSON payload.
api/services/job-functional-submission-service.R-8-#
api/services/job-functional-submission-service.R-9-# The durable handler receives serialized input, not a database connection, so
api/services/job-functional-submission-service.R-10-# all values it needs are fetched from `pool` before `create_job()` is called.
api/services/job-functional-submission-service.R-11-#
api/services/job-functional-submission-service.R-12-# This is an ENDPOINT service: it is sourced by the shared bootstrap loader
api/services/job-functional-submission-service.R-13-# (api/bootstrap/load_modules.R) like any other services/* file. The worker
api/services/job-functional-submission-service.R-14-# executes the registered `clustering` durable handler, never this submitter.
api/services/job-functional-submission-service.R-15-
api/services/job-functional-submission-service.R-16-#' Submit a functional (STRING-db) clustering job.
api/services/job-functional-submission-service.R-17-#'
api/services/job-functional-submission-service.R-18-#' Cache-first: if the memoised `gen_string_clust_obj_mem()` already has a
api/services/job-functional-submission-service.R-19-#' result for the resolved gene list + algorithm, the result is persisted as
api/services/job-functional-submission-service.R:20:#' an already-completed durable job via `async_job_service_store_completed()`
api/services/job-functional-submission-service.R-21-#' so the response shape matches a freshly-submitted job (this keeps LLM batch
api/services/job-functional-submission-service.R-22-#' generation on the same job/result hashes as the API-served table). A cache
api/services/job-functional-submission-service.R-23-#' miss falls through the public queue-depth capacity guard
api/services/job-functional-submission-service.R-24-#' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
api/services/job-functional-submission-service.R-25-#' new durable job via `create_job()`.
api/services/job-functional-submission-service.R-26-#'
api/services/job-functional-submission-service.R-27-#' The clustering gene universe (#574) is one of: an explicit `genes` list, a
api/services/job-functional-submission-service.R-28-#' curated-category selection via `category_filter` (resolved through
api/services/job-functional-submission-service.R-29-#' `clustering_resolve_category_universe()`), or -- when neither is supplied
api/services/job-functional-submission-service.R-30-#' -- the existing default all-NDD-genes universe. `genes` and
api/services/job-functional-submission-service.R-31-#' `category_filter` are mutually exclusive (400 if both are present). Every
api/services/job-functional-submission-service.R-32-#' submit records selector + fingerprint provenance in the durable payload
api/services/job-functional-submission-service.R-33-#' and (on a cache hit) the result meta; see `clustering-gene-universe.R`.
api/services/job-functional-submission-service.R-34-#'
api/services/job-functional-submission-service.R-35-#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm`/
api/services/job-functional-submission-service.R-36-#'   `category_filter` and `req$user$user_id`).
api/services/job-functional-submission-service.R-37-#' @param res Plumber response, mutated in place (status + headers).
api/services/job-functional-submission-service.R-38-#' @return List payload for the `json` serializer.
api/services/job-functional-submission-service.R-39-#' @export
api/services/job-functional-submission-service.R-40-svc_job_submit_functional_clustering <- function(req, res) {
--
api/services/job-functional-submission-service.R-235-        list(
api/services/job-functional-submission-service.R-236-          algorithm = algorithm,
api/services/job-functional-submission-service.R-237-          gene_count = length(genes_list),
api/services/job-functional-submission-service.R-238-          cluster_count = nrow(cached_clusters),
api/services/job-functional-submission-service.R-239-          cache_hit = TRUE
api/services/job-functional-submission-service.R-240-        ),
api/services/job-functional-submission-service.R-241-        provenance,
api/services/job-functional-submission-service.R-242-        attr(cached_clusters, "weight_channel")
api/services/job-functional-submission-service.R-243-      )
api/services/job-functional-submission-service.R-244-    )
api/services/job-functional-submission-service.R-245-    cache_request_payload <- list(
api/services/job-functional-submission-service.R-246-      genes = genes_list,
api/services/job-functional-submission-service.R-247-      algorithm = algorithm,
api/services/job-functional-submission-service.R-248-      category_links = category_links,
api/services/job-functional-submission-service.R-249-      string_id_table = string_id_table,
api/services/job-functional-submission-service.R-250-      provenance = provenance
api/services/job-functional-submission-service.R-251-    )
api/services/job-functional-submission-service.R-252-    if (!is.null(selector_chr)) {
api/services/job-functional-submission-service.R-253-      cache_request_payload$category_filter <- selector_chr
api/services/job-functional-submission-service.R-254-    }
api/services/job-functional-submission-service.R:255:    completed_job <- async_job_service_store_completed(
api/services/job-functional-submission-service.R-256-      job_type = "clustering",
api/services/job-functional-submission-service.R-257-      request_payload = cache_request_payload,
api/services/job-functional-submission-service.R-258-      result = cache_result,
api/services/job-functional-submission-service.R-259-      submitted_by = req$user$user_id %||% NULL,
api/services/job-functional-submission-service.R-260-      queue_name = "analysis",
api/services/job-functional-submission-service.R-261-      priority = 50L
api/services/job-functional-submission-service.R-262-    )
api/services/job-functional-submission-service.R-263-    job_id <- completed_job$job_id[[1]]
api/services/job-functional-submission-service.R-264-
api/services/job-functional-submission-service.R-265-    res$status <- 202
api/services/job-functional-submission-service.R-266-    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
api/services/job-functional-submission-service.R-267-    res$setHeader("Retry-After", "0")
api/services/job-functional-submission-service.R-268-
api/services/job-functional-submission-service.R-269-    return(list(
api/services/job-functional-submission-service.R-270-      job_id = job_id,
api/services/job-functional-submission-service.R-271-      status = "accepted",
api/services/job-functional-submission-service.R-272-      estimated_seconds = 0,
api/services/job-functional-submission-service.R-273-      status_url = paste0("/api/jobs/", job_id, "/status"),
api/services/job-functional-submission-service.R-274-      meta = list(llm_generation = "snapshot_refresh_owned")
api/services/job-functional-submission-service.R-275-    ))
--
api/functions/async-job-service.R-278-}
api/functions/async-job-service.R-279-
api/functions/async-job-service.R-280-#' Persist an already-completed durable async job row
api/functions/async-job-service.R-281-#'
api/functions/async-job-service.R-282-#' Used for cache-hit fast paths that should still return a normal durable
api/functions/async-job-service.R-283-#' job id without enqueueing worker execution.
api/functions/async-job-service.R-284-#'
api/functions/async-job-service.R-285-#' @param job_type Character durable job type.
api/functions/async-job-service.R-286-#' @param request_payload Named list or JSON payload string.
api/functions/async-job-service.R-287-#' @param result Completed handler result payload.
api/functions/async-job-service.R-288-#' @param submitted_by Optional user id.
api/functions/async-job-service.R-289-#' @param queue_name Character queue name.
api/functions/async-job-service.R-290-#' @param priority Integer queue priority.
api/functions/async-job-service.R-291-#' @param job_id Optional explicit job id.
api/functions/async-job-service.R-292-#' @param submitted_at Optional submission timestamp.
api/functions/async-job-service.R-293-#' @param completed_at Optional completion timestamp.
api/functions/async-job-service.R-294-#' @param conn Optional DB connection or pool.
api/functions/async-job-service.R-295-#'
api/functions/async-job-service.R-296-#' @return Tibble with the stored completed job row.
api/functions/async-job-service.R-297-#' @export
api/functions/async-job-service.R:298:async_job_service_store_completed <- function(
api/functions/async-job-service.R-299-  job_type,
api/functions/async-job-service.R-300-  request_payload,
api/functions/async-job-service.R-301-  result,
api/functions/async-job-service.R-302-  submitted_by = NULL,
api/functions/async-job-service.R-303-  queue_name = "default",
api/functions/async-job-service.R-304-  priority = 100L,
api/functions/async-job-service.R-305-  job_id = uuid::UUIDgenerate(),
api/functions/async-job-service.R-306-  submitted_at = Sys.time(),
api/functions/async-job-service.R-307-  completed_at = submitted_at,
api/functions/async-job-service.R-308-  conn = NULL
api/functions/async-job-service.R-309-) {
api/functions/async-job-service.R-310-  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
api/functions/async-job-service.R-311-  job_id <- .async_job_service_non_empty_string(job_id, "job_id")
api/functions/async-job-service.R-312-  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
api/functions/async-job-service.R-313-  payload_json <- async_job_service_payload_json(request_payload)
api/functions/async-job-service.R-314-  result_json <- async_job_service_payload_json(result)
api/functions/async-job-service.R-315-
api/functions/async-job-service.R-316-  async_job_repository_create(
api/functions/async-job-service.R-317-    list(
api/functions/async-job-service.R-318-      job_id = job_id,

 succeeded in 0ms:
api/functions/async-job-handlers.R-93-  }
api/functions/async-job-handlers.R-94-
api/functions/async-job-handlers.R-95-  categories
api/functions/async-job-handlers.R-96-}
api/functions/async-job-handlers.R-97-
api/functions/async-job-handlers.R-98-.async_job_run_clustering <- function(job, payload, state, worker_config) {
api/functions/async-job-handlers.R-99-  genes <- .async_job_payload_field(payload, "genes")
api/functions/async-job-handlers.R-100-  algorithm <- .async_job_payload_scalar(payload, "algorithm")
api/functions/async-job-handlers.R-101-  string_id_table <- .async_job_payload_field(payload, "string_id_table", required = FALSE)
api/functions/async-job-handlers.R-102-  category_links <- .async_job_payload_field(payload, "category_links", required = FALSE)
api/functions/async-job-handlers.R:103:  # #574 D3: the cheap-path selector/fingerprint provenance the submit
api/functions/async-job-handlers.R-104-  # service (job-functional-submission-service.R) recorded in the payload.
api/functions/async-job-handlers.R-105-  # Absent on legacy/explicit-genes payloads pre-dating #574 (required =
api/functions/async-job-handlers.R-106-  # FALSE) so a worker-run job for those still completes normally.
api/functions/async-job-handlers.R:107:  provenance <- .async_job_payload_field(payload, "provenance", required = FALSE)
api/functions/async-job-handlers.R-108-  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
api/functions/async-job-handlers.R-109-
api/functions/async-job-handlers.R-110-  progress("cluster", "Running functional clustering...", current = 0, total = 1)
api/functions/async-job-handlers.R-111-
api/functions/async-job-handlers.R-112-  clusters <- gen_string_clust_obj(
api/functions/async-job-handlers.R-113-    genes,
api/functions/async-job-handlers.R-114-    algorithm = algorithm,
api/functions/async-job-handlers.R-115-    string_id_table = string_id_table
api/functions/async-job-handlers.R-116-  )
api/functions/async-job-handlers.R-117-
api/functions/async-job-handlers.R-118-  progress("complete", "Functional clustering complete", current = 1, total = 1)
api/functions/async-job-handlers.R-119-
api/functions/async-job-handlers.R-120-  # Mirror the cache-hit result meta shape (job-functional-submission-service.R)
api/functions/async-job-handlers.R-121-  # via the shared `clustering_result_meta()` helper (clustering-gene-universe.R):
api/functions/async-job-handlers.R-122-  # base fields (incl. cache_hit = FALSE, for shape parity with the cache-hit
api/functions/async-job-handlers.R:123:  # path), then the request's cheap-path `provenance` (selector/
api/functions/async-job-handlers.R-124-  # resolved_gene_count/gene_list_sha256/intended_fingerprint/
api/functions/async-job-handlers.R-125-  # source_data_version) when present, then the `effective_fingerprint` --
api/functions/async-job-handlers.R-126-  # only knowable now that `clusters` has actually been computed -- so a
api/functions/async-job-handlers.R-127-  # silent exp+db -> combined-score STRING fallback on a worker-run job is
api/functions/async-job-handlers.R-128-  # visible in the stored result too, not just a cache hit's.
api/functions/async-job-handlers.R-129-  meta <- clustering_result_meta(
api/functions/async-job-handlers.R-130-    list(
api/functions/async-job-handlers.R-131-      algorithm = algorithm,
api/functions/async-job-handlers.R-132-      gene_count = length(genes),
api/functions/async-job-handlers.R-133-      cluster_count = nrow(clusters),
api/functions/async-job-handlers.R-134-      cache_hit = FALSE
api/functions/async-job-handlers.R-135-    ),
api/functions/async-job-handlers.R:136:    provenance,
api/functions/async-job-handlers.R-137-    attr(clusters, "weight_channel")
api/functions/async-job-handlers.R-138-  )
api/functions/async-job-handlers.R-139-
api/functions/async-job-handlers.R-140-  list(
api/functions/async-job-handlers.R-141-    clusters = clusters,
api/functions/async-job-handlers.R-142-    categories = .async_job_functional_categories(clusters, category_links),
api/functions/async-job-handlers.R-143-    meta = meta
api/functions/async-job-handlers.R-144-  )
api/functions/async-job-handlers.R-145-}
api/functions/async-job-handlers.R-146-
--
api/functions/clustering-gene-universe.R-1-# api/functions/clustering-gene-universe.R
api/functions/clustering-gene-universe.R-2-#
api/functions/clustering-gene-universe.R-3-# Category-selected clustering gene-universe resolver (#574 D1).
api/functions/clustering-gene-universe.R-4-#
api/functions/clustering-gene-universe.R-5-# `POST /api/jobs/clustering/submit` will (D2/D3, not this file) accept a
api/functions/clustering-gene-universe.R:6:# `category_filter` (e.g. c("Definitive")) to resolve the clustering gene
api/functions/clustering-gene-universe.R-7-# universe from curated SysNDD confidence categories instead of the default
api/functions/clustering-gene-universe.R:8:# "all NDD genes" set. This file builds ONLY the resolver + provenance
api/functions/clustering-gene-universe.R-9-# helpers; the submit service and durable handler wiring is done later.
api/functions/clustering-gene-universe.R-10-#
api/functions/clustering-gene-universe.R-11-# Entity-level resolution: a gene qualifies if it has >=1 NDD entity
api/functions/clustering-gene-universe.R-12-# (`ndd_phenotype == 1`) whose `category` is in the selector, even if the
api/functions/clustering-gene-universe.R-13-# same gene also has OTHER-category entities. This mirrors
api/functions/clustering-gene-universe.R-14-# `generate_ndd_hgnc_ids()` (the existing default-universe query) with an
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
api/functions/clustering-gene-universe.R:26:clustering_normalize_category_filter <- function(category_filter) {
api/functions/clustering-gene-universe.R:27:  if (is.null(category_filter)) return(NULL)
api/functions/clustering-gene-universe.R:28:  vals <- trimws(as.character(unlist(category_filter, use.names = FALSE)))
api/functions/clustering-gene-universe.R-29-  vals <- vals[nzchar(vals)]
api/functions/clustering-gene-universe.R-30-  if (length(vals) == 0L) return(character(0)) # supplied but empty -> 400 downstream
api/functions/clustering-gene-universe.R-31-  sort(unique(vals))
api/functions/clustering-gene-universe.R-32-}
api/functions/clustering-gene-universe.R-33-
api/functions/clustering-gene-universe.R-34-clustering_gene_list_sha256 <- function(hgnc_ids) {
api/functions/clustering-gene-universe.R-35-  digest::digest(
api/functions/clustering-gene-universe.R-36-    jsonlite::toJSON(sort(unique(as.character(hgnc_ids))), auto_unbox = TRUE),
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
api/functions/clustering-gene-universe.R-47-    return(list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids)))
api/functions/clustering-gene-universe.R-48-  }
api/functions/clustering-gene-universe.R-49-  if (length(selector) == 0L) {
api/functions/clustering-gene-universe.R:50:    stop_for_bad_request("category_filter was supplied but empty; provide at least one active category")
api/functions/clustering-gene-universe.R-51-  }
api/functions/clustering-gene-universe.R-52-
api/functions/clustering-gene-universe.R-53-  active <- conn %>%
api/functions/clustering-gene-universe.R-54-    dplyr::tbl("ndd_entity_status_categories_list") %>%
api/functions/clustering-gene-universe.R-55-    dplyr::filter(is_active == 1) %>%
api/functions/clustering-gene-universe.R-56-    dplyr::select(category) %>%
api/functions/clustering-gene-universe.R-57-    dplyr::collect() %>%
api/functions/clustering-gene-universe.R-58-    dplyr::pull(category)
api/functions/clustering-gene-universe.R-59-  unknown <- setdiff(selector, active)
api/functions/clustering-gene-universe.R-60-  if (length(unknown) > 0L) {
api/functions/clustering-gene-universe.R-61-    # Allowed set goes in the MESSAGE: core/filters.R serializes conditionMessage(err), not `detail`.
api/functions/clustering-gene-universe.R-62-    stop_for_bad_request(sprintf(
api/functions/clustering-gene-universe.R:63:      "Unknown or inactive category_filter value(s): %s. Allowed active categories: %s",
api/functions/clustering-gene-universe.R-64-      paste(unknown, collapse = ", "), paste(sort(active), collapse = ", ")
api/functions/clustering-gene-universe.R-65-    ))
api/functions/clustering-gene-universe.R-66-  }
api/functions/clustering-gene-universe.R-67-
api/functions/clustering-gene-universe.R-68-  hgnc_ids <- conn %>%
api/functions/clustering-gene-universe.R-69-    dplyr::tbl("ndd_entity_view") %>%
api/functions/clustering-gene-universe.R-70-    dplyr::arrange(entity_id) %>%
api/functions/clustering-gene-universe.R-71-    dplyr::filter(ndd_phenotype == 1, category %in% !!selector) %>%
api/functions/clustering-gene-universe.R-72-    dplyr::select(hgnc_id) %>%
api/functions/clustering-gene-universe.R-73-    dplyr::collect() %>%
api/functions/clustering-gene-universe.R-74-    unique() %>%
api/functions/clustering-gene-universe.R-75-    dplyr::pull(hgnc_id)
api/functions/clustering-gene-universe.R-76-
api/functions/clustering-gene-universe.R-77-  if (length(hgnc_ids) < 2L) {
api/functions/clustering-gene-universe.R-78-    stop_for_bad_request(sprintf(
api/functions/clustering-gene-universe.R:79:      "category_filter=[%s] resolved %d NDD gene(s); clustering needs at least 2",
api/functions/clustering-gene-universe.R-80-      paste(selector, collapse = ","), length(hgnc_ids)
api/functions/clustering-gene-universe.R-81-    ))
api/functions/clustering-gene-universe.R-82-  }
api/functions/clustering-gene-universe.R-83-  list(hgnc_ids = hgnc_ids, selector = selector, resolved_gene_count = length(hgnc_ids))
api/functions/clustering-gene-universe.R-84-}
api/functions/clustering-gene-universe.R-85-
api/functions/clustering-gene-universe.R-86-# Module-level (survives across requests within the same process) cache for
api/functions/clustering-gene-universe.R-87-# `analysis_snapshot_source_data_version()`. That read joins/aggregates across
api/functions/clustering-gene-universe.R-88-# public tables and changes rarely (only when the snapshot builder's source
api/functions/clustering-gene-universe.R-89-# view moves), so a short-TTL process cache avoids paying that cost on every
api/functions/clustering-gene-universe.R-90-# clustering submit while still self-refreshing.
api/functions/clustering-gene-universe.R-91-.clustering_source_data_version_cache <- new.env(parent = emptyenv())
api/functions/clustering-gene-universe.R-92-
api/functions/clustering-gene-universe.R-93-#' Cached, fail-closed read of the current analysis source-data version.
api/functions/clustering-gene-universe.R-94-#'
api/functions/clustering-gene-universe.R:95:#' D2 (#574) provenance helper: the clustering submit service calls this
api/functions/clustering-gene-universe.R-96-#' AFTER admission/dedup, only when it is actually about to build a durable
api/functions/clustering-gene-universe.R-97-#' payload. Refetches once `ttl_seconds` has elapsed since the last
api/functions/clustering-gene-universe.R-98-#' successful read. Deliberately does NOT wrap
api/functions/clustering-gene-universe.R-99-#' `analysis_snapshot_source_data_version()` in a tryCatch here -- an error
api/functions/clustering-gene-universe.R-100-#' PROPAGATES to the caller (never cached, never coerced to NA), so a
api/functions/clustering-gene-universe.R-101-#' transient DB problem fails the submit closed (503) instead of recording
api/functions/clustering-gene-universe.R:102:#' broken provenance.
api/functions/clustering-gene-universe.R-103-#'
api/functions/clustering-gene-universe.R-104-#' @param conn DB connection/pool. Defaults to the package-global `pool`.
api/functions/clustering-gene-universe.R-105-#' @param ttl_seconds Cache TTL in seconds. Default 300 (5 minutes).
api/functions/clustering-gene-universe.R-106-#' @return character(1) source data version.
api/functions/clustering-gene-universe.R-107-#' @export
api/functions/clustering-gene-universe.R-108-clustering_cached_source_data_version <- function(conn = pool, ttl_seconds = 300) {
api/functions/clustering-gene-universe.R-109-  now <- Sys.time()
api/functions/clustering-gene-universe.R-110-  cached_at <- .clustering_source_data_version_cache$cached_at
api/functions/clustering-gene-universe.R-111-  if (!is.null(cached_at) &&
api/functions/clustering-gene-universe.R-112-        as.numeric(difftime(now, cached_at, units = "secs")) < ttl_seconds) {
api/functions/clustering-gene-universe.R-113-    return(.clustering_source_data_version_cache$value)
api/functions/clustering-gene-universe.R-114-  }
api/functions/clustering-gene-universe.R-115-
api/functions/clustering-gene-universe.R-116-  value <- analysis_snapshot_source_data_version(conn = conn)
api/functions/clustering-gene-universe.R-117-
api/functions/clustering-gene-universe.R-118-  .clustering_source_data_version_cache$value <- value
api/functions/clustering-gene-universe.R-119-  .clustering_source_data_version_cache$cached_at <- now
api/functions/clustering-gene-universe.R-120-  value
api/functions/clustering-gene-universe.R-121-}
api/functions/clustering-gene-universe.R-122-
api/functions/clustering-gene-universe.R:123:# Assemble the clustering result `meta`: base fields + the cheap-path provenance
api/functions/clustering-gene-universe.R-124-# (selector/resolved_gene_count/gene_list_sha256/intended_fingerprint/
api/functions/clustering-gene-universe.R-125-# source_data_version, NULL for a legacy payload) + the EFFECTIVE weight_channel
api/functions/clustering-gene-universe.R-126-# observed post-compute. Shared by the cache-hit path
api/functions/clustering-gene-universe.R-127-# (job-functional-submission-service.R) and the worker-run/durable handler
api/functions/clustering-gene-universe.R-128-# (.async_job_run_clustering, async-job-handlers.R, #574 D3) so the two result
api/functions/clustering-gene-universe.R-129-# shapes cannot drift apart by hand-copied edits.
api/functions/clustering-gene-universe.R:130:clustering_result_meta <- function(base, provenance, weight_channel) {
api/functions/clustering-gene-universe.R-131-  c(base,
api/functions/clustering-gene-universe.R:132:    if (!is.null(provenance)) provenance else list(),
api/functions/clustering-gene-universe.R-133-    list(effective_fingerprint = list(weight_channel = weight_channel)))
api/functions/clustering-gene-universe.R-134-}
--
api/services/job-functional-submission-service.R-18-#' Cache-first: if the memoised `gen_string_clust_obj_mem()` already has a
api/services/job-functional-submission-service.R-19-#' result for the resolved gene list + algorithm, the result is persisted as
api/services/job-functional-submission-service.R-20-#' an already-completed durable job via `async_job_service_store_completed()`
api/services/job-functional-submission-service.R-21-#' so the response shape matches a freshly-submitted job (this keeps LLM batch
api/services/job-functional-submission-service.R-22-#' generation on the same job/result hashes as the API-served table). A cache
api/services/job-functional-submission-service.R-23-#' miss falls through the public queue-depth capacity guard
api/services/job-functional-submission-service.R-24-#' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
api/services/job-functional-submission-service.R-25-#' new durable job via `create_job()`.
api/services/job-functional-submission-service.R-26-#'
api/services/job-functional-submission-service.R-27-#' The clustering gene universe (#574) is one of: an explicit `genes` list, a
api/services/job-functional-submission-service.R:28:#' curated-category selection via `category_filter` (resolved through
api/services/job-functional-submission-service.R-29-#' `clustering_resolve_category_universe()`), or -- when neither is supplied
api/services/job-functional-submission-service.R-30-#' -- the existing default all-NDD-genes universe. `genes` and
api/services/job-functional-submission-service.R:31:#' `category_filter` are mutually exclusive (400 if both are present). Every
api/services/job-functional-submission-service.R:32:#' submit records selector + fingerprint provenance in the durable payload
api/services/job-functional-submission-service.R-33-#' and (on a cache hit) the result meta; see `clustering-gene-universe.R`.
api/services/job-functional-submission-service.R-34-#'
api/services/job-functional-submission-service.R-35-#' @param req Plumber request (reads `req$argsBody$genes`/`algorithm`/
api/services/job-functional-submission-service.R:36:#'   `category_filter` and `req$user$user_id`).
api/services/job-functional-submission-service.R-37-#' @param res Plumber response, mutated in place (status + headers).
api/services/job-functional-submission-service.R-38-#' @return List payload for the `json` serializer.
api/services/job-functional-submission-service.R-39-#' @export
api/services/job-functional-submission-service.R-40-svc_job_submit_functional_clustering <- function(req, res) {
api/services/job-functional-submission-service.R-41-  # Guard FIRST (#535 S6): per-caller submit admission throttle, applied before any
api/services/job-functional-submission-service.R-42-  # DB/cache/duplicate work so an abusive caller is rejected before it can do — or
api/services/job-functional-submission-service.R-43-  # provoke — expensive work (a cache hit still writes a completed job row, and the
api/services/job-functional-submission-service.R-44-  # duplicate/data fetch below touch the DB). Layered on the global capacity cap.
api/services/job-functional-submission-service.R-45-  admission <- async_job_submit_admission_guard(req, res)
api/services/job-functional-submission-service.R-46-  if (!isTRUE(admission$admitted)) {
api/services/job-functional-submission-service.R-47-    return(admission$response)
api/services/job-functional-submission-service.R-48-  }
api/services/job-functional-submission-service.R-49-
api/services/job-functional-submission-service.R-50-  # Extract request data before durable submission.
api/services/job-functional-submission-service.R-51-
api/services/job-functional-submission-service.R-52-  # Connection objects cannot cross process boundaries. `genes` and
api/services/job-functional-submission-service.R:53:  # `category_filter` are mutually exclusive gene-universe selectors (#574):
api/services/job-functional-submission-service.R-54-  # an explicit gene list, a curated-category selection, or (both absent) the
api/services/job-functional-submission-service.R-55-  # existing default all-NDD-genes universe. Presence is decided from the RAW
api/services/job-functional-submission-service.R:56:  # request field, not a length check, so an explicitly-empty category_filter
api/services/job-functional-submission-service.R-57-  # still reaches (and is rejected by) the resolver instead of silently
api/services/job-functional-submission-service.R-58-  # falling through to the all-NDD default.
api/services/job-functional-submission-service.R-59-  genes_in <- req$argsBody$genes
api/services/job-functional-submission-service.R:60:  category_supplied <- !is.null(req$argsBody$category_filter)
api/services/job-functional-submission-service.R-61-  has_genes <- !is.null(genes_in) && length(genes_in) > 0
api/services/job-functional-submission-service.R-62-
api/services/job-functional-submission-service.R-63-  if (has_genes && category_supplied) {
api/services/job-functional-submission-service.R:64:    stop_for_bad_request("Provide either genes or category_filter, not both")
api/services/job-functional-submission-service.R-65-  }
api/services/job-functional-submission-service.R-66-
api/services/job-functional-submission-service.R-67-  # Extract algorithm parameter (default: leiden)
api/services/job-functional-submission-service.R-68-  # Ensure we get a scalar value (JSON may pass arrays)
api/services/job-functional-submission-service.R-69-  algorithm <- "leiden"
api/services/job-functional-submission-service.R-70-  if (!is.null(req$argsBody$algorithm)) {
api/services/job-functional-submission-service.R-71-    algo_input <- req$argsBody$algorithm
api/services/job-functional-submission-service.R-72-    # Handle array input - always take first element if vector
api/services/job-functional-submission-service.R-73-    if (is.list(algo_input) || length(algo_input) >= 1) {
api/services/job-functional-submission-service.R-74-      algo_input <- algo_input[[1]]
api/services/job-functional-submission-service.R-75-    }
api/services/job-functional-submission-service.R-76-    algorithm <- tolower(as.character(algo_input))
api/services/job-functional-submission-service.R-77-    if (!algorithm %in% c("leiden", "walktrap")) {
api/services/job-functional-submission-service.R-78-      algorithm <- "leiden"
api/services/job-functional-submission-service.R-79-    }
api/services/job-functional-submission-service.R-80-  }
api/services/job-functional-submission-service.R-81-
api/services/job-functional-submission-service.R:82:  # Resolve the clustering gene universe + selector provenance (#574). The
api/services/job-functional-submission-service.R-83-  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
api/services/job-functional-submission-service.R-84-  # from before this feature: `clustering_resolve_category_universe(NULL)`
api/services/job-functional-submission-service.R-85-  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
api/services/job-functional-submission-service.R-86-  # so cache parity (memoise key = gene set + algorithm) is preserved.
api/services/job-functional-submission-service.R-87-  selector_chr <- NULL
api/services/job-functional-submission-service.R-88-  if (has_genes) {
api/services/job-functional-submission-service.R-89-    genes_list <- as.character(unlist(genes_in))
api/services/job-functional-submission-service.R-90-    kind <- "explicit"
api/services/job-functional-submission-service.R-91-  } else if (category_supplied) {
api/services/job-functional-submission-service.R:92:    universe <- clustering_resolve_category_universe(req$argsBody$category_filter)
api/services/job-functional-submission-service.R-93-    genes_list <- universe$hgnc_ids
api/services/job-functional-submission-service.R-94-    selector_chr <- universe$selector
api/services/job-functional-submission-service.R-95-    kind <- "category"
api/services/job-functional-submission-service.R-96-  } else {
api/services/job-functional-submission-service.R-97-    universe <- clustering_resolve_category_universe(NULL)
api/services/job-functional-submission-service.R-98-    genes_list <- universe$hgnc_ids
api/services/job-functional-submission-service.R-99-    kind <- "all_ndd"
api/services/job-functional-submission-service.R-100-  }
api/services/job-functional-submission-service.R-101-
api/services/job-functional-submission-service.R-102-  # Pre-fetch the STRING ID table because DB connections cannot cross the
--
api/services/job-functional-submission-service.R-105-    dplyr::tbl("non_alt_loci_set") %>%
api/services/job-functional-submission-service.R-106-    dplyr::filter(!is.na(STRING_id)) %>%
api/services/job-functional-submission-service.R-107-    dplyr::select(symbol, hgnc_id, STRING_id) %>%
api/services/job-functional-submission-service.R-108-    dplyr::collect()
api/services/job-functional-submission-service.R-109-
api/services/job-functional-submission-service.R-110-  # Check for duplicate job (include algorithm in check). The selector is
api/services/job-functional-submission-service.R-111-  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
api/services/job-functional-submission-service.R-112-  # submits keep the pre-#574 dedup identity byte-identical.
api/services/job-functional-submission-service.R-113-  dup_params <- list(genes = genes_list, algorithm = algorithm)
api/services/job-functional-submission-service.R-114-  if (!is.null(selector_chr)) {
api/services/job-functional-submission-service.R:115:    dup_params$category_filter <- selector_chr
api/services/job-functional-submission-service.R-116-  }
api/services/job-functional-submission-service.R-117-  dup_check <- check_duplicate_job("clustering", dup_params)
api/services/job-functional-submission-service.R-118-  if (dup_check$duplicate) {
api/services/job-functional-submission-service.R-119-    res$status <- 409
api/services/job-functional-submission-service.R-120-    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
api/services/job-functional-submission-service.R-121-    return(list(
api/services/job-functional-submission-service.R-122-      error = "DUPLICATE_JOB",
api/services/job-functional-submission-service.R-123-      message = "Identical job already running",
api/services/job-functional-submission-service.R-124-      existing_job_id = dup_check$existing_job_id,
api/services/job-functional-submission-service.R-125-      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
api/services/job-functional-submission-service.R-126-    ))
api/services/job-functional-submission-service.R-127-  }
api/services/job-functional-submission-service.R-128-
api/services/job-functional-submission-service.R:129:  # Cheap-path provenance (no expensive query yet). `selector_obj` records
api/services/job-functional-submission-service.R-130-  # WHICH universe was resolved; `intended_fingerprint` records the STRING
api/services/job-functional-submission-service.R-131-  # cache identity + fixed clustering params this submit intends to run
api/services/job-functional-submission-service.R-132-  # with. The *effective* fingerprint (e.g. the STRING weight channel a
api/services/job-functional-submission-service.R-133-  # computed result actually used) is only knowable from a computed result,
api/services/job-functional-submission-service.R-134-  # so it is recorded separately in the cache-hit result meta below.
api/services/job-functional-submission-service.R:135:  selector_obj <- list(kind = kind, category_filter = selector_chr)
api/services/job-functional-submission-service.R-136-  intended_fingerprint <- list(
api/services/job-functional-submission-service.R-137-    string_cache_fingerprint = analysis_string_cache_fingerprint(),
api/services/job-functional-submission-service.R-138-    score_threshold = 400L,
api/services/job-functional-submission-service.R-139-    algorithm = algorithm,
api/services/job-functional-submission-service.R-140-    seed = 42L
api/services/job-functional-submission-service.R-141-  )
api/services/job-functional-submission-service.R-142-  gene_sha <- clustering_gene_list_sha256(genes_list)
api/services/job-functional-submission-service.R-143-
api/services/job-functional-submission-service.R-144-  # Source-data version: a CACHED, fail-closed read, fetched only now that a
api/services/job-functional-submission-service.R-145-  # payload is actually about to be built -- its backing view runs global
api/services/job-functional-submission-service.R-146-  # counts/joins, so it must never run before admission/dedup. A lookup
api/services/job-functional-submission-service.R:147:  # failure must never silently record NA/broken provenance; fail the
api/services/job-functional-submission-service.R-148-  # request closed instead.
api/services/job-functional-submission-service.R-149-  src_ver <- tryCatch(
api/services/job-functional-submission-service.R-150-    clustering_cached_source_data_version(conn = pool),
api/services/job-functional-submission-service.R-151-    error = function(e) e
api/services/job-functional-submission-service.R-152-  )
api/services/job-functional-submission-service.R-153-  if (inherits(src_ver, "error")) {
api/services/job-functional-submission-service.R-154-    res$status <- 503L
api/services/job-functional-submission-service.R-155-    return(list(
api/services/job-functional-submission-service.R-156-      error = "PROVENANCE_UNAVAILABLE",
api/services/job-functional-submission-service.R-157-      message = "Snapshot source-data version unavailable; retry shortly."
api/services/job-functional-submission-service.R-158-    ))
api/services/job-functional-submission-service.R-159-  }
api/services/job-functional-submission-service.R-160-
api/services/job-functional-submission-service.R:161:  provenance <- list(
api/services/job-functional-submission-service.R-162-    selector = selector_obj,
api/services/job-functional-submission-service.R-163-    resolved_gene_count = length(genes_list),
api/services/job-functional-submission-service.R-164-    gene_list_sha256 = gene_sha,
api/services/job-functional-submission-service.R-165-    intended_fingerprint = intended_fingerprint,
api/services/job-functional-submission-service.R-166-    source_data_version = src_ver
api/services/job-functional-submission-service.R-167-  )
api/services/job-functional-submission-service.R-168-
api/services/job-functional-submission-service.R-169-  # Define category links (needed for result)
api/services/job-functional-submission-service.R-170-  category_links <- tibble::tibble(
api/services/job-functional-submission-service.R-171-    value = c(
--
api/services/job-functional-submission-service.R-213-      dplyr::arrange(category) %>%
api/services/job-functional-submission-service.R-214-      dplyr::mutate(
api/services/job-functional-submission-service.R-215-        text = dplyr::case_when(
api/services/job-functional-submission-service.R-216-          nchar(category) <= 5 ~ category,
api/services/job-functional-submission-service.R-217-          nchar(category) > 5 ~ stringr::str_to_sentence(category)
api/services/job-functional-submission-service.R-218-        )
api/services/job-functional-submission-service.R-219-      ) %>%
api/services/job-functional-submission-service.R-220-      dplyr::select(value = category, text) %>%
api/services/job-functional-submission-service.R-221-      dplyr::left_join(category_links, by = c("value"))
api/services/job-functional-submission-service.R-222-
api/services/job-functional-submission-service.R:223:    # Splice the base cache-hit fields with `provenance` (already assembled
api/services/job-functional-submission-service.R-224-    # above as selector/resolved_gene_count/gene_list_sha256/
api/services/job-functional-submission-service.R-225-    # intended_fingerprint/source_data_version) via the shared
api/services/job-functional-submission-service.R-226-    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
api/services/job-functional-submission-service.R-227-    # re-listing the same fields as duplicate literals -- keeps this shape in
api/services/job-functional-submission-service.R-228-    # lockstep with the worker-run handler's result meta by construction.
api/services/job-functional-submission-service.R-229-    # `effective_fingerprint` is only knowable from the computed result
api/services/job-functional-submission-service.R:230:    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
api/services/job-functional-submission-service.R-231-    cache_result <- list(
api/services/job-functional-submission-service.R-232-      clusters = cached_clusters,
api/services/job-functional-submission-service.R-233-      categories = categories,
api/services/job-functional-submission-service.R-234-      meta = clustering_result_meta(
api/services/job-functional-submission-service.R-235-        list(
api/services/job-functional-submission-service.R-236-          algorithm = algorithm,
api/services/job-functional-submission-service.R-237-          gene_count = length(genes_list),
api/services/job-functional-submission-service.R-238-          cluster_count = nrow(cached_clusters),
api/services/job-functional-submission-service.R-239-          cache_hit = TRUE
api/services/job-functional-submission-service.R-240-        ),
api/services/job-functional-submission-service.R:241:        provenance,
api/services/job-functional-submission-service.R-242-        attr(cached_clusters, "weight_channel")
api/services/job-functional-submission-service.R-243-      )
api/services/job-functional-submission-service.R-244-    )
api/services/job-functional-submission-service.R-245-    cache_request_payload <- list(
api/services/job-functional-submission-service.R-246-      genes = genes_list,
api/services/job-functional-submission-service.R-247-      algorithm = algorithm,
api/services/job-functional-submission-service.R-248-      category_links = category_links,
api/services/job-functional-submission-service.R-249-      string_id_table = string_id_table,
api/services/job-functional-submission-service.R:250:      provenance = provenance
api/services/job-functional-submission-service.R-251-    )
api/services/job-functional-submission-service.R-252-    if (!is.null(selector_chr)) {
api/services/job-functional-submission-service.R:253:      cache_request_payload$category_filter <- selector_chr
api/services/job-functional-submission-service.R-254-    }
api/services/job-functional-submission-service.R-255-    completed_job <- async_job_service_store_completed(
api/services/job-functional-submission-service.R-256-      job_type = "clustering",
api/services/job-functional-submission-service.R-257-      request_payload = cache_request_payload,
api/services/job-functional-submission-service.R-258-      result = cache_result,
api/services/job-functional-submission-service.R-259-      submitted_by = req$user$user_id %||% NULL,
api/services/job-functional-submission-service.R-260-      queue_name = "analysis",
api/services/job-functional-submission-service.R-261-      priority = 50L
api/services/job-functional-submission-service.R-262-    )
api/services/job-functional-submission-service.R-263-    job_id <- completed_job$job_id[[1]]
--
api/services/job-functional-submission-service.R-294-      retry_after = 60
api/services/job-functional-submission-service.R-295-    ))
api/services/job-functional-submission-service.R-296-  }
api/services/job-functional-submission-service.R-297-
api/services/job-functional-submission-service.R-298-  # Cache miss - create async job
api/services/job-functional-submission-service.R-299-  job_params <- list(
api/services/job-functional-submission-service.R-300-    genes = genes_list,
api/services/job-functional-submission-service.R-301-    algorithm = algorithm,
api/services/job-functional-submission-service.R-302-    category_links = category_links,
api/services/job-functional-submission-service.R-303-    string_id_table = string_id_table,
api/services/job-functional-submission-service.R:304:    provenance = provenance
api/services/job-functional-submission-service.R-305-  )
api/services/job-functional-submission-service.R-306-  if (!is.null(selector_chr)) {
api/services/job-functional-submission-service.R:307:    job_params$category_filter <- selector_chr
api/services/job-functional-submission-service.R-308-  }
api/services/job-functional-submission-service.R-309-  result <- create_job(
api/services/job-functional-submission-service.R-310-    operation = "clustering",
api/services/job-functional-submission-service.R-311-    params = job_params
api/services/job-functional-submission-service.R-312-  )
api/services/job-functional-submission-service.R-313-
api/services/job-functional-submission-service.R-314-  # Check capacity
api/services/job-functional-submission-service.R-315-  if (!is.null(result$error)) {
api/services/job-functional-submission-service.R-316-    res$status <- 503
api/services/job-functional-submission-service.R-317-    res$setHeader("Retry-After", as.character(result$retry_after))

exec
/bin/bash -lc "rg -n -C 5 'library\\(config\\)|require\\(config\\)|config::get|config\\(' api/tests api/start_sysndd_api.R api/bootstrap | head -n 300" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/start_sysndd_api.R-49-  Sys.setenv(API_CONFIG = "sysndd_db_dev")
api/start_sysndd_api.R-50-} else {
api/start_sysndd_api.R-51-  Sys.setenv(API_CONFIG = "sysndd_db_local")
api/start_sysndd_api.R-52-}
api/start_sysndd_api.R-53-
api/start_sysndd_api.R:54:dw <- config::get(Sys.getenv("API_CONFIG"))
api/start_sysndd_api.R-55-
api/start_sysndd_api.R:56:# config::get() may parse unquoted YAML values as lists; coerce + validate.
api/start_sysndd_api.R-57-if (is.list(dw$secret)) {
api/start_sysndd_api.R-58-  dw$secret <- as.character(dw$secret[[1]])
api/start_sysndd_api.R-59-  message("WARNING: dw$secret was list, coerced to character. Check config.yml quoting.")
api/start_sysndd_api.R-60-}
api/start_sysndd_api.R-61-stopifnot(
--
api/bootstrap/init_libraries.R-32-  library(tictoc)
api/bootstrap/init_libraries.R-33-  library(fs)
api/bootstrap/init_libraries.R-34-  library(jsonlite)
api/bootstrap/init_libraries.R-35-  library(DBI)
api/bootstrap/init_libraries.R-36-  library(RMariaDB)
api/bootstrap/init_libraries.R:37:  library(config)
api/bootstrap/init_libraries.R-38-  library(pool)
api/bootstrap/init_libraries.R-39-
api/bootstrap/init_libraries.R-40-  library(biomaRt)
api/bootstrap/init_libraries.R-41-  library(tidyverse)
api/bootstrap/init_libraries.R-42-  library(stringr)
--
api/bootstrap/create_pool.R-15-#' (default 5). Single-threaded R rarely needs >1–2 concurrent
api/bootstrap/create_pool.R-16-#' connections, but up to 5 accommodates burst load from mirai
api/bootstrap/create_pool.R-17-#' workers. Keeping an explicit upper bound prevents unbounded
api/bootstrap/create_pool.R-18-#' connection growth from exhausting MySQL's `max_connections`.
api/bootstrap/create_pool.R-19-#'
api/bootstrap/create_pool.R:20:#' @param dw A list from `config::get()` with `dbname`, `host`,
api/bootstrap/create_pool.R-21-#'   `user`, `password`, `server`, `port`.
api/bootstrap/create_pool.R-22-#' @return A pool object created by `pool::dbPool()`.
api/bootstrap/create_pool.R-23-#' @export
api/bootstrap/create_pool.R-24-bootstrap_create_pool <- function(dw) {
api/bootstrap/create_pool.R-25-  pool_env <- if (identical(Sys.getenv("SYSNDD_RUNTIME", ""), "mcp")) "MCP_DB_POOL_SIZE" else "DB_POOL_SIZE"
--
api/bootstrap/create_mcp_pool.R-1-# Bounded database pool for the dedicated MCP principal.
api/bootstrap/create_mcp_pool.R-2-
api/bootstrap/create_mcp_pool.R-3-#' Create the MCP database pool from validated dedicated configuration.
api/bootstrap/create_mcp_pool.R-4-#'
api/bootstrap/create_mcp_pool.R:5:#' @param config Output from mcp_readonly_config().
api/bootstrap/create_mcp_pool.R-6-#' @param pool_factory Injectable pool constructor for unit tests.
api/bootstrap/create_mcp_pool.R-7-#' @param driver Injectable MariaDB driver for unit tests.
api/bootstrap/create_mcp_pool.R-8-#' @return A pool object.
api/bootstrap/create_mcp_pool.R-9-bootstrap_create_mcp_pool <- function(
api/bootstrap/create_mcp_pool.R-10-    config,
--
api/tests/testthat/test-unit-admin-endpoint-services.R-212-test_that("svc_admin_force_apply_ontology_prepare does NOT marshal db_config into the job params (#535 S2b)", {
api/tests/testthat/test-unit-admin-endpoint-services.R-213-  # Post-S2b: the durable force_apply_ontology handler
api/tests/testthat/test-unit-admin-endpoint-services.R-214-  # (.async_job_run_force_apply_ontology) resolves DB creds at run time via
api/tests/testthat/test-unit-admin-endpoint-services.R-215-  # async_job_db_connect() from the worker's runtime config — no credential is
api/tests/testthat/test-unit-admin-endpoint-services.R-216-  # written into async_jobs.request_payload_json. The prior helper
api/tests/testthat/test-unit-admin-endpoint-services.R:217:  # .svc_admin_ontology_db_config() is removed.
api/tests/testthat/test-unit-admin-endpoint-services.R-218-  svc_src <- paste(
api/tests/testthat/test-unit-admin-endpoint-services.R-219-    deparse(body(svc_admin_force_apply_ontology_prepare)), collapse = "\n"
api/tests/testthat/test-unit-admin-endpoint-services.R-220-  )
api/tests/testthat/test-unit-admin-endpoint-services.R-221-  expect_false(grepl("db_config", svc_src, fixed = TRUE),
api/tests/testthat/test-unit-admin-endpoint-services.R-222-               info = "force_apply params must NOT carry db_config (creds resolved at run time)")
--
api/tests/testthat/test-integration-email.R-67-
api/tests/testthat/test-integration-email.R-68-  # Set SMTP_PASSWORD env var (Mailpit accepts any password)
api/tests/testthat/test-integration-email.R-69-  withr::local_envvar(SMTP_PASSWORD = "test")
api/tests/testthat/test-integration-email.R-70-
api/tests/testthat/test-integration-email.R-71-  # Get config to set up dw variable
api/tests/testthat/test-integration-email.R:72:  test_config <- get_test_config()
api/tests/testthat/test-integration-email.R-73-  # Override with Mailpit settings
api/tests/testthat/test-integration-email.R-74-  test_config$mail_noreply_host <- "127.0.0.1"
api/tests/testthat/test-integration-email.R-75-  test_config$mail_noreply_port <- 1025
api/tests/testthat/test-integration-email.R-76-  test_config$mail_noreply_use_ssl <- FALSE
api/tests/testthat/test-integration-email.R-77-
--
api/tests/testthat/helper-db.R-1-# tests/testthat/helper-db.R
api/tests/testthat/helper-db.R-2-# Database connection helpers for tests
api/tests/testthat/helper-db.R-3-#
api/tests/testthat/helper-db.R-4-# These functions provide isolated test database access with proper cleanup.
api/tests/testthat/helper-db.R:5:# Uses config::get() to load sysndd_db_test configuration.
api/tests/testthat/helper-db.R-6-
api/tests/testthat/helper-db.R-7-#' Get test database connection
api/tests/testthat/helper-db.R-8-#'
api/tests/testthat/helper-db.R-9-#' Creates a DBI connection to the test database.
api/tests/testthat/helper-db.R-10-#' Caller is responsible for disconnecting.
--
api/tests/testthat/helper-db.R-14-#' con <- get_test_db_connection()
api/tests/testthat/helper-db.R-15-#' # ... use connection ...
api/tests/testthat/helper-db.R-16-#' DBI::dbDisconnect(con)
api/tests/testthat/helper-db.R-17-get_test_db_connection <- function() {
api/tests/testthat/helper-db.R-18-  # Use get_test_config to find config.yml robustly
api/tests/testthat/helper-db.R:19:  test_config <- get_test_config()
api/tests/testthat/helper-db.R-20-
api/tests/testthat/helper-db.R-21-  if (is.null(test_config)) {
api/tests/testthat/helper-db.R-22-    stop("sysndd_db_test configuration not found in config.yml")
api/tests/testthat/helper-db.R-23-  }
api/tests/testthat/helper-db.R-24-
--
api/tests/testthat/helper-db.R-354-  if (is.null(config_path)) {
api/tests/testthat/helper-db.R-355-    stop("config.yml not found and MYSQL_HOST env not set. ",
api/tests/testthat/helper-db.R-356-         "Tried paths: ", paste(possible_paths, collapse = ", "))
api/tests/testthat/helper-db.R-357-  }
api/tests/testthat/helper-db.R-358-
api/tests/testthat/helper-db.R:359:  config <- config::get("sysndd_db_test", file = config_path)
api/tests/testthat/helper-db.R-360-
api/tests/testthat/helper-db.R-361-  if (is.null(key)) {
api/tests/testthat/helper-db.R-362-    return(config)
api/tests/testthat/helper-db.R-363-  }
api/tests/testthat/helper-db.R-364-
--
api/tests/testthat/test-mcp-select-principal-admin-config.R-25-    MCP_ADMIN_DB_NAME = "sysndd_db", MCP_ADMIN_DB_USER = "security_operator",
api/tests/testthat/test-mcp-select-principal-admin-config.R-26-    MCP_ADMIN_DB_PASSWORD_FILE = secret,
api/tests/testthat/test-mcp-select-principal-admin-config.R-27-    MCP_EXPECTED_VIEW_DEFINER = "schema_migrator@%",
api/tests/testthat/test-mcp-select-principal-admin-config.R-28-    MYSQL_USER = "must-not-be-used", MYSQL_PASSWORD = "must-not-be-used"
api/tests/testthat/test-mcp-select-principal-admin-config.R-29-  )
api/tests/testthat/test-mcp-select-principal-admin-config.R:30:  config <- mcp_readonly_admin_config(getenv = .admin_env(values))
api/tests/testthat/test-mcp-select-principal-admin-config.R-31-
api/tests/testthat/test-mcp-select-principal-admin-config.R-32-  expect_identical(config$host, "db-admin.internal")
api/tests/testthat/test-mcp-select-principal-admin-config.R-33-  expect_identical(config$port, 3307L)
api/tests/testthat/test-mcp-select-principal-admin-config.R-34-  expect_identical(config$dbname, "sysndd_db")
api/tests/testthat/test-mcp-select-principal-admin-config.R-35-  expect_identical(config$user, "security_operator")
api/tests/testthat/test-mcp-select-principal-admin-config.R-36-  expect_identical(config$password, "operator-secret")
api/tests/testthat/test-mcp-select-principal-admin-config.R-37-  expect_identical(config$expected_definer, "schema_migrator@%")
api/tests/testthat/test-mcp-select-principal-admin-config.R:38:  expect_error(mcp_readonly_admin_config(getenv = .admin_env(values[FALSE])), "MCP_ADMIN_DB_HOST")
api/tests/testthat/test-mcp-select-principal-admin-config.R:39:  expect_error(mcp_readonly_admin_config(getenv = .admin_env(c(
api/tests/testthat/test-mcp-select-principal-admin-config.R-40-    values[names(values) != "MCP_ADMIN_DB_PASSWORD_FILE"],
api/tests/testthat/test-mcp-select-principal-admin-config.R-41-    MCP_ADMIN_DB_PASSWORD = "direct-secret"
api/tests/testthat/test-mcp-select-principal-admin-config.R-42-  ))), "not supported")
api/tests/testthat/test-mcp-select-principal-admin-config.R-43-})
api/tests/testthat/test-mcp-select-principal-admin-config.R-44-
--
api/tests/testthat/test-mcp-select-principal-admin-config.R-48-  withr::defer(unlink(directory, recursive = TRUE))
api/tests/testthat/test-mcp-select-principal-admin-config.R-49-  secret <- file.path(directory, "password")
api/tests/testthat/test-mcp-select-principal-admin-config.R-50-  writeChar("file-secret", secret, eos = NULL, useBytes = TRUE)
api/tests/testthat/test-mcp-select-principal-admin-config.R-51-  Sys.chmod(secret, mode = "0600", use_umask = FALSE)
api/tests/testthat/test-mcp-select-principal-admin-config.R-52-
api/tests/testthat/test-mcp-select-principal-admin-config.R:53:  read_config <- function(path) mcp_readonly_admin_config(
api/tests/testthat/test-mcp-select-principal-admin-config.R-54-    getenv = .admin_env(c(.admin_base, MCP_ADMIN_DB_PASSWORD_FILE = path))
api/tests/testthat/test-mcp-select-principal-admin-config.R-55-  )
api/tests/testthat/test-mcp-select-principal-admin-config.R:56:  expect_identical(read_config(secret)$password, "file-secret")
api/tests/testthat/test-mcp-select-principal-admin-config.R-57-  Sys.chmod(secret, mode = "0640", use_umask = FALSE)
api/tests/testthat/test-mcp-select-principal-admin-config.R:58:  expect_error(read_config(secret), "owner-only regular file")
api/tests/testthat/test-mcp-select-principal-admin-config.R-59-  Sys.chmod(secret, mode = "0600", use_umask = FALSE)
api/tests/testthat/test-mcp-select-principal-admin-config.R-60-  link <- file.path(directory, "password-link")
api/tests/testthat/test-mcp-select-principal-admin-config.R-61-  file.symlink(secret, link)
api/tests/testthat/test-mcp-select-principal-admin-config.R:62:  expect_error(read_config(link), "symbolic link")
api/tests/testthat/test-mcp-select-principal-admin-config.R:63:  expect_error(read_config(directory), "regular file")
api/tests/testthat/test-mcp-select-principal-admin-config.R-64-})
api/tests/testthat/test-mcp-select-principal-admin-config.R-65-
api/tests/testthat/test-mcp-select-principal-admin-config.R-66-test_that("administrator password file is one bounded line", {
api/tests/testthat/test-mcp-select-principal-admin-config.R-67-  secret <- tempfile("mcp-admin-password-")
api/tests/testthat/test-mcp-select-principal-admin-config.R-68-  withr::defer(unlink(secret))
api/tests/testthat/test-mcp-select-principal-admin-config.R:69:  read_config <- function() mcp_readonly_admin_config(
api/tests/testthat/test-mcp-select-principal-admin-config.R-70-    getenv = .admin_env(c(.admin_base, MCP_ADMIN_DB_PASSWORD_FILE = secret))
api/tests/testthat/test-mcp-select-principal-admin-config.R-71-  )
api/tests/testthat/test-mcp-select-principal-admin-config.R-72-  write_secret <- function(bytes) {
api/tests/testthat/test-mcp-select-principal-admin-config.R-73-    writeBin(bytes, secret)
api/tests/testthat/test-mcp-select-principal-admin-config.R-74-    Sys.chmod(secret, mode = "0600", use_umask = FALSE)
api/tests/testthat/test-mcp-select-principal-admin-config.R-75-  }
api/tests/testthat/test-mcp-select-principal-admin-config.R-76-
api/tests/testthat/test-mcp-select-principal-admin-config.R-77-  write_secret(charToRaw("line-one\nline-two"))
api/tests/testthat/test-mcp-select-principal-admin-config.R:78:  expect_error(read_config(), "one nonempty line")
api/tests/testthat/test-mcp-select-principal-admin-config.R-79-  write_secret(raw())
api/tests/testthat/test-mcp-select-principal-admin-config.R:80:  expect_error(read_config(), "one nonempty line")
api/tests/testthat/test-mcp-select-principal-admin-config.R-81-  write_secret(as.raw(rep(65L, 4097L)))
api/tests/testthat/test-mcp-select-principal-admin-config.R:82:  expect_error(read_config(), "owner-only regular file|one nonempty line")
api/tests/testthat/test-mcp-select-principal-admin-config.R-83-})
--
api/tests/testthat/test-mcp-select-principal-config.R-48-
api/tests/testthat/test-mcp-select-principal-config.R-49-test_that("MCP configuration accepts only complete dedicated environment input", {
api/tests/testthat/test-mcp-select-principal-config.R-50-  sut <- load_sut(config_path)
api/tests/testthat/test-mcp-select-principal-config.R-51-  if (!expect_config_loaded(sut)) return(invisible(NULL))
api/tests/testthat/test-mcp-select-principal-config.R-52-
api/tests/testthat/test-mcp-select-principal-config.R:53:  config <- with_mcp_env(valid_mcp_env(), sut$env$mcp_readonly_config())
api/tests/testthat/test-mcp-select-principal-config.R-54-
api/tests/testthat/test-mcp-select-principal-config.R-55-  expect_identical(config$host, "mysql")
api/tests/testthat/test-mcp-select-principal-config.R-56-  expect_identical(config$port, 3306L)
api/tests/testthat/test-mcp-select-principal-config.R-57-  expect_identical(config$dbname, "sysndd_db")
api/tests/testthat/test-mcp-select-principal-config.R-58-  expect_identical(config$user, "sysndd_mcp")
--
api/tests/testthat/test-mcp-select-principal-config.R-71-  )
api/tests/testthat/test-mcp-select-principal-config.R-72-  withr::local_dir(withr::local_tempdir(pattern = "mcp-config-"))
api/tests/testthat/test-mcp-select-principal-config.R-73-  writeLines("default:\n  user: api-user\n  password: api-secret", "config.yml")
api/tests/testthat/test-mcp-select-principal-config.R-74-
api/tests/testthat/test-mcp-select-principal-config.R-75-  expect_error(
api/tests/testthat/test-mcp-select-principal-config.R:76:    with_mcp_env(api_env, sut$env$mcp_readonly_config()),
api/tests/testthat/test-mcp-select-principal-config.R-77-    class = "mcp_config_error"
api/tests/testthat/test-mcp-select-principal-config.R-78-  )
api/tests/testthat/test-mcp-select-principal-config.R-79-})
api/tests/testthat/test-mcp-select-principal-config.R-80-
api/tests/testthat/test-mcp-select-principal-config.R-81-test_that("MCP identity, connection fields, port and pool bounds fail closed", {
--
api/tests/testthat/test-mcp-select-principal-config.R-96-    c(MCP_DB_POOL_SIZE = "2.5")
api/tests/testthat/test-mcp-select-principal-config.R-97-  )
api/tests/testthat/test-mcp-select-principal-config.R-98-
api/tests/testthat/test-mcp-select-principal-config.R-99-  for (override in invalid) {
api/tests/testthat/test-mcp-select-principal-config.R-100-    expect_error(
api/tests/testthat/test-mcp-select-principal-config.R:101:      with_mcp_env(do.call(valid_mcp_env, as.list(override)), sut$env$mcp_readonly_config()),
api/tests/testthat/test-mcp-select-principal-config.R-102-      class = "mcp_config_error"
api/tests/testthat/test-mcp-select-principal-config.R-103-    )
api/tests/testthat/test-mcp-select-principal-config.R-104-  }
api/tests/testthat/test-mcp-select-principal-config.R-105-})
api/tests/testthat/test-mcp-select-principal-config.R-106-
--
api/tests/testthat/test-mcp-select-principal-config.R-113-  Sys.chmod(secret_path, mode = "0600")
api/tests/testthat/test-mcp-select-principal-config.R-114-  on.exit(unlink(secret_path), add = TRUE)
api/tests/testthat/test-mcp-select-principal-config.R-115-
api/tests/testthat/test-mcp-select-principal-config.R-116-  file_config <- with_mcp_env(
api/tests/testthat/test-mcp-select-principal-config.R-117-    valid_mcp_env(MCP_DB_PASSWORD = NA_character_, MCP_DB_PASSWORD_FILE = secret_path),
api/tests/testthat/test-mcp-select-principal-config.R:118:    sut$env$mcp_readonly_config()
api/tests/testthat/test-mcp-select-principal-config.R-119-  )
api/tests/testthat/test-mcp-select-principal-config.R-120-  expect_identical(file_config$password, "file-secret")
api/tests/testthat/test-mcp-select-principal-config.R-121-
api/tests/testthat/test-mcp-select-principal-config.R-122-  expect_error(
api/tests/testthat/test-mcp-select-principal-config.R-123-    with_mcp_env(
api/tests/testthat/test-mcp-select-principal-config.R-124-      valid_mcp_env(
api/tests/testthat/test-mcp-select-principal-config.R-125-        MCP_DB_PASSWORD = "direct-secret",
api/tests/testthat/test-mcp-select-principal-config.R-126-        MCP_DB_PASSWORD_FILE = NA_character_
api/tests/testthat/test-mcp-select-principal-config.R-127-      ),
api/tests/testthat/test-mcp-select-principal-config.R:128:      sut$env$mcp_readonly_config()
api/tests/testthat/test-mcp-select-principal-config.R-129-    ),
api/tests/testthat/test-mcp-select-principal-config.R-130-    class = "mcp_config_error"
api/tests/testthat/test-mcp-select-principal-config.R-131-  )
api/tests/testthat/test-mcp-select-principal-config.R-132-
api/tests/testthat/test-mcp-select-principal-config.R-133-  Sys.chmod(secret_path, mode = "0644")
api/tests/testthat/test-mcp-select-principal-config.R-134-  expect_error(
api/tests/testthat/test-mcp-select-principal-config.R-135-    with_mcp_env(
api/tests/testthat/test-mcp-select-principal-config.R-136-      valid_mcp_env(MCP_DB_PASSWORD = NA_character_, MCP_DB_PASSWORD_FILE = secret_path),
api/tests/testthat/test-mcp-select-principal-config.R:137:      sut$env$mcp_readonly_config()
api/tests/testthat/test-mcp-select-principal-config.R-138-    ),
api/tests/testthat/test-mcp-select-principal-config.R-139-    class = "mcp_config_error"
api/tests/testthat/test-mcp-select-principal-config.R-140-  )
api/tests/testthat/test-mcp-select-principal-config.R-141-})
api/tests/testthat/test-mcp-select-principal-config.R-142-
--
api/tests/testthat/test-mcp-select-principal-config.R-145-  if (!expect_config_loaded(sut)) return(invisible(NULL))
api/tests/testthat/test-mcp-select-principal-config.R-146-
api/tests/testthat/test-mcp-select-principal-config.R-147-  sut$env$get <- function(...) stop("masked get called")
api/tests/testthat/test-mcp-select-principal-config.R-148-  sut$env$exists <- function(...) stop("masked exists called")
api/tests/testthat/test-mcp-select-principal-config.R-149-
api/tests/testthat/test-mcp-select-principal-config.R:150:  expect_silent(with_mcp_env(valid_mcp_env(), sut$env$mcp_readonly_config()))
api/tests/testthat/test-mcp-select-principal-config.R-151-  source_text <- paste(readLines(config_path, warn = FALSE), collapse = "\n")
api/tests/testthat/test-mcp-select-principal-config.R-152-  expect_false(grepl("(?<!base::)\\b(get|exists)\\s*\\(", source_text, perl = TRUE))
api/tests/testthat/test-mcp-select-principal-config.R-153-})
api/tests/testthat/test-mcp-select-principal-config.R-154-
api/tests/testthat/test-mcp-select-principal-config.R-155-test_that("dedicated MCP pool uses the validated bounded size", {
--
api/tests/testthat/test-mcp-select-principal-config.R-314-  expect_match(script, 'source\\("functions/mcp-readonly-attestation.R"')
api/tests/testthat/test-mcp-select-principal-config.R-315-  expect_match(script, 'base::get\\("mcp_readonly_config"')
api/tests/testthat/test-mcp-select-principal-config.R-316-  expect_match(script, 'base::get\\("bootstrap_create_mcp_pool"')
api/tests/testthat/test-mcp-select-principal-config.R-317-  expect_match(script, 'base::get\\("mcp_readonly_attest"')
api/tests/testthat/test-mcp-select-principal-config.R-318-  expect_lt(regexpr("mcp_readonly_attest", script)[1], regexpr("mcp_server", script)[1])
api/tests/testthat/test-mcp-select-principal-config.R:319:  expect_false(grepl("config::get|API_CONFIG|bootstrap_create_pool|init_cache|bootstrap_bind_memoised", script))
api/tests/testthat/test-mcp-select-principal-config.R-320-  expect_match(script, "base::get")
api/tests/testthat/test-mcp-select-principal-config.R-321-  expect_match(script, "base::exists")
api/tests/testthat/test-mcp-select-principal-config.R-322-})
--
api/tests/testthat/test-unit-metadata-refresh-patterns.R-41-  }
api/tests/testthat/test-unit-metadata-refresh-patterns.R-42-
api/tests/testthat/test-unit-metadata-refresh-patterns.R-43-  expect_length(violations, 0)
api/tests/testthat/test-unit-metadata-refresh-patterns.R-44-})
api/tests/testthat/test-unit-metadata-refresh-patterns.R-45-
api/tests/testthat/test-unit-metadata-refresh-patterns.R:46:test_that("metadata-refresh.R dispatches log_warn via base::get (config::get mask, LOW-7)", {
api/tests/testthat/test-unit-metadata-refresh-patterns.R-47-  path <- file.path(get_api_dir(), "functions", "metadata-refresh.R")
api/tests/testthat/test-unit-metadata-refresh-patterns.R-48-  src <- paste(readLines(path, warn = FALSE), collapse = "\n")
api/tests/testthat/test-unit-metadata-refresh-patterns.R:49:  # config::get masks base::get (no `mode` arg) in the loaded API/worker env, so
api/tests/testthat/test-unit-metadata-refresh-patterns.R-50-  # a bare get(name, mode = "function") errors -> the warn silently degrades.
api/tests/testthat/test-unit-metadata-refresh-patterns.R-51-  expect_match(src, 'base::get("log_warn", mode = "function")', fixed = TRUE)
api/tests/testthat/test-unit-metadata-refresh-patterns.R-52-  # No bare get("log_warn", mode = ...) remains.
api/tests/testthat/test-unit-metadata-refresh-patterns.R-53-  expect_false(grepl('[^:]get\\("log_warn", mode', src))
api/tests/testthat/test-unit-metadata-refresh-patterns.R-54-})
--
api/tests/testthat/test-unit-llm-regenerate.R-51-  env$is_gemini_configured <- function() TRUE
api/tests/testthat/test-unit-llm-regenerate.R-52-  env$create_job <- function(operation, params) {
api/tests/testthat/test-unit-llm-regenerate.R-53-    captured$params <- params
api/tests/testthat/test-unit-llm-regenerate.R-54-    list(job_id = "job-1")
api/tests/testthat/test-unit-llm-regenerate.R-55-  }
api/tests/testthat/test-unit-llm-regenerate.R:56:  # Force reading config.yml to succeed by stubbing config::get through the env.
api/tests/testthat/test-unit-llm-regenerate.R-57-  # Simpler: point db_config resolution at a minimal config via a stub of the
api/tests/testthat/test-unit-llm-regenerate.R-58-  # helper path is not exposed, so instead stub the whole config read by giving
api/tests/testthat/test-unit-llm-regenerate.R-59-  # a config.yml-independent path: provide a fake `config` list via options is
api/tests/testthat/test-unit-llm-regenerate.R-60-  # not possible here. We rely on the real config.yml presence in api/ for the
api/tests/testthat/test-unit-llm-regenerate.R-61-  # db_config block; if it is unavailable, skip.
--
api/tests/testthat/test-e2e-user-lifecycle.R-17-# Test Configuration
api/tests/testthat/test-e2e-user-lifecycle.R-18-# =============================================================================
api/tests/testthat/test-e2e-user-lifecycle.R-19-
api/tests/testthat/test-e2e-user-lifecycle.R-20-# Get API base URL from config (typically http://localhost:7779)
api/tests/testthat/test-e2e-user-lifecycle.R-21-get_api_base_url <- function() {
api/tests/testthat/test-e2e-user-lifecycle.R:22:  config <- get_test_config()
api/tests/testthat/test-e2e-user-lifecycle.R-23-  config$api_base_url %||% "http://localhost:7779"
api/tests/testthat/test-e2e-user-lifecycle.R-24-}
api/tests/testthat/test-e2e-user-lifecycle.R-25-
api/tests/testthat/test-e2e-user-lifecycle.R-26-# Check if API server is available
api/tests/testthat/test-e2e-user-lifecycle.R-27-api_available <- function() {
--
api/tests/testthat/test-e2e-user-lifecycle.R-88-  # Otherwise construct minimal admin token
api/tests/testthat/test-e2e-user-lifecycle.R-89-  if (exists("create_test_jwt")) {
api/tests/testthat/test-e2e-user-lifecycle.R-90-    create_test_jwt(user_id = 1, user_role = "Administrator")
api/tests/testthat/test-e2e-user-lifecycle.R-91-  } else {
api/tests/testthat/test-e2e-user-lifecycle.R-92-    # Fallback: construct token manually
api/tests/testthat/test-e2e-user-lifecycle.R:93:    config <- get_test_config()

exec
/bin/bash -lc "rg -n -C 30 'active_request_hash|idx_async_jobs_active_request_hash' db/migrations db/schema.sql" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 exited 2 in 0ms:
rg: db/schema.sql: No such file or directory (os error 2)
db/migrations/020_add_async_job_schema.sql-1--- Migration: 020_add_async_job_schema
db/migrations/020_add_async_job_schema.sql-2--- Description: Adds durable async job and event storage for MySQL-backed workers
db/migrations/020_add_async_job_schema.sql-3-
db/migrations/020_add_async_job_schema.sql-4-CREATE TABLE async_jobs (
db/migrations/020_add_async_job_schema.sql-5-    job_id CHAR(36) NOT NULL PRIMARY KEY,
db/migrations/020_add_async_job_schema.sql-6-    job_type VARCHAR(64) NOT NULL,
db/migrations/020_add_async_job_schema.sql-7-    queue_name VARCHAR(64) NOT NULL DEFAULT 'default',
db/migrations/020_add_async_job_schema.sql-8-    priority INT NOT NULL DEFAULT 100,
db/migrations/020_add_async_job_schema.sql-9-    status ENUM('queued', 'running', 'completed', 'failed', 'cancel_requested', 'cancelled') NOT NULL DEFAULT 'queued',
db/migrations/020_add_async_job_schema.sql-10-    request_hash CHAR(64) NOT NULL,
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
db/migrations/020_add_async_job_schema.sql-34-                WHEN status IN ('queued', 'running', 'cancel_requested') THEN request_hash
db/migrations/020_add_async_job_schema.sql-35-                WHEN status = 'failed'
db/migrations/020_add_async_job_schema.sql-36-                     AND attempt_count < max_attempts
db/migrations/020_add_async_job_schema.sql-37-                     AND next_attempt_at IS NOT NULL THEN request_hash
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
db/migrations/020_add_async_job_schema.sql-57-    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
db/migrations/020_add_async_job_schema.sql-58-    KEY idx_async_job_events_job_created (job_id, created_at),
db/migrations/020_add_async_job_schema.sql-59-    CONSTRAINT fk_async_job_events_job
db/migrations/020_add_async_job_schema.sql-60-        FOREIGN KEY (job_id) REFERENCES async_jobs(job_id) ON DELETE CASCADE
db/migrations/020_add_async_job_schema.sql-61-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

codex
The core resolver follows the intended entity-level query and allowlist pattern. I’ve found concrete contract risks in provenance/test execution and am running the focused tests to distinguish real failures from hypothetical concerns.
exec
/bin/bash -lc "rg -n 'has_genes|category_supplied|resolved_gene_count|gene_list_sha256|clustering_cached_source' api/tests/testthat/test-unit-job-endpoint-services.R api/tests/testthat/test-unit-clustering-gene-universe.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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
api/tests/testthat/test-unit-clustering-gene-universe.R:159:  expect_identical(r$resolved_gene_count, 2L)
api/tests/testthat/test-unit-clustering-gene-universe.R:218:test_that("gene_list_sha256 is sort-order independent", {
api/tests/testthat/test-unit-clustering-gene-universe.R:222:    e$clustering_gene_list_sha256(c("HGNC:3", "HGNC:1")),
api/tests/testthat/test-unit-clustering-gene-universe.R:223:    e$clustering_gene_list_sha256(c("HGNC:1", "HGNC:3"))
api/tests/testthat/test-unit-job-endpoint-services.R:61:    list(hgnc_ids = hgnc_ids, selector = NULL, resolved_gene_count = length(hgnc_ids))
api/tests/testthat/test-unit-job-endpoint-services.R:66:#' now computes `intended_fingerprint`/`gene_list_sha256`/`source_data_version`
api/tests/testthat/test-unit-job-endpoint-services.R:71:  env$clustering_gene_list_sha256 <- function(hgnc_ids) paste0("sha-", length(hgnc_ids))
api/tests/testthat/test-unit-job-endpoint-services.R:72:  env$clustering_cached_source_data_version <- function(...) "srcv-test"
api/tests/testthat/test-unit-job-endpoint-services.R:162:  expect_equal(result_meta$gene_list_sha256, "sha-1") # job_endpoint_stub_clustering_provenance: paste0("sha-", length(genes))
api/tests/testthat/test-unit-job-endpoint-services.R:263:    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
api/tests/testthat/test-unit-job-endpoint-services.R:288:    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
api/tests/testthat/test-unit-job-endpoint-services.R:361:  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
api/tests/testthat/test-unit-job-endpoint-services.R:362:  env$clustering_cached_source_data_version <- function(...) stop("boom")

exec
/bin/bash -lc "nl -ba api/functions/async-job-service.R | sed -n '240,285p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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

exec
/bin/bash -lc 'git diff --unified=8 origin/master...HEAD -- api/tests/testthat/test-unit-job-endpoint-services.R api/tests/testthat/job-endpoint-services-fixtures.R api/tests/testthat/test-unit-async-job-handlers.R api/tests/testthat/test-unit-async-job-worker.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
diff --git a/api/tests/testthat/job-endpoint-services-fixtures.R b/api/tests/testthat/job-endpoint-services-fixtures.R
index 103f4621..d2deaae1 100644
--- a/api/tests/testthat/job-endpoint-services-fixtures.R
+++ b/api/tests/testthat/job-endpoint-services-fixtures.R
@@ -17,19 +17,29 @@ library(dplyr)
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
diff --git a/api/tests/testthat/test-unit-async-job-handlers.R b/api/tests/testthat/test-unit-async-job-handlers.R
index 30f63cef..dd50b54d 100644
--- a/api/tests/testthat/test-unit-async-job-handlers.R
+++ b/api/tests/testthat/test-unit-async-job-handlers.R
@@ -1,12 +1,16 @@
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
 
diff --git a/api/tests/testthat/test-unit-async-job-worker.R b/api/tests/testthat/test-unit-async-job-worker.R
index 792903e1..237528a0 100644
--- a/api/tests/testthat/test-unit-async-job-worker.R
+++ b/api/tests/testthat/test-unit-async-job-worker.R
@@ -11,16 +11,19 @@ async_job_worker_runtime_paths <- function() {
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
diff --git a/api/tests/testthat/test-unit-job-endpoint-services.R b/api/tests/testthat/test-unit-job-endpoint-services.R
index 3bb4b43f..49e3ac2a 100644
--- a/api/tests/testthat/test-unit-job-endpoint-services.R
+++ b/api/tests/testthat/test-unit-job-endpoint-services.R
@@ -43,23 +43,48 @@ job_endpoint_functional_pool <- function(env, ndd_entity_view = NULL) {
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
 
@@ -92,18 +117,24 @@ test_that("functional clustering: algorithm input is coerced to a lowercase scal
 
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
@@ -116,23 +147,33 @@ test_that("functional clustering: cache hit stores a completed job without calli
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
@@ -148,18 +189,21 @@ test_that("functional clustering: capacity guard (503) then a cache miss under c
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
@@ -182,16 +226,161 @@ test_that("functional clustering: admission throttle runs FIRST, before any DB/c
   res <- job_endpoint_fake_res()
   out <- env$svc_job_submit_functional_clustering(req, res)
   expect_equal(res$status, 429)
   expect_equal(out$error, "RATE_LIMITED")
   expect_false(pool_touched)
   expect_false(create_job_called)
 })
 
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
+  env$create_job <- function(operation, params) {
+    captured <<- params
+    list(job_id = "j1", status = "accepted", estimated_seconds = 5)
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
+  create_job_called <- FALSE
+  env$create_job <- function(...) {
+    create_job_called <<- TRUE
+    NULL
+  }
+  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
+  res <- job_endpoint_fake_res()
+
+  out <- env$svc_job_submit_functional_clustering(req, res)
+
+  expect_equal(res$status, 503L)
+  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
+  expect_false(create_job_called)
+})
+
 ## -------------------------------------------------------------------##
 ## job-phenotype-submission-service.R
 ## -------------------------------------------------------------------##
 
 job_endpoint_phenotype_single_entity_pool <- function(env) {
   job_endpoint_fake_pool(env, list(
     ndd_entity_view = tibble::tibble(
       entity_id = 1L, hgnc_id = "HGNC:1", symbol = "GENE1",

exec
/bin/bash -lc "nl -ba api/tests/testthat/setup.R | sed -n '1,260p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
     1	# tests/testthat/setup.R
     2	# Global test setup - runs before any test file
     3	
     4	# Load testing libraries
     5	library(testthat)
     6	library(dittodb)
     7	library(withr)
     8	library(httr2)
     9	library(jose)  # For JWT token testing
    10	
    11	# Load tidyverse for data manipulation (used in assertions)
    12	library(dplyr)
    13	library(tibble)
    14	library(stringr)
    15	
    16	# Resolve dplyr/AnnotationDbi select() conflict
    17	# AnnotationDbi (via biomaRt) masks dplyr::select, causing test failures
    18	# See: https://conflicted.r-lib.org/ and https://tidyverse.tidyverse.org/reference/tidyverse_conflicts.html
    19	if (requireNamespace("conflicted", quietly = TRUE)) {
    20	  conflicted::conflicts_prefer(dplyr::select)
    21	  conflicted::conflicts_prefer(dplyr::filter)
    22	} else {
    23	  # Fallback: ensure dplyr methods are accessible
    24	  # This helps when source()'d files use bare select()
    25	  select <- dplyr::select
    26	  filter <- dplyr::filter
    27	}
    28	
    29	# Source helper files (will be created in subsequent plans)
    30	# These use test_path() for portable path resolution
    31	helper_files <- list.files(
    32	  test_path(),
    33	  pattern = "^helper-.*\\.R$",
    34	  full.names = TRUE
    35	)
    36	for (helper in helper_files) {
    37	  source(helper, local = TRUE)
    38	}
    39	
    40	# Configure testthat options
    41	withr::local_options(
    42	  list(
    43	    testthat.progress.max_fails = 50,  # Don't stop early
    44	    testthat.progress.show_status = TRUE
    45	  ),
    46	  .local_envir = teardown_env()
    47	)
    48	
    49	# Log test initialization
    50	message("SysNDD API test environment initialized")

exec
/bin/bash -lc "rg -n 'base::get|bare.*get|config::get masks' api/tests/testthat/test-unit-base-exists-get-guard.R api/tests/testthat | head -n 200" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
exec
/bin/bash -lc "rg -n '"'^library'"\\(config\\)|"'^require'"\\(config\\)|loadNamespace\\(\"config\"' api/tests/testthat api/tests | head -n 100" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
 succeeded in 0ms:
api/tests/testthat/test-unit-base-exists-get-guard.R:4:# namespaced as base::exists / base::get.
api/tests/testthat/test-unit-base-exists-get-guard.R:24:# An offending line passes `inherits` to a *bare* exists()/get() call --
api/tests/testthat/test-unit-base-exists-get-guard.R:25:# i.e. one not already namespaced as `base::exists` / `base::get` (and not part
api/tests/testthat/test-unit-base-exists-get-guard.R:56:  offenders <- bare_inherits_offenders("get", guarded_source_files())
api/tests/testthat/test-unit-base-exists-get-guard.R:60:      "Use base::get() when passing inherits= (masked-verb guard):",
api/tests/testthat/test-unit-metadata-refresh-patterns.R:46:test_that("metadata-refresh.R dispatches log_warn via base::get (config::get mask, LOW-7)", {
api/tests/testthat/test-unit-metadata-refresh-patterns.R:49:  # config::get masks base::get (no `mode` arg) in the loaded API/worker env, so
api/tests/testthat/test-unit-metadata-refresh-patterns.R:50:  # a bare get(name, mode = "function") errors -> the warn silently degrades.
api/tests/testthat/test-unit-metadata-refresh-patterns.R:51:  expect_match(src, 'base::get("log_warn", mode = "function")', fixed = TRUE)
api/tests/testthat/test-unit-metadata-refresh-patterns.R:52:  # No bare get("log_warn", mode = ...) remains.
api/tests/testthat/test-unit-llm-endpoint-helpers.R:40:      prev <- if (had_prev) base::get(name, envir = .GlobalEnv, inherits = FALSE) else NULL
api/tests/testthat/test-unit-base-exists-get-guard.R:4:# namespaced as base::exists / base::get.
api/tests/testthat/test-unit-base-exists-get-guard.R:24:# An offending line passes `inherits` to a *bare* exists()/get() call --
api/tests/testthat/test-unit-base-exists-get-guard.R:25:# i.e. one not already namespaced as `base::exists` / `base::get` (and not part
api/tests/testthat/test-unit-base-exists-get-guard.R:56:  offenders <- bare_inherits_offenders("get", guarded_source_files())
api/tests/testthat/test-unit-base-exists-get-guard.R:60:      "Use base::get() when passing inherits= (masked-verb guard):",
api/tests/testthat/test-unit-seo-approved-only-guard.R:20:    sql <- base::get(fn)()
api/tests/testthat/test-unit-llm-prompt-template-repository.R:142:  original_pool <- if (had_global_pool) base::get("pool", envir = .GlobalEnv) else NULL
api/tests/testthat/test-mcp-select-principal-config.R:315:  expect_match(script, 'base::get\\("mcp_readonly_config"')
api/tests/testthat/test-mcp-select-principal-config.R:316:  expect_match(script, 'base::get\\("bootstrap_create_mcp_pool"')
api/tests/testthat/test-mcp-select-principal-config.R:317:  expect_match(script, 'base::get\\("mcp_readonly_attest"')
api/tests/testthat/test-mcp-select-principal-config.R:320:  expect_match(script, "base::get")
api/tests/testthat/test-unit-analysis-cache-fingerprint.R:63:test_that("fingerprint dispatch survives a masked base::get (config::get has no `mode` arg) (#514)", {
api/tests/testthat/test-unit-analysis-cache-fingerprint.R:64:  # Regression: config::get (loaded for DB config) masks base::get with a signature
api/tests/testthat/test-unit-analysis-cache-fingerprint.R:69:    base::get("get", envir = globalenv(), inherits = FALSE)
api/tests/testthat/test-mcp-select-principal-db-boundary.R:10:  if (prior_pool_exists) prior_pool <- base::get("pool", envir = .GlobalEnv)
api/tests/testthat/test-unit-async-job-repository.R:51:test_that("async job repository helpers load correctly when config masks base::get", {

exec
/bin/bash -lc "rg -n 'base::get\\(\"pool\"|get\\(\"pool\", envir = \\.GlobalEnv\\)' api/tests/testthat | head -n 100" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
api/tests/testthat/test-unit-endpoint-functions.R:564:  old_pool <- if (exists("pool", envir = .GlobalEnv)) get("pool", envir = .GlobalEnv) else NULL
api/tests/testthat/test-unit-panels-endpoint.R:450:  old_pool <- if (exists("pool", envir = .GlobalEnv)) get("pool", envir = .GlobalEnv) else NULL
api/tests/testthat/test-unit-llm-prompt-template-repository.R:142:  original_pool <- if (had_global_pool) base::get("pool", envir = .GlobalEnv) else NULL
api/tests/testthat/test-integration-clustering-category-submit.R:158:    old_pool <- if (exists("pool", envir = .GlobalEnv)) get("pool", envir = .GlobalEnv) else NULL
api/tests/testthat/test-mcp-select-principal-db-boundary.R:10:  if (prior_pool_exists) prior_pool <- base::get("pool", envir = .GlobalEnv)

codex
- **HIGH** — [job-functional-submission-service.R:61](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:61)  
  `{"genes":[],"category_filter":["Definitive"]}` bypasses mutual exclusion: `has_genes` is false for an explicitly supplied empty `genes` array, so the category job is accepted. The locked contract requires any `genes` + non-empty `category_filter` combination to 400. Track `genes_supplied <- !is.null(genes_in)` separately and use it for the mutual-exclusion guard.

- **HIGH** — [clustering-gene-universe.R:116](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/functions/clustering-gene-universe.R:116)  
  The TTL cache accepts and caches `NA`/empty source versions. If the source-version read succeeds structurally but returns `NA_character_` (for example, a malformed/NULL view result), it is persisted in provenance rather than returning `503 PROVENANCE_UNAVAILABLE`; subsequent requests reuse it for the TTL. This violates the locked “never records NA” fail-closed requirement. Validate both fetched and cached values as one non-empty, non-NA string; clear/reject invalid cache entries and throw so the service maps it to 503.

- **MEDIUM** — [job-functional-submission-service.R:142](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:142), [job-functional-submission-service.R:163](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:163)  
  Explicit duplicate genes make provenance internally inconsistent. `{"genes":["HGNC:1","HGNC:1"]}` records `resolved_gene_count = 2`, while `gene_list_sha256` hashes sorted-unique IDs and is identical to the singleton universe. Record the count as `length(unique(genes_list))` (or normalize explicit IDs consistently before provenance).

- **LOW** — [test-integration-clustering-category-submit.R:158](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/tests/testthat/test-integration-clustering-category-submit.R:158)  
  The populated-DB NULL-branch test uses bare `get()`. In an API-loaded R session, `config::get` masks it and rejects `envir`, so the test aborts before validating the pool rebinding. Use `base::get("pool", envir = .GlobalEnv)`.

`git diff --check` was clean. Focused R tests could not run because the read-only sandbox prevents R from creating its temporary `-e` file.

**VERDICT: NO-SHIP — 0 BLOCKER findings (2 HIGH).**
tokens used
144,204
- **HIGH** — [job-functional-submission-service.R:61](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:61)  
  `{"genes":[],"category_filter":["Definitive"]}` bypasses mutual exclusion: `has_genes` is false for an explicitly supplied empty `genes` array, so the category job is accepted. The locked contract requires any `genes` + non-empty `category_filter` combination to 400. Track `genes_supplied <- !is.null(genes_in)` separately and use it for the mutual-exclusion guard.

- **HIGH** — [clustering-gene-universe.R:116](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/functions/clustering-gene-universe.R:116)  
  The TTL cache accepts and caches `NA`/empty source versions. If the source-version read succeeds structurally but returns `NA_character_` (for example, a malformed/NULL view result), it is persisted in provenance rather than returning `503 PROVENANCE_UNAVAILABLE`; subsequent requests reuse it for the TTL. This violates the locked “never records NA” fail-closed requirement. Validate both fetched and cached values as one non-empty, non-NA string; clear/reject invalid cache entries and throw so the service maps it to 503.

- **MEDIUM** — [job-functional-submission-service.R:142](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:142), [job-functional-submission-service.R:163](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:163)  
  Explicit duplicate genes make provenance internally inconsistent. `{"genes":["HGNC:1","HGNC:1"]}` records `resolved_gene_count = 2`, while `gene_list_sha256` hashes sorted-unique IDs and is identical to the singleton universe. Record the count as `length(unique(genes_list))` (or normalize explicit IDs consistently before provenance).

- **LOW** — [test-integration-clustering-category-submit.R:158](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/tests/testthat/test-integration-clustering-category-submit.R:158)  
  The populated-DB NULL-branch test uses bare `get()`. In an API-loaded R session, `config::get` masks it and rejects `envir`, so the test aborts before validating the pool rebinding. Use `base::get("pool", envir = .GlobalEnv)`.

`git diff --check` was clean. Focused R tests could not run because the read-only sandbox prevents R from creating its temporary `-e` file.

**VERDICT: NO-SHIP — 0 BLOCKER findings (2 HIGH).**
