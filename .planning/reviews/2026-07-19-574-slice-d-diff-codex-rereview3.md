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
session id: 019f77b7-4a6e-77d2-b923-0bd9368eb771
--------
user
Third-pass review of feature #574 (category-selected gene universes for functional clustering). Run `git diff origin/master...HEAD -- ':(exclude).planning/**'`. Read touched files in full.

Your round-2 review returned NO-SHIP with 1 HIGH + 1 MEDIUM. Both were addressed:
1. HIGH — mutual exclusion now uses JSON key-presence via `names(req$argsBody)` (`genes_key && category_key` → 400), so `{"genes":null,"category_filter":[...]}` AND `{"genes":[],"category_filter":[...]}` both 400, while `{"genes":null}` / `{"genes":[]}` alone still default, and `{"genes":["X"]}` alone is still explicit. VERIFY this is correct and that no valid single-selector request now wrongly 400s.
2. MEDIUM — `.async_job_run_clustering` now sets `gene_count = length(unique(genes))`, matching the cache-hit path's `resolved_count`. VERIFY both paths now agree for duplicate genes and that `nrow(clusters)`/payload `genes` were not changed.

Confirm explicitly whether each is resolved. Then do a final adversarial pass for anything still lurking — but do NOT invent speculative or stylistic findings; only report a finding you can tie to a concrete failure scenario (specific inputs → wrong output/crash/contract violation). Re-confirm the locked contract holds: entity-level resolution; NULL/absent→default cache parity; supplied-empty category→400; <2 genes→400; allowed set in the error MESSAGE; selector-aware dedup additive-only (explicit/no-arg request_hash byte-identical); provenance + effective_fingerprint on both cache-hit and worker paths; fail-closed source_data_version (never NA, 503 on failure); never public_ready; dbplyr `%in%` not string interpolation; `dplyr::`/`base::get` namespacing; touched files < 600 lines.

Output: for each finding, severity (BLOCKER/HIGH/MEDIUM/LOW), file:line, concrete failure scenario, fix. Final line: **VERDICT: SHIP** (zero BLOCKER/HIGH) or **VERDICT: NO-SHIP** with the count.
codex
I’ll inspect the requested merge-base diff and read every touched source/test file in full, then verify the two stated fixes against the locked request contracts.
exec
/bin/bash -lc "sed -n '1,240p' /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-security-bug-scan/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-code-quality/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-async-jobs/SKILL.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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

codex
I’m using the repository’s security, code-quality, async-job, and analysis-snapshot review guides because this change crosses a public submit endpoint, dbplyr query construction, and worker execution.
exec
/bin/bash -lc "sed -n '1,320p' .agents/skills/sysndd-analysis-snapshots/SKILL.md && git diff --stat origin/master...HEAD -- ':(exclude).planning/**' && git diff --name-only origin/master...HEAD -- ':(exclude).planning/**' && git diff --check origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
---
name: sysndd-analysis-snapshots
description: Use when changing gene clustering (STRING/Leiden functional axis or phenotype MCA/HCPC), the analysis snapshot builder or validator, the memoised clustering cache, cache coherence, or LLM cluster summaries — or deploying a clustering change so public endpoints and summaries reflect it
---

# SysNDD Analysis Snapshots & Cache Coherence

Use this skill before touching clustering, the snapshot builder/validator, the clustering cache, or LLM cluster summaries. This subsystem (#508–#514) is coherence-sensitive: a subtle mistake serves a stale, internally-incoherent snapshot that still activates as public-ready.

## Architecture

- Public endpoints (`/api/analysis/functional_clustering`, `.../phenotype_clustering`) read **activated `analysis_snapshot_*` rows** — not live compute. Nothing public changes until a **snapshot refresh job** (worker) rebuilds and activates a new row.
- Heavy clustering (`gen_string_clust_obj`, `gen_mca_clust_obj`, `gen_network_edges`) is **memoised to a disk cache on a named volume that SURVIVES redeploys** (`bootstrap/init_cache.R`).
- The builder reads **membership** from the memoised function; the **validator** (`validate_functional_clusters`, not memoised) recomputes fresh. They are coherent only when both clustered the identical graph with the identical seed.

## The Additivity Lever

`analysis_snapshot_payload_hash` **excludes** `partition_validation` and `reproducibility` (`analysis-snapshot-builder.R`). So new validation metrics are **additive** — they never change `cluster_hash` and never invalidate LLM summaries. Only changes to cluster **membership** (graph construction, STRING channel, MCA hygiene, Leiden/HCPC params) change `cluster_hash`.

## Cache Invalidation — Two Mechanisms

The memoise key is call-args **plus a call-time `.cache_fingerprint`** (`analysis-cache-fingerprint.R`).

- **Code change to clustering inputs/algorithm → bump `CLUSTER_LOGIC_VERSION`.** This is the only thing that changes the key for a code-only change; the data-identity components (STRING channel, exp+db file `size:mtime`, MCA prevalence band) won't. This **supersedes** the manual `CACHE_VERSION` bump for clustering caches (`CACHE_VERSION` nukes *all* memoised `.rds` and still governs other return-shape changes).
- **Data/channel/prevalence change → self-invalidates** via the fingerprint at call time, no restart needed.

## The Coherence Gate — Do Not Bypass

The builder joins validation onto membership **only** through `analysis_snapshot_join_validated_clusters()` → `analysis_snapshot_assert_partition_coherent()` (`analysis-snapshot-coherence.R`). It refuses to publish (throws → refresh fails → prior public-ready retained) when the visible membership cluster set ≠ the validation set, a visible cluster lacks a stability score, or the membership channel ≠ the validation channel. **Never reintroduce a bare `left_join(clusters, val$per_cluster)`.** `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE` defaults `true`; setting it `false` to "get a refresh through" re-opens the incoherent-publish hole — bump `CLUSTER_LOGIC_VERSION` instead.

## LLM Summaries

Keyed by per-cluster `cluster_hash` **plus `LLM_SUMMARY_PROMPT_VERSION`** (`llm-summary-config.R`). A membership change changes `cluster_hash`, so old summaries retire and regenerate. **Bump `LLM_SUMMARY_PROMPT_VERSION` only when the prompt or generation/judge logic changes** — not for a clustering change (the hash already handles that; bumping would gratuitously blank untouched clusters).

## Membership-Change Deploy Runbook

1. Ensure the exp+db artifact exists (`api/data/9606.protein.links.expdb.v11.5.min400.txt.gz`) if the functional axis needs it — else clustering silently falls back to the text-mining graph (loud via `warning()` + health flag).
2. Bump `CLUSTER_LOGIC_VERSION` (only for a code change).
3. Restart `worker` **and** `worker-maintenance` (worker-executed code; the refresh runs on the worker).
4. `POST /api/admin/analysis/snapshots/refresh?analysis_type=functional_clusters&force=true` (and `…phenotype_clusters`). **`force` is required** — a non-forced refresh skips a preset whose current snapshot is still `available`.
5. `POST /api/llm/regenerate?cluster_type=functional&force=true` (and `…phenotype`). **`force` required here too**, else it short-circuits on existing `is_current` rows.

## Verify

- Health endpoint (`health_endpoints.R`): `analysis.cluster_logic_version` == new value, `analysis.expdb_edges_file_present == true`.
- `GET /api/admin/analysis/snapshots/status`: preset `available`, fresh timestamps.
- Snapshot refresh job in history is **succeeded, not failed** (a coherence throw shows here — the tell you forgot the version bump).
- Public endpoint: every visible cluster has a **non-null stability score** (the #514 symptom was `n/a`), metrics agree, and `weight_channel`/`membership_weight_channel == experimental_database`.
- LLM: summaries map to a **new** `cluster_hash`. In the batch-generation log, "all cached / 0 generated" means membership did **not** change — the change was additive and a forced regen is wasteful.
 AGENTS.md                                          |   2 +
 CHANGELOG.md                                       |  47 +++
 api/bootstrap/load_modules.R                       |   6 +
 api/endpoints/jobs_endpoints.R                     |  35 +-
 api/functions/async-job-handlers.R                 |  41 +-
 api/functions/clustering-gene-universe.R           | 157 ++++++++
 api/services/job-functional-submission-service.R   | 183 +++++++--
 .../testthat/job-endpoint-services-fixtures.R      |  10 +
 .../test-integration-clustering-category-submit.R  | 206 ++++++++++
 api/tests/testthat/test-unit-async-job-handlers.R  |   4 +
 api/tests/testthat/test-unit-async-job-worker.R    |   3 +
 .../testthat/test-unit-clustering-gene-universe.R  | 278 +++++++++++++
 .../testthat/test-unit-clustering-handler-meta.R   | 171 ++++++++
 .../test-unit-job-endpoint-services-phenotype.R    | 223 +++++++++++
 .../testthat/test-unit-job-endpoint-services.R     | 439 +++++++++++++--------
 api/version_spec.json                              |   2 +-
 app/package-lock.json                              |   4 +-
 app/package.json                                   |   2 +-
 documentation/08-development.qmd                   |  15 +
 19 files changed, 1628 insertions(+), 200 deletions(-)
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
api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
api/tests/testthat/test-unit-job-endpoint-services.R
api/version_spec.json
app/package-lock.json
app/package.json
documentation/08-development.qmd

exec
/bin/bash -lc 'nl -ba api/functions/clustering-gene-universe.R && nl -ba api/services/job-functional-submission-service.R && nl -ba api/endpoints/jobs_endpoints.R && nl -ba api/functions/async-job-handlers.R && nl -ba api/bootstrap/load_modules.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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
    57	  category_supplied <- !is.null(req$argsBody$category_filter)
    58	  has_genes <- !is.null(genes_in) && length(genes_in) > 0
    59	
    60	  # Mutual exclusion is gated on JSON KEY PRESENCE, not value-nullness or
    61	  # length -- `!is.null(genes_in)` cannot distinguish an ABSENT `genes` key
    62	  # from an explicit JSON `null` (both parse to a NULL `req$argsBody$genes`
    63	  # in R), so `{"genes":null, "category_filter":["X"]}` previously slipped
    64	  # past the guard and silently ran a category job (Codex round-2 review
    65	  # fix). Checking `names(req$argsBody)` instead catches both an explicit
    66	  # null AND an empty array (`{"genes":[], "category_filter":["X"]}`,
    67	  # round-1's fix) because both forms keep the `genes` name in the parsed
    68	  # list. `has_genes`/`category_supplied` (value-based) are unchanged and
    69	  # still drive the LATER branch-selection decision below.
    70	  body_names <- names(req$argsBody)
    71	  genes_key <- "genes" %in% body_names
    72	  category_key <- "category_filter" %in% body_names
    73	
    74	  if (genes_key && category_key) {
    75	    stop_for_bad_request("Provide either genes or category_filter, not both")
    76	  }
    77	
    78	  # Extract algorithm parameter (default: leiden)
    79	  # Ensure we get a scalar value (JSON may pass arrays)
    80	  algorithm <- "leiden"
    81	  if (!is.null(req$argsBody$algorithm)) {
    82	    algo_input <- req$argsBody$algorithm
    83	    # Handle array input - always take first element if vector
    84	    if (is.list(algo_input) || length(algo_input) >= 1) {
    85	      algo_input <- algo_input[[1]]
    86	    }
    87	    algorithm <- tolower(as.character(algo_input))
    88	    if (!algorithm %in% c("leiden", "walktrap")) {
    89	      algorithm <- "leiden"
    90	    }
    91	  }
    92	
    93	  # Resolve the clustering gene universe + selector provenance (#574). The
    94	  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
    95	  # from before this feature: `clustering_resolve_category_universe(NULL)`
    96	  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
    97	  # so cache parity (memoise key = gene set + algorithm) is preserved.
    98	  selector_chr <- NULL
    99	  if (has_genes) {
   100	    genes_list <- as.character(unlist(genes_in))
   101	    kind <- "explicit"
   102	  } else if (category_supplied) {
   103	    universe <- clustering_resolve_category_universe(req$argsBody$category_filter)
   104	    genes_list <- universe$hgnc_ids
   105	    selector_chr <- universe$selector
   106	    kind <- "category"
   107	  } else {
   108	    universe <- clustering_resolve_category_universe(NULL)
   109	    genes_list <- universe$hgnc_ids
   110	    kind <- "all_ndd"
   111	  }
   112	
   113	  # Pre-fetch the STRING ID table because DB connections cannot cross the
   114	  # durable worker boundary.
   115	  string_id_table <- pool %>%
   116	    dplyr::tbl("non_alt_loci_set") %>%
   117	    dplyr::filter(!is.na(STRING_id)) %>%
   118	    dplyr::select(symbol, hgnc_id, STRING_id) %>%
   119	    dplyr::collect()
   120	
   121	  # Check for duplicate job (include algorithm in check). The selector is
   122	  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
   123	  # submits keep the pre-#574 dedup identity byte-identical.
   124	  dup_params <- list(genes = genes_list, algorithm = algorithm)
   125	  if (!is.null(selector_chr)) {
   126	    dup_params$category_filter <- selector_chr
   127	  }
   128	  dup_check <- check_duplicate_job("clustering", dup_params)
   129	  if (dup_check$duplicate) {
   130	    res$status <- 409
   131	    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
   132	    return(list(
   133	      error = "DUPLICATE_JOB",
   134	      message = "Identical job already running",
   135	      existing_job_id = dup_check$existing_job_id,
   136	      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
   137	    ))
   138	  }
   139	
   140	  # Cheap-path provenance (no expensive query yet). `selector_obj` records
   141	  # WHICH universe was resolved; `intended_fingerprint` records the STRING
   142	  # cache identity + fixed clustering params this submit intends to run
   143	  # with. The *effective* fingerprint (e.g. the STRING weight channel a
   144	  # computed result actually used) is only knowable from a computed result,
   145	  # so it is recorded separately in the cache-hit result meta below.
   146	  selector_obj <- list(kind = kind, category_filter = selector_chr)
   147	  intended_fingerprint <- list(
   148	    string_cache_fingerprint = analysis_string_cache_fingerprint(),
   149	    score_threshold = 400L,
   150	    algorithm = algorithm,
   151	    seed = 42L
   152	  )
   153	  gene_sha <- clustering_gene_list_sha256(genes_list)
   154	  # `gene_list_sha256` hashes sort(unique(...)); the provenance/meta gene
   155	  # count must agree with it, so it is computed from the SAME dedup -- an
   156	  # explicit payload with duplicate genes (e.g. `["HGNC:1","HGNC:1"]`) must
   157	  # not report a resolved count that disagrees with a singleton sha256. This
   158	  # never dedups the payload `genes` list itself (`genes_list` stays
   159	  # byte-identical to the raw request) -- only the reported COUNT (Codex
   160	  # review fix).
   161	  resolved_count <- length(unique(genes_list))
   162	
   163	  # Source-data version: a CACHED, fail-closed read, fetched only now that a
   164	  # payload is actually about to be built -- its backing view runs global
   165	  # counts/joins, so it must never run before admission/dedup. A lookup
   166	  # failure must never silently record NA/broken provenance; fail the
   167	  # request closed instead.
   168	  src_ver <- tryCatch(
   169	    clustering_cached_source_data_version(conn = pool),
   170	    error = function(e) e
   171	  )
   172	  if (inherits(src_ver, "error")) {
   173	    res$status <- 503L
   174	    return(list(
   175	      error = "PROVENANCE_UNAVAILABLE",
   176	      message = "Snapshot source-data version unavailable; retry shortly."
   177	    ))
   178	  }
   179	
   180	  provenance <- list(
   181	    selector = selector_obj,
   182	    resolved_gene_count = resolved_count,
   183	    gene_list_sha256 = gene_sha,
   184	    intended_fingerprint = intended_fingerprint,
   185	    source_data_version = src_ver
   186	  )
   187	
   188	  # Define category links (needed for result)
   189	  category_links <- tibble::tibble(
   190	    value = c(
   191	      "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
   192	      "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
   193	      "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
   194	    ),
   195	    link = c(
   196	      "https://www.ebi.ac.uk/QuickGO/term/",
   197	      "https://www.ebi.ac.uk/QuickGO/term/",
   198	      "https://disease-ontology.org/term/",
   199	      "https://www.ebi.ac.uk/QuickGO/term/",
   200	      "https://hpo.jax.org/browse/term/",
   201	      "http://www.ebi.ac.uk/interpro/entry/InterPro/",
   202	      "https://www.genome.jp/dbget-bin/www_bget?",
   203	      "https://www.uniprot.org/keywords/",
   204	      "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
   205	      "https://www.ebi.ac.uk/interpro/entry/pfam/",
   206	      "https://www.ncbi.nlm.nih.gov/search/all/?term=",
   207	      "https://www.ebi.ac.uk/QuickGO/term/",
   208	      "https://reactome.org/content/detail/R-",
   209	      "http://www.ebi.ac.uk/interpro/entry/smart/",
   210	      "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
   211	      "https://www.wikipathways.org/index.php/Pathway:"
   212	    )
   213	  )
   214	
   215	  # Cache-first: if the memoized function already has a cached result,
   216	  # return it immediately without submitting a durable worker job.
   217	  # The network_edges endpoint (graph) warms this cache on first load,
   218	  # so subsequent table requests resolve instantly.
   219	  cache_hit <- tryCatch(
   220	    memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
   221	    error = function(e) FALSE
   222	  )
   223	
   224	  if (cache_hit) {
   225	    cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)
   226	
   227	    categories <- cached_clusters %>%
   228	      dplyr::select(term_enrichment) %>%
   229	      tidyr::unnest(cols = c(term_enrichment)) %>%
   230	      dplyr::select(category) %>%
   231	      unique() %>%
   232	      dplyr::arrange(category) %>%
   233	      dplyr::mutate(
   234	        text = dplyr::case_when(
   235	          nchar(category) <= 5 ~ category,
   236	          nchar(category) > 5 ~ stringr::str_to_sentence(category)
   237	        )
   238	      ) %>%
   239	      dplyr::select(value = category, text) %>%
   240	      dplyr::left_join(category_links, by = c("value"))
   241	
   242	    # Splice the base cache-hit fields with `provenance` (already assembled
   243	    # above as selector/resolved_gene_count/gene_list_sha256/
   244	    # intended_fingerprint/source_data_version) via the shared
   245	    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
   246	    # re-listing the same fields as duplicate literals -- keeps this shape in
   247	    # lockstep with the worker-run handler's result meta by construction.
   248	    # `effective_fingerprint` is only knowable from the computed result
   249	    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
   250	    cache_result <- list(
   251	      clusters = cached_clusters,
   252	      categories = categories,
   253	      meta = clustering_result_meta(
   254	        list(
   255	          algorithm = algorithm,
   256	          gene_count = resolved_count,
   257	          cluster_count = nrow(cached_clusters),
   258	          cache_hit = TRUE
   259	        ),
   260	        provenance,
   261	        attr(cached_clusters, "weight_channel")
   262	      )
   263	    )
   264	    cache_request_payload <- list(
   265	      genes = genes_list,
   266	      algorithm = algorithm,
   267	      category_links = category_links,
   268	      string_id_table = string_id_table,
   269	      provenance = provenance
   270	    )
   271	    if (!is.null(selector_chr)) {
   272	      cache_request_payload$category_filter <- selector_chr
   273	    }
   274	    completed_job <- async_job_service_store_completed(
   275	      job_type = "clustering",
   276	      request_payload = cache_request_payload,
   277	      result = cache_result,
   278	      submitted_by = req$user$user_id %||% NULL,
   279	      queue_name = "analysis",
   280	      priority = 50L
   281	    )
   282	    job_id <- completed_job$job_id[[1]]
   283	
   284	    res$status <- 202
   285	    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   286	    res$setHeader("Retry-After", "0")
   287	
   288	    return(list(
   289	      job_id = job_id,
   290	      status = "accepted",
   291	      estimated_seconds = 0,
   292	      status_url = paste0("/api/jobs/", job_id, "/status"),
   293	      meta = list(llm_generation = "snapshot_refresh_owned")
   294	    ))
   295	  }
   296	
   297	  # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
   298	  # "default" matches the queue create_job() enqueues on via async_job_service_submit.
   299	  if (async_job_capacity_exceeded(
   300	        tryCatch(
   301	          async_job_active_count("default"),
   302	          error = function(e) {
   303	            log_warn("async_job_active_count failed (capacity check fail-open): {e$message}")
   304	            0L
   305	          }
   306	        )
   307	      )) {
   308	    res$status <- 503
   309	    res$setHeader("Retry-After", "60")
   310	    return(list(
   311	      error = "CAPACITY_EXCEEDED",
   312	      message = "Analysis queue is at capacity. Please retry shortly.",
   313	      retry_after = 60
   314	    ))
   315	  }
   316	
   317	  # Cache miss - create async job
   318	  job_params <- list(
   319	    genes = genes_list,
   320	    algorithm = algorithm,
   321	    category_links = category_links,
   322	    string_id_table = string_id_table,
   323	    provenance = provenance
   324	  )
   325	  if (!is.null(selector_chr)) {
   326	    job_params$category_filter <- selector_chr
   327	  }
   328	  result <- create_job(
   329	    operation = "clustering",
   330	    params = job_params
   331	  )
   332	
   333	  # Check capacity
   334	  if (!is.null(result$error)) {
   335	    res$status <- 503
   336	    res$setHeader("Retry-After", as.character(result$retry_after))
   337	    return(result)
   338	  }
   339	
   340	  # Success - return HTTP 202 Accepted
   341	  res$status <- 202
   342	  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
   343	  res$setHeader("Retry-After", "5")
   344	
   345	  list(
   346	    job_id = result$job_id,
   347	    status = result$status,
   348	    estimated_seconds = result$estimated_seconds,
   349	    status_url = paste0("/api/jobs/", result$job_id, "/status")
   350	  )
   351	}
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
/bin/bash -lc "nl -ba api/services/job-functional-submission-service.R | sed -n '1,460p'; nl -ba api/functions/async-job-handlers.R | sed -n '1,180p'; nl -ba api/endpoints/jobs_endpoints.R | sed -n '1,260p'; nl -ba AGENTS.md | sed -n '1,80p'; nl -ba CHANGELOG.md | sed -n '1,100p'; nl -ba documentation/08-development.qmd | sed -n '1,160p'; nl -ba api/version_spec.json; nl -ba app/package.json; nl -ba app/package-lock.json | sed -n '1,80p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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
    57	  category_supplied <- !is.null(req$argsBody$category_filter)
    58	  has_genes <- !is.null(genes_in) && length(genes_in) > 0
    59	
    60	  # Mutual exclusion is gated on JSON KEY PRESENCE, not value-nullness or
    61	  # length -- `!is.null(genes_in)` cannot distinguish an ABSENT `genes` key
    62	  # from an explicit JSON `null` (both parse to a NULL `req$argsBody$genes`
    63	  # in R), so `{"genes":null, "category_filter":["X"]}` previously slipped
    64	  # past the guard and silently ran a category job (Codex round-2 review
    65	  # fix). Checking `names(req$argsBody)` instead catches both an explicit
    66	  # null AND an empty array (`{"genes":[], "category_filter":["X"]}`,
    67	  # round-1's fix) because both forms keep the `genes` name in the parsed
    68	  # list. `has_genes`/`category_supplied` (value-based) are unchanged and
    69	  # still drive the LATER branch-selection decision below.
    70	  body_names <- names(req$argsBody)
    71	  genes_key <- "genes" %in% body_names
    72	  category_key <- "category_filter" %in% body_names
    73	
    74	  if (genes_key && category_key) {
    75	    stop_for_bad_request("Provide either genes or category_filter, not both")
    76	  }
    77	
    78	  # Extract algorithm parameter (default: leiden)
    79	  # Ensure we get a scalar value (JSON may pass arrays)
    80	  algorithm <- "leiden"
    81	  if (!is.null(req$argsBody$algorithm)) {
    82	    algo_input <- req$argsBody$algorithm
    83	    # Handle array input - always take first element if vector
    84	    if (is.list(algo_input) || length(algo_input) >= 1) {
    85	      algo_input <- algo_input[[1]]
    86	    }
    87	    algorithm <- tolower(as.character(algo_input))
    88	    if (!algorithm %in% c("leiden", "walktrap")) {
    89	      algorithm <- "leiden"
    90	    }
    91	  }
    92	
    93	  # Resolve the clustering gene universe + selector provenance (#574). The
    94	  # explicit-genes and no-arg (all-NDD) branches are unchanged in substance
    95	  # from before this feature: `clustering_resolve_category_universe(NULL)`
    96	  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
    97	  # so cache parity (memoise key = gene set + algorithm) is preserved.
    98	  selector_chr <- NULL
    99	  if (has_genes) {
   100	    genes_list <- as.character(unlist(genes_in))
   101	    kind <- "explicit"
   102	  } else if (category_supplied) {
   103	    universe <- clustering_resolve_category_universe(req$argsBody$category_filter)
   104	    genes_list <- universe$hgnc_ids
   105	    selector_chr <- universe$selector
   106	    kind <- "category"
   107	  } else {
   108	    universe <- clustering_resolve_category_universe(NULL)
   109	    genes_list <- universe$hgnc_ids
   110	    kind <- "all_ndd"
   111	  }
   112	
   113	  # Pre-fetch the STRING ID table because DB connections cannot cross the
   114	  # durable worker boundary.
   115	  string_id_table <- pool %>%
   116	    dplyr::tbl("non_alt_loci_set") %>%
   117	    dplyr::filter(!is.na(STRING_id)) %>%
   118	    dplyr::select(symbol, hgnc_id, STRING_id) %>%
   119	    dplyr::collect()
   120	
   121	  # Check for duplicate job (include algorithm in check). The selector is
   122	  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
   123	  # submits keep the pre-#574 dedup identity byte-identical.
   124	  dup_params <- list(genes = genes_list, algorithm = algorithm)
   125	  if (!is.null(selector_chr)) {
   126	    dup_params$category_filter <- selector_chr
   127	  }
   128	  dup_check <- check_duplicate_job("clustering", dup_params)
   129	  if (dup_check$duplicate) {
   130	    res$status <- 409
   131	    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
   132	    return(list(
   133	      error = "DUPLICATE_JOB",
   134	      message = "Identical job already running",
   135	      existing_job_id = dup_check$existing_job_id,
   136	      status_url = paste0("/api/jobs/", dup_check$existing_job_id, "/status")
   137	    ))
   138	  }
   139	
   140	  # Cheap-path provenance (no expensive query yet). `selector_obj` records
   141	  # WHICH universe was resolved; `intended_fingerprint` records the STRING
   142	  # cache identity + fixed clustering params this submit intends to run
   143	  # with. The *effective* fingerprint (e.g. the STRING weight channel a
   144	  # computed result actually used) is only knowable from a computed result,
   145	  # so it is recorded separately in the cache-hit result meta below.
   146	  selector_obj <- list(kind = kind, category_filter = selector_chr)
   147	  intended_fingerprint <- list(
   148	    string_cache_fingerprint = analysis_string_cache_fingerprint(),
   149	    score_threshold = 400L,
   150	    algorithm = algorithm,
   151	    seed = 42L
   152	  )
   153	  gene_sha <- clustering_gene_list_sha256(genes_list)
   154	  # `gene_list_sha256` hashes sort(unique(...)); the provenance/meta gene
   155	  # count must agree with it, so it is computed from the SAME dedup -- an
   156	  # explicit payload with duplicate genes (e.g. `["HGNC:1","HGNC:1"]`) must
   157	  # not report a resolved count that disagrees with a singleton sha256. This
   158	  # never dedups the payload `genes` list itself (`genes_list` stays
   159	  # byte-identical to the raw request) -- only the reported COUNT (Codex
   160	  # review fix).
   161	  resolved_count <- length(unique(genes_list))
   162	
   163	  # Source-data version: a CACHED, fail-closed read, fetched only now that a
   164	  # payload is actually about to be built -- its backing view runs global
   165	  # counts/joins, so it must never run before admission/dedup. A lookup
   166	  # failure must never silently record NA/broken provenance; fail the
   167	  # request closed instead.
   168	  src_ver <- tryCatch(
   169	    clustering_cached_source_data_version(conn = pool),
   170	    error = function(e) e
   171	  )
   172	  if (inherits(src_ver, "error")) {
   173	    res$status <- 503L
   174	    return(list(
   175	      error = "PROVENANCE_UNAVAILABLE",
   176	      message = "Snapshot source-data version unavailable; retry shortly."
   177	    ))
   178	  }
   179	
   180	  provenance <- list(
   181	    selector = selector_obj,
   182	    resolved_gene_count = resolved_count,
   183	    gene_list_sha256 = gene_sha,
   184	    intended_fingerprint = intended_fingerprint,
   185	    source_data_version = src_ver
   186	  )
   187	
   188	  # Define category links (needed for result)
   189	  category_links <- tibble::tibble(
   190	    value = c(
   191	      "COMPARTMENTS", "Component", "DISEASES", "Function", "HPO",
   192	      "InterPro", "KEGG", "Keyword", "NetworkNeighborAL", "Pfam",
   193	      "PMID", "Process", "RCTM", "SMART", "TISSUES", "WikiPathways"
   194	    ),
   195	    link = c(
   196	      "https://www.ebi.ac.uk/QuickGO/term/",
   197	      "https://www.ebi.ac.uk/QuickGO/term/",
   198	      "https://disease-ontology.org/term/",
   199	      "https://www.ebi.ac.uk/QuickGO/term/",
   200	      "https://hpo.jax.org/browse/term/",
   201	      "http://www.ebi.ac.uk/interpro/entry/InterPro/",
   202	      "https://www.genome.jp/dbget-bin/www_bget?",
   203	      "https://www.uniprot.org/keywords/",
   204	      "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
   205	      "https://www.ebi.ac.uk/interpro/entry/pfam/",
   206	      "https://www.ncbi.nlm.nih.gov/search/all/?term=",
   207	      "https://www.ebi.ac.uk/QuickGO/term/",
   208	      "https://reactome.org/content/detail/R-",
   209	      "http://www.ebi.ac.uk/interpro/entry/smart/",
   210	      "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
   211	      "https://www.wikipathways.org/index.php/Pathway:"
   212	    )
   213	  )
   214	
   215	  # Cache-first: if the memoized function already has a cached result,
   216	  # return it immediately without submitting a durable worker job.
   217	  # The network_edges endpoint (graph) warms this cache on first load,
   218	  # so subsequent table requests resolve instantly.
   219	  cache_hit <- tryCatch(
   220	    memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm = algorithm),
   221	    error = function(e) FALSE
   222	  )
   223	
   224	  if (cache_hit) {
   225	    cached_clusters <- gen_string_clust_obj_mem(genes_list, algorithm = algorithm)
   226	
   227	    categories <- cached_clusters %>%
   228	      dplyr::select(term_enrichment) %>%
   229	      tidyr::unnest(cols = c(term_enrichment)) %>%
   230	      dplyr::select(category) %>%
   231	      unique() %>%
   232	      dplyr::arrange(category) %>%
   233	      dplyr::mutate(
   234	        text = dplyr::case_when(
   235	          nchar(category) <= 5 ~ category,
   236	          nchar(category) > 5 ~ stringr::str_to_sentence(category)
   237	        )
   238	      ) %>%
   239	      dplyr::select(value = category, text) %>%
   240	      dplyr::left_join(category_links, by = c("value"))
   241	
   242	    # Splice the base cache-hit fields with `provenance` (already assembled
   243	    # above as selector/resolved_gene_count/gene_list_sha256/
   244	    # intended_fingerprint/source_data_version) via the shared
   245	    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
   246	    # re-listing the same fields as duplicate literals -- keeps this shape in
   247	    # lockstep with the worker-run handler's result meta by construction.
   248	    # `effective_fingerprint` is only knowable from the computed result
   249	    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
   250	    cache_result <- list(
   251	      clusters = cached_clusters,
   252	      categories = categories,
   253	      meta = clustering_result_meta(
   254	        list(
   255	          algorithm = algorithm,
   256	          gene_count = resolved_count,
   257	          cluster_count = nrow(cached_clusters),
   258	          cache_hit = TRUE
   259	        ),
   260	        provenance,
   261	        attr(cached_clusters, "weight_channel")
   262	      )
   263	    )
   264	    cache_request_payload <- list(
   265	      genes = genes_list,
   266	      algorithm = algorithm,
   267	      category_links = category_links,
   268	      string_id_table = string_id_table,
   269	      provenance = provenance
   270	    )
   271	    if (!is.null(selector_chr)) {
   272	      cache_request_payload$category_filter <- selector_chr
   273	    }
   274	    completed_job <- async_job_service_store_completed(
   275	      job_type = "clustering",
   276	      request_payload = cache_request_payload,
   277	      result = cache_result,
   278	      submitted_by = req$user$user_id %||% NULL,
   279	      queue_name = "analysis",
   280	      priority = 50L
   281	    )
   282	    job_id <- completed_job$job_id[[1]]
   283	
   284	    res$status <- 202
   285	    res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
   286	    res$setHeader("Retry-After", "0")
   287	
   288	    return(list(
   289	      job_id = job_id,
   290	      status = "accepted",
   291	      estimated_seconds = 0,
   292	      status_url = paste0("/api/jobs/", job_id, "/status"),
   293	      meta = list(llm_generation = "snapshot_refresh_owned")
   294	    ))
   295	  }
   296	
   297	  # Guard: refuse if the queue is already at capacity (soft, fail-open on DB error).
   298	  # "default" matches the queue create_job() enqueues on via async_job_service_submit.
   299	  if (async_job_capacity_exceeded(
   300	        tryCatch(
   301	          async_job_active_count("default"),
   302	          error = function(e) {
   303	            log_warn("async_job_active_count failed (capacity check fail-open): {e$message}")
   304	            0L
   305	          }
   306	        )
   307	      )) {
   308	    res$status <- 503
   309	    res$setHeader("Retry-After", "60")
   310	    return(list(
   311	      error = "CAPACITY_EXCEEDED",
   312	      message = "Analysis queue is at capacity. Please retry shortly.",
   313	      retry_after = 60
   314	    ))
   315	  }
   316	
   317	  # Cache miss - create async job
   318	  job_params <- list(
   319	    genes = genes_list,
   320	    algorithm = algorithm,
   321	    category_links = category_links,
   322	    string_id_table = string_id_table,
   323	    provenance = provenance
   324	  )
   325	  if (!is.null(selector_chr)) {
   326	    job_params$category_filter <- selector_chr
   327	  }
   328	  result <- create_job(
   329	    operation = "clustering",
   330	    params = job_params
   331	  )
   332	
   333	  # Check capacity
   334	  if (!is.null(result$error)) {
   335	    res$status <- 503
   336	    res$setHeader("Retry-After", as.character(result$retry_after))
   337	    return(result)
   338	  }
   339	
   340	  # Success - return HTTP 202 Accepted
   341	  res$status <- 202
   342	  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
   343	  res$setHeader("Retry-After", "5")
   344	
   345	  list(
   346	    job_id = result$job_id,
   347	    status = result$status,
   348	    estimated_seconds = result$estimated_seconds,
   349	    status_url = paste0("/api/jobs/", result$job_id, "/status")
   350	  )
   351	}
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
     1	# AGENTS.md
     2	
     3	This is the canonical agent-facing instruction file for this repository. SysNDD is a neurodevelopmental disorder gene-disease database with three main code trees:
     4	
     5	- `api/` — R/Plumber REST API with `renv`
     6	- `app/` — Vue 3 + TypeScript SPA built with Vite
     7	- `db/` — MySQL schema, data-prep scripts, and versioned migrations
     8	
     9	## Code Organization
    10	
    11	- Write modular, focused code with one clear responsibility per file or module, so humans and LLM agents can read, test, and edit it in a single context.
    12	- Keep handwritten source files under 600 lines when practical. Treat this as a soft ceiling: if a file approaches it, extract cohesive helpers, components, composables, or services before adding more behavior.
    13	- Do not split code mechanically. Tests, migrations, generated files, snapshots, fixtures, and tightly coupled implementations may exceed 600 lines when splitting would reduce clarity.
    14	- Documented size exceptions (WP9 / #346): `db/C_Rcommands_set-table-connections.R` is an intentional exception to the 600-line ceiling. It is an out-of-band, sequential schema-bootstrap DB-prep script (ALTER TABLE / FK / index DDL plus ~10 large inlined `CREATE OR REPLACE VIEW` definitions) that must read top-to-bottom in dependency order, and its `ndd_entity_view` body must stay mirrored byte-for-byte (modulo the `sysndd_db.` schema prefix and the migration's `ALGORITHM`/`SQL SECURITY INVOKER` clause) with the latest `CREATE OR REPLACE VIEW ndd_entity_view` migration (currently `db/migrations/026_add_entity_last_update.sql`, the source of truth); splitting it would reduce clarity and risk the mirror. The exception is recorded here and allowlisted in `scripts/code-quality-file-size-baseline.tsv`; the script itself is left untouched so its baseline does not ratchet up. `db/11_Rcommands_sysndd_db_table_database_comparisons.R` was instead brought under the ceiling by extracting its cohesive HGNC/HPO helper block into `db/11_Rcommands_sysndd_db_table_database_comparisons_helpers.R`, `source()`d after `db_bootstrap()`.
    15	
    16	## Code Quality
    17	
    18	- Start from nearby patterns and existing helpers before adding new abstractions, dependencies, or cross-layer shortcuts.
    19	- Pair behavior changes with targeted tests or deterministic checks. Run the smallest useful check first, then `make pre-commit` or `make ci-local` when the scope warrants it.
    20	- When touching files already over the 600-line soft ceiling, avoid making them larger by default. Extract cohesive code from the area being changed, but leave broad legacy splits for planned refactors. `make code-quality-audit` enforces this as a fast file-size ratchet.
    21	- Frontend API access should go through typed clients in `app/src/api/*`; do not add raw axios calls in views/components or direct `localStorage.token` / `localStorage.user` access.
    22	- API integration tests that write database state should use `with_test_db_transaction()` or document why rollback is not possible.
    23	- Use `.agents/skills/sysndd-code-quality/SKILL.md` for maintainability, modularity, file-size, DRY/KISS/SOLID, and anti-pattern review passes.
    24	
    25	## Repository Skills
    26	
    27	Focused, cross-LLM skill guides live under `.agents/skills/<name>/SKILL.md`. Read the relevant one before working in its area — each distills the invariants and traps for that subsystem so you do not have to reconstruct them from this file or the code.
    28	
    29	- `sysndd-code-quality` — maintainability, modularity, file-size ceiling, DRY/KISS/SOLID, typed boundaries, anti-pattern review passes.
    30	- `sysndd-visual-design` — UI/UX, layouts, tables, mobile rows, design tokens, admin/curation and public data surfaces.
    31	- `sysndd-api-testing` — writing/running R API tests: the container boundary (`tests/` not bind-mounted), `with_test_db_transaction()`, SKIP-vs-PASS, helper/path resolution, mocking external providers, and the static guard tests.
    32	- `sysndd-async-jobs` — durable MySQL-backed jobs and workers: handler registration, `bootstrap/load_modules.R`, lane/priority routing, the restart-the-worker rule, and external budgets.
    33	- `sysndd-analysis-snapshots` — clustering, the snapshot builder/validator, the survives-redeploy memoise cache, `CLUSTER_LOGIC_VERSION`, the coherence gate, LLM summaries, and the membership-change deploy runbook.
    34	- `sysndd-mcp-readonly` — the read-only MCP sidecar contract: approved-public-only reads, no writes/LLM-generation/external calls, `data_class` labels, and the schema-version contract.
    35	- `sysndd-security-bug-scan` — security + correctness review pass: authorization/role gates, SQL/expression injection, credential and secret handling, public/MCP data exposure, external-call DoS, error/info leakage, and the repo's R/Plumber footguns.
    36	- `sysndd-migrations-db` — DB migrations and SQL views: the startup migration runner + manifest (`EXPECTED_LATEST_MIGRATION`), advisory locks, `ndd_entity_view`/core-view mirroring, restore drift, and rollback-safe metadata refresh.
    37	- `sysndd-external-proxy` — outbound provider calls: `external_proxy_budget()`/`make_external_request()`, `memoise_external_success_only`, the per-request time ceiling, batch per-call resets, and cheap-route isolation.
    38	- `sysndd-frontend-integration` — Vue↔API boundary: typed clients only, Plumber array unwrap, problem+json error extraction, and the BVN dotted-key / tooltip-reactivity table traps.
    39	
    40	## Verify Before Handoff
    41	
    42	- Fast deterministic code-quality audit: `make code-quality-audit`
    43	- Full-repo check: `make ci-local`
    44	- Fast pre-push check: `make pre-commit`
    45	- Full dev stack: `make dev`
    46	- DB-only stack: `make docker-dev-db`
    47	- API tests: `make test-api`
    48	- Fast API PR gate: `make test-api-fast`
    49	- API lint: `make lint-api`
    50	- Frontend lint: `make lint-app`
    51	- Frontend type-check: `cd app && npm run type-check`
    52	- Frontend strict-scope type-check: `cd app && npm run type-check:strict`
    53	- Frontend unit tests: `cd app && npm run test:unit`
    54	- Frontend public-route bundle budget: `make verify-app-bundle-budget`
    55	- Frontend SEO prerender gate: `make verify-seo-app`
    56	- Frontend E2E (Playwright, **local-only**): `make playwright-stack && cd app && npx playwright test && cd .. && make playwright-stack-down`. The isolated stack serves the app/API at `http://localhost:8088` by default, and `app/playwright.config.ts` uses that default when `PLAYWRIGHT_BASE_URL` is unset. There is no Playwright CI workflow — the spec files in `app/tests/e2e/` exist for ad-hoc local regression checks. The official lane (lint, type-check, vitest, R API, smoke) is the automated coverage.
    57	
    58	Single-test shortcuts:
    59	
    60	```bash
    61	# R — single file (host)
    62	cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-entity-creation.R')"
    63	
    64	# R — single file (inside the running container; tests/ is NOT bind-mounted)
    65	docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-xyz.R')"
    66	
    67	# Frontend — single spec or test name
    68	cd app && npx vitest run src/components/AppFooter.spec.ts
    69	cd app && npx vitest run -t "match name pattern"
    70	```
    71	
    72	## Architecture Invariants
    73	
    74	### API bootstrap and source order
    75	
    76	`api/start_sysndd_api.R` sources the runtime into the global environment. Source order matters:
    77	
    78	1. `functions/*` and repository helpers
    79	2. `core/*`
    80	3. `services/*`
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
    86	  201 for a genuinely new release, 200 for an idempotent rebuild of
    87	  identical content, 400 naming the failing layer/reason otherwise; `GET
    88	  /releases` (including drafts), `GET /releases/<id>`, `POST
    89	  /releases/<id>/publish`, `PATCH /releases/<id>/doi` (additive Zenodo/DOI
    90	  provenance, outside the content hash), and `DELETE /releases/<id>`
    91	  (draft-only — a published release can never be deleted).
    92	- **Fail-closed build gate**: a release is only ever minted from sources that
    93	  are available, pass a hard partition-coherence re-check (ignoring any
    94	  local coherence-gate downgrade), carry a stored reproducibility bundle,
    95	  share one source-data version, and — for the correlation layer — pin the
    96	  exact dependency lineage (`snapshot_id` + `payload_hash`) of both cluster
    97	  axes. A TOCTOU advisory lock plus a fresh pre-insert re-read close the race
    98	  between reading sources and persisting the release.
    99	- **Verifiable checksums and lineage**: every file carries its own
   100	  `content_sha256`; `sha256(reproducibility.json) == reproducibility_hash`
     1	---
     2	title: "Development"
     3	---
     4	
     5	# Development
     6	
     7	This page is the concise human-facing entry point for local SysNDD development.
     8	
     9	## Requirements
    10	
    11	- Docker with Compose v2
    12	- Git
    13	- GNU Make
    14	- Node.js matching `app/.nvmrc`
    15	- R 4.5.x for host-side API work
    16	
    17	Helpful extras:
    18	
    19	- `jq`
    20	- `gh`
    21	- a MySQL client such as `mysql` or `mycli`
    22	
    23	## Quickstart
    24	
    25	```bash
    26	git clone https://github.com/berntpopp/sysndd.git
    27	cd sysndd
    28	make install-dev
    29	make doctor
    30	make dev
    31	```
    32	
    33	After `make dev`:
    34	
    35	- App: `http://localhost`
    36	- App (Vite): `http://localhost:5173`
    37	- API: `http://localhost/api`
    38	- API (direct): `http://localhost:7778`
    39	- Traefik dashboard: `http://localhost:8090`
    40	- MySQL dev: `localhost:7654`
    41	- MySQL test: `localhost:7655`
    42	
    43	Stop the stack with:
    44	
    45	```bash
    46	make docker-down
    47	```
    48	
    49	## Daily Commands
    50	
    51	```bash
    52	make dev
    53	make docker-dev-db
    54	make serve-app
    55	make code-quality-audit
    56	make pre-commit
    57	make test-api-fast
    58	make ci-local
    59	```
    60	
    61	Frontend-only verification:
    62	
    63	```bash
    64	cd app
    65	npm run lint
    66	npm run type-check
    67	npm run test:unit
    68	```
    69	
    70	SEO prerender verification:
    71	
    72	```bash
    73	make verify-seo-app
    74	cd app
    75	npm run seo:generate:fixture
    76	SEO_API_BASE_URL=http://localhost/api SEO_PUBLIC_BASE_URL=https://sysndd.dbmr.unibe.ch npm run seo:generate
    77	npm run seo:verify
    78	```
    79	
    80	The fixture generator is deterministic and does not require the API. API-backed generation reads `/api/seo/routes`, `/api/seo/gene/:symbol`, and `/api/seo/entity/:id`; run it after `make dev` or against another healthy SysNDD API. The generator writes route-specific HTML and sitemap files into `app/dist`.
    81	
    82	API-only verification:
    83	
    84	```bash
    85	make lint-api
    86	make test-api-fast
    87	make test-api
    88	```
    89	
    90	MCP analysis verification:
    91	
    92	```bash
    93	cd api
    94	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
    95	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-repository.R')"
    96	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"
    97	cd ..
    98	make test-api-fast
    99	```
   100	
   101	For MCP 1.2 analysis changes, also check that the analysis tools remain read-only and bounded: `get_sysndd_analysis_catalog` -> `get_gene_research_context(dry_run = TRUE, response_mode = "compact")` -> focused follow-up tools. Analysis responses should use compact defaults, `max_response_chars = "auto"`, `budget` metadata, and `dry_run`/`diagnostics` recovery hints for broad result sets. Cached LLM summaries are validated admin-generated cache reads only, NDDScore is an ML prediction layer rather than a curated evidence tier, and stored external IDs should be treated only as `external_reference_identifier`.
   102	
   103	Public and MCP analysis sections such as phenotype correlations, phenotype clusters, and STRING-derived gene networks require current public-ready analysis snapshots. Public REST and MCP paths report snapshot diagnostics such as `snapshot_missing`, `snapshot_stale`, or `source_version_mismatch`; they do not compute heavy analysis or read draft/admin data on miss.
   104	
   105	### Database Version (issue #22)
   106	
   107	The human-facing DB semantic version lives in the single-row `db_version` table (migration `028_add_db_version.sql`) and is read by `api/functions/db-version.R`. It is exposed in the `database` block of `GET /api/version` and rendered on the About page via `app/src/components/AppVersionInfo.vue` (typed client `app/src/api/version.ts`).
   108	
   109	- Bump the seeded semantic version in a new numbered migration when the DB schema or core seed data changes meaningfully; do not edit an applied migration.
   110	- At release time, capture the last `db/`-folder git commit and the version with `./db/scripts/update-db-version.sh` and inject `DB_VERSION` / `DB_COMMIT` into the API container; `db_version_sync_from_env()` updates the row at startup (non-fatal no-op when unset). See `documentation/09-deployment.qmd`.
   111	- Run focused checks while iterating:
   112	
   113	```bash
   114	cd api
   115	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-db-version.R')"
   116	cd ../app && npx vitest run src/api/version.spec.ts src/components/AppVersionInfo.spec.ts
   117	```
   118	
   119	### Public Analysis Snapshots
   120	
   121	When adding a snapshot table or shape change, create a numbered migration under `db/migrations/`, update `api/functions/migration-manifest.R`, and add or update the migration and preset tests. Snapshot presets live in `api/functions/analysis-snapshot-presets.R`; unsupported public parameters should fail there before any repository or analysis work starts.
   122	
   123	Run focused snapshot checks while iterating:
   124	
   125	```bash
   126	cd api
   127	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-migration.R')"
   128	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-presets.R')"
   129	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-repository.R')"
   130	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-builder.R')"
   131	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-endpoint-analysis-snapshot-read.R')"
   132	```
   133	
   134	To refresh a snapshot in a local API or worker R session with DB configuration loaded, submit the durable worker job:
   135	
   136	```r
   137	async_job_service_submit(
   138	  job_type = "analysis_snapshot_refresh",
   139	  request_payload = list(
   140	    analysis_type = "functional_clusters",
   141	    params = list(algorithm = "leiden")
   142	  ),
   143	  queue_name = "analysis"
   144	)
   145	```
   146	
   147	Use `analysis_snapshot_refresh("functional_clusters", list(algorithm = "leiden"))` only for a deliberate local one-off where the R session owns a valid DB connection. After snapshot or MCP analysis changes, run `make test-mcp-smoke` against a running MCP sidecar in addition to the focused MCP unit tests.
   148	
   149	### Analysis-Snapshot Releases (#573)
   150	
   151	Analysis-snapshot **releases** (`api/functions/analysis-snapshot-release*.R`, `api/services/analysis-snapshot-release-service.R`, migration `045_add_analysis_snapshot_release.sql`) freeze the currently active public-ready snapshots above into an immutable, content-addressed, independently-downloadable artifact. They are a separate layer on top of snapshots, not a replacement — building one requires snapshots to already be `available`.
   152	
   153	Run focused release checks while iterating:
   154	
   155	```bash
   156	cd api
   157	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-release-migration.R')"
   158	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-release-manifest.R')"
   159	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-release-service.R')"
   160	Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-integration-analysis-snapshot-release-build.R')"
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
     1	{
     2	  "name": "sysndd",
     3	  "version": "0.30.1",
     4	  "lockfileVersion": 3,
     5	  "requires": true,
     6	  "packages": {
     7	    "": {
     8	      "name": "sysndd",
     9	      "version": "0.30.1",
    10	      "dependencies": {
    11	        "@popperjs/core": "^2.11.8",
    12	        "@unhead/vue": "^3.1.8",
    13	        "@upsetjs/bundle": "^1.11.0",
    14	        "@vee-validate/rules": "^4.15.1",
    15	        "@vueuse/core": "^14.3.0",
    16	        "bootstrap": "^5.3.8",
    17	        "bootstrap-icons": "^1.13.1",
    18	        "bootstrap-vue-next": "^0.45.8",
    19	        "chart.js": "^4.5.1",
    20	        "cytoscape": "^3.34.0",
    21	        "cytoscape-fcose": "^2.2.0",
    22	        "cytoscape-svg": "^0.4.0",
    23	        "d3": "^7.4.2",
    24	        "date-fns": "^4.4.0",
    25	        "dompurify": "^3.4.12",
    26	        "exceljs": "^4.4.0",
    27	        "file-saver": "^2.0.5",
    28	        "gsap": "^3.15.0",
    29	        "html2canvas": "^1.4.1",
    30	        "markdown-it": "^14.3.0",
    31	        "ngl": "^2.4.0",
    32	        "pinia": "^3.0.4",
    33	        "splitpanes": "^4.1.2",
    34	        "swagger-ui": "^5.32.8",
    35	        "swagger-ui-dist": "^5.32.8",
    36	        "vee-validate": "^4.15.1",
    37	        "vue": "^3.5.39",
    38	        "vue-chartjs": "^5.3.4",
    39	        "vue-dompurify-html": "^5.3.0",
    40	        "vue-router": "^5.1.0",
    41	        "vuedraggable": "^4.1.0"
    42	      },
    43	      "devDependencies": {
    44	        "@axe-core/playwright": "^4.12.1",
    45	        "@eslint/js": "^9.39.2",
    46	        "@playwright/test": "^1.61.1",
    47	        "@testing-library/dom": "^10.4.1",
    48	        "@testing-library/user-event": "^14.6.1",
    49	        "@testing-library/vue": "^8.1.0",
    50	        "@types/cytoscape": "^3.31.0",
    51	        "@types/d3": "^7.4.3",
    52	        "@types/dompurify": "^3.2.0",
    53	        "@types/markdown-it": "^14.1.2",
    54	        "@types/node": "^26.1.1",
    55	        "@vitejs/plugin-vue": "^6.0.7",
    56	        "@vitest/coverage-v8": "^4.1.10",
    57	        "@vitest/ui": "^4.0.18",
    58	        "@vue/compiler-sfc": "^3.5.39",
    59	        "@vue/test-utils": "^2.4.11",
    60	        "@vue/tsconfig": "^0.9.0",
    61	        "axios": "^1.18.1",
    62	        "cssnano": "^8.0.2",
    63	        "eslint": "^10.7.0",
    64	        "eslint-config-prettier": "^10.1.8",
    65	        "eslint-plugin-vue": "^10.9.2",
    66	        "globals": "^17.7.0",
    67	        "husky": "^9.1.7",
    68	        "jsdom": "^29.1.1",
    69	        "lint-staged": "^17.0.8",
    70	        "msw": "^2.15.0",
    71	        "postcss": "^8.5.19",
    72	        "prettier": "^3.9.5",
    73	        "rollup-plugin-visualizer": "^7.0.1",
    74	        "sass": "^1.101.0",
    75	        "typescript": "^6.0.3",
    76	        "typescript-eslint": "^8.63.0",
    77	        "vite": "^7.3.6",
    78	        "vite-plugin-pwa": "^1.3.0",
    79	        "vitest": "^4.0.18",
    80	        "vitest-axe": "^0.1.0",

exec
/bin/bash -lc "nl -ba api/functions/async-job-handlers.R | sed -n '60,190p'; nl -ba api/endpoints/jobs_endpoints.R | sed -n '1,260p'; nl -ba api/tests/testthat/test-unit-async-job-handlers.R; nl -ba api/tests/testthat/test-unit-async-job-worker.R; nl -ba api/tests/testthat/job-endpoint-services-fixtures.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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
   201	  expect_equal(heartbeat_call$lease_seconds, 120L)
   202	  expect_equal(heartbeat_call$claim_token, "claim-heartbeat")
   203	})
   204	
   205	test_that("async_job_worker_run_claimed_job dispatches the matching handler and persists completion", {
   206	  runtime <- load_async_job_worker_runtime()
   207	  events <- character(0)
   208	  completed <- NULL
   209	  call_order <- character(0)
   210	  heartbeat_calls <- list()
   211	
   212	  runtime$async_job_repository_append_event <- function(job_id, event_type, event_message = NULL, event_payload = NULL, conn = NULL) { # nolint: line_length_linter
   213	    events <<- c(events, paste(job_id, event_type, sep = ":"))
   214	    1L
   215	  }
   216	  runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
   217	    heartbeat_calls[[length(heartbeat_calls) + 1L]] <<- list(
   218	      job_id = job_id,
   219	      lease_seconds = lease_seconds,
   220	      claim_token = claim_token
   221	    )
   222	    1L
   223	  }
   224	  runtime$async_job_repository_complete <- function(job_id, result_json, claim_token, conn = NULL) {
   225	    call_order <<- c(call_order, "complete")
   226	    completed <<- list(
   227	      job_id = job_id,
   228	      result = jsonlite::fromJSON(result_json, simplifyVector = TRUE),
   229	      claim_token = claim_token
   230	    )
   231	    1L
   232	  }
   233	  runtime$async_job_repository_fail <- function(...) {
   234	    stop("failure path should not be used in this test")
   235	  }
   236	
   237	  claimed <- tibble(
   238	    job_id = "job-run",
   239	    job_type = "hgnc_update",
   240	    request_payload_json = '{"refresh":true}',
   241	    claim_token = "claim-run"
   242	  )
   243	
   244	  registry <- list(
   245	    hgnc_update = list(
   246	      cancel_mode = "non_interruptible",
   247	      run = function(job, payload, state, worker_config) {
   248	        reporter <- runtime$create_async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
   249	        reporter("execute", "Running handler", current = 1, total = 1)
   250	        list(ok = TRUE, refresh = payload$refresh)
   251	      },
   252	      after_success = function(result, job, payload, state, worker_config) {
   253	        call_order <<- c(call_order, "after_success")
   254	        events <<- c(events, paste(job$job_id[[1]], "after_success", sep = ":"))
   255	        invisible(result)
   256	      }
   257	    )
   258	  )
   259	
   260	  progress_calls <- list()
   261	  runtime$async_job_repository_update_progress <- function(job_id, progress_pct = NULL, progress_message = NULL, claim_token, conn = NULL) { # nolint: line_length_linter
   262	    progress_calls[[length(progress_calls) + 1L]] <<- list(
   263	      job_id = job_id,
   264	      progress_pct = progress_pct,
   265	      progress_message = progress_message,
   266	      claim_token = claim_token
   267	    )
   268	    1L
   269	  }
   270	
   271	  runtime$async_job_worker_run_claimed_job(
   272	    claimed_job = claimed,
   273	    state = runtime$async_job_worker_state(),
   274	    worker_config = list(
   275	      worker_id = "worker-run",
   276	      lease_seconds = 60L,
   277	      job_run_lease_seconds = 300L
   278	    ),
   279	    registry = registry
   280	  )
   281	
   282	  expect_equal(completed$job_id, "job-run")
   283	  expect_equal(completed$claim_token, "claim-run")
   284	  expect_true(isTRUE(completed$result$ok))
   285	  expect_true(isTRUE(completed$result$refresh))
   286	  expect_true("job-run:started" %in% events)
   287	  expect_true("job-run:completed" %in% events)
   288	  expect_true("job-run:after_success" %in% events)
   289	  expect_equal(progress_calls[[1]]$progress_pct, 100)
   290	  expect_equal(progress_calls[[1]]$claim_token, "claim-run")
   291	  expect_gte(length(heartbeat_calls), 1L)
   292	  expect_equal(heartbeat_calls[[1]]$lease_seconds, 300L)
   293	  expect_equal(heartbeat_calls[[1]]$claim_token, "claim-run")
   294	  expect_equal(call_order, c("complete", "after_success"))
   295	})
   296	
   297	test_that("async_job_worker_run_claimed_job treats event writes as best-effort", {
   298	  runtime <- load_async_job_worker_runtime()
   299	  completed <- NULL
   300	  fail_calls <- list()
   301	
   302	  runtime$async_job_repository_append_event <- function(...) {
   303	    stop("event store unavailable")
   304	  }
   305	  runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
   306	    1L
   307	  }
   308	  runtime$async_job_repository_complete <- function(job_id, result_json, claim_token, conn = NULL) {
   309	    completed <<- list(
   310	      job_id = job_id,
   311	      result = jsonlite::fromJSON(result_json, simplifyVector = TRUE),
   312	      claim_token = claim_token
   313	    )
   314	    1L
   315	  }
   316	  runtime$async_job_repository_fail <- function(job_id, error_code, error_message, claim_token, next_attempt_at = NULL, conn = NULL) { # nolint: line_length_linter
   317	    fail_calls[[length(fail_calls) + 1L]] <<- list(
   318	      job_id = job_id,
   319	      error_code = error_code,
   320	      error_message = error_message,
   321	      claim_token = claim_token
   322	    )
   323	    1L
   324	  }
   325	
   326	  result <- runtime$async_job_worker_run_claimed_job(
   327	    claimed_job = tibble(
   328	      job_id = "job-safe-events",
   329	      job_type = "hgnc_update",
   330	      request_payload_json = "{}",
   331	      claim_token = "claim-safe-events"
   332	    ),
   333	    state = runtime$async_job_worker_state(),
   334	    worker_config = list(worker_id = "worker-safe", lease_seconds = 60L),
   335	    registry = list(
   336	      hgnc_update = list(
   337	        cancel_mode = "non_interruptible",
   338	        run = function(job, payload, state, worker_config) {
   339	          list(ok = TRUE)
   340	        }
   341	      )
   342	    )
   343	  )
   344	
   345	  expect_true(isTRUE(result))
   346	  expect_equal(completed$job_id, "job-safe-events")
   347	  expect_equal(completed$claim_token, "claim-safe-events")
   348	  expect_true(isTRUE(completed$result$ok))
   349	  expect_length(fail_calls, 0L)
   350	})
   351	
   352	test_that("async_job_worker_run_claimed_job fails malformed job rows instead of crashing", {
   353	  runtime <- load_async_job_worker_runtime()
   354	  fail_calls <- list()
   355	  completed_calls <- 0L
   356	
   357	  runtime$async_job_repository_append_event <- function(job_id, event_type, event_message = NULL, event_payload = NULL, conn = NULL) { # nolint: line_length_linter
   358	    1L
   359	  }
   360	  runtime$async_job_repository_heartbeat <- function(job_id, lease_seconds, claim_token, conn = NULL) {
   361	    1L
   362	  }
   363	  runtime$async_job_repository_fail <- function(job_id, error_code, error_message, claim_token, next_attempt_at = NULL, conn = NULL) { # nolint: line_length_linter
   364	    fail_calls[[length(fail_calls) + 1L]] <<- list(
   365	      job_id = job_id,
   366	      error_code = error_code,
   367	      error_message = error_message,
   368	      claim_token = claim_token
   369	    )
   370	    1L
   371	  }
   372	  runtime$async_job_repository_complete <- function(job_id, result_json, claim_token, conn = NULL) {
   373	    completed_calls <<- completed_calls + 1L
   374	    1L
   375	  }
   376	
   377	  unknown_result <- runtime$async_job_worker_run_claimed_job(
   378	    claimed_job = tibble(
   379	      job_id = "job-unknown-handler",
   380	      job_type = "unknown_job_type",
   381	      request_payload_json = "{}",
   382	      claim_token = "claim-unknown-handler"
   383	    ),
   384	    state = runtime$async_job_worker_state(),
   385	    worker_config = list(worker_id = "worker-malformed", lease_seconds = 60L),
   386	    registry = list()
   387	  )
   388	
   389	  invalid_json_result <- runtime$async_job_worker_run_claimed_job(
   390	    claimed_job = tibble(
   391	      job_id = "job-invalid-json",
   392	      job_type = "hgnc_update",
   393	      request_payload_json = "{bad-json",
   394	      claim_token = "claim-invalid-json"
   395	    ),
   396	    state = runtime$async_job_worker_state(),
   397	    worker_config = list(worker_id = "worker-malformed", lease_seconds = 60L),
   398	    registry = list(
   399	      hgnc_update = list(
   400	        cancel_mode = "non_interruptible",
   401	        run = function(job, payload, state, worker_config) list(ok = TRUE)
   402	      )
   403	    )
   404	  )
   405	
   406	  expect_false(isTRUE(unknown_result))
   407	  expect_false(isTRUE(invalid_json_result))
   408	  expect_equal(completed_calls, 0L)
   409	  expect_length(fail_calls, 2L)
   410	  expect_equal(fail_calls[[1]]$job_id, "job-unknown-handler")
   411	  expect_match(fail_calls[[1]]$error_message, "No durable async job handler registered")
   412	  expect_equal(fail_calls[[2]]$job_id, "job-invalid-json")
   413	})
   414	
   415	test_that("async_job_worker_sync_drain_signal flips the worker into shutdown mode", {
   416	  runtime <- load_async_job_worker_runtime()
   417	  state <- runtime$async_job_worker_state()
   418	  drain_file <- tempfile("async-job-worker-drain-")
   419	
   420	  on.exit(unlink(drain_file, force = TRUE), add = TRUE)
   421	  file.create(drain_file)
   422	
   423	  runtime$async_job_worker_sync_drain_signal(
   424	    state = state,
   425	    worker_config = list(drain_file = drain_file)
   426	  )
   427	
   428	  expect_true(isTRUE(state$draining))
   429	  expect_true(isTRUE(state$shutdown_requested))
   430	})
   431	
   432	test_that("worker main exits cleanly when drain is requested or lifetime bounds are reached", {
   433	  runtime <- load_async_job_worker_runtime()
   434	
   435	  drain_state <- runtime$async_job_worker_state()
   436	  drain_state$draining <- TRUE
   437	  drain_claims <- 0L
   438	
   439	  result_state <- runtime$async_job_worker_main(
   440	    worker_config = list(
   441	      worker_id = "worker-drain",
   442	      hostname = "host-drain",
   443	      lease_seconds = 60L,
   444	      idle_sleep_seconds = 0,
   445	      max_jobs_per_worker = 10L,
   446	      max_worker_lifetime_seconds = 600L,
   447	      queues = "default"
   448	    ),
   449	    state = drain_state,
   450	    registry = list(),
   451	    claim_fn = function(...) {
   452	      drain_claims <<- drain_claims + 1L
   453	      tibble()
   454	    },
   455	    recover_stale_fn = function() invisible(tibble::tibble(jobs_recovered = 0L)),
   456	    sleep_fn = function(seconds) invisible(seconds),
   457	    now_fn = function() as.POSIXct("2026-04-23 12:00:00", tz = "UTC")
   458	  )
   459	
   460	  expect_identical(result_state, drain_state)
   461	  expect_equal(drain_claims, 0L)
   462	
   463	  lifetime_state <- runtime$async_job_worker_state(
   464	    started_at = as.POSIXct("2026-04-23 12:00:00", tz = "UTC")
   465	  )
   466	  lifetime_claims <- 0L
   467	  tick_times <- as.POSIXct(
   468	    c("2026-04-23 12:00:00", "2026-04-23 12:00:02"),
   469	    tz = "UTC"
   470	  )
   471	  tick_index <- 0L
   472	
   473	  lifetime_result <- runtime$async_job_worker_main(
   474	    worker_config = list(
   475	      worker_id = "worker-life",
   476	      hostname = "host-life",
   477	      lease_seconds = 60L,
   478	      idle_sleep_seconds = 0,
   479	      max_jobs_per_worker = 10L,
   480	      max_worker_lifetime_seconds = 1L,
   481	      queues = "default"
   482	    ),
   483	    state = lifetime_state,
   484	    registry = list(),
   485	    claim_fn = function(...) {
   486	      lifetime_claims <<- lifetime_claims + 1L
   487	      tibble()
   488	    },
   489	    recover_stale_fn = function() invisible(tibble::tibble(jobs_recovered = 0L)),
   490	    sleep_fn = function(seconds) invisible(seconds),
   491	    now_fn = function() {
   492	      tick_index <<- min(tick_index + 1L, length(tick_times))
   493	      tick_times[[tick_index]]
   494	    }
   495	  )
   496	
   497	  expect_identical(lifetime_result, lifetime_state)
   498	  expect_equal(lifetime_claims, 1L)
   499	})
   500	
   501	test_that("worker main reaps stale jobs before attempting new claims", {
   502	  runtime <- load_async_job_worker_runtime()
   503	  state <- runtime$async_job_worker_state()
   504	  call_order <- character(0)
   505	
   506	  runtime$async_job_worker_main(
   507	    worker_config = list(
   508	      worker_id = "worker-recover",
   509	      hostname = "host-recover",
   510	      lease_seconds = 60L,
   511	      job_run_lease_seconds = 300L,
   512	      idle_sleep_seconds = 0,
   513	      max_jobs_per_worker = 1L,
   514	      max_worker_lifetime_seconds = 600L,
   515	      queues = "default",
   516	      drain_file = ""
   517	    ),
   518	    state = state,
   519	    registry = list(),
   520	    recover_stale_fn = function() {
   521	      call_order <<- c(call_order, "recover")
   522	      invisible(tibble::tibble(jobs_recovered = 1L))
   523	    },
   524	    claim_fn = function(...) {
   525	      call_order <<- c(call_order, "claim")
   526	      state$shutdown_requested <- TRUE
   527	      tibble()
   528	    },
   529	    sleep_fn = function(seconds) invisible(seconds),
   530	    now_fn = function() as.POSIXct("2026-04-23 12:00:00", tz = "UTC")
   531	  )
   532	
   533	  expect_equal(call_order, c("recover", "claim"))
   534	})
   535	
   536	test_that("clustering durable handler preserves executor result shape and chains LLM generation", {
   537	  skip_if_not_installed("dplyr")
   538	  skip_if_not_installed("tidyr")
   539	  skip_if_not_installed("stringr")
   540	
   541	  runtime <- load_async_job_worker_runtime()
   542	  progress_calls <- list()
   543	
   544	  clusters <- tibble::tibble(
   545	    cluster = 1L,
   546	    identifiers = list(tibble::tibble(symbol = "GENE1", hgnc_id = 101L)),
   547	    term_enrichment = list(tibble::tibble(category = c("HPO", "Process")))
   548	  )
   549	  llm_call <- NULL
   550	
   551	  runtime$gen_string_clust_obj <- function(genes, algorithm, string_id_table = NULL) {
   552	    expect_equal(genes, c("GENE1", "GENE2"))
   553	    expect_equal(algorithm, "walktrap")
   554	    expect_equal(string_id_table$STRING_id, c("s1", "s2"))
   555	    clusters
   556	  }
   557	  runtime$trigger_llm_batch_generation <- function(clusters, cluster_type, parent_job_id) {
   558	    llm_call <<- list(
   559	      clusters = clusters,
   560	      cluster_type = cluster_type,
   561	      parent_job_id = parent_job_id
   562	    )
   563	    list(job_id = "llm-job")
   564	  }
   565	  runtime$create_async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
   566	    force(job_id)
   567	    force(throttle_seconds)
   568	    function(step, message, current = NULL, total = NULL) {
   569	      progress_calls[[length(progress_calls) + 1L]] <<- list(
   570	        job_id = job_id,
   571	        step = step,
   572	        message = message,
   573	        current = current,
   574	        total = total
   575	      )
   576	      invisible(NULL)
   577	    }
   578	  }
   579	
   580	  handler <- runtime$async_job_get_handler("clustering")
   581	  result <- handler$run(
   582	    job = tibble::tibble(job_id = "job-clustering"),
   583	    payload = list(
   584	      genes = c("GENE1", "GENE2"),
   585	      algorithm = "walktrap",
   586	      string_id_table = tibble::tibble(symbol = c("GENE1", "GENE2"), STRING_id = c("s1", "s2")),
   587	      category_links = tibble::tibble(
   588	        value = c("HPO", "Process"),
   589	        link = c("https://hpo.test/", "https://process.test/")
   590	      )
   591	    ),
   592	    state = runtime$async_job_worker_state(),
   593	    worker_config = list(worker_id = "worker-clustering")
   594	  )
   595	
   596	  expect_equal(result$clusters, clusters)
   597	  expect_equal(result$categories$value, c("HPO", "Process"))
   598	  expect_equal(result$categories$link, c("https://hpo.test/", "https://process.test/"))
   599	  expect_equal(result$meta$algorithm, "walktrap")
   600	  expect_equal(result$meta$gene_count, 2L)
   601	  expect_equal(result$meta$cluster_count, 1L)
   602	  expect_length(progress_calls, 2L)
   603	  expect_equal(vapply(progress_calls, `[[`, character(1), "step"), c("cluster", "complete"))
   604	  expect_equal(progress_calls[[1]]$current, 0)
   605	  expect_equal(progress_calls[[1]]$total, 1)
   606	  expect_equal(progress_calls[[2]]$current, 1)
   607	  expect_equal(progress_calls[[2]]$total, 1)
   608	
   609	  handler$after_success(
   610	    result = result,
   611	    job = tibble::tibble(job_id = "job-clustering"),
   612	    payload = list(),
   613	    state = runtime$async_job_worker_state(),
   614	    worker_config = list(worker_id = "worker-clustering")
   615	  )
   616	
   617	  expect_equal(llm_call$cluster_type, "functional")
   618	  expect_equal(llm_call$parent_job_id, "job-clustering")
   619	  expect_equal(llm_call$clusters, clusters)
   620	})
   621	
   622	test_that("phenotype clustering durable handler restores identifiers and chains LLM generation", {
   623	  skip_if_not_installed("dplyr")
   624	  skip_if_not_installed("tidyr")
   625	
   626	  runtime <- load_async_job_worker_runtime()
   627	  progress_calls <- list()
   628	
   629	  runtime$gen_mca_clust_obj <- function(data_frame) {
   630	    expect_equal(rownames(data_frame), c("11", "22"))
   631	    tibble::tibble(
   632	      cluster = 2L,
   633	      identifiers = list(tibble::tibble(entity_id = c("11", "22"))),
   634	      quali_inp_var = list(tibble::tibble(term = "Phenotype"))
   635	    )
   636	  }
   637	
   638	  llm_call <- NULL
   639	  runtime$trigger_llm_batch_generation <- function(clusters, cluster_type, parent_job_id) {
   640	    llm_call <<- list(
   641	      clusters = clusters,
   642	      cluster_type = cluster_type,
   643	      parent_job_id = parent_job_id
   644	    )
   645	    list(job_id = "llm-job")
   646	  }
   647	  runtime$create_async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
   648	    force(job_id)
   649	    force(throttle_seconds)
   650	    function(step, message, current = NULL, total = NULL) {
   651	      progress_calls[[length(progress_calls) + 1L]] <<- list(
   652	        job_id = job_id,
   653	        step = step,
   654	        message = message,
   655	        current = current,
   656	        total = total
   657	      )
   658	      invisible(NULL)
   659	    }
   660	  }
   661	
   662	  handler <- runtime$async_job_get_handler("phenotype_clustering")
   663	  result <- handler$run(
   664	    job = tibble::tibble(job_id = "job-phenotype"),
   665	    payload = list(
   666	      ndd_entity_view_tbl = tibble::tibble(
   667	        entity_id = c(11L, 22L),
   668	        hgnc_id = c("HGNC:11", "HGNC:22"),
   669	        symbol = c("GENE11", "GENE22"),
   670	        hpo_mode_of_inheritance_term_name = c("Autosomal dominant", "Autosomal dominant"),
   671	        ndd_phenotype = c("Yes", "Yes")
   672	      ),
   673	      ndd_entity_review_tbl = tibble::tibble(review_id = c(101L, 202L)),
   674	      ndd_review_phenotype_connect_tbl = tibble::tibble(
   675	        entity_id = c(11L, 22L),
   676	        review_id = c(101L, 202L),
   677	        modifier_id = c(1L, 1L),
   678	        phenotype_id = c("HP:0000001", "HP:0000002")
   679	      ),
   680	      modifier_list_tbl = tibble::tibble(modifier_id = 1L, modifier_name = "present"),
   681	      phenotype_list_tbl = tibble::tibble(
   682	        phenotype_id = c("HP:0000001", "HP:0000002"),
   683	        HPO_term = c("Phenotype A", "Phenotype B"),
   684	        category = "Definitive"
   685	      ),
   686	      id_phenotype_ids = c("HP:0001249"),
   687	      categories = "Definitive"
   688	    ),
   689	    state = runtime$async_job_worker_state(),
   690	    worker_config = list(worker_id = "worker-phenotype")
   691	  )
   692	
   693	  identifiers <- result$identifiers[[1]]
   694	  expect_equal(identifiers$entity_id, c(11L, 22L))
   695	  expect_equal(identifiers$hgnc_id, c("HGNC:11", "HGNC:22"))
   696	  expect_equal(identifiers$symbol, c("GENE11", "GENE22"))
   697	  expect_equal(
   698	    vapply(progress_calls, `[[`, character(1), "step"),
   699	    c("prepare_matrix", "cluster", "complete")
   700	  )
   701	  expect_equal(progress_calls[[1]]$current, 0)
   702	  expect_equal(progress_calls[[1]]$total, 2)
   703	  expect_equal(progress_calls[[2]]$current, 1)
   704	  expect_equal(progress_calls[[2]]$total, 2)
   705	  expect_equal(progress_calls[[3]]$current, 2)
   706	  expect_equal(progress_calls[[3]]$total, 2)
   707	
   708	  handler$after_success(
   709	    result = result,
   710	    job = tibble::tibble(job_id = "job-phenotype"),
   711	    payload = list(),
   712	    state = runtime$async_job_worker_state(),
   713	    worker_config = list(worker_id = "worker-phenotype")
   714	  )
   715	
   716	  expect_equal(llm_call$cluster_type, "phenotype")
   717	  expect_equal(llm_call$parent_job_id, "job-phenotype")
   718	  expect_equal(llm_call$clusters, result)
   719	})
   720	
   721	test_that("legacy durable handlers inject the current durable job id into reused executors", {
   722	  runtime <- load_async_job_worker_runtime()
   723	
   724	  comparisons_params <- NULL
   725	  runtime$comparisons_update_async <- function(params) {
   726	    comparisons_params <<- params
   727	    list(ok = TRUE, worker_job = params$.__job_id__)
   728	  }
   729	
   730	  llm_params <- NULL
   731	  runtime$llm_batch_executor <- function(params) {
   732	    llm_params <<- params
   733	    list(ok = TRUE, worker_job = params$.__job_id__)
   734	  }
   735	
   736	  comparisons_result <- runtime$async_job_get_handler("comparisons_update")$run(
   737	    job = tibble::tibble(job_id = "job-comparisons"),
   738	    payload = list(db_config = list(host = "db")),
   739	    state = runtime$async_job_worker_state(),
   740	    worker_config = list(worker_id = "worker-legacy")
   741	  )
   742	
   743	  llm_result <- runtime$async_job_get_handler("llm_generation")$run(
   744	    job = tibble::tibble(job_id = "job-llm"),
   745	    payload = list(clusters = tibble::tibble(cluster = 1L), cluster_type = "functional"),
   746	    state = runtime$async_job_worker_state(),
   747	    worker_config = list(worker_id = "worker-legacy")
   748	  )
   749	
   750	  expect_equal(comparisons_result$worker_job, "job-comparisons")
   751	  expect_equal(comparisons_params$.__job_id__, "job-comparisons")
   752	  expect_equal(llm_result$worker_job, "job-llm")
   753	  expect_equal(llm_params$.__job_id__, "job-llm")
   754	})
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

codex
The two code changes are present in the intended locations: key-presence is tested before branch selection, and worker metadata now uses the distinct-gene count without mutating the payload or cluster result. I’m now checking the test coverage and the serialized job/result paths for edge-case disagreement.
exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-clustering-gene-universe.R | sed -n '1,340p'; nl -ba api/tests/testthat/test-unit-clustering-handler-meta.R | sed -n '1,260p'; nl -ba api/tests/testthat/test-integration-clustering-category-submit.R | sed -n '1,280p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-job-endpoint-services.R | sed -n '1,500p'; nl -ba api/tests/testthat/test-unit-job-endpoint-services-phenotype.R | sed -n '1,280p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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
   281	test_that("functional clustering: an explicit-null genes KEY + category_filter still triggers mutual exclusion -> error_400 (Codex round-2 review fix)", {
   282	  # Bug: mutual exclusion was gated on `!is.null(genes_in)`, which cannot
   283	  # distinguish an ABSENT `genes` key from an explicit JSON `null` (both
   284	  # parse to a NULL `req$argsBody$genes`) -- so
   285	  # `{"genes":null, "category_filter":["Definitive"]}` bypassed the guard and
   286	  # a category job was silently accepted. `list(genes = NULL)` in base R
   287	  # KEEPS the `genes` name with a NULL value (verified:
   288	  # "genes" %in% names(list(genes = NULL)) is TRUE), so gating on
   289	  # `names(req$argsBody)` instead of value-nullness catches this.
   290	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   291	  source_api_file("core/errors.R", local = FALSE, envir = env)
   292	  env$pool <- job_endpoint_functional_pool(env)
   293	  req <- list(
   294	    argsBody = list(genes = NULL, category_filter = list("Definitive")),
   295	    user = list(user_id = NULL)
   296	  )
   297	  res <- job_endpoint_fake_res()
   298	
   299	  expect_true("genes" %in% names(req$argsBody)) # pin the base-R name-retention fact this test relies on
   300	  expect_error(
   301	    env$svc_job_submit_functional_clustering(req, res),
   302	    class = "error_400"
   303	  )
   304	})
   305	
   306	test_that("functional clustering: an explicit-null genes KEY ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
   307	  # Regression guard for the fix above: gating mutual exclusion on JSON key
   308	  # presence must NOT change the pre-existing behavior for a null `genes`
   309	  # value with no `category_filter` at all -- it must still fall through to
   310	  # the all-NDD default exactly as before.
   311	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   312	  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
   313	    entity_id = 1:3,
   314	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
   315	    ndd_phenotype = c(1L, 0L, 1L)
   316	  ))
   317	  job_endpoint_stub_all_ndd_universe(env)
   318	  captured <- NULL
   319	  env$check_duplicate_job <- function(operation, params) {
   320	    captured <<- params
   321	    list(duplicate = TRUE, existing_job_id = "dup-null-genes")
   322	  }
   323	  req <- list(argsBody = list(genes = NULL), user = list(user_id = NULL))
   324	  res <- job_endpoint_fake_res()
   325	
   326	  out <- env$svc_job_submit_functional_clustering(req, res)
   327	
   328	  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
   329	  expect_equal(res$status, 409)
   330	  expect_equal(out$error, "DUPLICATE_JOB")
   331	})
   332	
   333	test_that("functional clustering: an EMPTY genes array ALONE (no category_filter) still defaults to the all-NDD universe, unchanged", {
   334	  # Regression guard for the fix above: gating mutual exclusion on
   335	  # `genes_supplied` (key presence) must NOT change the pre-existing
   336	  # behavior for an empty `genes` array with no `category_filter` at all --
   337	  # it must still fall through to the all-NDD default exactly as before.
   338	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   339	  env$pool <- job_endpoint_functional_pool(env, tibble::tibble(
   340	    entity_id = 1:3,
   341	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
   342	    ndd_phenotype = c(1L, 0L, 1L)
   343	  ))
   344	  job_endpoint_stub_all_ndd_universe(env)
   345	  captured <- NULL
   346	  env$check_duplicate_job <- function(operation, params) {
   347	    captured <<- params
   348	    list(duplicate = TRUE, existing_job_id = "dup-empty-genes")
   349	  }
   350	  req <- list(argsBody = list(genes = list()), user = list(user_id = NULL))
   351	  res <- job_endpoint_fake_res()
   352	
   353	  out <- env$svc_job_submit_functional_clustering(req, res)
   354	
   355	  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
   356	  expect_equal(res$status, 409)
   357	  expect_equal(out$error, "DUPLICATE_JOB")
   358	})
   359	
   360	test_that("functional clustering: category_filter resolves the universe and records the selector object + provenance in the durable payload", {
   361	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   362	  env$pool <- job_endpoint_functional_pool(env)
   363	  job_endpoint_stub_clustering_provenance(env)
   364	  env$clustering_resolve_category_universe <- function(category_filter, conn = NULL) {
   365	    expect_identical(category_filter, list("Definitive"))
   366	    list(hgnc_ids = c("HGNC:1", "HGNC:5"), selector = "Definitive", resolved_gene_count = 2L)
   367	  }
   368	  env$check_duplicate_job <- function(operation, params) {
   369	    expect_true("category_filter" %in% names(params))
   370	    expect_identical(params$category_filter, "Definitive")
   371	    list(duplicate = FALSE)
   372	  }
   373	  env$async_job_capacity_exceeded <- function(...) FALSE
   374	  env$async_job_active_count <- function(...) 0L
   375	  captured <- NULL
   376	  env$create_job <- function(operation, params) {
   377	    captured <<- params
   378	    list(job_id = "j1", status = "accepted", estimated_seconds = 5)
   379	  }
   380	  req <- list(argsBody = list(category_filter = list("Definitive")), user = list(user_id = NULL))
   381	  res <- job_endpoint_fake_res()
   382	
   383	  out <- env$svc_job_submit_functional_clustering(req, res)
   384	
   385	  expect_equal(res$status, 202)
   386	  expect_identical(captured$category_filter, "Definitive")
   387	  expect_identical(captured$genes, c("HGNC:1", "HGNC:5"))
   388	  expect_identical(captured$provenance$selector$kind, "category")
   389	  expect_identical(captured$provenance$selector$category_filter, "Definitive")
   390	  expect_true(all(
   391	    c("resolved_gene_count", "gene_list_sha256", "intended_fingerprint", "source_data_version") %in%
   392	      names(captured$provenance)
   393	  ))
   394	})
   395	
   396	test_that("functional clustering: explicit genes and no-arg submits keep a category_filter-free payload (byte-identical identity to pre-#574)", {
   397	  # Explicit genes.
   398	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   399	  env$pool <- job_endpoint_functional_pool(env)
   400	  job_endpoint_stub_clustering_provenance(env)
   401	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   402	  env$async_job_capacity_exceeded <- function(...) FALSE
   403	  env$async_job_active_count <- function(...) 0L
   404	  captured_explicit <- NULL
   405	  env$create_job <- function(operation, params) {
   406	    captured_explicit <<- params
   407	    list(job_id = "j2", status = "accepted", estimated_seconds = 5)
   408	  }
   409	  req_explicit <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   410	  env$svc_job_submit_functional_clustering(req_explicit, job_endpoint_fake_res())
   411	
   412	  expect_false("category_filter" %in% names(captured_explicit))
   413	  expect_identical(captured_explicit$provenance$selector$kind, "explicit")
   414	  expect_null(captured_explicit$provenance$selector$category_filter)
   415	
   416	  # No-arg (all-NDD default).
   417	  env2 <- job_endpoint_source_service("job-functional-submission-service.R")
   418	  env2$pool <- job_endpoint_functional_pool(env2, tibble::tibble(
   419	    entity_id = 1:2, hgnc_id = c("HGNC:1", "HGNC:2"), ndd_phenotype = c(1L, 1L)
   420	  ))
   421	  job_endpoint_stub_clustering_provenance(env2)
   422	  job_endpoint_stub_all_ndd_universe(env2)
   423	  env2$check_duplicate_job <- function(...) list(duplicate = FALSE)
   424	  env2$async_job_capacity_exceeded <- function(...) FALSE
   425	  env2$async_job_active_count <- function(...) 0L
   426	  captured_no_arg <- NULL
   427	  env2$create_job <- function(operation, params) {
   428	    captured_no_arg <<- params
   429	    list(job_id = "j3", status = "accepted", estimated_seconds = 5)
   430	  }
   431	  req_no_arg <- list(argsBody = list(), user = list(user_id = NULL))
   432	  env2$svc_job_submit_functional_clustering(req_no_arg, job_endpoint_fake_res())
   433	
   434	  expect_false("category_filter" %in% names(captured_no_arg))
   435	  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
   436	  expect_null(captured_no_arg$provenance$selector$category_filter)
   437	})
   438	
   439	test_that("functional clustering: duplicate explicit genes report a resolved_gene_count consistent with gene_list_sha256, without deduping the payload genes (Codex review fix)", {
   440	  # `gene_list_sha256` hashes sort(unique(...)), so `resolved_gene_count` must
   441	  # be computed the same way -- otherwise a duplicate-gene payload
   442	  # (`["HGNC:1","HGNC:1"]`) reports resolved_gene_count=2 alongside a
   443	  # singleton sha256. The payload `genes` list itself must stay
   444	  # byte-identical to the raw request (never deduped) -- only the COUNT
   445	  # field changes.
   446	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   447	  env$pool <- job_endpoint_functional_pool(env)
   448	  job_endpoint_stub_clustering_provenance(env)
   449	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   450	  env$async_job_capacity_exceeded <- function(...) FALSE
   451	  env$async_job_active_count <- function(...) 0L
   452	  captured <- NULL
   453	  env$create_job <- function(operation, params) {
   454	    captured <<- params
   455	    list(job_id = "j-dup-genes", status = "accepted", estimated_seconds = 5)
   456	  }
   457	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:1")), user = list(user_id = NULL))
   458	  res <- job_endpoint_fake_res()
   459	
   460	  env$svc_job_submit_functional_clustering(req, res)
   461	
   462	  expect_identical(captured$genes, c("HGNC:1", "HGNC:1")) # byte-identical, NOT deduped
   463	  expect_identical(captured$provenance$resolved_gene_count, 1L) # consistent with the sha256's dedup
   464	})
   465	
   466	test_that("functional clustering: request_hash is selector-aware for category_filter", {
   467	  # Pure-function coverage of the underlying dedup identity: sourced directly
   468	  # (not via the service env) since these are free functions in
   469	  # functions/async-job-service.R, not bare globals the service references.
   470	  hash_env <- new.env(parent = globalenv())
   471	  sys.source(file.path(get_api_dir(), "functions", "async-job-service.R"), envir = hash_env)
   472	
   473	  h <- function(genes, algo, cf) {
   474	    payload <- c(list(genes = genes, algorithm = algo), if (!is.null(cf)) list(category_filter = cf))
   475	    hash_env$async_job_service_request_hash(
   476	      "clustering",
   477	      hash_env$async_job_service_payload_json(payload)
   478	    )
   479	  }
   480	  g <- c("HGNC:1", "HGNC:5")
   481	
   482	  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
   483	  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
   484	  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
   485	})
   486	
   487	test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
   488	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   489	  env$pool <- job_endpoint_functional_pool(env)
   490	  env$analysis_string_cache_fingerprint <- function() "fp-test"
   491	  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
   492	  env$clustering_cached_source_data_version <- function(...) stop("boom")
   493	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   494	  create_job_called <- FALSE
   495	  env$create_job <- function(...) {
   496	    create_job_called <<- TRUE
   497	    NULL
   498	  }
   499	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   500	  res <- job_endpoint_fake_res()
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
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-job-endpoint-services.R | sed -n '480,620p'; git diff --unified=80 origin/master...HEAD -- api/services/job-functional-submission-service.R api/functions/async-job-handlers.R api/functions/clustering-gene-universe.R api/endpoints/jobs_endpoints.R api/bootstrap/load_modules.R; git diff --unified=20 origin/master...HEAD -- api/tests/testthat/test-unit-job-endpoint-services.R api/tests/testthat/test-unit-clustering-handler-meta.R api/tests/testthat/test-unit-clustering-gene-universe.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
   480	  g <- c("HGNC:1", "HGNC:5")
   481	
   482	  expect_false(identical(h(g, "leiden", "Definitive"), h(g, "leiden", c("Definitive", "Moderate"))))
   483	  expect_identical(h(g, "leiden", "Definitive"), h(g, "leiden", "Definitive"))
   484	  expect_identical(h(g, "leiden", NULL), h(g, "leiden", NULL)) # explicit/no-arg unchanged
   485	})
   486	
   487	test_that("functional clustering: a failing source-data-version lookup returns 503 PROVENANCE_UNAVAILABLE", {
   488	  env <- job_endpoint_source_service("job-functional-submission-service.R")
   489	  env$pool <- job_endpoint_functional_pool(env)
   490	  env$analysis_string_cache_fingerprint <- function() "fp-test"
   491	  env$clustering_gene_list_sha256 <- function(hgnc_ids) "sha-test"
   492	  env$clustering_cached_source_data_version <- function(...) stop("boom")
   493	  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
   494	  create_job_called <- FALSE
   495	  env$create_job <- function(...) {
   496	    create_job_called <<- TRUE
   497	    NULL
   498	  }
   499	  req <- list(argsBody = list(genes = list("HGNC:1", "HGNC:5")), user = list(user_id = NULL))
   500	  res <- job_endpoint_fake_res()
   501	
   502	  out <- env$svc_job_submit_functional_clustering(req, res)
   503	
   504	  expect_equal(res$status, 503L)
   505	  expect_equal(out$error, "PROVENANCE_UNAVAILABLE")
   506	  expect_false(create_job_called)
   507	})
   508	
   509	# job-phenotype-submission-service.R coverage lives in
   510	# test-unit-job-endpoint-services-phenotype.R (split out to keep this file under
   511	# the 600-line ceiling, #574 Codex-review-fix pass).
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
index 150c61e0..2afa6a18 100644
--- a/api/services/job-functional-submission-service.R
+++ b/api/services/job-functional-submission-service.R
@@ -1,240 +1,351 @@
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
+  category_supplied <- !is.null(req$argsBody$category_filter)
+  has_genes <- !is.null(genes_in) && length(genes_in) > 0
+
+  # Mutual exclusion is gated on JSON KEY PRESENCE, not value-nullness or
+  # length -- `!is.null(genes_in)` cannot distinguish an ABSENT `genes` key
+  # from an explicit JSON `null` (both parse to a NULL `req$argsBody$genes`
+  # in R), so `{"genes":null, "category_filter":["X"]}` previously slipped
+  # past the guard and silently ran a category job (Codex round-2 review
+  # fix). Checking `names(req$argsBody)` instead catches both an explicit
+  # null AND an empty array (`{"genes":[], "category_filter":["X"]}`,
+  # round-1's fix) because both forms keep the `genes` name in the parsed
+  # list. `has_genes`/`category_supplied` (value-based) are unchanged and
+  # still drive the LATER branch-selection decision below.
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
diff --git a/api/tests/testthat/test-unit-job-endpoint-services.R b/api/tests/testthat/test-unit-job-endpoint-services.R
index 3bb4b43f..29490948 100644
--- a/api/tests/testthat/test-unit-job-endpoint-services.R
+++ b/api/tests/testthat/test-unit-job-endpoint-services.R
@@ -1,77 +1,105 @@
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
@@ -80,301 +108,404 @@ job_endpoint_capture_functional_algorithm <- function(algorithm_body) {
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
   ))
-  env$check_duplicate_job <- function(...) list(duplicate = FALSE)
-  env$async_job_capacity_exceeded <- function(...) FALSE
-  env$async_job_active_count <- function(...) 0L
-  captured_params <- NULL
-  env$create_job <- function(operation, params) {
-    captured_params <<- params
-    list(job_id = "job-x", status = "accepted", estimated_seconds = 30)
+  job_endpoint_stub_all_ndd_universe(env)
+  captured <- NULL
+  env$check_duplicate_job <- function(operation, params) {
+    captured <<- params
+    list(duplicate = TRUE, existing_job_id = "dup-null-genes")
   }
-  req <- list(user = list(user_id = NULL))
+  req <- list(argsBody = list(genes = NULL), user = list(user_id = NULL))
   res <- job_endpoint_fake_res()
 
-  env$svc_job_submit_phenotype_clustering(req, res)
+  out <- env$svc_job_submit_functional_clustering(req, res)
 
-  # Only review_id 1 (primary + approved) survives the gather step; review 2
-  # (unapproved) and review 3 (not primary) must never reach the clustering
-  # input, even though review 2 is attached to the same (otherwise-included)
-  # entity_id as review 1.
-  expect_equal(captured_params$ndd_entity_review_tbl$review_id, 1L)
+  expect_equal(sort(captured$genes), c("HGNC:1", "HGNC:3"))
+  expect_equal(res$status, 409)
+  expect_equal(out$error, "DUPLICATE_JOB")
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
 
+  expect_false("category_filter" %in% names(captured_no_arg))
+  expect_identical(captured_no_arg$provenance$selector$kind, "all_ndd")
+  expect_null(captured_no_arg$provenance$selector$category_filter)
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

exec
/bin/bash -lc 'rg -n -C 6 "''^(create_job|check_duplicate_job)|check_duplicate_job'"\\(|async_job_service_request_hash|async_job_service_submit\\(\" api/functions api/services | head -n 400; nl -ba api/functions/job-manager.R | sed -n '1,300p'; nl -ba api/functions/async-job-service.R | sed -n '1,260p'; rg -n \"public_ready|analysis_snapshot\" api/services/job-functional-submission-service.R api/functions/async-job-handlers.R api/functions/job-manager.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
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
--
api/services/admin-publication-refresh-endpoint-service.R-1-# api/services/admin-publication-refresh-endpoint-service.R
api/services/admin-publication-refresh-endpoint-service.R-2-#
api/services/admin-publication-refresh-endpoint-service.R-3-# Service layer for POST /admin/publications/refresh, extracted from
api/services/admin-publication-refresh-endpoint-service.R-4-# api/endpoints/admin_endpoints.R (issue #346, Wave 3).
api/services/admin-publication-refresh-endpoint-service.R-5-#
api/services/admin-publication-refresh-endpoint-service.R-6-# `create_job()` (functions/job-manager.R) is a durable-job compatibility
api/services/admin-publication-refresh-endpoint-service.R:7:# facade: it routes through `async_job_service_submit(job_type = operation,
api/services/admin-publication-refresh-endpoint-service.R-8-# request_payload = params)`. The real, currently-executed handler is
api/services/admin-publication-refresh-endpoint-service.R-9-# `.async_job_run_publication_refresh()` in functions/async-job-handlers.R
api/services/admin-publication-refresh-endpoint-service.R-10-# (registered in `async_job_handler_registry`), which already has the
api/services/admin-publication-refresh-endpoint-service.R-11-# publication_date_source fix, the same 350ms rate limit, and its own DB
api/services/admin-publication-refresh-endpoint-service.R-12-# connection lifecycle.
api/services/admin-publication-refresh-endpoint-service.R-13-#
--
api/services/job-maintenance-submission-service.R-20-# concurrently — including across a deploy that changes its payload schema.
api/services/job-maintenance-submission-service.R-21-# `create_job()` submits only the operation and payload; registered durable
api/services/job-maintenance-submission-service.R-22-# handlers execute the work.
api/services/job-maintenance-submission-service.R-23-#
api/services/job-maintenance-submission-service.R-24-# This is an ENDPOINT service: it is sourced by the shared bootstrap loader
api/services/job-maintenance-submission-service.R-25-# (api/bootstrap/load_modules.R) like any other services/* file, and only ever
api/services/job-maintenance-submission-service.R:26:# submits durable jobs (`async_job_service_submit()`); the worker executes the
api/services/job-maintenance-submission-service.R-27-# registered handlers, never these svc_ functions.
api/services/job-maintenance-submission-service.R-28-
api/services/job-maintenance-submission-service.R-29-#' Submit a disease ontology update job (MONDO + OMIM).
api/services/job-maintenance-submission-service.R-30-#'
api/services/job-maintenance-submission-service.R-31-#' @param res Plumber response, mutated in place (status + headers).
api/services/job-maintenance-submission-service.R-32-#' @return List payload for the `json` serializer.
--
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
--
api/services/job-functional-submission-service.R-122-  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
api/services/job-functional-submission-service.R-123-  # submits keep the pre-#574 dedup identity byte-identical.
api/services/job-functional-submission-service.R-124-  dup_params <- list(genes = genes_list, algorithm = algorithm)
api/services/job-functional-submission-service.R-125-  if (!is.null(selector_chr)) {
api/services/job-functional-submission-service.R-126-    dup_params$category_filter <- selector_chr
api/services/job-functional-submission-service.R-127-  }
api/services/job-functional-submission-service.R:128:  dup_check <- check_duplicate_job("clustering", dup_params)
api/services/job-functional-submission-service.R-129-  if (dup_check$duplicate) {
api/services/job-functional-submission-service.R-130-    res$status <- 409
api/services/job-functional-submission-service.R-131-    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
api/services/job-functional-submission-service.R-132-    return(list(
api/services/job-functional-submission-service.R-133-      error = "DUPLICATE_JOB",
api/services/job-functional-submission-service.R-134-      message = "Identical job already running",
--
api/services/job-phenotype-submission-service.R-82-  params_hash_input <- list(
api/services/job-phenotype-submission-service.R-83-    entity_count = nrow(ndd_entity_view_tbl),
api/services/job-phenotype-submission-service.R-84-    operation = "phenotype_clustering"
api/services/job-phenotype-submission-service.R-85-  )
api/services/job-phenotype-submission-service.R-86-
api/services/job-phenotype-submission-service.R-87-  # Check for duplicate
api/services/job-phenotype-submission-service.R:88:  dup_check <- check_duplicate_job("phenotype_clustering", params_hash_input)
api/services/job-phenotype-submission-service.R-89-  if (dup_check$duplicate) {
api/services/job-phenotype-submission-service.R-90-    res$status <- 409
api/services/job-phenotype-submission-service.R-91-    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
api/services/job-phenotype-submission-service.R-92-    return(list(
api/services/job-phenotype-submission-service.R-93-      error = "DUPLICATE_JOB",
api/services/job-phenotype-submission-service.R-94-      message = "Identical job already running",
--
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
--
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
--
api/services/disease-ontology-mapping-service.R-121-
api/services/disease-ontology-mapping-service.R-122-  sched <- now
api/services/disease-ontology-mapping-service.R-123-  if (stagger && stagger_seconds > 0L) {
api/services/disease-ontology-mapping-service.R-124-    sched <- now + stagger_seconds
api/services/disease-ontology-mapping-service.R-125-  }
api/services/disease-ontology-mapping-service.R-126-
api/services/disease-ontology-mapping-service.R:127:  # queue_name intentionally omitted so async_job_service_submit() routes this
api/services/disease-ontology-mapping-service.R-128-  # heavy external MONDO refresh to the "maintenance" lane by job type (#486); it
api/services/disease-ontology-mapping-service.R-129-  # is a maintenance-classified job and must not run on the interactive lane.
api/services/disease-ontology-mapping-service.R-130-  outcome <- submit_fn(
api/services/disease-ontology-mapping-service.R-131-    job_type        = "disease_ontology_mapping_refresh",
api/services/disease-ontology-mapping-service.R-132-    request_payload = list(force = force),
api/services/disease-ontology-mapping-service.R-133-    priority        = 50L,
--
api/functions/job-manager.R-30-#' \dontrun{
api/functions/job-manager.R-31-#' result <- create_job(
api/functions/job-manager.R-32-#'   operation = "clustering",
api/functions/job-manager.R-33-#'   params = list(genes = c("BRCA1", "TP53"))
api/functions/job-manager.R-34-#' )
api/functions/job-manager.R-35-#' }
api/functions/job-manager.R:36:create_job <- function(operation, params) {
api/functions/job-manager.R:37:  submitted <- async_job_service_submit(
api/functions/job-manager.R-38-    job_type = operation,
api/functions/job-manager.R-39-    request_payload = params
api/functions/job-manager.R-40-  )
api/functions/job-manager.R-41-
api/functions/job-manager.R-42-  job_id <- if (nrow(submitted$job) > 0) submitted$job$job_id[[1]] else NULL
api/functions/job-manager.R-43-
--
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
--
api/functions/async-job-service.R-166-      dataframe = "rows",
api/functions/async-job-service.R-167-      POSIXt = "ISO8601"
api/functions/async-job-service.R-168-    )
api/functions/async-job-service.R-169-  )
api/functions/async-job-service.R-170-}
api/functions/async-job-service.R-171-
api/functions/async-job-service.R:172:async_job_service_request_hash <- function(job_type, request_payload_json) {
api/functions/async-job-service.R-173-  digest::digest(
api/functions/async-job-service.R-174-    paste0(
api/functions/async-job-service.R-175-      .async_job_service_non_empty_string(job_type, "job_type"),
api/functions/async-job-service.R-176-      ":",
api/functions/async-job-service.R-177-      as.character(.async_job_service_scalar(request_payload_json, ""))
api/functions/async-job-service.R-178-    ),
--
api/functions/async-job-service.R-237-  }
api/functions/async-job-service.R-238-  if (is.null(priority)) {
api/functions/async-job-service.R-239-    priority <- async_job_priority_for_type(job_type)
api/functions/async-job-service.R-240-  }
api/functions/async-job-service.R-241-  queue_name <- .async_job_service_non_empty_string(queue_name, "queue_name")
api/functions/async-job-service.R-242-  payload_json <- async_job_service_payload_json(request_payload)
api/functions/async-job-service.R:243:  request_hash <- async_job_service_request_hash(job_type, payload_json)
api/functions/async-job-service.R-244-  submitted_at <- Sys.time()
api/functions/async-job-service.R-245-
api/functions/async-job-service.R-246-  stored_job <- tryCatch(
api/functions/async-job-service.R-247-    {
api/functions/async-job-service.R-248-      async_job_repository_create(
api/functions/async-job-service.R-249-        list(
--
api/functions/async-job-service.R-317-    list(
api/functions/async-job-service.R-318-      job_id = job_id,
api/functions/async-job-service.R-319-      job_type = job_type,
api/functions/async-job-service.R-320-      queue_name = queue_name,
api/functions/async-job-service.R-321-      priority = as.integer(priority),
api/functions/async-job-service.R-322-      status = "completed",
api/functions/async-job-service.R:323:      request_hash = async_job_service_request_hash(job_type, payload_json),
api/functions/async-job-service.R-324-      request_payload_json = payload_json,
api/functions/async-job-service.R-325-      submitted_by = if (is.null(submitted_by)) NULL else as.integer(submitted_by),
api/functions/async-job-service.R-326-      submitted_at = submitted_at,
api/functions/async-job-service.R-327-      scheduled_at = submitted_at,
api/functions/async-job-service.R-328-      started_at = submitted_at,
api/functions/async-job-service.R-329-      completed_at = completed_at,
--
api/functions/async-job-service.R-347-async_job_service_find_duplicate <- function(job_type, request_payload, conn = NULL) {
api/functions/async-job-service.R-348-  job_type <- .async_job_service_non_empty_string(job_type, "job_type")
api/functions/async-job-service.R-349-  payload_json <- async_job_service_payload_json(request_payload)
api/functions/async-job-service.R-350-
api/functions/async-job-service.R-351-  async_job_repository_find_active_duplicate(
api/functions/async-job-service.R-352-    job_type = job_type,
api/functions/async-job-service.R:353:    request_hash = async_job_service_request_hash(job_type, payload_json),
api/functions/async-job-service.R-354-    conn = conn
api/functions/async-job-service.R-355-  )
api/functions/async-job-service.R-356-}
api/functions/async-job-service.R-357-
api/functions/async-job-service.R-358-#' Read current durable async job status
api/functions/async-job-service.R-359-#'
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
api/functions/async-job-handlers.R:13:#   - functions/async-job-analysis-snapshot-handlers.R (analysis_snapshot_refresh)
api/functions/async-job-handlers.R:339:  analysis_snapshot_refresh = list(
api/functions/async-job-handlers.R:341:    run = function(...) .async_job_run_analysis_snapshot_refresh(...),

exec
/bin/bash -lc "git show origin/master:api/endpoints/jobs_endpoints.R | nl -ba | sed -n '1,300p'; git show origin/master:api/functions/async-job-service.R | nl -ba | sed -n '150,290p'; git show origin/master:api/functions/job-manager.R | nl -ba | sed -n '1,80p'; git show origin/master:api/services/job-functional-submission-service.R 2>/dev/null | head -n 15 || true; git show origin/master:api/functions/async-job-repository.R | rg -n -C 5 \"request_hash|duplicate|find_active\"" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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

44-#' @return Character job_id.
45-#' @export
46-async_job_repository_create <- function(job, conn = NULL) {
47-  .async_job_require_fields(
48-    job,
49:    c("job_id", "job_type", "request_payload_json", "request_hash")
50-  )
51-
52-  submitted_at <- .async_job_scalar(job$submitted_at, Sys.time())
53-  scheduled_at <- .async_job_scalar(job$scheduled_at, submitted_at)
54-
--
56-    job_id = .async_job_scalar(job$job_id),
57-    job_type = .async_job_scalar(job$job_type),
58-    queue_name = .async_job_scalar(job$queue_name, "default"),
59-    priority = as.integer(.async_job_scalar(job$priority, 100L)),
60-    status = .async_job_scalar(job$status, "queued"),
61:    request_hash = .async_job_scalar(job$request_hash),
62-    request_payload_json = .async_job_scalar(job$request_payload_json),
63-    submitted_at = submitted_at,
64-    scheduled_at = scheduled_at,
65-    attempt_count = as.integer(.async_job_scalar(job$attempt_count, 0L)),
66-    max_attempts = as.integer(.async_job_scalar(job$max_attempts, 1L))
--
112-  tryCatch(
113-    {
114-      db_execute_statement(sql, params, conn = conn)
115-    },
116-    db_statement_error = function(e) {
117:      is_duplicate <- grepl(
118:        "idx_async_jobs_active_request_hash",
119-        e$message,
120-        fixed = TRUE
121-      )
122:      if (!is_duplicate) {
123-        stop(e)
124-      }
125-
126:      duplicate <- async_job_repository_find_active_duplicate(
127-        job_type = .async_job_scalar(job$job_type),
128:        request_hash = .async_job_scalar(job$request_hash),
129-        conn = conn
130-      )
131-
132-      abort(
133-        message = "Active async job with matching request hash already exists",
134:        class = "async_job_duplicate_error",
135:        job_id = if (nrow(duplicate) > 0) duplicate$job_id[[1]] else NULL,
136:        duplicate_job = duplicate
137-      )
138-    }
139-  )
140-
141-  .async_job_scalar(job$job_id)
--
156-  )
157-
158-  db_execute_query(sql, list(job_id), conn = conn)
159-}
160-
161:#' Find an active duplicate by job_type and durable request hash
162-#'
163-#' @param job_type Character job type.
164:#' @param request_hash Character durable request hash.
165-#' @param conn Optional connection or pool for dependency injection.
166-#'
167:#' @return Tibble with zero or one active duplicate row.
168-#' @export
169:# "Active" = in-flight OR retryable-failed. Shared by the hash-keyed duplicate
170-# lookup and the job-type single-flight lookup so they stay identical.
171-.async_job_active_status_sql <- paste(
172-  "(status IN ('queued', 'running', 'cancel_requested')",
173-  "OR (status = 'failed' AND attempt_count < max_attempts AND next_attempt_at IS NOT NULL))"
174-)
175-
176:async_job_repository_find_active_duplicate <- function(job_type, request_hash, conn = NULL) {
177-  sql <- paste(
178-    .async_job_build_select(FALSE),
179:    "FROM async_jobs WHERE job_type = ? AND request_hash = ?",
180-    "AND", .async_job_active_status_sql,
181-    "ORDER BY submitted_at DESC LIMIT 1"
182-  )
183-
184:  db_execute_query(sql, list(job_type, request_hash), conn = conn)
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
199:async_job_repository_find_active_by_type <- function(job_type, conn = NULL) {
200-  sql <- paste(
201-    .async_job_build_select(FALSE),
202-    "FROM async_jobs WHERE job_type = ?",
203-    "AND", .async_job_active_status_sql,
204-    "ORDER BY submitted_at DESC LIMIT 1"

exec
/bin/bash -lc "git show origin/master:api/services/job-functional-submission-service.R | nl -ba | sed -n '35,360p'; git diff --word-diff=porcelain origin/master...HEAD -- api/services/job-functional-submission-service.R | sed -n '1,500p'; git show origin/master:api/functions/job-manager.R | rg -n -C 5 \"check_duplicate_job\"; git log --oneline --decorate origin/master..HEAD" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
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
diff --git a/api/services/job-functional-submission-service.R b/api/services/job-functional-submission-service.R
index 150c61e0..2afa6a18 100644
--- a/api/services/job-functional-submission-service.R
+++ b/api/services/job-functional-submission-service.R
@@ -24,8 +24,16 @@
 #' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
~
 #' new durable job via `create_job()`.
~
 #'
~
 #' 
+The clustering gene universe (#574) is one of: an explicit `genes` list, a
~
+#' curated-category selection via `category_filter` (resolved through
~
+#' `clustering_resolve_category_universe()`), or -- when neither is supplied
~
+#' -- the existing default all-NDD-genes universe. `genes` and
~
+#' `category_filter` are mutually exclusive (400 if both are present). Every
~
+#' submit records selector + fingerprint provenance in the durable payload
~
+#' and (on a cache hit) the result meta; see `clustering-gene-universe.R`.
~
+#'
~
+#'
  @param req Plumber request (reads 
-`req$argsBody$genes`/`algorithm` and
+`req$argsBody$genes`/`algorithm`/
~
 #'   
+`category_filter` and
  `req$user$user_id`).
~
 #' @param res Plumber response, mutated in place (status + headers).
~
 #' @return List payload for the `json` serializer.
~
 #' @export
~
@@ -41,10 +49,30 @@ svc_job_submit_functional_clustering <- function(req, res) {
 
~
   # Extract request data before durable submission.
~
 
~
   # Connection objects cannot cross process 
-boundaries
~
-  genes_list
+boundaries. `genes` and
~
+  # `category_filter` are mutually exclusive gene-universe selectors (#574):
~
+  # an explicit gene list, a curated-category selection, or (both absent) the
~
+  # existing default all-NDD-genes universe.
~
+  genes_in <- req$argsBody$genes
~
+  category_supplied <- !is.null(req$argsBody$category_filter)
~
+  has_genes
  <- 
+!is.null(genes_in) && length(genes_in) > 0
~
~
+  # Mutual exclusion is gated on JSON KEY PRESENCE, not value-nullness or
~
+  # length -- `!is.null(genes_in)` cannot distinguish an ABSENT `genes` key
~
+  # from an explicit JSON `null` (both parse to a
  NULL 
+`req$argsBody$genes`
~
+  # in R), so `{"genes":null, "category_filter":["X"]}` previously slipped
~
+  # past the guard and silently ran a category job (Codex round-2 review
~
+  # fix). Checking `names(req$argsBody)` instead catches both an explicit
~
+  # null AND an empty array (`{"genes":[], "category_filter":["X"]}`,
~
+  # round-1's fix) because both forms keep the `genes` name in the parsed
~
+  # list. `has_genes`/`category_supplied` (value-based) are unchanged and
~
+  # still drive the LATER branch-selection decision below.
~
+  body_names <- names(req$argsBody)
~
+  genes_key <- "genes" %in% body_names
~
+  category_key <- "category_filter" %in% body_names
~
~
   if 
-(!is.null(req$argsBody$genes))
+(genes_key && category_key)
  {
~
     
-genes_list <- req$argsBody$genes
+stop_for_bad_request("Provide either genes or category_filter, not both")
~
   }
~
 
~
   # Extract algorithm parameter (default: leiden)
~
@@ -62,17 +90,24 @@ svc_job_submit_functional_clustering <- function(req, res) {
     }
~
   }
~
 
~
   # 
-If no genes provided, use default (all NDD genes)
+Resolve the clustering gene universe + selector provenance (#574). The
~
   # 
-This matches current functional_clustering endpoint behavior
+explicit-genes and no-arg (all-NDD) branches are unchanged in substance
~
+  # from before this feature: `clustering_resolve_category_universe(NULL)`
~
+  # calls the same `generate_ndd_hgnc_ids()` query the old inline block used,
~
+  # so cache parity (memoise key = gene set + algorithm) is preserved.
~
+  selector_chr <- NULL
~
   if 
-(is.null(genes_list) || length(genes_list) == 0)
+(has_genes)
  {
~
     genes_list <- 
-pool %>%
~
-      dplyr::tbl("ndd_entity_view") %>%
~
-      dplyr::arrange(entity_id) %>%
~
-      dplyr::filter(ndd_phenotype == 1) %>%
~
-      dplyr::select(hgnc_id) %>%
~
-      dplyr::collect() %>%
~
-      unique() %>%
~
-      dplyr::pull(hgnc_id)
+as.character(unlist(genes_in))
~
+    kind <- "explicit"
~
+  } else if (category_supplied) {
~
+    universe <- clustering_resolve_category_universe(req$argsBody$category_filter)
~
+    genes_list <- universe$hgnc_ids
~
+    selector_chr <- universe$selector
~
+    kind <- "category"
~
+  } else {
~
+    universe <- clustering_resolve_category_universe(NULL)
~
+    genes_list <- universe$hgnc_ids
~
+    kind <- "all_ndd"
~
   }
~
 
~
   # Pre-fetch the STRING ID table because DB connections cannot cross the
~
@@ -83,8 +118,14 @@ svc_job_submit_functional_clustering <- function(req, res) {
     dplyr::select(symbol, hgnc_id, STRING_id) %>%
~
     dplyr::collect()
~
 
~
   # Check for duplicate job (include algorithm in 
-check)
~
-  dup_check
+check). The selector is
~
+  # folded into the dedup identity ONLY for category runs -- explicit/no-arg
~
+  # submits keep the pre-#574 dedup identity byte-identical.
~
+  dup_params
  <-
-check_duplicate_job("clustering",
  list(genes = genes_list, algorithm = 
-algorithm))
+algorithm)
~
+  if (!is.null(selector_chr)) {
~
+    dup_params$category_filter <- selector_chr
~
+  }
~
+  dup_check <- check_duplicate_job("clustering", dup_params)
~
   if (dup_check$duplicate) {
~
     res$status <- 409
~
     res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
~
@@ -96,6 +137,54 @@ svc_job_submit_functional_clustering <- function(req, res) {
     ))
~
   }
~
 
~
   
+# Cheap-path provenance (no expensive query yet). `selector_obj` records
~
+  # WHICH universe was resolved; `intended_fingerprint` records the STRING
~
+  # cache identity + fixed clustering params this submit intends to run
~
+  # with. The *effective* fingerprint (e.g. the STRING weight channel a
~
+  # computed result actually used) is only knowable from a computed result,
~
+  # so it is recorded separately in the cache-hit result meta below.
~
+  selector_obj <- list(kind = kind, category_filter = selector_chr)
~
+  intended_fingerprint <- list(
~
+    string_cache_fingerprint = analysis_string_cache_fingerprint(),
~
+    score_threshold = 400L,
~
+    algorithm = algorithm,
~
+    seed = 42L
~
+  )
~
+  gene_sha <- clustering_gene_list_sha256(genes_list)
~
+  # `gene_list_sha256` hashes sort(unique(...)); the provenance/meta gene
~
+  # count must agree with it, so it is computed from the SAME dedup -- an
~
+  # explicit payload with duplicate genes (e.g. `["HGNC:1","HGNC:1"]`) must
~
+  # not report a resolved count that disagrees with a singleton sha256. This
~
+  # never dedups the payload `genes` list itself (`genes_list` stays
~
+  # byte-identical to the raw request) -- only the reported COUNT (Codex
~
+  # review fix).
~
+  resolved_count <- length(unique(genes_list))
~
~
+  # Source-data version: a CACHED, fail-closed read, fetched only now that a
~
+  # payload is actually about to be built -- its backing view runs global
~
+  # counts/joins, so it must never run before admission/dedup. A lookup
~
+  # failure must never silently record NA/broken provenance; fail the
~
+  # request closed instead.
~
+  src_ver <- tryCatch(
~
+    clustering_cached_source_data_version(conn = pool),
~
+    error = function(e) e
~
+  )
~
+  if (inherits(src_ver, "error")) {
~
+    res$status <- 503L
~
+    return(list(
~
+      error = "PROVENANCE_UNAVAILABLE",
~
+      message = "Snapshot source-data version unavailable; retry shortly."
~
+    ))
~
+  }
~
~
+  provenance <- list(
~
+    selector = selector_obj,
~
+    resolved_gene_count = resolved_count,
~
+    gene_list_sha256 = gene_sha,
~
+    intended_fingerprint = intended_fingerprint,
~
+    source_data_version = src_ver
~
+  )
~
~
   # Define category links (needed for result)
~
   category_links <- tibble::tibble(
~
     value = c(
~
@@ -150,24 +239,41 @@ svc_job_submit_functional_clustering <- function(req, res) {
       dplyr::select(value = category, text) %>%
~
       dplyr::left_join(category_links, by = c("value"))
~
 
~
     
+# Splice the base cache-hit fields with `provenance` (already assembled
~
+    # above as selector/resolved_gene_count/gene_list_sha256/
~
+    # intended_fingerprint/source_data_version) via the shared
~
+    # `clustering_result_meta()` helper (clustering-gene-universe.R) instead of
~
+    # re-listing the same fields as duplicate literals -- keeps this shape in
~
+    # lockstep with the worker-run handler's result meta by construction.
~
+    # `effective_fingerprint` is only knowable from the computed result
~
+    # (`cached_clusters`), so it is not part of the cheap-path `provenance` list.
~
     cache_result <- list(
~
       clusters = cached_clusters,
~
       categories = categories,
~
       meta = 
+clustering_result_meta(
~
         list(
~
           algorithm = algorithm,
~
           gene_count = 
-length(genes_list),
+resolved_count,
~
           cluster_count = nrow(cached_clusters),
~
           cache_hit = TRUE
~
         
+),
~
+        provenance,
~
+        attr(cached_clusters, "weight_channel")
~
       )
~
     )
~
     
+cache_request_payload <- list(
~
+      genes = genes_list,
~
+      algorithm = algorithm,
~
+      category_links = category_links,
~
+      string_id_table = string_id_table,
~
+      provenance = provenance
~
+    )
~
+    if (!is.null(selector_chr)) {
~
+      cache_request_payload$category_filter <- selector_chr
~
+    }
~
     completed_job <- async_job_service_store_completed(
~
       job_type = "clustering",
~
       request_payload = 
-list(
~
-        genes = genes_list,
~
-        algorithm = algorithm,
~
-        category_links = category_links,
~
-        string_id_table = string_id_table
~
-      ),
+cache_request_payload,
~
       result = cache_result,
~
       submitted_by = req$user$user_id %||% NULL,
~
       queue_name = "analysis",
~
@@ -209,14 +315,19 @@ svc_job_submit_functional_clustering <- function(req, res) {
   }
~
 
~
   # Cache miss - create async job
~
   
+job_params <- list(
~
+    genes = genes_list,
~
+    algorithm = algorithm,
~
+    category_links = category_links,
~
+    string_id_table = string_id_table,
~
+    provenance = provenance
~
+  )
~
+  if (!is.null(selector_chr)) {
~
+    job_params$category_filter <- selector_chr
~
+  }
~
   result <- create_job(
~
     operation = "clustering",
~
     params = 
-list(
~
-      genes = genes_list,
~
-      algorithm = algorithm,
~
-      category_links = category_links,
~
-      string_id_table = string_id_table
~
-    )
+job_params
~
   )
~
 
~
   # Check capacity
~
216-#'   - duplicate=TRUE, existing_job_id: if duplicate found
217-#'   - duplicate=FALSE: if no duplicate
218-#'
219-#' @examples
220-#' \dontrun{
221:#' dup <- check_duplicate_job("clustering", list(genes = c("BRCA1")))
222-#' if (dup$duplicate) {
223-#'   return_existing_job(dup$existing_job_id)
224-#' }
225-#' }
226:check_duplicate_job <- function(operation, params) {
227-  async_job_service_duplicate(operation, params)
228-}
229-
230-#' Job-type single-flight duplicate check for destructive maintenance jobs.
231-#'
232:#' Same `(operation, params)` shape as [check_duplicate_job()] so it is a
233-#' drop-in `duplicate_check_fn` seam, but dedupes on job_type alone rather than
234-#' the payload hash (#535 S2b HIGH-4): a full-table-replace maintenance job must
235-#' never run concurrently, including across a deploy that changes its payload
236-#' schema. `params` is ignored.
237-#'
34d8701d (HEAD -> feat/category-clustering-universes-574) fix(api): key-presence mutual exclusion + distinct gene_count in worker meta (#574 Codex round 2)
c3422dd2 fix(api): reject empty-genes+category, fail-closed NA source-version, dedup provenance count (#574 Codex review)
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
/bin/bash -lc "rg -n -C 15 \"generate_ndd_hgnc_ids\\s*<-|gen_string_clust_obj(_mem)?\\s*<-\" api/functions/analyses-functions.R; rg -n -C 8 \"async_job_service_duplicate\\s*<-|async_job_service_store_completed\\s*<-\" api/functions/async-job-service.R; git diff --numstat origin/master...HEAD -- ':(exclude).planning/**'; git diff --name-only origin/master...HEAD -- ':(exclude).planning/**' | while IFS= read -r f; do wc -l \""'$f"; done; git status --short' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
135-}
136-
137-#' A recursive function generating a functional gene cluster with string-db
138-#'
139-#' @param hgnc_list A comma separated list as concatenated text
140-#' @param min_size A number defining the minimal cluster size to return
141-#' @param subcluster Boolean value indicating whether to perform subclustering
142-#' @param parent the parent cluster name used in the generation of subclusters
143-#' @param enrichment Boolean value indicating whether to perform enrichment
144-#' @param algorithm Clustering algorithm name (default: "leiden")
145-#' @param string_id_table Pre-fetched STRING ID table (for daemon context)
146-#' @param score_threshold STRING confidence score threshold (0-1000, default 400 = medium)
147-#'
148-#' @return The clusters tibble
149-#' @export
150:gen_string_clust_obj <- function(
151-  hgnc_list,
152-  min_size = 10,
153-  resolution = 1.0,
154-  subcluster = TRUE,
155-  parent = NA,
156-  enrichment = TRUE,
157-  algorithm = "leiden",
158-  string_id_table = NULL,
159-  score_threshold = 400,
160-  # #514: folded into the memoise key so a methodology/data/channel change
161-  # self-invalidates the disk cache. Call-time default (memoise hashes it);
162-  # the body ignores it. Self-guarding so minimal/test envs without the
163-  # fingerprint module degrade to a constant NULL key component instead of erroring.
164-  .cache_fingerprint = if (exists("analysis_cache_fingerprint", mode = "function")) {
165-    analysis_cache_fingerprint("string")
--
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
290-#' @param priority Integer queue priority.
291-#' @param job_id Optional explicit job id.
292-#' @param submitted_at Optional submission timestamp.
293-#' @param completed_at Optional completion timestamp.
294-#' @param conn Optional DB connection or pool.
295-#'
296-#' @return Tibble with the stored completed job row.
297-#' @export
298:async_job_service_store_completed <- function(
299-  job_type,
300-  request_payload,
301-  result,
302-  submitted_by = NULL,
303-  queue_name = "default",
304-  priority = 100L,
305-  job_id = uuid::UUIDgenerate(),
306-  submitted_at = Sys.time(),
--
411-}
412-
413-#' Legacy duplicate response wrapper for endpoints not migrated yet
414-#'
415-#' @inheritParams async_job_service_find_duplicate
416-#'
417-#' @return List shaped like the previous duplicate helper.
418-#' @export
419:async_job_service_duplicate <- function(job_type, request_payload, conn = NULL) {
420-  duplicate <- async_job_service_find_duplicate(
421-    job_type = job_type,
422-    request_payload = request_payload,
423-    conn = conn
424-  )
425-
426-  if (nrow(duplicate) == 0) {
427-    return(list(duplicate = FALSE))
2	0	AGENTS.md
47	0	CHANGELOG.md
6	0	api/bootstrap/load_modules.R
34	1	api/endpoints/jobs_endpoints.R
36	5	api/functions/async-job-handlers.R
157	0	api/functions/clustering-gene-universe.R
147	36	api/services/job-functional-submission-service.R
10	0	api/tests/testthat/job-endpoint-services-fixtures.R
206	0	api/tests/testthat/test-integration-clustering-category-submit.R
4	0	api/tests/testthat/test-unit-async-job-handlers.R
3	0	api/tests/testthat/test-unit-async-job-worker.R
278	0	api/tests/testthat/test-unit-clustering-gene-universe.R
171	0	api/tests/testthat/test-unit-clustering-handler-meta.R
223	0	api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
285	154	api/tests/testthat/test-unit-job-endpoint-services.R
1	1	api/version_spec.json
2	2	app/package-lock.json
1	1	app/package.json
15	0	documentation/08-development.qmd
284 AGENTS.md
1272 CHANGELOG.md
288 api/bootstrap/load_modules.R
174 api/endpoints/jobs_endpoints.R
398 api/functions/async-job-handlers.R
157 api/functions/clustering-gene-universe.R
351 api/services/job-functional-submission-service.R
60 api/tests/testthat/job-endpoint-services-fixtures.R
206 api/tests/testthat/test-integration-clustering-category-submit.R
266 api/tests/testthat/test-unit-async-job-handlers.R
754 api/tests/testthat/test-unit-async-job-worker.R
278 api/tests/testthat/test-unit-clustering-gene-universe.R
171 api/tests/testthat/test-unit-clustering-handler-meta.R
223 api/tests/testthat/test-unit-job-endpoint-services-phenotype.R
511 api/tests/testthat/test-unit-job-endpoint-services.R
14 api/version_spec.json
20508 app/package-lock.json
135 app/package.json
458 documentation/08-development.qmd
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-prompt.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-reconciliation.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview-prompt.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview3-prompt.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-rereview3.md
?? .planning/reviews/2026-07-19-574-slice-d-diff-codex-review.md

codex
The focused test command is blocked by the read-only sandbox because R cannot create its temporary files; the static diff check is clean. I’m completing the contract audit from the source and the test fixtures themselves.
exec
/bin/bash -lc "git diff origin/master...HEAD -- ':(exclude).planning/**' > /dev/null && git diff --check origin/master...HEAD -- ':(exclude).planning/**' && git diff --unified=8 origin/master...HEAD -- app/package.json app/package-lock.json api/version_spec.json AGENTS.md CHANGELOG.md documentation/08-development.qmd api/tests/testthat/test-unit-async-job-handlers.R api/tests/testthat/test-unit-async-job-worker.R api/tests/testthat/job-endpoint-services-fixtures.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574
 succeeded in 0ms:
diff --git a/AGENTS.md b/AGENTS.md
index 7aa9b3e1..e9647c88 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -118,16 +118,18 @@ Analysis-snapshot **releases** are immutable, content-addressed, frozen exports
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
diff --git a/CHANGELOG.md b/CHANGELOG.md
index 48651d8b..d3058047 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -1,16 +1,63 @@
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
diff --git a/api/version_spec.json b/api/version_spec.json
index 86e2b6e6..5efd7ddc 100644
--- a/api/version_spec.json
+++ b/api/version_spec.json
@@ -1,12 +1,12 @@
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
diff --git a/app/package-lock.json b/app/package-lock.json
index bcc638de..73e3f535 100644
--- a/app/package-lock.json
+++ b/app/package-lock.json
@@ -1,17 +1,17 @@
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
diff --git a/app/package.json b/app/package.json
index ea8dbd91..5004dbe1 100644
--- a/app/package.json
+++ b/app/package.json
@@ -1,11 +1,11 @@
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
diff --git a/documentation/08-development.qmd b/documentation/08-development.qmd
index c56d803e..1c553653 100644
--- a/documentation/08-development.qmd
+++ b/documentation/08-development.qmd
@@ -187,16 +187,31 @@ mkdir -p /tmp/asr-verify && tar -xzf bundle.tar.gz -C /tmp/asr-verify
 
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
 

codex
Round-2 fixes are resolved:

- Mutual exclusion: resolved. `names(req$argsBody)` correctly rejects both `genes:null` and `genes:[]` when `category_filter` is also present, while each single-selector/default form remains accepted.
- Duplicate-gene metadata: resolved. Both paths report `length(unique(genes))`; raw payload genes and `nrow(clusters)` remain unchanged.

Findings:

- HIGH — [job-functional-submission-service.R:269](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:269), [job-functional-submission-service.R:323](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:323): explicit/no-arg durable payloads now include `provenance`. Since `async_job_service_submit()` hashes the full serialized payload, their persisted `request_hash` is not byte-identical to pre-#574 despite the stated locked contract. An active pre-deploy explicit job and an identical post-deploy submission have different hashes, so the DB active-job uniqueness guard can admit duplicate clustering work. Fix: separate the durable handler payload from a stable dedup/hash payload (`genes`, `algorithm`, and normalized `category_filter` only when category-selected), and use that identity consistently for preflight and persisted request hashes.

Other locked contracts hold in the reviewed code: entity-level dbplyr resolution; default behavior; empty/<2/category validation errors; allowed-set error message; namespacing; provenance/effective fingerprint on both paths; fail-closed source version; and no `public_ready` path.

`git diff --check` passed. Targeted R tests and `make code-quality-audit` could not run because the read-only sandbox prevents temporary-file creation.

**VERDICT: NO-SHIP — 1 HIGH**
tokens used
136,722
Round-2 fixes are resolved:

- Mutual exclusion: resolved. `names(req$argsBody)` correctly rejects both `genes:null` and `genes:[]` when `category_filter` is also present, while each single-selector/default form remains accepted.
- Duplicate-gene metadata: resolved. Both paths report `length(unique(genes))`; raw payload genes and `nrow(clusters)` remain unchanged.

Findings:

- HIGH — [job-functional-submission-service.R:269](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:269), [job-functional-submission-service.R:323](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-d-574/api/services/job-functional-submission-service.R:323): explicit/no-arg durable payloads now include `provenance`. Since `async_job_service_submit()` hashes the full serialized payload, their persisted `request_hash` is not byte-identical to pre-#574 despite the stated locked contract. An active pre-deploy explicit job and an identical post-deploy submission have different hashes, so the DB active-job uniqueness guard can admit duplicate clustering work. Fix: separate the durable handler payload from a stable dedup/hash payload (`genes`, `algorithm`, and normalized `category_filter` only when category-selected), and use that identity consistently for preflight and persisted request hashes.

Other locked contracts hold in the reviewed code: entity-level dbplyr resolution; default behavior; empty/<2/category validation errors; allowed-set error message; namespacing; provenance/effective fingerprint on both paths; fail-closed source version; and no `public_ready` path.

`git diff --check` passed. Targeted R tests and `make code-quality-audit` could not run because the read-only sandbox prevents temporary-file creation.

**VERDICT: NO-SHIP — 1 HIGH**
