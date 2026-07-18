Reading additional input from stdin...
OpenAI Codex v0.144.5
--------
workdir: /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
model: gpt-5.6-terra
provider: openai
approval: never
sandbox: read-only
reasoning effort: high
reasoning summaries: none
session id: 019f76fe-8e27-7492-ad2f-8ee422f9ffe8
--------
user
# Codex final re-review (round 4) — #573 Slice A, confirm SHIP

Prior rounds resolved: BLOCKER (layers policy/traversal), HIGH (public leak, reproducibility-hash, idempotency race, member-set coherence attestation, CI file-size ratchet), MEDIUM (db_release conflict, STRING->hgnc one-to-many, partial-attestation), LOW (pagination clamp+echo, trailing whitespace). Latest fix commits: `8765302c` (extract prune -> analysis-snapshot-prune-helpers.R, repository.R now 550), `bb757756` (one-to-many STRING->hgnc dict + partial-attestation rejected as incoherent), `0a416a96` (strip trailing whitespace).

Re-review `git diff 67cf6003..HEAD` and CONFIRM the round-3 findings are resolved:
1. `analysis-snapshot-repository.R` <= 600 lines; the extracted `analysis-snapshot-prune-helpers.R` is registered in load_modules.R and the prune release-guard still works.
2. STRING_id -> hgnc dict now preserves ALL mappings (one-to-many) so a coherent functional snapshot with a one-to-many gene is NOT false-rejected; reference sets expand to the union.
3. A present-but-PARTIAL/malformed attestation is now treated as INCOHERENT (key set must equal the served/validated cluster set), while a fully-ABSENT attestation still degrades gracefully.
4. `git diff --check 67cf6003..HEAD` is clean.
Adversarially check the extraction + the new mapping/attestation logic for any regression or new correctness/security issue. If all resolved and NO BLOCKER/HIGH remains, end with SHIP. Read-only.
codex
I’ll perform a read-only adversarial review of the requested commit range, using the snapshot, code-quality, and security review guides because this touches release integrity and public-facing analysis behavior.
exec
/bin/bash -lc "sed -n '1,240p' /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-analysis-snapshots/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-code-quality/SKILL.md && sed -n '1,300p' .agents/skills/sysndd-security-bug-scan/SKILL.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
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

exec
/bin/bash -lc 'git status --short && git diff --check 67cf6003..HEAD && git diff --stat 67cf6003..HEAD && git diff --name-status 67cf6003..HEAD && git log --oneline --decorate 67cf6003..HEAD' in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-prompt.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-reconciliation.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-rereview-prompt.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-rereview.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-rereview3-prompt.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-rereview3.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-rereview4-prompt.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-rereview4.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-review.md
 .gitignore                                         |   3 +
 ...-analysis-snapshot-releases-573-codex-prompt.md |  33 ++
 ...s-snapshot-releases-573-codex-reconciliation.md |  19 +
 ...-analysis-snapshot-releases-573-codex-review.md |  33 ++
 ...tegory-clustering-universes-574-codex-prompt.md |  33 ++
 ...lustering-universes-574-codex-reconciliation.md |  15 +
 ...tegory-clustering-universes-574-codex-review.md |  23 +
 ...26-07-18-analysis-snapshot-releases-573-plan.md | 415 +++++++++++++
 ...07-18-category-clustering-universes-574-plan.md | 277 +++++++++
 ...-07-18-analysis-snapshot-releases-573-design.md | 352 +++++++++++
 ...-18-category-clustering-universes-574-design.md | 151 +++++
 AGENTS.md                                          |  13 +
 CHANGELOG.md                                       |  61 ++
 README.md                                          |   1 +
 api/bootstrap/load_modules.R                       |  17 +
 api/bootstrap/setup_workers.R                      |   1 +
 api/endpoints/admin_analysis_snapshot_endpoints.R  | 232 ++++++++
 api/endpoints/analysis_endpoints.R                 | 161 +++++
 api/functions/analysis-reproducibility.R           |  25 +
 api/functions/analysis-snapshot-builder.R          |   8 +-
 api/functions/analysis-snapshot-coherence.R        |  98 ++++
 api/functions/analysis-snapshot-prune-helpers.R    |  81 +++
 api/functions/analysis-snapshot-release-manifest.R | 279 +++++++++
 .../analysis-snapshot-release-materialize.R        | 420 ++++++++++++++
 .../analysis-snapshot-release-repository.R         | 484 ++++++++++++++++
 api/functions/analysis-snapshot-release.R          | 540 +++++++++++++++++
 api/functions/analysis-snapshot-repository.R       |  50 +-
 api/functions/migration-manifest.R                 |   4 +-
 api/services/analysis-snapshot-release-service.R   | 288 +++++++++
 api/tests/testthat/helper-db.R                     | 105 ++++
 ...-integration-analysis-release-admin-endpoints.R | 488 ++++++++++++++++
 .../test-integration-analysis-release-endpoints.R  | 369 ++++++++++++
 ...t-integration-analysis-snapshot-release-build.R | 645 +++++++++++++++++++++
 ...egration-analysis-snapshot-release-repository.R | 313 ++++++++++
 .../test-mcp-select-principal-projections.R        |   6 +-
 .../test-unit-admin-snapshot-endpoint-guard.R      |  21 +-
 .../testthat/test-unit-analysis-reproducibility.R  |  80 +++
 .../test-unit-analysis-snapshot-coherence.R        |  54 ++
 .../test-unit-analysis-snapshot-migration.R        |   4 +-
 ...st-unit-analysis-snapshot-prune-release-guard.R | 226 ++++++++
 .../test-unit-analysis-snapshot-release-manifest.R | 180 ++++++
 ...test-unit-analysis-snapshot-release-migration.R | 110 ++++
 .../test-unit-analysis-snapshot-release-service.R  | 534 +++++++++++++++++
 .../test-unit-analysis-snapshot-repository.R       |  20 +-
 .../testthat/test-unit-cheap-route-isolation.R     |  74 +++
 api/tests/testthat/test-unit-core-views-manifest.R |   8 +-
 api/version_spec.json                              |   2 +-
 app/package-lock.json                              |   4 +-
 app/package.json                                   |   2 +-
 .../045_add_analysis_snapshot_release.sql          |  69 +++
 db/migrations/README.md                            |   7 +-
 documentation/08-development.qmd                   |  46 ++
 documentation/09-deployment.qmd                    |  69 +++
 53 files changed, 7483 insertions(+), 70 deletions(-)
M	.gitignore
A	.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-prompt.md
A	.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-reconciliation.md
A	.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md
A	.planning/reviews/2026-07-18-category-clustering-universes-574-codex-prompt.md
A	.planning/reviews/2026-07-18-category-clustering-universes-574-codex-reconciliation.md
A	.planning/reviews/2026-07-18-category-clustering-universes-574-codex-review.md
A	.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md
A	.planning/superpowers/plans/2026-07-18-category-clustering-universes-574-plan.md
A	.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md
A	.planning/superpowers/specs/2026-07-18-category-clustering-universes-574-design.md
M	AGENTS.md
M	CHANGELOG.md
M	README.md
M	api/bootstrap/load_modules.R
M	api/bootstrap/setup_workers.R
M	api/endpoints/admin_analysis_snapshot_endpoints.R
M	api/endpoints/analysis_endpoints.R
M	api/functions/analysis-reproducibility.R
M	api/functions/analysis-snapshot-builder.R
M	api/functions/analysis-snapshot-coherence.R
A	api/functions/analysis-snapshot-prune-helpers.R
A	api/functions/analysis-snapshot-release-manifest.R
A	api/functions/analysis-snapshot-release-materialize.R
A	api/functions/analysis-snapshot-release-repository.R
A	api/functions/analysis-snapshot-release.R
M	api/functions/analysis-snapshot-repository.R
M	api/functions/migration-manifest.R
A	api/services/analysis-snapshot-release-service.R
M	api/tests/testthat/helper-db.R
A	api/tests/testthat/test-integration-analysis-release-admin-endpoints.R
A	api/tests/testthat/test-integration-analysis-release-endpoints.R
A	api/tests/testthat/test-integration-analysis-snapshot-release-build.R
A	api/tests/testthat/test-integration-analysis-snapshot-release-repository.R
M	api/tests/testthat/test-mcp-select-principal-projections.R
M	api/tests/testthat/test-unit-admin-snapshot-endpoint-guard.R
M	api/tests/testthat/test-unit-analysis-reproducibility.R
M	api/tests/testthat/test-unit-analysis-snapshot-coherence.R
M	api/tests/testthat/test-unit-analysis-snapshot-migration.R
A	api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R
A	api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R
A	api/tests/testthat/test-unit-analysis-snapshot-release-migration.R
A	api/tests/testthat/test-unit-analysis-snapshot-release-service.R
M	api/tests/testthat/test-unit-analysis-snapshot-repository.R
M	api/tests/testthat/test-unit-cheap-route-isolation.R
M	api/tests/testthat/test-unit-core-views-manifest.R
M	api/version_spec.json
M	app/package-lock.json
M	app/package.json
A	db/migrations/045_add_analysis_snapshot_release.sql
M	db/migrations/README.md
M	documentation/08-development.qmd
M	documentation/09-deployment.qmd
0a416a96 (HEAD -> worktree-analysis-snapshot-releases-573-slice-a) chore(planning): strip trailing whitespace from codex review MD (#573)
bb757756 fix(api): one-to-many STRING->hgnc mapping + reject partial coherence attestation (#573)
8765302c refactor(api): extract analysis_snapshot_prune to keep repository under 600 lines (#573)
75c62c46 fix(api): public release list echoes clamped pagination (#573)
338aa92c fix(api): release member-set coherence attestation + db_release conflict gate (#573)
f5224285 fix(api): release public-surface hardening — head projection, 503 lock path, pagination clamp, prune guard (#573)
44455711 fix(api): release build hardening — layer selection, path containment, repro-hash verify, TOCTOU idempotency, DB provenance (#573)
49eb025b fix(api): avoid duplicate Content-Type header on release byte routes (#573)
51c0e0b8 docs(api): drop manuscript wording from release layer comment/tests (#573)
68092abc docs: reword #572 runbook to drop manuscript reference (#573)
b875f07b docs: analysis-snapshot releases + #572 runbook + v0.30.0 (#573)
6c2c252e refactor(api): prune guard reuses referenced-snapshot-ids helper (#573)
325a6d66 feat(api): register release modules + prune guard + route isolation (#573)
1230dcc7 feat(api): admin analysis-release endpoints (#573)
cf6ac3f0 test(api): draft-404 coverage for release manifest/file routes (#573)
d3f1c023 feat(api): public analysis-release read routes (#573)
79dbd8cb feat(api): analysis-release service (#573)
29f46d39 fix(api): strengthen release coherence channel-check + real TOCTOU re-read (#573)
51b90b85 feat(api): analysis-snapshot release build orchestrator (#573)
0848488d feat(api): raw reproducibility decode helper (#573)
44fff3bd feat(api): analysis-release repository (#573)
a03fb2de feat(api): release manifest + deterministic archive helpers (#573)
1fa6cc72 feat(db): analysis-snapshot release tables (#573)
fea196a9 chore: gitignore .superpowers SDD scratch dir
87b41f5f (plan/analysis-snapshot-releases-573) docs(review): Codex (gpt-5.6-terra) adversarial review + reconciled #574 design/plan
5558850e docs(spec+plan): dedicated rigorous #574 design + TDD plan (category-selected clustering)
e925c54e docs(review): Codex (gpt-5.6-terra) adversarial review + reconciled spec/plan (#573)
ec20f31d docs(plan): implementation plan for analysis-snapshot releases (#573/#574/#572)
758da251 docs(spec): immutable public analysis-snapshot releases (#573) + companions (#574/#572)

codex
The requested whitespace check is clean. I’ve also confirmed the working tree has only untracked review artifacts, which I’ll leave untouched; next I’m tracing the extracted prune path and the new coherence attestation end-to-end.
exec
/bin/bash -lc 'wc -l api/functions/analysis-snapshot-repository.R api/functions/analysis-snapshot-prune-helpers.R api/bootstrap/load_modules.R && git diff --unified=80 67cf6003..HEAD -- api/functions/analysis-snapshot-repository.R api/functions/analysis-snapshot-prune-helpers.R api/bootstrap/load_modules.R api/functions/analysis-snapshot-coherence.R api/functions/analysis-snapshot-release.R api/functions/analysis-snapshot-release-manifest.R api/functions/analysis-snapshot-release-materialize.R api/functions/analysis-snapshot-release-repository.R api/services/analysis-snapshot-release-service.R api/endpoints/analysis_endpoints.R api/endpoints/admin_analysis_snapshot_endpoints.R db/migrations/045_add_analysis_snapshot_release.sql' in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
  550 api/functions/analysis-snapshot-repository.R
   81 api/functions/analysis-snapshot-prune-helpers.R
  282 api/bootstrap/load_modules.R
  913 total
diff --git a/api/bootstrap/load_modules.R b/api/bootstrap/load_modules.R
index 2979b913..512a3065 100644
--- a/api/bootstrap/load_modules.R
+++ b/api/bootstrap/load_modules.R
@@ -1,265 +1,282 @@
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
+    "functions/analysis-snapshot-prune-helpers.R",
     "functions/analysis-snapshot-coherence.R",
     "functions/analysis-snapshot-dependencies.R",
     "functions/analysis-snapshot-builder.R",
     "functions/analysis-reproducibility.R",
+    # Immutable, content-addressed public analysis-snapshot releases (#573
+    # Slice A). Synchronous admin/API-only build path (svc_release_build(),
+    # called directly from the admin endpoint) -- NOT a durable async-job
+    # handler and NOT a mirai daemon job, so (unlike the sibling
+    # analysis-snapshot-*.R files above) these are intentionally absent from
+    # bootstrap/setup_workers.R's mirai everywhere() block. Registered here
+    # only, which still covers the durable worker (start_async_worker.R) and
+    # the MCP sidecar (start_sysndd_mcp.R) via this shared loader. Order:
+    # manifest (content digest / canonical JSON / tar.gz) -> repository (DB
+    # CRUD) -> materialize (coherence assertions + file/README building) ->
+    # release (orchestrator, depends on all three).
+    "functions/analysis-snapshot-release-manifest.R",
+    "functions/analysis-snapshot-release-repository.R",
+    "functions/analysis-snapshot-release-materialize.R",
+    "functions/analysis-snapshot-release.R",
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
+    "services/analysis-snapshot-release-service.R",
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
diff --git a/api/endpoints/admin_analysis_snapshot_endpoints.R b/api/endpoints/admin_analysis_snapshot_endpoints.R
index a877add6..78ceb261 100644
--- a/api/endpoints/admin_analysis_snapshot_endpoints.R
+++ b/api/endpoints/admin_analysis_snapshot_endpoints.R
@@ -1,61 +1,293 @@
 ## -------------------------------------------------------------------##
 # api/endpoints/admin_analysis_snapshot_endpoints.R
 #
 # Administrator-only HTTP triggers for the durable public analysis snapshots that
 # the /api/analysis/* read endpoints serve. Mounted at /api/admin/analysis, so:
 #   POST /api/admin/analysis/snapshots/refresh  (submit refresh jobs)
 #   GET  /api/admin/analysis/snapshots/status   (per-preset manifest state)
 #
 # All three snapshot submit paths (startup hook, this endpoint, and the operator
 # script scripts/refresh-analysis-snapshots.R) share one function,
 # service_analysis_snapshot_submit_refresh(), so submission logic is not
 # duplicated. Spec: .planning/superpowers/specs/2026-06-14-analysis-snapshot-bootstrap-design.md
+#
+# #573 Slice A / Task A7 appends 6 Administrator-only routes for immutable,
+# content-addressed public analysis-snapshot RELEASES: build/list/detail/
+# publish/record-DOI/delete-draft. The mutating routes (build, publish, set
+# DOI, delete draft) thinly delegate to the A5 service layer
+# (services/analysis-snapshot-release-service.R, `svc_release_*`); the two
+# admin READS that must see DRAFT rows call the A3 repository
+# (functions/analysis-snapshot-release-repository.R) directly with
+# `include_draft = TRUE` / `status = NULL` -- the sibling
+# svc_release_list()/svc_release_get() in the service layer are
+# PUBLISHED-ONLY by design (the public routes in analysis_endpoints.R use
+# those), so this file bypasses them for the two admin listings. The service
+# file and the four release function files are wired into
+# bootstrap/load_modules.R by Task A8, so these routes are live.
 ## -------------------------------------------------------------------##
 
+if (!exists("%||%", mode = "function")) {
+  `%||%` <- function(x, y) if (is.null(x)) y else x
+}
+
 #* Submit analysis snapshot refresh jobs (Administrator only)
 #*
 #* Idempotently submits `analysis_snapshot_refresh` jobs so the worker rebuilds +
 #* activates the durable public-ready snapshots. By default only presets without a
 #* current public-ready snapshot are submitted; pass `force=true` to rebuild all.
 #* Re-submitting a queued/running refresh returns the existing job (dedup).
 #*
 #* @tag admin
 #* @serializer unboxedJSON
 #*
 #* @param analysis_type:str Optional single preset (e.g. "gene_network_edges"). Omit for all supported presets.
 #* @param force:bool Optional; rebuild even when a current snapshot exists. Default false.
 #*
 #* @post /snapshots/refresh
 function(req, res, analysis_type = NULL, force = FALSE) {
   require_role(req, res, "Administrator")
 
   at <- if (is.null(analysis_type) || !nzchar(as.character(analysis_type[[1]]))) {
     NULL
   } else {
     as.character(analysis_type[[1]])
   }
   force_flag <- isTRUE(force) ||
     identical(tolower(as.character(force)[[1]]), "true") ||
     identical(as.character(force)[[1]], "1")
 
   summary <- service_analysis_snapshot_submit_refresh(analysis_type = at, force = force_flag)
 
   res$status <- 202L
   summary
 }
 
 #* Per-preset analysis snapshot status (Administrator only)
 #*
 #* Returns the manifest state (missing / available / stale /
 #* source_version_mismatch) for each supported analysis preset, with timestamps
 #* and stored row counts, so an operator can watch a rebuild progress without DB
 #* access.
 #*
 #* @tag admin
 #* @serializer unboxedJSON
 #*
 #* @get /snapshots/status
 function(req, res) {
   require_role(req, res, "Administrator")
   service_analysis_snapshot_status()
 }
+
+## -------------------------------------------------------------------##
+## Analysis-snapshot RELEASES: admin routes (#573 Slice A / Task A7)
+## -------------------------------------------------------------------##
+
+#' Parse a POST/PATCH JSON request body with `jsonlite::fromJSON(simplifyVector
+#' = FALSE)`, NOT Plumber's default `req$argsBody` (`plumber:::safeFromJSON`,
+#' which parses with `simplifyVector = TRUE`).
+#'
+#' This matters specifically for `POST /releases`'s optional `layers` array
+#' override. Verified live: `simplifyVector = TRUE` collapses a JSON array of
+#' layer-override objects into a *data.frame* -- and a nested object field
+#' (e.g. `params`) collapses into its OWN nested data.frame column when every
+#' layer shares the same param keys. `analysis_snapshot_release_build()`
+#' iterates its `layers` argument with `lapply(layers, function(layer)
+#' layer$analysis_type[[1]])`; iterating a data.frame with `lapply()` walks
+#' the data.frame's COLUMNS (atomic vectors), the same "$ operator is invalid
+#' for atomic vectors" trap AGENTS.md documents for the force-apply payload
+#' helpers (`functions/async-job-force-apply-payload.R`). Re-parsing the raw
+#' body text with `simplifyVector = FALSE` instead -- the same call
+#' `core/logging_sanitizer.R`'s `sanitize_post_body_for_log()` already makes
+#' on `req$postBody` -- yields the EXACT list-of-named-lists shape
+#' `analysis_snapshot_release_layers()` itself returns (each layer's `params`
+#' comes back as a genuine named list too), so a caller-supplied `layers`
+#' override needs no further normalization before being forwarded to
+#' `svc_release_build()`. `req$postBody` is populated by Plumber's default
+#' `bodyFilter` for every request with a body, independent of any `@parser`
+#' annotation on this route.
+#'
+#' @noRd
+.admin_release_parse_json_body <- function(req) {
+  raw <- tryCatch(req$postBody, error = function(e) NULL)
+  if (is.null(raw) || !nzchar(raw)) {
+    return(list())
+  }
+  tryCatch(
+    jsonlite::fromJSON(raw, simplifyVector = FALSE),
+    error = function(e) stop_for_bad_request("Malformed JSON request body")
+  )
+}
+
+#' Defensively parse a query-string integer with a default.
+#'
+#' A file-local duplicate of the identically-named helper in
+#' `endpoints/analysis_endpoints.R`: each endpoints file is mounted as its
+#' OWN Plumber sub-router / environment (`plumber::pr(file)`), so a top-level
+#' helper defined in a sibling endpoints file is not visible here.
+#'
+#' @noRd
+.admin_release_query_int <- function(value, default) {
+  scalar <- if (is.null(value)) default else value[[1]]
+  parsed <- suppressWarnings(as.integer(scalar))
+  if (is.na(parsed)) default else parsed
+}
+
+#* Build (and, by default, publish) a new analysis-snapshot release (Administrator only)
+#*
+#* Loads the currently active public-ready snapshots for the fixed layer
+#* registry (or a caller-supplied `layers` override -- see the JSON body
+#* shape below), gates them (available + hard coherence + reproducibility
+#* presence + shared source-data version + dependency lineage), materializes
+#* the release files, and persists an immutable, content-addressed release.
+#* A rebuild whose content is IDENTICAL to an existing release is idempotent
+#* (200, same release_id, no duplicate row); a genuinely new content set is
+#* 201. A gate failure (a layer not available / incoherent / missing its
+#* reproducibility bundle / mismatched source version or dependency lineage)
+#* is 400, naming the failing layer.
+#*
+#* JSON body (all fields optional): `{ layers?: [...], title?,
+#* scope_statement?, license?, publish? }`. `publish` defaults to `true`;
+#* `false` stages a draft for review before a Zenodo run. `license` defaults
+#* to `"CC-BY-4.0"`. Omitting `layers` uses the fixed default registry
+#* (`analysis_snapshot_release_layers()`).
+#*
+#* @tag admin
+#* @serializer unboxedJSON
+#*
+#* @post /releases
+function(req, res) {
+  require_role(req, res, "Administrator")
+
+  body <- .admin_release_parse_json_body(req)
+  publish_flag <- if (is.null(body$publish)) TRUE else isTRUE(body$publish)
+
+  # analysis_snapshot_release_build() ultimately calls
+  # analysis_release_insert(), which wraps its writes in ONE
+  # DBI::dbWithTransaction() and binds blob params via list(<raw>) -- both
+  # need a real DBIConnection, never the global `pool` Pool object directly
+  # (see functions/analysis-snapshot-release-repository.R's file header).
+  # The other 5 admin routes below issue single non-transactional
+  # dbExecute()/dbGetQuery() calls, which pool::Pool supports directly.
+  conn <- pool::poolCheckout(pool)
+  on.exit(pool::poolReturn(conn), add = TRUE)
+
+  svc_release_build(
+    res,
+    layers = body$layers,
+    title = body$title,
+    scope_statement = body$scope_statement,
+    license = body$license %||% "CC-BY-4.0",
+    publish = publish_flag,
+    created_by = req$user_id,
+    conn = conn
+  )
+}
+
+#* List ALL analysis-snapshot releases, including drafts (Administrator only)
+#*
+#* Unlike the public `GET /api/analysis/releases` (published-only, see
+#* `svc_release_list()`), this admin listing includes draft rows so an
+#* operator can see an in-progress/failed build before it is published or
+#* deleted.
+#*
+#* @tag admin
+#* @serializer unboxedJSON
+#*
+#* @param limit:int Optional page size. Default 50.
+#* @param offset:int Optional page offset. Default 0.
+#*
+#* @get /releases
+function(req, res, limit = NULL, offset = NULL) {
+  require_role(req, res, "Administrator")
+
+  limit_int <- .admin_release_query_int(limit, 50L)
+  offset_int <- .admin_release_query_int(offset, 0L)
+  releases <- analysis_release_list(status = NULL, limit = limit_int, offset = offset_int, conn = pool)
+
+  list(
+    releases = releases,
+    pagination = list(limit = limit_int, offset = offset_int, count = length(releases))
+  )
+}
+
+#* Fetch one analysis-snapshot release, including a draft (Administrator only)
+#*
+#* Unlike the public `GET /api/analysis/releases/<id>` (published-only, see
+#* `svc_release_get()`), this admin detail resolves a draft release too.
+#*
+#* @tag admin
+#* @serializer unboxedJSON
+#*
+#* @get /releases/<release_id>
+function(req, res, release_id) {
+  require_role(req, res, "Administrator")
+
+  head <- analysis_release_get(release_id, include_draft = TRUE, conn = pool)
+  if (is.null(head)) {
+    stop_for_not_found("Release not found")
+  }
+  head
+}
+
+#* Publish a draft analysis-snapshot release (Administrator only)
+#*
+#* Unknown release id -> 404. Publishing an already-published release is an
+#* idempotent no-op. Returns the (published) release head.
+#*
+#* @tag admin
+#* @serializer unboxedJSON
+#*
+#* @post /releases/<release_id>/publish
+function(req, res, release_id) {
+  require_role(req, res, "Administrator")
+  svc_release_publish(release_id, conn = pool)
+}
+
+#* Record external Zenodo/DOI provenance on a release (Administrator only)
+#*
+#* Additive metadata only; NEVER touches the release's `content_digest` /
+#* `manifest_sha256` (release scientific identity is immutable once minted).
+#* Any subset of the four fields may be supplied -- an omitted field is left
+#* unchanged, it is never cleared/nulled out.
+#*
+#* @tag admin
+#* @serializer unboxedJSON
+#*
+#* @param zenodo_record_id:str Optional.
+#* @param zenodo_record_url:str Optional.
+#* @param version_doi:str Optional.
+#* @param concept_doi:str Optional.
+#*
+#* @patch /releases/<release_id>/doi
+function(req, res, release_id, zenodo_record_id = NULL, zenodo_record_url = NULL,
+         version_doi = NULL, concept_doi = NULL) {
+  require_role(req, res, "Administrator")
+
+  doi_fields <- list(
+    zenodo_record_id = zenodo_record_id,
+    zenodo_record_url = zenodo_record_url,
+    version_doi = version_doi,
+    concept_doi = concept_doi
+  )
+  # Only forward fields the caller actually supplied -- list(a = NULL) still
+  # keeps the name "a", so an unfiltered pass-through would overwrite every
+  # omitted field to NULL instead of leaving it unchanged.
+  doi_fields <- doi_fields[!vapply(doi_fields, is.null, logical(1))]
+
+  svc_release_set_doi(release_id, doi_fields = doi_fields, conn = pool)
+}
+
+#* Delete a draft analysis-snapshot release (Administrator only)
+#*
+#* Unknown release id -> 404. Refuses (400) once the release is published --
+#* releases are retained indefinitely once published; only a draft (e.g. a
+#* failed/aborted build) can be discarded.
+#*
+#* @tag admin
+#* @serializer unboxedJSON
+#*
+#* @delete /releases/<release_id>
+function(req, res, release_id) {
+  require_role(req, res, "Administrator")
+  svc_release_delete_draft(release_id, conn = pool)
+}
diff --git a/api/endpoints/analysis_endpoints.R b/api/endpoints/analysis_endpoints.R
index 0cfa80dc..0777af64 100644
--- a/api/endpoints/analysis_endpoints.R
+++ b/api/endpoints/analysis_endpoints.R
@@ -295,82 +295,243 @@ function(cluster_hash = NULL, cluster_number = NULL, req, res) {
 #* # `Details`
 #* - Looks up cached summary by cluster_hash (SHA256 hash of cluster composition)
 #* - If not cached, generates new summary via Gemini API
 #* - Excludes rejected summaries (validation_status = 'rejected')
 #* - Returns summary_json with structured content (summary, key_themes, pathways, etc.)
 #*
 #* @tag analysis
 #* @serializer json list(na="string")
 #* @param cluster_hash:str SHA256 hash of cluster composition (or equals(hash,...) format)
 #* @param cluster_number:str Cluster number (integer as string)
 #*
 #* @response 200 OK. Returns summary with metadata
 #* @response 400 Bad Request. Missing required parameters
 #* @response 404 Not Found. Cluster not found, summary rejected, or not cached (generation needs Curator+)
 #* @response 500 Internal Server Error. Generation failed
 #* @response 503 Service Unavailable. LLM not configured
 #*
 #* @get phenotype_cluster_summary
 function(cluster_hash = NULL, cluster_number = NULL, req, res) {
   source("functions/llm-endpoint-helpers.R", local = TRUE)
   allow_gen <- !is.null(req$user_role) && req$user_role %in% c("Curator", "Administrator")
   get_cluster_summary(cluster_hash, cluster_number, "phenotype", res, allow_generation = allow_gen)
 }
 
 
 #* Functional Clustering Reproducibility Bundle
 #*
 #* Read-only sibling of `/functional_clustering` (#512). Returns the inputs
 #* needed to INDEPENDENTLY recompute the served functional modularity: the
 #* largest-connected-component STRING edge list, the complete Leiden membership,
 #* the served modularity, params, and a SHA-256 reproducibility hash.
 #*
 #* # `Details`
 #* - DB-only read from the current public snapshot's reproducibility row.
 #* - Approved-public data only (the snapshot is built from approved public data).
 #* - The `bundle` is the decompressed, parsed JSON of the stored gzip blob.
 #*
 #* NOTE: These reproducibility routes live in this file (not a separate mounted
 #* sub-router) on purpose. Plumber cannot mount a second router at `/api/analysis`
 #* (a duplicate mount replaces the first) and a sub-router 404 does not fall
 #* through to other mounts, so the only way to serve the documented sibling path
 #* `/api/analysis/functional_clustering/reproducibility` is as a route inside the
 #* same analysis sub-router. The endpoint logic is kept thin (delegated to
 #* `analysis_reproducibility_endpoint()` in functions/analysis-reproducibility.R).
 #*
 #* @tag analysis
 #* @serializer json list(na="string", auto_unbox=TRUE)
 #*
 #* @response 200 OK. Returns { reproducibility_hash, kind, byte_size, snapshot_id, bundle }.
 #* @response 404 Not Found. No public snapshot or no reproducibility bundle yet.
 #*
 #* @get functional_clustering/reproducibility
 function(res) {
   analysis_reproducibility_endpoint("functional_clusters", res)
 }
 
 
 #* Phenotype Clustering Reproducibility Bundle
 #*
 #* Read-only sibling of `/phenotype_clustering` (#512). Returns the inputs needed
 #* to INDEPENDENTLY recompute the served phenotype silhouette: the MCA coordinate
 #* matrix, the cluster membership, the served silhouette, params, and a SHA-256
 #* reproducibility hash.
 #*
 #* # `Details`
 #* - DB-only read from the current public snapshot's reproducibility row.
 #* - Approved-public data only.
 #* - See the functional sibling above for why these routes live in this file.
 #*
 #* @tag analysis
 #* @serializer json list(na="string", auto_unbox=TRUE)
 #*
 #* @response 200 OK. Returns { reproducibility_hash, kind, byte_size, snapshot_id, bundle }.
 #* @response 404 Not Found. No public snapshot or no reproducibility bundle yet.
 #*
 #* @get phenotype_clustering/reproducibility
 function(res) {
   analysis_reproducibility_endpoint("phenotype_clusters", res)
 }
 
+
+## -------------------------------------------------------------------##
+## Analysis-snapshot RELEASES: public read routes (#573 Slice A / Task A6)
+## -------------------------------------------------------------------##
+#
+# Immutable, content-addressed public releases of the analysis snapshots
+# above (see services/analysis-snapshot-release-service.R for the full
+# contract). DB-only, published-only: every svc_release_* read is pinned to
+# status = "published", so an unknown release id and a draft release id are
+# indistinguishable to the caller -- both resolve to a plain 404. `conn =
+# pool` mirrors the established global-pool endpoint pattern (see
+# endpoints/seo_endpoints.R) -- the A3 release repository requires an
+# explicit connection on every call (no NULL/global-pool fallback), unlike
+# the sibling analysis-snapshot-repository.R.
+#
+# DECLARATION ORDER IS LOAD-BEARING: `releases/latest` MUST stay declared
+# before `releases/<release_id>` below -- Plumber matches routes in
+# declaration order, so the dynamic `<release_id>` segment would otherwise
+# shadow the literal "latest" segment (the same class of bug documented in
+# AGENTS.md's `/status/_list` vs `/status/<status_id_requested>` lesson). A
+# static test (test-integration-analysis-release-endpoints.R) guards this
+# ordering directly against this source file.
+
+analysis_release_query_int <- function(value, default) {
+  parsed <- suppressWarnings(as.integer(analysis_endpoint_scalar(value, default)))
+  if (is.na(parsed)) default else parsed
+}
+
+#* List published analysis-snapshot releases
+#*
+#* Immutable, content-addressed public releases (newest first). Draft
+#* releases are never returned.
+#*
+#* @tag analysis
+#* @serializer json list(na="string", auto_unbox=TRUE)
+#* @param limit:str Max releases to return (default "50")
+#* @param offset:str Offset into the published list (default "0")
+#*
+#* @response 200 OK. Returns { releases, pagination }.
+#*
+#* @get releases
+function(limit = "50", offset = "0", res) {
+  limit_int <- analysis_release_query_int(limit, 50L)
+  offset_int <- analysis_release_query_int(offset, 0L)
+  releases <- svc_release_list(limit = limit_int, offset = offset_int, conn = pool)
+  # L2: echo the EFFECTIVE (clamped) pagination the service actually queried,
+  # not the caller's raw values (svc_release_clamp_* is the single clamp source).
+  list(
+    releases = releases,
+    pagination = list(
+      limit = svc_release_clamp_limit(limit_int),
+      offset = svc_release_clamp_offset(offset_int),
+      count = length(releases)
+    )
+  )
+}
+
+
+#* Get the newest published analysis-snapshot release
+#*
+#* MUST stay declared before `releases/<release_id>` (see the ordering note
+#* above this section).
+#*
+#* @tag analysis
+#* @serializer json list(na="string", auto_unbox=TRUE)
+#*
+#* @response 200 OK. Returns the release head + `manifest` (same shape as the detail route).
+#* @response 404 Not Found. No published release exists yet.
+#*
+#* @get releases/latest
+function(res) {
+  newest <- svc_release_list(limit = 1, offset = 0, conn = pool)
+  if (length(newest) == 0L) {
+    stop_for_not_found("No published analysis-snapshot release exists yet")
+  }
+  svc_release_get(as.character(newest[[1]]$release_id), conn = pool)
+}
+
+
+#* Get one published analysis-snapshot release
+#*
+#* @tag analysis
+#* @serializer json list(na="string", auto_unbox=TRUE)
+#* @param release_id Release id (`asr_<16 hex>`).
+#*
+#* @response 200 OK. Returns the release head + `manifest`.
+#* @response 404 Not Found. Unknown release id, or the release is still a draft.
+#*
+#* @get releases/<release_id>
+function(release_id, res) {
+  svc_release_get(release_id, conn = pool)
+}
+
+
+#* Get a published release's stored `manifest.json` bytes verbatim
+#*
+#* Serves the EXACT stored bytes (never re-serialized), so
+#* `sha256(bytes) == manifest_sha256` on the release head.
+#*
+#* @tag analysis
+#* @serializer octet list(type = "application/json")
+#* @param release_id Release id.
+#*
+#* @response 200 OK. Raw manifest.json bytes, Content-Type application/json.
+#* @response 404 Not Found. Unknown release id, or the release is still a draft.
+#*
+#* @get releases/<release_id>/manifest.json
+function(release_id, res) {
+  content <- svc_release_manifest(release_id, conn = pool)
+  # Content-Type is set by the octet serializer (application/json) -- do NOT also
+  # res$setHeader() it, which would emit a duplicate Content-Type header.
+  content$bytes
+}
+
+
+#* Get one content file from a published release by its exact archive path
+#*
+#* `path` is a QUERY parameter, not a path segment -- Plumber 1.3.2 has no
+#* `<path:.*>` multi-segment param type, so a nested path segment would 404.
+#* Resolved by an exact `(release_id, file_path)` primary-key lookup, so
+#* there is no path-traversal surface.
+#*
+#* @tag analysis
+#* @serializer octet
+#* @param release_id Release id.
+#* @param path:str Exact archive-relative file path, e.g. "functional_clusters/payload.json".
+#*
+#* @response 200 OK. Raw file bytes, Content-Type from the stored file's media type.
+#* @response 404 Not Found. Unknown release id, draft release, or unknown file path.
+#*
+#* @get releases/<release_id>/file
+function(release_id, path = "", res) {
+  file_path <- analysis_endpoint_scalar(path, "")
+  content <- svc_release_file(release_id, file_path, conn = pool)
+  # The stored media type is per-file (usually application/json), so set the
+  # serializer's type dynamically rather than res$setHeader()-ing a second
+  # Content-Type alongside the octet serializer's default.
+  res$serializer <- plumber::serializer_octet(type = content$media_type)
+  content$bytes
+}
+
+
+#* Download a published release's whole archive (`bundle.tar.gz`) verbatim
+#*
+#* @tag analysis
+#* @serializer octet list(type = "application/gzip")
+#* @param release_id Release id.
+#*
+#* @response 200 OK. Raw gzip tar bytes, served as an attachment download.
+#* @response 404 Not Found. Unknown release id, or the release is still a draft.
+#*
+#* @get releases/<release_id>/bundle
+function(release_id, res) {
+  bundle <- svc_release_bundle(release_id, conn = pool)
+  # Content-Type (application/gzip) is set by the octet serializer -- do NOT also
+  # res$setHeader() it (duplicate header). Content-Disposition/Length are distinct.
+  res$setHeader("Content-Disposition", sprintf('attachment; filename="%s"', bundle$filename))
+  res$setHeader("Content-Length", as.character(length(bundle$bytes)))
+  bundle$bytes
+}
+
 ## Analyses endpoints
 ## -------------------------------------------------------------------##
diff --git a/api/functions/analysis-snapshot-coherence.R b/api/functions/analysis-snapshot-coherence.R
index 04be5f23..c977618f 100644
--- a/api/functions/analysis-snapshot-coherence.R
+++ b/api/functions/analysis-snapshot-coherence.R
@@ -59,132 +59,230 @@ analysis_snapshot_assert_partition_coherent <- function(membership, per_cluster,
   membership_ids <- if (is.null(membership) || !("cluster" %in% names(membership))) {
     character(0)
   } else {
     as.character(membership$cluster)
   }
   validation_ids <- if (is.null(per_cluster) || !("cluster_id" %in% names(per_cluster))) {
     character(0)
   } else {
     as.character(per_cluster$cluster_id)
   }
 
   missing_scores <- setdiff(membership_ids, validation_ids) # served clusters with no stability row
   orphan_scores <- setdiff(validation_ids, membership_ids) # validation clusters not served
   channel_mismatch <- !is.null(membership_channel) && !is.null(validation_channel) &&
     !identical(as.character(membership_channel), as.character(validation_channel))
 
   problems <- character(0)
   if (length(missing_scores)) {
     problems <- c(problems, sprintf(
       "%d visible %s cluster(s) have no validation/stability score (ids: %s)",
       length(missing_scores), kind, paste(missing_scores, collapse = ", ")
     ))
   }
   if (length(orphan_scores)) {
     problems <- c(problems, sprintf(
       "%d validation %s cluster(s) are not in the served membership (ids: %s)",
       length(orphan_scores), kind, paste(orphan_scores, collapse = ", ")
     ))
   }
   if (channel_mismatch) {
     problems <- c(problems, sprintf(
       "%s membership channel (%s) disagrees with the validation channel (%s)",
       kind, membership_channel, validation_channel
     ))
   }
 
   # Same-partition proof (not just same labels): for every shared cluster_id the
   # served membership and the validated reference partition must contain the SAME
   # member set. Catches a stale membership whose cluster-id labels coincide with the
   # fresh validation but whose contents differ.
   if (!is.null(membership_members) && !is.null(validation_members)) {
     shared <- intersect(names(membership_members), names(validation_members))
     content_mismatch <- character(0)
     for (cid in shared) {
       a <- unique(as.character(membership_members[[cid]]))
       b <- unique(as.character(validation_members[[cid]]))
       if (!setequal(a, b)) content_mismatch <- c(content_mismatch, cid)
     }
     if (length(content_mismatch)) {
       problems <- c(problems, sprintf(
         "%d %s cluster(s) have membership content that differs from the validated partition (ids: %s)",
         length(content_mismatch), kind, paste(content_mismatch, collapse = ", ")
       ))
     }
   }
 
   coherent <- length(problems) == 0L
   if (!coherent) {
     msg <- sprintf(
       paste0(
         "Incoherent %s partition snapshot: membership and validation describe ",
         "different partitions: %s. Refusing to publish (#514)."
       ),
       kind, paste(problems, collapse = "; ")
     )
     if (require_coherence) {
       stop(msg, call. = FALSE)
     } else {
       warning(msg, call. = FALSE)
     }
   }
 
   invisible(list(
     coherent = coherent,
     problems = problems,
     missing_scores = missing_scores,
     orphan_scores = orphan_scores
   ))
 }
 
+#' Partition-independent STRING_id -> {hgnc_id...} dictionary from served identifiers.
+#'
+#' Each served membership identifier row carries the fixed (STRING_id, hgnc_id)
+#' gene pairing (from the STRING id table join); this pairing is a property of the
+#' gene set, NOT of the partition, so it is reliable even for a stale membership.
+#' One STRING protein can join MULTIPLE hgnc records (`non_alt_loci_set` has no
+#' STRING_id uniqueness), and the served cluster_members then contain ALL of those
+#' hgnc ids — so this returns a named LIST mapping each STRING_id to the SET of all
+#' its hgnc_ids (MC1: a first-wins scalar dict would drop the others and
+#' false-reject a coherent snapshot).
+#' @return named list: STRING_id -> character vector of hgnc_ids.
+#' @noRd
+.analysis_snapshot_string_to_hgnc_dict <- function(membership) {
+  if (is.null(membership) || !("identifiers" %in% names(membership))) {
+    return(list())
+  }
+  pairs <- lapply(membership$identifiers, function(df) {
+    if (is.data.frame(df) && all(c("STRING_id", "hgnc_id") %in% names(df))) {
+      data.frame(
+        STRING_id = as.character(df$STRING_id),
+        hgnc_id = as.character(df$hgnc_id),
+        stringsAsFactors = FALSE
+      )
+    } else {
+      NULL
+    }
+  })
+  pairs <- pairs[!vapply(pairs, is.null, logical(1))]
+  if (length(pairs) == 0L) {
+    return(list())
+  }
+  pairs <- do.call(rbind, pairs)
+  pairs <- pairs[!is.na(pairs$STRING_id) & !is.na(pairs$hgnc_id), , drop = FALSE]
+  if (nrow(pairs) == 0L) {
+    return(list())
+  }
+  lapply(split(pairs$hgnc_id, pairs$STRING_id), function(h) unique(as.character(h)))
+}
+
+#' Express the validator's reference member sets in the STORED cluster_member id
+#' space so a RELEASE can independently verify member-set coherence (#573 H4).
+#'
+#' The stored `analysis_snapshot_cluster_member` table keeps `hgnc_id` (functional)
+#' or `entity_id` (phenotype). The validator's `reference_members` are STRING
+#' protein ids (functional) / entity ids (phenotype). This maps them into the
+#' stored space: phenotype is already entity_id; functional STRING_ids are mapped
+#' to hgnc_id via the partition-independent gene dictionary, and any UNMAPPED
+#' STRING_id is kept verbatim (fail-closed — it cannot equal a stored hgnc_id, so
+#' an incoherent membership is never silently masked).
+#'
+#' @return A named list keyed by cluster_id (string) -> member-id character vector.
+#' @noRd
+analysis_snapshot_reference_members_store_space <- function(reference_members, membership, kind) {
+  reference_members <- reference_members %||% list()
+  if (length(reference_members) == 0L) {
+    return(list())
+  }
+  if (identical(kind, "phenotype")) {
+    return(lapply(reference_members, function(ids) unique(as.character(ids))))
+  }
+  dict <- .analysis_snapshot_string_to_hgnc_dict(membership)
+  lapply(reference_members, function(sids) {
+    sids <- as.character(sids)
+    # Expand each STRING_id to the SET (union) of all its hgnc_ids so the mapped
+    # reference set equals the served cluster_members set; an UNMAPPED STRING_id is
+    # kept verbatim (fail-closed — it cannot equal a stored hgnc_id).
+    mapped <- unlist(lapply(sids, function(s) {
+      hg <- dict[[s]]
+      if (is.null(hg) || length(hg) == 0L) s else hg
+    }), use.names = FALSE)
+    unique(as.character(mapped))
+  })
+}
+
+#' Attach the additive partition provenance the join computed onto `partition`.
+#'
+#' Copies the served membership channel (#514, functional only — NA on the
+#' phenotype axis is not stored) and the H4 reference member-set attestation
+#' (#573, both axes) from the joined-tibble attributes onto `val$partition`, which
+#' the builder persists into `validation_json`. `partition_validation` is excluded
+#' from `payload_hash`, so this never churns `cluster_hash`.
+#' @export
+analysis_snapshot_attach_partition_provenance <- function(partition, joined) {
+  channel <- attr(joined, "membership_weight_channel")
+  if (!is.null(channel) && !all(is.na(channel))) {
+    partition$membership_weight_channel <- channel
+  }
+  partition$reference_members <- attr(joined, "reference_members_store_space")
+  partition
+}
+
 #' Gate then join the validator's per-cluster scores onto the served membership.
 #'
 #' Single choke-point for the builder's two clustering presets: it asserts partition
 #' coherence FIRST (so an incoherent snapshot can never be published), then performs the
 #' `cluster` <-> `cluster_id` left-join, and carries the served membership channel as a
 #' `membership_weight_channel` attribute for additive provenance.
 #'
 #' @param membership tibble from the memoised clustering function (integer `cluster`,
 #'   optional `weight_channel` attribute).
 #' @param val the validator return list (`per_cluster` tibble + `partition` list).
 #' @param kind "functional" or "phenotype".
 #' @return the joined clusters tibble (validation columns merged; `cluster_id` dropped).
 #' @export
 analysis_snapshot_join_validated_clusters <- function(membership, val, kind) {
   membership_channel <- attr(membership, "weight_channel")
   validation_channel <- val$partition$weight_channel
 
   # Member id space differs per axis: functional clusters over STRING node ids, phenotype
   # clusters over entity ids. Extract the served per-cluster member set (keyed by the same
   # integer cluster label as val$reference_members) for the same-partition proof.
   member_col <- if (identical(kind, "functional")) "STRING_id" else "entity_id"
   membership_members <- NULL
   if (all(c("identifiers", "cluster") %in% names(membership))) {
     membership_members <- stats::setNames(
       lapply(membership$identifiers, function(df) {
         if (is.data.frame(df) && member_col %in% names(df)) {
           as.character(df[[member_col]])
         } else {
           character(0)
         }
       }),
       as.character(membership$cluster)
     )
   }
 
   analysis_snapshot_assert_partition_coherent(
     membership, val$per_cluster, kind,
     membership_channel = membership_channel,
     validation_channel = validation_channel,
     membership_members = membership_members,
     validation_members = val$reference_members
   )
 
   joined <- dplyr::left_join(
     dplyr::mutate(membership, cluster_id = as.character(cluster)),
     val$per_cluster,
     by = "cluster_id"
   )
   joined <- dplyr::select(joined, -cluster_id)
   attr(joined, "membership_weight_channel") <- membership_channel %||% NA_character_
+  # #573 H4: carry the validator's reference member sets, expressed in the STORED
+  # cluster_member id space, so the builder can persist them into validation_json
+  # and a RELEASE can later re-prove member-set coherence independently. Attached
+  # as an attribute (not mutated onto `val`, which is a by-value copy here).
+  attr(joined, "reference_members_store_space") <- analysis_snapshot_reference_members_store_space(
+    val$reference_members, membership, kind
+  )
   joined
 }
diff --git a/api/functions/analysis-snapshot-prune-helpers.R b/api/functions/analysis-snapshot-prune-helpers.R
new file mode 100644
index 00000000..515359a0
--- /dev/null
+++ b/api/functions/analysis-snapshot-prune-helpers.R
@@ -0,0 +1,81 @@
+# functions/analysis-snapshot-prune-helpers.R
+#
+# Retention / prune helper for public analysis-snapshot manifests. Extracted from
+# `analysis-snapshot-repository.R` (#573 round-3 CI1) to keep that file under the
+# 600-line ceiling; the logic is unchanged.
+#
+# `analysis_snapshot_prune()` keeps the newest `keep_public_ready`
+# public_ready/superseded rows and deletes superseded rows older than
+# `keep_superseded_days` — but NEVER deletes a snapshot a #573 release still
+# references (its live reproducibility endpoint would then 503). The
+# release-reference lookup (`analysis_release_referenced_snapshot_ids`) is
+# `exists()`-guarded for mirai-pool parity: on the legacy mirai worker the release
+# repository file is not sourced, so the guard degrades to "no release references"
+# (the pre-existing behavior) rather than erroring.
+#
+# Registered in both `bootstrap/load_modules.R` (API + durable worker + MCP) and
+# `bootstrap/setup_workers.R` (mirai `everywhere()`), immediately after
+# `analysis-snapshot-repository.R`, because the snapshot builder calls this during
+# a refresh on either execution path.
+
+if (!exists("%||%", mode = "function")) {
+  `%||%` <- function(x, y) if (is.null(x)) y else x
+}
+
+analysis_snapshot_prune <- function(analysis_type,
+                                    parameter_hash,
+                                    keep_public_ready = 3L,
+                                    keep_superseded_days = 14L,
+                                    conn = NULL) {
+  keep_public_ready <- max(1L, as.integer(keep_public_ready))
+  keep_superseded_days <- max(0L, as.integer(keep_superseded_days))
+
+  keep_rows <- db_execute_query(
+    "SELECT snapshot_id
+       FROM analysis_snapshot_manifest
+      WHERE analysis_type = ?
+        AND parameter_hash = ?
+        AND status IN ('public_ready', 'superseded')
+      ORDER BY COALESCE(activated_at, generated_at, created_at) DESC, snapshot_id DESC
+      LIMIT ?",
+    unname(list(analysis_type, parameter_hash, keep_public_ready)),
+    conn = conn
+  )
+  keep_ids <- as.numeric(keep_rows$snapshot_id %||% numeric())
+
+  cutoff_time <- as.POSIXct(Sys.time() - (keep_superseded_days * 86400), tz = "UTC")
+  cutoff <- format(cutoff_time, "%Y-%m-%d %H:%M:%OS6", tz = "UTC")
+  candidates <- db_execute_query(
+    "SELECT snapshot_id
+       FROM analysis_snapshot_manifest
+      WHERE analysis_type = ?
+        AND parameter_hash = ?
+        AND status = 'superseded'
+        AND COALESCE(superseded_at, updated_at, created_at) < ?",
+    unname(list(analysis_type, parameter_hash, cutoff)),
+    conn = conn
+  )
+
+  # Never prune a snapshot a release (#573) still references (its LIVE
+  # reproducibility endpoint would 503). analysis_release_referenced_snapshot_ids()
+  # is the single source of truth for this -- do not inline a NOT IN subquery.
+  # exists()-guarded for mirai-pool parity (the release repository file is not
+  # sourced on the legacy mirai worker), mirroring the lock-name guard.
+  referenced_ids <- if (exists("analysis_release_referenced_snapshot_ids", mode = "function")) {
+    as.numeric(analysis_release_referenced_snapshot_ids(conn = conn))
+  } else {
+    numeric()
+  }
+
+  delete_ids <- setdiff(as.numeric(candidates$snapshot_id %||% numeric()), union(keep_ids, referenced_ids))
+  if (length(delete_ids) == 0L) {
+    return(invisible(0L))
+  }
+
+  placeholders <- paste(rep("?", length(delete_ids)), collapse = ", ")
+  db_execute_statement(
+    paste0("DELETE FROM analysis_snapshot_manifest WHERE snapshot_id IN (", placeholders, ")"),
+    unname(as.list(delete_ids)),
+    conn = conn
+  )
+}
diff --git a/api/functions/analysis-snapshot-release-manifest.R b/api/functions/analysis-snapshot-release-manifest.R
new file mode 100644
index 00000000..8e5bb84f
--- /dev/null
+++ b/api/functions/analysis-snapshot-release-manifest.R
@@ -0,0 +1,279 @@
+# Pure, DB-free helpers for immutable public analysis-snapshot RELEASES
+# (#573 Slice A / Task A2): the layer registry, content-address identity
+# (content_digest / release_id), the manifest.json / checksums.sha256
+# builders, and the deterministic tar.gz archive writer.
+#
+# These functions define release IDENTITY and file contracts consumed by
+# later tasks (repository persistence, build orchestrator). They must stay
+# pure: no DB access, no network, no side effects beyond a scratch tempdir
+# used internally by `analysis_release_build_tar_gz()`.
+#
+# Reuses the EXISTING canonical JSON serializer from
+# `analysis-snapshot-presets.R` (`analysis_snapshot_canonical_json()`, sourced
+# by callers before this file) so release file bytes hash identically to the
+# bytes the public snapshot API already serves. Do not reimplement it here.
+
+ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION <- "1.0"
+
+#' Default analysis layers bundled into a release.
+#'
+#' Registry-driven (a list, single source of truth): which analysis types are
+#' included, the locked snapshot params used to select their source snapshot,
+#' the archive path prefix for that layer's files, and whether a
+#' reproducibility bundle is expected for it.
+#'
+#' @return list of `list(analysis_type, params, files_prefix,
+#'   has_reproducibility)`.
+analysis_snapshot_release_layers <- function() {
+  list(
+    list(
+      analysis_type = "functional_clusters",
+      params = list(algorithm = "leiden"),
+      files_prefix = "functional_clusters",
+      has_reproducibility = TRUE
+    ),
+    list(
+      analysis_type = "phenotype_clusters",
+      params = list(),
+      files_prefix = "phenotype_clusters",
+      has_reproducibility = TRUE
+    ),
+    list(
+      analysis_type = "phenotype_functional_correlations",
+      params = list(algorithm = "leiden"),
+      files_prefix = "phenotype_functional_correlations",
+      has_reproducibility = FALSE
+    )
+  )
+}
+
+#' Resolve a caller-supplied `layers` request to authoritative REGISTRY entries.
+#'
+#' `layers` in a build request is a SELECTION, never a policy redefinition: each
+#' requested entry is read ONLY for its `analysis_type` (accepting either a bare
+#' string or a `{analysis_type, ...}` object), matched against the authoritative
+#' `analysis_snapshot_release_layers()` registry, and the REGISTRY entry is
+#' returned — so the caller can never override `params`, `files_prefix`, or the
+#' gate-controlling `has_reproducibility` (which would let an Admin skip the hard
+#' coherence / reproducibility gates, or path-traverse via `files_prefix`).
+#'
+#' NULL/absent `requested` -> the full registry unchanged. An unknown or
+#' duplicated `analysis_type` -> 400 (`stop_for_bad_request`).
+#'
+#' @param requested NULL, or a list of selectors (strings or `{analysis_type}`).
+#' @return list of registry layer entries (a subset of the registry, in request
+#'   order).
+analysis_snapshot_release_resolve_layers <- function(requested = NULL) {
+  registry <- analysis_snapshot_release_layers()
+  if (is.null(requested) || length(requested) == 0L) {
+    return(registry)
+  }
+
+  registry_types <- vapply(registry, function(layer) layer$analysis_type, character(1))
+  registry_by_type <- stats::setNames(registry, registry_types)
+
+  seen <- character(0)
+  lapply(requested, function(entry) {
+    analysis_type <- if (is.list(entry)) entry$analysis_type else entry
+    analysis_type <- as.character(analysis_type %||% "")[[1]]
+    if (!nzchar(analysis_type)) {
+      stop_for_bad_request("release layer selector is missing analysis_type")
+    }
+    if (analysis_type %in% seen) {
+      stop_for_bad_request(sprintf("duplicate release layer: %s", analysis_type))
+    }
+    seen <<- c(seen, analysis_type)
+    match <- registry_by_type[[analysis_type]]
+    if (is.null(match)) {
+      stop_for_bad_request(sprintf("unknown release layer: %s", analysis_type))
+    }
+    match
+  })
+}
+
+#' Reject an archive-relative file path that could escape the archive root.
+#'
+#' Defense-in-depth against path traversal: rejects any path that is empty,
+#' absolute (leading `/` or a Windows drive), contains a backslash separator, or
+#' contains a `..` segment. Called for every materialized file path AND every
+#' path written into the tar archive (`analysis_release_build_tar_gz`).
+#'
+#' @param path chr, an archive-relative file path.
+#' @return invisibly TRUE; throws on an unsafe path.
+.analysis_release_assert_safe_path <- function(path) {
+  p <- as.character(path)[[1]]
+  segments <- strsplit(p, "/", fixed = TRUE)[[1]]
+  if (!nzchar(p) ||
+    startsWith(p, "/") ||
+    grepl("^[A-Za-z]:[\\\\/]", p) ||
+    grepl("\\\\", p) ||
+    any(segments == "..")) {
+    stop(sprintf("unsafe release file path: %s", p), call. = FALSE)
+  }
+  invisible(TRUE)
+}
+
+#' UTF-8 raw bytes of the canonical JSON serialization of `obj`.
+#'
+#' Uses the SAME serializer as the public snapshot API
+#' (`analysis_snapshot_canonical_json()`), so release file bytes hash
+#' identically to the corresponding public API response bytes.
+#'
+#' @param obj Any value accepted by `analysis_snapshot_canonical_json()`.
+#' @return raw vector.
+analysis_release_canonical_bytes <- function(obj) {
+  charToRaw(enc2utf8(analysis_snapshot_canonical_json(obj)))
+}
+
+#' SHA-256 hex digest of raw bytes or a character string.
+#'
+#' Repo-wide convention: `digest::digest(x, algo = "sha256", serialize =
+#' FALSE)`. With `serialize = FALSE`, a raw vector is hashed as its bytes
+#' directly and a character string is hashed as its string content, so this
+#' accepts either without branching.
+#'
+#' @param raw_or_chr raw vector or a length-1 character string.
+#' @return chr, a 64-character lowercase hex sha256 digest.
+analysis_release_sha256 <- function(raw_or_chr) {
+  digest::digest(raw_or_chr, algo = "sha256", serialize = FALSE)
+}
+
+#' Order-independent content digest: the identity basis for a release.
+#'
+#' Deliberately excludes `created_at`, `title`, and any DOI — release
+#' identity is pure scientific content (each layer's input/payload/
+#' reproducibility hashes and dependencies, plus the source data version and
+#' manifest schema version), never presentation metadata. `layer_entries` is
+#' sorted by `analysis_type` before hashing so caller-supplied ordering never
+#' changes the digest.
+#'
+#' @param layer_entries list of list(analysis_type, input_hash, payload_hash,
+#'   reproducibility_hash, dependencies).
+#' @param source_data_version chr.
+#' @param manifest_schema_version chr.
+#' @return chr, a 64-character lowercase hex sha256 digest.
+analysis_release_content_digest <- function(layer_entries, source_data_version, manifest_schema_version) {
+  analysis_types <- vapply(layer_entries, function(entry) entry$analysis_type, character(1))
+  # method = "radix" is locale-invariant: the content identity must not depend on
+  # the builder's LC_COLLATE (de-risks cross-host #574 reproducibility).
+  sorted_entries <- layer_entries[order(analysis_types, method = "radix")]
+
+  identity_layers <- lapply(sorted_entries, function(entry) {
+    entry[c("analysis_type", "input_hash", "payload_hash", "reproducibility_hash", "dependencies")]
+  })
+
+  identity_obj <- list(
+    manifest_schema_version = manifest_schema_version,
+    source_data_version = source_data_version,
+    layers = identity_layers
+  )
+
+  analysis_release_sha256(analysis_release_canonical_bytes(identity_obj))
+}
+
+#' Short, readable release handle derived from the content digest.
+#'
+#' The first 16 hex characters (64 bits) of the content digest, prefixed
+#' `asr_`. This is a human/URL-facing handle only; the full content digest is
+#' the authoritative identity value and is stored separately by later tasks.
+#'
+#' @param content_digest chr, as returned by `analysis_release_content_digest()`.
+#' @return chr, matching `^asr_[0-9a-f]{16}$` for a well-formed digest.
+analysis_release_id <- function(content_digest) {
+  paste0("asr_", substr(content_digest, 1, 16))
+}
+
+#' Build the release `manifest.json` R list.
+#'
+#' `fields$files` is the caller-computed flat file list (one
+#' `list(path, sha256, bytes)` entry per archive member). Neither
+#' `manifest.json` nor `checksums.sha256` can describe their own checksum, so
+#' both are excluded from the `files[]` array in the built manifest.
+#'
+#' @param fields list with elements `release_id`, `release_version`, `title`,
+#'   `created_at`, `license`, `scope_statement`, `generator`, `source`,
+#'   `layers`, `files`, `content_digest`.
+#' @return list, the manifest ready for `analysis_snapshot_canonical_json()`.
+analysis_release_build_manifest <- function(fields) {
+  self_describing_paths <- c("manifest.json", "checksums.sha256")
+  files <- Filter(function(f) !(f$path %in% self_describing_paths), fields$files)
+
+  list(
+    release_id = fields$release_id,
+    release_version = fields$release_version,
+    title = fields$title,
+    created_at = fields$created_at,
+    license = fields$license,
+    scope_statement = fields$scope_statement,
+    generator = fields$generator,
+    source = fields$source,
+    layers = fields$layers,
+    files = files,
+    content_digest = fields$content_digest
+  )
+}
+
+#' Build the `checksums.sha256` file content.
+#'
+#' One `"<sha256>  <path>\n"` line per file (the classic `sha256sum` format),
+#' excluding `checksums.sha256` itself since a file cannot list its own
+#' checksum.
+#'
+#' @param files list of `list(path, sha256, bytes)`.
+#' @return chr, the full checksums file text (empty string if `files` yields
+#'   no lines after exclusion).
+analysis_release_checksums_text <- function(files) {
+  files <- Filter(function(f) f$path != "checksums.sha256", files)
+  if (length(files) == 0) {
+    return("")
+  }
+  lines <- vapply(files, function(f) paste0(f$sha256, "  ", f$path), character(1))
+  paste0(paste(lines, collapse = "\n"), "\n")
+}
+
+#' Build a gzip-compressed tar archive from named raw vectors.
+#'
+#' `named_raw_list` is a named list of `path = raw_bytes`; each name becomes
+#' a (possibly nested, e.g. `"functional_clusters/reproducibility.json.gz"`)
+#' relative file path inside the archive. Built ONCE at release-build time
+#' and stored/served verbatim thereafter, so byte-level rebuild determinism
+#' is NOT required here — per-file `checksums.sha256` entries plus the
+#' manifest are the verification anchors for individual file contents. Paths
+#' are sorted purely for a stable, readable archive listing order.
+#'
+#' @param named_raw_list named list of raw vectors, keyed by archive-relative
+#'   path.
+#' @return raw vector, the gzip-compressed tar archive bytes.
+analysis_release_build_tar_gz <- function(named_raw_list) {
+  paths <- names(named_raw_list)
+  stopifnot(
+    "named_raw_list must be a non-empty named list" = length(paths) > 0 && all(nzchar(paths))
+  )
+  # Containment: refuse any path that could escape the archive root before it is
+  # written under the scratch dir with file.path(src_dir, path).
+  for (path in paths) {
+    .analysis_release_assert_safe_path(path)
+  }
+  paths <- sort(paths)
+
+  src_dir <- tempfile("analysis-release-src-")
+  dir.create(src_dir, recursive = TRUE)
+  on.exit(unlink(src_dir, recursive = TRUE, force = TRUE), add = TRUE)
+
+  for (path in paths) {
+    full_path <- file.path(src_dir, path)
+    dir.create(dirname(full_path), recursive = TRUE, showWarnings = FALSE)
+    writeBin(named_raw_list[[path]], full_path)
+  }
+
+  tar_file <- tempfile("analysis-release-", fileext = ".tar")
+  on.exit(unlink(tar_file, force = TRUE), add = TRUE)
+
+  previous_wd <- setwd(src_dir)
+  on.exit(setwd(previous_wd), add = TRUE)
+  # tar = "internal" forces R's built-in (pure-R) tar writer so the archive
+  # never depends on a system `tar` binary being present/compatible.
+  utils::tar(tarfile = tar_file, files = paths, compression = "none", tar = "internal")
+
+  memCompress(readBin(tar_file, "raw", n = file.info(tar_file)$size), type = "gzip")
+}
diff --git a/api/functions/analysis-snapshot-release-materialize.R b/api/functions/analysis-snapshot-release-materialize.R
new file mode 100644
index 00000000..94c1dbbf
--- /dev/null
+++ b/api/functions/analysis-snapshot-release-materialize.R
@@ -0,0 +1,420 @@
+# functions/analysis-snapshot-release-materialize.R
+#
+# Pure, DB-light helpers for the immutable analysis-snapshot RELEASE build
+# orchestrator (#573 Slice A / Task A4). Split out of
+# `analysis-snapshot-release.R` to keep both files under the 600-line ceiling.
+#
+# Contains: the classed-condition constructor, the manifest/loader extraction
+# helpers, the best-effort HARD coherence-re-check default (`coherence_assert`
+# seam default), the cross-layer lineage gates, and the per-layer file
+# materialization (payload / reproducibility / README). No DB access, no network.
+#
+# Sourced together with `analysis-snapshot-release.R` (both registered in
+# `bootstrap/load_modules.R` -- Task A8 -- and both sourced by the direct-source
+# integration test).
+
+if (!exists("%||%", mode = "function")) {
+  `%||%` <- function(x, y) if (is.null(x)) y else x
+}
+
+# --------------------------------------------------------------------------- #
+# Classed conditions
+# --------------------------------------------------------------------------- #
+
+#' Construct a classed release-gate condition (`c(<class>,"error","condition")`).
+#'
+#' The five `release_*` gate classes are surfaced to the A5 service, which maps
+#' them to HTTP 400 (`stop_for_bad_request`; the contract has no 409 class).
+#' @noRd
+.analysis_release_condition <- function(class, message, ...) {
+  structure(
+    list(message = message, call = NULL, ...),
+    class = c(class, "error", "condition")
+  )
+}
+
+# --------------------------------------------------------------------------- #
+# Extraction helpers
+# --------------------------------------------------------------------------- #
+
+#' Scalar read of a manifest field (manifest is a 1-row data.frame / tibble).
+#' @noRd
+.analysis_release_manifest_scalar <- function(manifest, field, default = NA) {
+  if (is.null(manifest)) {
+    return(default)
+  }
+  if (!(field %in% names(manifest))) {
+    return(default)
+  }
+  column <- manifest[[field]]
+  if (length(column) == 0L) {
+    return(default)
+  }
+  value <- column[[1]]
+  if (is.null(value)) default else value
+}
+
+#' Take a consistent scalar of `field` across the loaded layer manifests.
+#'
+#' NA when no layer carries it. When `strict = TRUE` (M2), distinct non-empty
+#' values that DISAGREE across layers raise `release_source_version_mismatch`
+#' (mirroring the source_data_version gate — the service maps it to 400); empty
+#' NA values are ignored (not a conflict). When `strict = FALSE`, a disagreement
+#' silently takes the first non-empty value.
+#' @noRd
+.analysis_release_consistent_manifest_value <- function(loaded, field, strict = FALSE) {
+  values <- vapply(
+    loaded,
+    function(e) as.character(.analysis_release_manifest_scalar(e$manifest, field, NA_character_)),
+    character(1)
+  )
+  values <- values[!is.na(values) & nzchar(values)]
+  if (length(values) == 0L) {
+    return(NA_character_)
+  }
+  distinct <- unique(values)
+  if (isTRUE(strict) && length(distinct) > 1L) {
+    stop(.analysis_release_condition(
+      "release_source_version_mismatch",
+      sprintf(
+        "release layers disagree on %s (found: %s)",
+        field, paste(distinct, collapse = ", ")
+      )
+    ))
+  }
+  values[[1]]
+}
+
+#' Coerce a possibly-NULL child tibble to a plain data.frame for serialization.
+#' @noRd
+.analysis_release_rows <- function(x) {
+  if (is.null(x)) {
+    return(data.frame())
+  }
+  as.data.frame(x, stringsAsFactors = FALSE)
+}
+
+#' Map a cluster analysis_type to its cluster_kind label.
+#' @noRd
+.analysis_release_layer_kind <- function(analysis_type) {
+  switch(as.character(analysis_type[[1]]),
+    functional_clusters = "functional",
+    phenotype_clusters = "phenotype",
+    NA_character_
+  )
+}
+
+#' Extract the reproducibility_hash from a loader row (df or list), or NA.
+#' @noRd
+.analysis_release_repro_hash <- function(repro) {
+  if (is.null(repro)) {
+    return(NA_character_)
+  }
+  if (is.data.frame(repro) && nrow(repro) == 0L) {
+    return(NA_character_)
+  }
+  hash <- repro$reproducibility_hash
+  if (is.null(hash) || length(hash) == 0L) {
+    return(NA_character_)
+  }
+  as.character(hash[[1]])
+}
+
+# --------------------------------------------------------------------------- #
+# Default coherence seam (best-effort HARD re-check over the STORED snapshot).
+#
+# Two of the three #514 coherence components ARE reconstructable from the stored
+# public snapshot and are re-checked here (HARD, require_coherence = TRUE,
+# ignoring the ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE downgrade):
+#   1. Cluster-set integrity: every visible cluster (by cluster_kind) must appear
+#      in the membership AND carry a non-NA stability score (jaccard_mean) in its
+#      metadata_json — directly catching the #514 symptom ("real clusters with n/a
+#      stability") in stored form.
+#   2. Channel match (functional axis): the served membership channel
+#      (`membership_weight_channel`) and the validation channel (`weight_channel`)
+#      are both persisted in the manifest `validation_json`; when both are present
+#      they must agree, else the served membership was clustered on a different
+#      STRING channel than the validation scored (the #514 text-mining-vs-exp+db
+#      case that slips through when cluster-id labels coincide).
+# The THIRD component — full member-set equality — is genuinely NOT
+# reconstructable: the validator's `reference_members` is a sibling of `partition`
+# and is never persisted. That check is left to the build-time gate; the dev-stack
+# e2e exercises the true membership-vs-validation recompute path.
+# --------------------------------------------------------------------------- #
+
+#' Parse the manifest `validation_json` column to a plain list (or empty list).
+#' @noRd
+.analysis_release_parse_validation_json <- function(manifest) {
+  raw <- suppressWarnings(as.character(.analysis_release_manifest_scalar(manifest, "validation_json", NA_character_)))
+  if (length(raw) == 0L || is.na(raw[[1]]) || !nzchar(raw[[1]])) {
+    return(list())
+  }
+  parsed <- tryCatch(jsonlite::fromJSON(raw[[1]], simplifyVector = TRUE), error = function(e) NULL)
+  if (is.null(parsed) || !is.list(parsed)) {
+    return(list())
+  }
+  parsed
+}
+
+#' @noRd
+.analysis_release_cluster_has_stability <- function(metadata_json) {
+  txt <- suppressWarnings(as.character(metadata_json))
+  if (length(txt) == 0L || is.na(txt[[1]]) || !nzchar(txt[[1]])) {
+    return(FALSE)
+  }
+  parsed <- tryCatch(jsonlite::fromJSON(txt[[1]], simplifyVector = TRUE), error = function(e) NULL)
+  if (is.null(parsed)) {
+    return(FALSE)
+  }
+  score <- parsed$jaccard_mean %||% parsed$stability %||% parsed$stability_score
+  !is.null(score) && length(score) >= 1L && !is.na(suppressWarnings(as.numeric(score[[1]])))
+}
+
+#' Hard coherence re-check over a loaded cluster snapshot. Default `coherence_assert`.
+#' @export
+analysis_snapshot_release_assert_coherent <- function(snapshot, kind) {
+  clusters <- .analysis_release_rows(snapshot$clusters)
+  members <- .analysis_release_rows(snapshot$cluster_members)
+  if ("cluster_kind" %in% names(clusters)) {
+    clusters <- clusters[as.character(clusters$cluster_kind) == kind, , drop = FALSE]
+  }
+  if ("cluster_kind" %in% names(members)) {
+    members <- members[as.character(members$cluster_kind) == kind, , drop = FALSE]
+  }
+
+  membership_ids <- if ("cluster_id" %in% names(members)) unique(as.character(members$cluster_id)) else character(0)
+  membership <- tibble::tibble(cluster = membership_ids)
+
+  valid_ids <- character(0)
+  if (nrow(clusters) > 0L && "cluster_id" %in% names(clusters)) {
+    metadata <- if ("metadata_json" %in% names(clusters)) clusters$metadata_json else rep(NA_character_, nrow(clusters))
+    has_stability <- vapply(
+      seq_len(nrow(clusters)),
+      function(i) .analysis_release_cluster_has_stability(metadata[[i]]),
+      logical(1)
+    )
+    valid_ids <- as.character(clusters$cluster_id[has_stability])
+  }
+  per_cluster <- tibble::tibble(cluster_id = valid_ids)
+
+  validation <- .analysis_release_parse_validation_json(snapshot$manifest)
+
+  # Channel match (functional axis only): both channels live in validation_json;
+  # when both are present they must agree. Absent/older snapshots skip this
+  # comparison (assert_partition_coherent only fires channel_mismatch when BOTH
+  # membership_channel and validation_channel are non-NULL).
+  membership_channel <- NULL
+  validation_channel <- NULL
+  if (identical(kind, "functional")) {
+    membership_channel <- validation$membership_weight_channel
+    validation_channel <- validation$weight_channel
+  }
+
+  # H4: MEMBER-SET proof. Reconstruct the served membership member sets from the
+  # stored cluster_members (grouped by cluster_id, in the stored id space:
+  # hgnc_id for functional / entity_id for phenotype) and compare them against the
+  # persisted validator reference sets (validation_json$reference_members, same
+  # stored space). When the attestation is ABSENT (legacy pre-#573 snapshot),
+  # GRACEFULLY DEGRADE to the channel + stability check and WARN — never hard
+  # reject a legacy snapshot (that would block every release until a full rebuild).
+  member_col <- if (identical(kind, "functional")) "hgnc_id" else "entity_id"
+  membership_members <- NULL
+  if (all(c("cluster_id", member_col) %in% names(members)) && nrow(members) > 0L) {
+    grouped <- split(as.character(members[[member_col]]), as.character(members$cluster_id))
+    membership_members <- lapply(grouped, function(v) unique(v[!is.na(v) & nzchar(v)]))
+  }
+  validation_members <- validation$reference_members
+  if (!is.null(validation_members) && length(validation_members) > 0L) {
+    validation_members <- lapply(validation_members, function(v) unique(as.character(v)))
+    # MC2: a PRESENT attestation must be COMPLETE — its cluster-id key set must
+    # equal the served membership cluster set. A partial/malformed attestation
+    # (missing a served cluster that would otherwise mismatch) must NOT slip
+    # through the intersection-only same-partition proof: it is INCOHERENT, not
+    # legacy-absent. (The served set == the validated per_cluster set is enforced
+    # separately by the missing/orphan checks in assert_partition_coherent.)
+    served_cluster_ids <- if (!is.null(membership_members)) names(membership_members) else membership_ids
+    if (!setequal(names(validation_members), served_cluster_ids)) {
+      stop(.analysis_release_condition(
+        "release_source_incoherent",
+        sprintf(
+          "%s snapshot reference attestation is partial/malformed: cluster set does not cover the served membership",
+          kind
+        ),
+        kind = kind
+      ))
+    }
+  } else {
+    validation_members <- NULL
+    membership_members <- NULL # fully-absent (legacy) -> no reference to prove against
+    warning(sprintf(
+      paste0(
+        "release coherence: %s snapshot carries no persisted reference member sets ",
+        "(legacy snapshot); full member-set verification is unavailable, degraded to ",
+        "channel + stability check. Rebuild the snapshot (worker-executed) to attest coherence."
+      ),
+      kind
+    ), call. = FALSE)
+  }
+
+  tryCatch(
+    analysis_snapshot_assert_partition_coherent(
+      membership, per_cluster, kind,
+      membership_channel = membership_channel,
+      validation_channel = validation_channel,
+      membership_members = membership_members,
+      validation_members = validation_members,
+      require_coherence = TRUE
+    ),
+    error = function(e) {
+      stop(.analysis_release_condition(
+        "release_source_incoherent",
+        sprintf("%s snapshot failed hard coherence re-check: %s", kind, conditionMessage(e)),
+        kind = kind
+      ))
+    }
+  )
+  invisible(TRUE)
+}
+
+# --------------------------------------------------------------------------- #
+# Cross-layer lineage gates (step 2). Re-asserted immediately before insert.
+# --------------------------------------------------------------------------- #
+
+#' @noRd
+.analysis_release_dep_matches <- function(dependencies, key, entry) {
+  if (!is.list(dependencies)) {
+    return(FALSE)
+  }
+  dep <- dependencies[[key]]
+  if (!is.list(dep)) {
+    return(FALSE)
+  }
+  dep_id <- suppressWarnings(as.integer(dep$snapshot_id %||% NA))
+  dep_hash <- as.character(dep$payload_hash %||% "")
+  entry_id <- suppressWarnings(as.integer(entry$snapshot_id))
+  entry_hash <- as.character(entry$payload_hash %||% "")
+  !is.na(dep_id) && !is.na(entry_id) && identical(dep_id, entry_id) &&
+    nzchar(dep_hash) && nzchar(entry_hash) && identical(dep_hash, entry_hash)
+}
+
+#' Assert one shared source_data_version + correlation dependency lineage.
+#' @noRd
+.analysis_release_assert_lineage <- function(loaded) {
+  versions <- vapply(
+    loaded,
+    function(e) as.character(e$source_data_version %||% NA_character_),
+    character(1)
+  )
+  uniq <- unique(versions)
+  if (length(uniq) != 1L || is.na(uniq[[1]]) || !nzchar(uniq[[1]])) {
+    stop(.analysis_release_condition(
+      "release_source_version_mismatch",
+      sprintf(
+        "release layers do not share one source_data_version (found: %s)",
+        paste(ifelse(is.na(versions), "<NA>", versions), collapse = ", ")
+      )
+    ))
+  }
+
+  corr <- loaded[["phenotype_functional_correlations"]]
+  func <- loaded[["functional_clusters"]]
+  phen <- loaded[["phenotype_clusters"]]
+  if (!is.null(corr) && !is.null(func) && !is.null(phen)) {
+    dependencies <- analysis_snapshot_manifest_dependencies(corr$manifest)
+    ok <- .analysis_release_dep_matches(dependencies, "functional_clusters", func) &&
+      .analysis_release_dep_matches(dependencies, "phenotype_clusters", phen)
+    if (!ok) {
+      stop(.analysis_release_condition(
+        "release_dependency_lineage_mismatch",
+        paste(
+          "correlation snapshot dependency lineage does not match the pinned",
+          "functional/phenotype cluster snapshots (a cluster axis was refreshed",
+          "after the correlation was computed)"
+        )
+      ))
+    }
+  }
+  invisible(TRUE)
+}
+
+# --------------------------------------------------------------------------- #
+# File materialization
+# --------------------------------------------------------------------------- #
+
+#' Layer-appropriate payload object (its own bytes; NOT the snapshot payload_hash).
+#' @noRd
+.analysis_release_layer_payload <- function(snapshot, layer) {
+  if (isTRUE(layer$has_reproducibility)) {
+    list(
+      clusters = .analysis_release_rows(snapshot$clusters),
+      cluster_members = .analysis_release_rows(snapshot$cluster_members)
+    )
+  } else if (grepl("correlation", layer$analysis_type, fixed = TRUE)) {
+    list(correlations = .analysis_release_rows(snapshot$correlations))
+  } else {
+    list(
+      network_nodes = .analysis_release_rows(snapshot$network_nodes),
+      network_edges = .analysis_release_rows(snapshot$network_edges)
+    )
+  }
+}
+
+#' Assemble one materialized artifact with its own sha256 + byte_size.
+#' @noRd
+.analysis_release_artifact <- function(path, bytes, media_type) {
+  # Every materialized file path flows through here — assert containment at this
+  # single choke point (defense-in-depth alongside analysis_release_build_tar_gz).
+  .analysis_release_assert_safe_path(path)
+  list(
+    path = path,
+    bytes = bytes,
+    media_type = media_type,
+    sha256 = analysis_release_sha256(bytes),
+    byte_size = length(bytes)
+  )
+}
+
+#' README.md content bytes (scope + independent-verification recipe).
+#' @noRd
+.analysis_release_readme_bytes <- function(release_id, title, scope_statement, license,
+                                           source_data_version, layer_entries) {
+  layer_lines <- vapply(
+    layer_entries,
+    function(e) {
+      sprintf(
+        "- %s (snapshot_id %s, payload_hash %s)",
+        e$analysis_type, as.character(e$snapshot_id), substr(e$payload_hash, 1, 12)
+      )
+    },
+    character(1)
+  )
+  lines <- c(
+    sprintf("# %s", title %||% "SysNDD analysis-snapshot release"),
+    "",
+    sprintf("Release: `%s`", release_id),
+    sprintf("License: %s", license %||% "CC-BY-4.0"),
+    sprintf("Source data version: %s", source_data_version %||% "unknown"),
+    "",
+    "## Scope",
+    "",
+    scope_statement %||% paste(
+      "Immutable, content-addressed public export of the curated derived",
+      "cluster-analysis snapshots served by the SysNDD analysis API."
+    ),
+    "",
+    "## Layers",
+    "",
+    layer_lines,
+    "",
+    "## Verify",
+    "",
+    "1. `sha256sum -c checksums.sha256` verifies every file against its recorded digest.",
+    "2. `manifest.json` records each layer's source snapshot lineage",
+    "   (`snapshot_id`, `payload_hash`, `input_hash`) plus the reproducibility hash.",
+    "3. Each cluster layer's `reproducibility.json` hashes exactly to its",
+    "   `reproducibility_hash` and carries the inputs to independently recompute",
+    "   the served separation metric (modularity / silhouette).",
+    ""
+  )
+  charToRaw(enc2utf8(paste(lines, collapse = "\n")))
+}
diff --git a/api/functions/analysis-snapshot-release-repository.R b/api/functions/analysis-snapshot-release-repository.R
new file mode 100644
index 00000000..4888fc71
--- /dev/null
+++ b/api/functions/analysis-snapshot-release-repository.R
@@ -0,0 +1,484 @@
+# functions/analysis-snapshot-release-repository.R
+#
+# DB persistence for immutable public analysis-snapshot RELEASES (#573 Slice
+# A / Task A3). Reads/writes the three tables added by migration
+# `045_add_analysis_snapshot_release.sql`: `analysis_snapshot_release` (head),
+# `analysis_snapshot_release_member` (per-layer lineage), and
+# `analysis_snapshot_release_file` (per-archive-file blob + checksum).
+#
+# Deliberately self-contained: uses raw `DBI::dbGetQuery()` / `DBI::dbExecute()`
+# with bound `?` params (never string-interpolated identifiers) instead of the
+# `db_execute_query()`/`db_execute_statement()` wrappers in `db-helpers.R`.
+# Those wrappers eagerly stringify every param for a DEBUG log line — fine for
+# scalar params, but for a LONGBLOB param (`list(<raw>)`) that would deparse
+# the whole multi-MB blob on every call, mirroring the exact trap already
+# documented in `analysis-reproducibility.R`'s
+# `analysis_snapshot_insert_reproducibility()`. Blob columns (`bundle_gzip`,
+# `content_gzip`) are always bound as `list(<raw vector>)`, per DBI's blob
+# binding convention (verified against RMariaDB).
+#
+# `conn` is a REQUIRED, explicit DBI connection on every function here (no
+# `conn = NULL` global-pool fallback like the sibling
+# `analysis-snapshot-repository.R`). Two reasons: (1) `analysis_release_insert()`
+# wraps its writes in one `DBI::dbWithTransaction(conn, {...})`, which needs a
+# real `DBIConnection`, not a `Pool`; and (2) blob binding via
+# `list(<raw vector>)` needs the same. Callers (services, later tasks) are
+# responsible for resolving/checking out a real connection before calling in.
+#
+# IMPORTANT test/caller trap (verified live against RMariaDB): calling
+# `analysis_release_insert()` on a connection that already has an open
+# transaction raises "Nested transactions not supported" (RMariaDB's
+# `dbBegin()` rejects it) — the same trap documented in
+# `test-integration-additive-ontology-terms.R` /
+# `test-integration-ontology-mapping-refresh.R`. Never call it from inside
+# `with_test_db_transaction()`.
+
+if (!exists("%||%", mode = "function")) {
+  `%||%` <- function(x, y) if (is.null(x)) y else x
+}
+
+# --------------------------------------------------------------------------- #
+# Internal helpers
+# --------------------------------------------------------------------------- #
+
+#' Unwrap a single-row blob column value to its raw vector.
+#' @noRd
+.analysis_release_blob <- function(x) {
+  if (is.list(x)) x <- x[[1]]
+  x
+}
+
+#' Coerce a possibly-NULL scalar to a bindable value, defaulting to NA.
+#' @noRd
+.analysis_release_chr <- function(x) {
+  if (is.null(x) || length(x) == 0L) return(NA_character_)
+  as.character(x[[1]])
+}
+
+#' Head-table column list shared by SELECTs (excludes the `bundle_gzip` blob
+#' so metadata reads never pull the multi-MB bundle unless explicitly asked
+#' for via `analysis_release_get_bundle()`).
+#' @noRd
+.analysis_release_head_columns <- paste(
+  "release_id, release_version, title, status, manifest_schema_version,",
+  "content_digest, manifest_sha256, bundle_sha256, bundle_bytes,",
+  "source_data_version, db_release_version, db_release_commit, scope_statement,",
+  "license, file_count, total_bytes, created_by_user_id, created_at,",
+  "published_at, updated_at, zenodo_record_id, zenodo_record_url,",
+  "version_doi, concept_doi, last_error_message"
+)
+
+#' Convert a single-row data.frame (as returned by dbGetQuery) into a plain
+#' named list, one element per column.
+#' @noRd
+.analysis_release_row_to_list <- function(rows, i = 1L) {
+  as.list(rows[i, , drop = FALSE])
+}
+
+# --------------------------------------------------------------------------- #
+# Write
+# --------------------------------------------------------------------------- #
+
+#' Insert a release head + its members + its files in ONE transaction.
+#'
+#' `release_head` is a named list with (at least) `release_id`,
+#' `manifest_schema_version`, `content_digest`, `manifest_sha256`,
+#' `bundle_sha256`, `bundle_gzip` (raw), plus optional `release_version`,
+#' `title`, `source_data_version`, `db_release_version`, `db_release_commit`,
+#' `scope_statement`, `license` (defaults `"CC-BY-4.0"`),
+#' `created_by_user_id`. Always inserted with `status = 'draft'` —
+#' `analysis_release_publish()` is the only way to flip it.
+#'
+#' `bundle_bytes`, `file_count`, `total_bytes` are derived here (not trusted
+#' from the caller) from `bundle_gzip`/`files` directly, so they can never
+#' drift from the actual stored bytes.
+#'
+#' `members` is a list of `list(analysis_type, parameter_hash, snapshot_id,
+#' input_hash, payload_hash, schema_version, reproducibility_hash = NULL,
+#' role = "layer")`.
+#'
+#' `files` is a list of `list(file_path, content_sha256, byte_size,
+#' media_type = "application/json", content_gzip)` (`content_gzip` a raw
+#' vector).
+#'
+#' @return chr, the inserted `release_id`.
+#' @export
+analysis_release_insert <- function(release_head, members = list(), files = list(), conn) {
+  release_id <- .analysis_release_chr(release_head$release_id)
+  if (is.na(release_id) || !nzchar(release_id)) {
+    stop("release_head$release_id is required", call. = FALSE)
+  }
+  bundle_gzip <- release_head$bundle_gzip
+  if (!is.raw(bundle_gzip)) {
+    stop("release_head$bundle_gzip must be a raw vector", call. = FALSE)
+  }
+
+  file_count <- length(files)
+  total_bytes <- sum(vapply(files, function(f) as.numeric(f$byte_size %||% 0), numeric(1)))
+
+  DBI::dbWithTransaction(conn, {
+    DBI::dbExecute(
+      conn,
+      "INSERT INTO analysis_snapshot_release (
+         release_id, release_version, title, status, manifest_schema_version,
+         content_digest, manifest_sha256, bundle_sha256, bundle_gzip, bundle_bytes,
+         source_data_version, db_release_version, db_release_commit, scope_statement,
+         license, file_count, total_bytes, created_by_user_id
+       ) VALUES (?, ?, ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
+      params = unname(list(
+        release_id,
+        .analysis_release_chr(release_head$release_version),
+        .analysis_release_chr(release_head$title),
+        .analysis_release_chr(release_head$manifest_schema_version),
+        .analysis_release_chr(release_head$content_digest),
+        .analysis_release_chr(release_head$manifest_sha256),
+        .analysis_release_chr(release_head$bundle_sha256),
+        list(bundle_gzip),
+        length(bundle_gzip),
+        .analysis_release_chr(release_head$source_data_version),
+        .analysis_release_chr(release_head$db_release_version),
+        .analysis_release_chr(release_head$db_release_commit),
+        .analysis_release_chr(release_head$scope_statement),
+        release_head$license %||% "CC-BY-4.0",
+        as.integer(file_count),
+        as.numeric(total_bytes),
+        if (is.null(release_head$created_by_user_id)) NA_integer_ else as.integer(release_head$created_by_user_id)
+      ))
+    )
+
+    for (m in members) {
+      DBI::dbExecute(
+        conn,
+        "INSERT INTO analysis_snapshot_release_member (
+           release_id, analysis_type, parameter_hash, snapshot_id, input_hash,
+           payload_hash, schema_version, reproducibility_hash, role
+         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
+        params = unname(list(
+          release_id,
+          .analysis_release_chr(m$analysis_type),
+          .analysis_release_chr(m$parameter_hash),
+          as.numeric(m$snapshot_id),
+          .analysis_release_chr(m$input_hash),
+          .analysis_release_chr(m$payload_hash),
+          .analysis_release_chr(m$schema_version),
+          .analysis_release_chr(m$reproducibility_hash),
+          m$role %||% "layer"
+        ))
+      )
+    }
+
+    for (f in files) {
+      DBI::dbExecute(
+        conn,
+        "INSERT INTO analysis_snapshot_release_file (
+           release_id, file_path, content_sha256, byte_size, media_type, content_gzip
+         ) VALUES (?, ?, ?, ?, ?, ?)",
+        params = unname(list(
+          release_id,
+          .analysis_release_chr(f$file_path),
+          .analysis_release_chr(f$content_sha256),
+          as.integer(f$byte_size),
+          f$media_type %||% "application/json",
+          list(f$content_gzip)
+        ))
+      )
+    }
+  })
+
+  release_id
+}
+
+# --------------------------------------------------------------------------- #
+# Public projection
+# --------------------------------------------------------------------------- #
+
+#' Project a release head to the PUBLIC allowlist (#573 H1).
+#'
+#' The raw head carries operational columns — `created_by_user_id`,
+#' `last_error_message`, `updated_at` — that must never reach the public
+#' list/detail/latest surface. This projects to an explicit allowlist and groups
+#' the DOI fields under `zenodo`. Public-safe derived members (`layers` from
+#' `analysis_release_list()`, the parsed `manifest` from `analysis_release_get()`)
+#' are carried through when present. The ADMIN surface keeps the raw head.
+#'
+#' @param head A named list (a raw head from the repository read functions), or NULL.
+#' @return The projected named list, or NULL when `head` is NULL.
+#' @export
+analysis_release_public_head <- function(head) {
+  if (is.null(head)) {
+    return(NULL)
+  }
+  nullify <- function(x) if (is.null(x) || (length(x) == 1L && is.na(x))) NULL else x
+
+  allowlist <- c(
+    "release_id", "release_version", "title", "status", "content_digest",
+    "created_at", "published_at", "source_data_version",
+    "db_release_version", "db_release_commit", "manifest_sha256",
+    "bundle_sha256", "license", "file_count", "total_bytes"
+  )
+  projected <- head[intersect(allowlist, names(head))]
+  projected$zenodo <- list(
+    record_url = nullify(head$zenodo_record_url),
+    version_doi = nullify(head$version_doi),
+    concept_doi = nullify(head$concept_doi)
+  )
+  if (!is.null(head$layers)) {
+    projected$layers <- head$layers
+  }
+  if (!is.null(head$manifest)) {
+    projected$manifest <- head$manifest
+  }
+  projected
+}
+
+# --------------------------------------------------------------------------- #
+# Read
+# --------------------------------------------------------------------------- #
+
+#' Fetch a release head (+ parsed manifest.json, if stored) by id.
+#'
+#' Draft rows are hidden unless `include_draft = TRUE` — the visibility
+#' filter is applied in SQL (`AND status = 'published'`), not by fetching and
+#' discarding in R.
+#'
+#' @return A named list (head columns + `$manifest`, the parsed manifest.json
+#'   as a plain R list via `jsonlite::fromJSON(simplifyVector = FALSE)`), or
+#'   `NULL` if no matching (visible) row exists.
+#' @export
+analysis_release_get <- function(release_id, include_draft = FALSE, conn) {
+  status_clause <- if (isTRUE(include_draft)) "" else " AND status = 'published'"
+  sql <- paste0(
+    "SELECT ", .analysis_release_head_columns, "
+       FROM analysis_snapshot_release
+      WHERE release_id = ?", status_clause, "
+      LIMIT 1"
+  )
+  rows <- DBI::dbGetQuery(conn, sql, params = unname(list(as.character(release_id))))
+  if (nrow(rows) == 0L) {
+    return(NULL)
+  }
+
+  head <- .analysis_release_row_to_list(rows)
+
+  manifest_file <- analysis_release_get_file(
+    release_id, "manifest.json",
+    include_draft = include_draft, conn = conn
+  )
+  head$manifest <- if (is.null(manifest_file)) {
+    NULL
+  } else {
+    tryCatch(
+      jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE),
+      error = function(e) NULL
+    )
+  }
+
+  head
+}
+
+#' List release heads (newest first), each with a `layers` member summary.
+#'
+#' `status = NULL` returns releases of every status; otherwise filters to the
+#' given status (e.g. `"published"`, `"draft"`) in SQL.
+#'
+#' @return A list of named lists (head columns + `$layers`, a list of
+#'   `list(analysis_type, snapshot_id, payload_hash)` for `role = 'layer'`
+#'   members). Empty list if no rows match.
+#' @export
+analysis_release_list <- function(status = "published", limit = 50L, offset = 0L, conn) {
+  where_clause <- ""
+  params <- list()
+  if (!is.null(status)) {
+    where_clause <- " WHERE status = ?"
+    params <- list(as.character(status))
+  }
+  sql <- paste0(
+    "SELECT ", .analysis_release_head_columns, "
+       FROM analysis_snapshot_release",
+    where_clause,
+    " ORDER BY created_at DESC LIMIT ? OFFSET ?"
+  )
+  params <- c(params, list(as.integer(limit), as.integer(offset)))
+  rows <- DBI::dbGetQuery(conn, sql, params = unname(params))
+  if (nrow(rows) == 0L) {
+    return(list())
+  }
+
+  release_ids <- as.character(rows$release_id)
+  placeholders <- paste(rep("?", length(release_ids)), collapse = ",")
+  members <- DBI::dbGetQuery(
+    conn,
+    paste0(
+      "SELECT release_id, analysis_type, snapshot_id, payload_hash
+         FROM analysis_snapshot_release_member
+        WHERE role = 'layer' AND release_id IN (", placeholders, ")
+        ORDER BY release_id, analysis_type"
+    ),
+    params = unname(as.list(release_ids))
+  )
+
+  lapply(seq_len(nrow(rows)), function(i) {
+    head <- .analysis_release_row_to_list(rows, i)
+    rid <- as.character(head$release_id)
+    layer_rows <- members[members$release_id == rid, , drop = FALSE]
+    head$layers <- lapply(seq_len(nrow(layer_rows)), function(j) {
+      list(
+        analysis_type = as.character(layer_rows$analysis_type[[j]]),
+        snapshot_id = layer_rows$snapshot_id[[j]],
+        payload_hash = as.character(layer_rows$payload_hash[[j]])
+      )
+    })
+    head
+  })
+}
+
+#' Fetch one archive file's bytes by its exact (release_id, file_path) key.
+#'
+#' PK lookup only — no path building/concatenation. Draft-release files are
+#' hidden unless `include_draft = TRUE` (a SQL join against the head table's
+#' `status`, applied before any blob is fetched).
+#'
+#' @return `list(bytes = <raw, decompressed>, media_type = chr,
+#'   content_sha256 = chr)`, or `NULL` if no matching (visible) row exists.
+#' @export
+analysis_release_get_file <- function(release_id, file_path, include_draft = FALSE, conn) {
+  status_clause <- if (isTRUE(include_draft)) "" else " AND r.status = 'published'"
+  sql <- paste0(
+    "SELECT f.content_gzip, f.media_type, f.content_sha256
+       FROM analysis_snapshot_release_file f
+       JOIN analysis_snapshot_release r ON r.release_id = f.release_id
+      WHERE f.release_id = ? AND f.file_path = ?", status_clause, "
+      LIMIT 1"
+  )
+  rows <- DBI::dbGetQuery(
+    conn, sql,
+    params = unname(list(as.character(release_id), as.character(file_path)))
+  )
+  if (nrow(rows) == 0L) {
+    return(NULL)
+  }
+
+  gz <- .analysis_release_blob(rows$content_gzip[[1]])
+  list(
+    bytes = memDecompress(gz, type = "gzip"),
+    media_type = as.character(rows$media_type[[1]]),
+    content_sha256 = as.character(rows$content_sha256[[1]])
+  )
+}
+
+#' Fetch the whole release archive (`bundle_gzip`) verbatim.
+#'
+#' `bundle_gzip` is stored already-gzipped and served as-is — this does NOT
+#' decompress it (unlike `analysis_release_get_file()`, which stores each
+#' file's gzip as a transport-only encoding of JSON content). Draft releases
+#' are hidden unless `include_draft = TRUE`, filtered in SQL.
+#'
+#' @return `list(bytes = <raw, verbatim gzip tar>, sha256 = chr, filename =
+#'   "<release_id>.tar.gz")`, or `NULL` if no matching (visible) row exists.
+#' @export
+analysis_release_get_bundle <- function(release_id, include_draft = FALSE, conn) {
+  status_clause <- if (isTRUE(include_draft)) "" else " AND status = 'published'"
+  sql <- paste0(
+    "SELECT bundle_gzip, bundle_sha256
+       FROM analysis_snapshot_release
+      WHERE release_id = ?", status_clause, "
+      LIMIT 1"
+  )
+  rows <- DBI::dbGetQuery(conn, sql, params = unname(list(as.character(release_id))))
+  if (nrow(rows) == 0L) {
+    return(NULL)
+  }
+
+  list(
+    bytes = .analysis_release_blob(rows$bundle_gzip[[1]]),
+    sha256 = as.character(rows$bundle_sha256[[1]]),
+    filename = paste0(as.character(release_id), ".tar.gz")
+  )
+}
+
+#' Check whether a release id exists (any status) — for idempotent creation.
+#' @return logical(1).
+#' @export
+analysis_release_exists <- function(release_id, conn) {
+  rows <- DBI::dbGetQuery(
+    conn,
+    "SELECT 1 AS found FROM analysis_snapshot_release WHERE release_id = ? LIMIT 1",
+    params = unname(list(as.character(release_id)))
+  )
+  nrow(rows) > 0L
+}
+
+#' Distinct snapshot ids referenced by any release member (the later prune
+#' guard uses this to never delete a snapshot a release still points to).
+#' @return integer vector (possibly empty).
+#' @export
+analysis_release_referenced_snapshot_ids <- function(conn) {
+  rows <- DBI::dbGetQuery(
+    conn,
+    "SELECT DISTINCT snapshot_id FROM analysis_snapshot_release_member"
+  )
+  as.integer(rows$snapshot_id)
+}
+
+# --------------------------------------------------------------------------- #
+# Update / delete
+# --------------------------------------------------------------------------- #
+
+#' Publish a draft release (no-op if it is not currently a draft).
+#' @return logical(1), TRUE iff the row flipped to published.
+#' @export
+analysis_release_publish <- function(release_id, conn) {
+  affected <- DBI::dbExecute(
+    conn,
+    "UPDATE analysis_snapshot_release
+        SET status = 'published', published_at = NOW(6)
+      WHERE release_id = ? AND status = 'draft'",
+    params = unname(list(as.character(release_id)))
+  )
+  affected > 0L
+}
+
+#' Record external Zenodo/DOI provenance on an existing release.
+#'
+#' Additive metadata only — updates whichever of `zenodo_record_id`,
+#' `zenodo_record_url`, `version_doi`, `concept_doi` are present in
+#' `doi_fields`; never touches `content_digest`/`manifest_sha256` (release
+#' scientific identity is immutable once minted).
+#'
+#' @param doi_fields Named list, any subset of `zenodo_record_id`,
+#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
+#' @return logical(1), TRUE iff a row was updated.
+#' @export
+analysis_release_set_doi <- function(release_id, doi_fields = list(), conn) {
+  allowed <- c("zenodo_record_id", "zenodo_record_url", "version_doi", "concept_doi")
+  present <- intersect(names(doi_fields), allowed)
+  if (length(present) == 0L) {
+    return(FALSE)
+  }
+
+  set_clause <- paste(paste0(present, " = ?"), collapse = ", ")
+  value_params <- lapply(present, function(k) .analysis_release_chr(doi_fields[[k]]))
+  affected <- DBI::dbExecute(
+    conn,
+    paste0("UPDATE analysis_snapshot_release SET ", set_clause, " WHERE release_id = ?"),
+    params = unname(c(value_params, list(as.character(release_id))))
+  )
+  affected > 0L
+}
+
+#' Delete a release ONLY while it is still a draft (children cascade via FK).
+#'
+#' Refuses (returns FALSE, no-op) once a release is published — releases are
+#' immutable/retained-indefinitely once published; only an unpublished draft
+#' can be discarded (e.g. a failed/aborted build).
+#'
+#' @return logical(1), TRUE iff a draft row was deleted.
+#' @export
+analysis_release_delete_draft <- function(release_id, conn) {
+  affected <- DBI::dbExecute(
+    conn,
+    "DELETE FROM analysis_snapshot_release WHERE release_id = ? AND status = 'draft'",
+    params = unname(list(as.character(release_id)))
+  )
+  affected > 0L
+}
diff --git a/api/functions/analysis-snapshot-release.R b/api/functions/analysis-snapshot-release.R
new file mode 100644
index 00000000..0569149c
--- /dev/null
+++ b/api/functions/analysis-snapshot-release.R
@@ -0,0 +1,540 @@
+# functions/analysis-snapshot-release.R
+#
+# Build orchestrator for immutable, content-addressed public analysis-snapshot
+# RELEASES (#573 Slice A / Task A4). This is the correctness-critical layer: it
+# LOADS the active public snapshots, GATES them (available + hard coherence +
+# reproducibility presence + shared source-data version + dependency lineage +
+# TOCTOU), MATERIALIZES the release files, computes the content-addressed
+# identity, and PERSISTS via the A3 repository.
+#
+# Reuses (sourced by callers before this file / registered in load_modules):
+#   - analysis-snapshot-presets.R          : canonical JSON + parameter hashing
+#   - analysis-snapshot-coherence.R        : analysis_snapshot_assert_partition_coherent
+#   - analysis-snapshot-dependencies.R     : analysis_snapshot_manifest_dependencies
+#   - analysis-reproducibility.R           : analysis_reproducibility_decode_raw
+#   - analysis-snapshot-release-manifest.R : identity + manifest/checksums/tar helpers (A2)
+#   - analysis-snapshot-release-repository.R: analysis_release_insert/get/exists/... (A3)
+#
+# DEPENDENCY-INJECTION SEAMS. The three collaborators below are injectable so the
+# gates are deterministically unit-testable WITHOUT seeding the complex snapshot
+# tables. Their call-time defaults are the real functions; the body always calls
+# the seam, never the real function directly:
+#   - loader(analysis_type, parameter_hash, conn)  -> loaded snapshot
+#   - reproducibility_loader(snapshot_id, conn)    -> reproducibility row (or NULL)
+#   - coherence_assert(snapshot, kind)             -> invisibly / throws
+#
+# ERROR CONTRACT. The five classed conditions below are `c(<name>,"error",
+# "condition")`; the A5 service maps them to HTTP 400 (the contract has no 409):
+#   release_snapshot_not_available, release_source_incoherent,
+#   release_reproducibility_missing, release_source_version_mismatch,
+#   release_dependency_lineage_mismatch.
+# A DUPLICATE build is NOT an error: it returns the existing head with
+# created = FALSE (service -> 200).
+
+if (!exists("%||%", mode = "function")) {
+  `%||%` <- function(x, y) if (is.null(x)) y else x
+}
+
+# Materialization / gate / coherence helpers live in the sibling file (kept
+# separate so both stay under the 600-line ceiling). Registered together in
+# bootstrap/load_modules.R -- Task A8 -- and sourced together by the integration test.
+
+# --------------------------------------------------------------------------- #
+# Advisory locks (TOCTOU): serialize a build against a concurrent axis refresh.
+#
+# The build acquires the SAME per-preset advisory lock the axis refresh holds —
+# `analysis_snapshot_lock_name(analysis_type, parameter_hash)` — so a mid-flight
+# refresh of a source preset blocks the read (MySQL 8 lets one session hold many
+# named GET_LOCKs). Best-effort: engaged only on a real DBIConnection (a
+# pooled/NULL conn cannot hold a session-scoped GET_LOCK meaningfully), and a
+# lock-acquire timeout does NOT abort — the fresh pre-insert re-read below is the
+# invariant that always catches a snapshot that changed under us.
+# --------------------------------------------------------------------------- #
+
+#' Per-preset lock name — identical to the axis-refresh lock so they collide.
+#' @noRd
+.analysis_release_preset_lock_name <- function(analysis_type, parameter_hash) {
+  if (exists("analysis_snapshot_lock_name", mode = "function")) {
+    return(analysis_snapshot_lock_name(analysis_type, parameter_hash))
+  }
+  # Byte-identical fallback for minimal/test envs where the repository file that
+  # defines analysis_snapshot_lock_name() is not sourced.
+  paste0("asr:", substr(as.character(parameter_hash[[1]]), 1, 56))
+}
+
+#' @noRd
+.analysis_release_get_lock <- function(conn, name, timeout_seconds = 5L) {
+  if (!inherits(conn, "DBIConnection")) {
+    return(FALSE)
+  }
+  tryCatch(
+    {
+      rows <- DBI::dbGetQuery(
+        conn, "SELECT GET_LOCK(?, ?) AS acquired",
+        params = unname(list(name, as.integer(timeout_seconds)))
+      )
+      isTRUE(as.integer(rows$acquired[[1]]) == 1L)
+    },
+    error = function(e) FALSE
+  )
+}
+
+#' @noRd
+.analysis_release_release_named_lock <- function(conn, name) {
+  if (!inherits(conn, "DBIConnection")) {
+    return(invisible(FALSE))
+  }
+  tryCatch(
+    DBI::dbGetQuery(
+      conn, "SELECT RELEASE_LOCK(?) AS released",
+      params = unname(list(name))
+    ),
+    error = function(e) NULL
+  )
+  invisible(TRUE)
+}
+
+#' Default `lock_acquire` seam: acquire every per-preset lock (all-or-nothing).
+#'
+#' @return `list(ok, acquired, skipped)`. On a non-DBIConnection the locks are
+#'   skipped (`ok = TRUE, skipped = TRUE`) — the test/mirai path. On a real
+#'   connection, a failed acquisition releases any partially-held locks and
+#'   returns `ok = FALSE` so the caller raises `release_lock_unavailable`.
+#' @noRd
+.analysis_release_acquire_preset_locks <- function(conn, lock_names, timeout_seconds = 5L) {
+  if (!inherits(conn, "DBIConnection")) {
+    return(list(ok = TRUE, acquired = character(0), skipped = TRUE))
+  }
+  acquired <- character(0)
+  for (lock_name in lock_names) {
+    if (.analysis_release_get_lock(conn, lock_name, timeout_seconds)) {
+      acquired <- c(acquired, lock_name)
+    } else {
+      for (held in acquired) .analysis_release_release_named_lock(conn, held)
+      return(list(ok = FALSE, acquired = character(0), skipped = FALSE))
+    }
+  }
+  list(ok = TRUE, acquired = acquired, skipped = FALSE)
+}
+
+#' Fresh pre-insert re-read: re-load each layer via the loader seam (NOT the
+#' cached step-1 `loaded`) and confirm each layer's {snapshot_id, payload_hash}
+#' and the correlation dependencies still equal the pinned lineage. Throws a
+#' classed gate error if a source snapshot changed between the first read and the
+#' insert (the real TOCTOU catch).
+#' @noRd
+.analysis_release_verify_lineage_unchanged <- function(layer_specs, loaded, loader, conn) {
+  for (spec in layer_specs) {
+    at <- spec$analysis_type
+    entry <- loaded[[at]]
+    fresh <- loader(at, spec$parameter_hash, conn = conn)
+    status_code <- if (is.null(fresh)) "snapshot_missing" else (fresh$status_code %||% "snapshot_missing")
+    if (!identical(status_code, "available")) {
+      stop(.analysis_release_condition(
+        "release_snapshot_not_available",
+        sprintf("layer %s became unavailable before insert: %s", at, status_code),
+        analysis_type = at, status_code = status_code
+      ))
+    }
+    fresh_id <- suppressWarnings(as.integer(.analysis_release_manifest_scalar(fresh$manifest, "snapshot_id")))
+    fresh_hash <- as.character(.analysis_release_manifest_scalar(fresh$manifest, "payload_hash", NA_character_))
+    if (!identical(fresh_id, suppressWarnings(as.integer(entry$snapshot_id))) ||
+      !identical(fresh_hash, entry$payload_hash)) {
+      stop(.analysis_release_condition(
+        "release_dependency_lineage_mismatch",
+        sprintf(
+          "layer %s snapshot changed between read and insert (was snapshot_id %s, now %s)",
+          at, as.character(entry$snapshot_id), as.character(fresh_id)
+        ),
+        analysis_type = at
+      ))
+    }
+    if (identical(at, "phenotype_functional_correlations") &&
+      !is.null(loaded[["functional_clusters"]]) && !is.null(loaded[["phenotype_clusters"]])) {
+      fresh_deps <- analysis_snapshot_manifest_dependencies(fresh$manifest)
+      ok <- .analysis_release_dep_matches(fresh_deps, "functional_clusters", loaded[["functional_clusters"]]) &&
+        .analysis_release_dep_matches(fresh_deps, "phenotype_clusters", loaded[["phenotype_clusters"]])
+      if (!ok) {
+        stop(.analysis_release_condition(
+          "release_dependency_lineage_mismatch",
+          "correlation dependency lineage changed between read and insert",
+          analysis_type = at
+        ))
+      }
+    }
+  }
+  invisible(TRUE)
+}
+
+# --------------------------------------------------------------------------- #
+# Orchestrator
+# --------------------------------------------------------------------------- #
+
+#' Build (and optionally publish) an immutable analysis-snapshot release.
+#'
+#' @param layers Layer registry (default `analysis_snapshot_release_layers()`).
+#' @param title,scope_statement,license Presentation metadata (excluded from the
+#'   content digest / release identity).
+#' @param publish If TRUE the inserted draft is flipped to `published`.
+#' @param created_by Optional user id recorded on the head row.
+#' @param conn A real DBIConnection (required for persistence; A5 checks one out).
+#' @param layers Optional SELECTION of layers to include (NULL = full registry);
+#'   resolved to authoritative registry entries by
+#'   `analysis_snapshot_release_resolve_layers()` (caller cannot override policy).
+#' @param loader,reproducibility_loader,coherence_assert,lock_acquire,inserter
+#'   Injectable seams (see file header); call-time defaults are the real
+#'   functions. `lock_acquire` returns `list(ok, acquired, skipped)`; `inserter`
+#'   persists the head/members/files.
+#' @return `list(release = <head>, created = TRUE|FALSE)`.
+#' @export
+analysis_snapshot_release_build <- function(layers = NULL,
+                                            title = NULL,
+                                            scope_statement = NULL,
+                                            license = "CC-BY-4.0",
+                                            publish = TRUE,
+                                            created_by = NULL,
+                                            conn = NULL,
+                                            loader = analysis_snapshot_get_public,
+                                            reproducibility_loader = analysis_snapshot_get_reproducibility,
+                                            coherence_assert = analysis_snapshot_release_assert_coherent,
+                                            lock_acquire = .analysis_release_acquire_preset_locks,
+                                            inserter = analysis_release_insert) {
+  # B1: a caller `layers` request is a SELECTION, never a policy redefinition —
+  # resolve each selector to the AUTHORITATIVE registry entry (params /
+  # files_prefix / has_reproducibility come from the registry, never the caller).
+  layers <- analysis_snapshot_release_resolve_layers(layers)
+
+  # Resolve (analysis_type, parameter_hash) per layer once (pure; validates params).
+  layer_specs <- lapply(layers, function(layer) {
+    at <- as.character(layer$analysis_type[[1]])
+    list(
+      analysis_type = at,
+      layer = layer,
+      parameter_hash = analysis_snapshot_normalize_params(at, layer$params %||% list())$parameter_hash
+    )
+  })
+
+  # --- Step 0: per-preset TOCTOU advisory locks ----------------------------
+  # Acquire the SAME per-preset lock the axis refresh holds, so a mid-flight
+  # refresh of a source preset serializes against this read. On a REAL
+  # DBIConnection a failed acquisition MUST NOT proceed unlocked (H3): it raises
+  # `release_lock_unavailable`, which the service maps to 503 + Retry-After.
+  # A non-DBI/test conn skips the lock (lock_state$skipped).
+  lock_names <- vapply(
+    layer_specs,
+    function(spec) .analysis_release_preset_lock_name(spec$analysis_type, spec$parameter_hash),
+    character(1)
+  )
+  lock_state <- lock_acquire(conn, lock_names)
+  if (length(lock_state$acquired %||% character(0)) > 0L) {
+    on.exit(
+      for (lock_name in lock_state$acquired) .analysis_release_release_named_lock(conn, lock_name),
+      add = TRUE
+    )
+  }
+  if (!isTRUE(lock_state$ok)) {
+    stop(.analysis_release_condition(
+      "release_lock_unavailable",
+      "source analysis snapshots are being refreshed; retry the release build shortly"
+    ))
+  }
+
+  # --- Step 1/1b/1c: load + gate each layer --------------------------------
+  loaded <- list()
+  for (spec in layer_specs) {
+    layer <- spec$layer
+    at <- spec$analysis_type
+    parameter_hash <- spec$parameter_hash
+
+    snapshot <- loader(at, parameter_hash, conn = conn)
+    status_code <- if (is.null(snapshot)) "snapshot_missing" else (snapshot$status_code %||% "snapshot_missing")
+    if (!identical(status_code, "available")) {
+      stop(.analysis_release_condition(
+        "release_snapshot_not_available",
+        sprintf("layer %s is not available for release: %s", at, status_code),
+        analysis_type = at, status_code = status_code
+      ))
+    }
+
+    manifest <- snapshot$manifest
+    entry <- list(
+      analysis_type = at,
+      kind = .analysis_release_layer_kind(at),
+      layer = layer,
+      snapshot = snapshot,
+      manifest = manifest,
+      snapshot_id = .analysis_release_manifest_scalar(manifest, "snapshot_id"),
+      payload_hash = as.character(.analysis_release_manifest_scalar(manifest, "payload_hash", NA_character_)),
+      input_hash = as.character(.analysis_release_manifest_scalar(manifest, "input_hash", NA_character_)),
+      schema_version = as.character(.analysis_release_manifest_scalar(manifest, "schema_version", NA_character_)),
+      source_data_version = as.character(
+        .analysis_release_manifest_scalar(manifest, "source_data_version", NA_character_)
+      ),
+      parameter_hash = parameter_hash,
+      reproducibility_hash = NULL,
+      dependencies = NULL,
+      reproducibility_bundle = NULL
+    )
+
+    if (isTRUE(layer$has_reproducibility)) {
+      # 1b: HARD coherence re-check (any failure -> release_source_incoherent).
+      tryCatch(
+        coherence_assert(snapshot, entry$kind),
+        release_source_incoherent = function(e) stop(e),
+        error = function(e) {
+          stop(.analysis_release_condition(
+            "release_source_incoherent",
+            sprintf("layer %s failed the hard coherence re-check: %s", at, conditionMessage(e)),
+            analysis_type = at
+          ))
+        }
+      )
+
+      # 1c: reproducibility bundle presence.
+      repro <- reproducibility_loader(entry$snapshot_id, conn = conn)
+      repro_hash <- .analysis_release_repro_hash(repro)
+      if (is.na(repro_hash) || !nzchar(repro_hash)) {
+        stop(.analysis_release_condition(
+          "release_reproducibility_missing",
+          sprintf("layer %s has no reproducibility bundle; the release requires one", at),
+          analysis_type = at
+        ))
+      }
+      entry$reproducibility_hash <- repro_hash
+      entry$reproducibility_bundle <- repro$bundle_gzip_json
+    }
+
+    loaded[[at]] <- entry
+  }
+
+  # --- Step 2: shared source version + correlation dependency lineage ------
+  .analysis_release_assert_lineage(loaded)
+  shared_source_version <- unique(vapply(
+    loaded, function(e) as.character(e$source_data_version), character(1)
+  ))[[1]]
+
+  # M1/M2: DB release provenance — carried on each pinned snapshot manifest.
+  # strict = TRUE: distinct non-empty values that DISAGREE across layers reject
+  # the build (release_source_version_mismatch -> 400), like source_data_version.
+  shared_db_release_version <- .analysis_release_consistent_manifest_value(loaded, "db_release_version", strict = TRUE)
+  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit", strict = TRUE)
+
+  # For the correlation layer, pin the actual dependency lineage into its entry.
+  corr <- loaded[["phenotype_functional_correlations"]]
+  if (!is.null(corr)) {
+    loaded[["phenotype_functional_correlations"]]$dependencies <-
+      analysis_snapshot_manifest_dependencies(corr$manifest)
+  }
+
+  # --- Step 3/4/5: materialize per-layer files + README, build layer_entries
+  artifacts <- list()
+  layer_entries <- list()
+
+  for (layer in layers) {
+    at <- as.character(layer$analysis_type[[1]])
+    entry <- loaded[[at]]
+    prefix <- layer$files_prefix %||% at
+
+    payload_bytes <- analysis_release_canonical_bytes(.analysis_release_layer_payload(entry$snapshot, layer))
+    artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
+      paste0(prefix, "/payload.json"), payload_bytes, "application/json"
+    )
+
+    if (isTRUE(layer$has_reproducibility)) {
+      repro_bytes <- charToRaw(analysis_reproducibility_decode_raw(entry$reproducibility_bundle))
+      # H2: the LOCKED equality `sha256(reproducibility.json) == reproducibility_hash`
+      # must HOLD, not merely be present — verify the decoded bytes hash to the
+      # stored hash (a corrupt/restored bundle whose bytes drifted from its hash
+      # is rejected, not published).
+      computed_repro_hash <- analysis_release_sha256(repro_bytes)
+      if (!identical(computed_repro_hash, entry$reproducibility_hash)) {
+        stop(.analysis_release_condition(
+          "release_reproducibility_missing",
+          sprintf(
+            "layer %s reproducibility bytes do not hash to the stored reproducibility_hash (bundle corrupt)",
+            at
+          ),
+          analysis_type = at
+        ))
+      }
+      artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
+        paste0(prefix, "/reproducibility.json"), repro_bytes, "application/json"
+      )
+    }
+
+    layer_entries[[length(layer_entries) + 1L]] <- list(
+      analysis_type = at,
+      parameter_hash = entry$parameter_hash,
+      snapshot_id = entry$snapshot_id,
+      input_hash = entry$input_hash,
+      payload_hash = entry$payload_hash,
+      schema_version = entry$schema_version,
+      reproducibility_hash = entry$reproducibility_hash,
+      dependencies = entry$dependencies
+    )
+  }
+
+  # --- Step 6: content_digest -> release_id + idempotency ------------------
+  content_digest <- analysis_release_content_digest(
+    layer_entries, shared_source_version, ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION
+  )
+  release_id <- analysis_release_id(content_digest)
+
+  if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
+    existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
+    if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
+      return(list(release = existing, created = FALSE))
+    }
+    stop(sprintf(
+      "release id %s already exists with a different content_digest (identity anomaly)",
+      release_id
+    ), call. = FALSE)
+  }
+
+  # README carries the resolved release_id now that it is known.
+  readme_bytes <- .analysis_release_readme_bytes(
+    release_id, title, scope_statement, license, shared_source_version, layer_entries
+  )
+  artifacts <- c(
+    list(.analysis_release_artifact("README.md", readme_bytes, "text/markdown")),
+    artifacts
+  )
+
+  created_at <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
+
+  # --- Step 7: manifest.json (files[] excludes manifest + checksums) -------
+  content_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256, bytes = a$byte_size))
+  manifest_obj <- analysis_release_build_manifest(list(
+    release_id = release_id,
+    release_version = NULL,
+    title = title,
+    created_at = created_at,
+    license = license %||% "CC-BY-4.0",
+    scope_statement = scope_statement,
+    generator = list(
+      name = "sysndd-analysis-snapshot-release-build",
+      manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
+      reproducibility_schema_version = if (exists("ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION")) {
+        ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION
+      } else {
+        NULL
+      }
+    ),
+    source = list(
+      source_data_version = shared_source_version,
+      db_release = list(
+        version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
+        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
+      ),
+      snapshots = lapply(layer_entries, function(e) {
+        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
+      })
+    ),
+    layers = layer_entries,
+    files = content_files,
+    content_digest = content_digest
+  ))
+  manifest_bytes <- analysis_release_canonical_bytes(manifest_obj)
+  manifest_artifact <- .analysis_release_artifact("manifest.json", manifest_bytes, "application/json")
+  manifest_sha256 <- manifest_artifact$sha256
+  artifacts[[length(artifacts) + 1L]] <- manifest_artifact
+
+  # --- Step 8: checksums.sha256 (all files incl. manifest, excl. checksums)-
+  checksum_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256))
+  checksums_bytes <- charToRaw(enc2utf8(analysis_release_checksums_text(checksum_files)))
+  artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
+    "checksums.sha256", checksums_bytes, "text/plain"
+  )
+
+  # --- Step 9: bundle.tar.gz (all files) -----------------------------------
+  named_raw <- stats::setNames(
+    lapply(artifacts, function(a) a$bytes),
+    vapply(artifacts, function(a) a$path, character(1))
+  )
+  bundle_gzip <- analysis_release_build_tar_gz(named_raw)
+  bundle_sha256 <- analysis_release_sha256(bundle_gzip)
+
+  # --- Step 2 (re-assert immediately before insert) ------------------------
+  # A FRESH DB re-read via the loader seam (not the cached `loaded`) so a source
+  # snapshot that was refreshed between the first read and now is caught. Combined
+  # with the per-preset locks above, this closes the TOCTOU window.
+  .analysis_release_assert_lineage(loaded)
+  .analysis_release_verify_lineage_unchanged(layer_specs, loaded, loader, conn)
+
+  # --- Step 10: persist ----------------------------------------------------
+  release_head <- list(
+    release_id = release_id,
+    release_version = NULL,
+    title = title,
+    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
+    content_digest = content_digest,
+    manifest_sha256 = manifest_sha256,
+    bundle_sha256 = bundle_sha256,
+    bundle_gzip = bundle_gzip,
+    source_data_version = shared_source_version,
+    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
+    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
+    scope_statement = scope_statement,
+    license = license %||% "CC-BY-4.0",
+    created_by_user_id = created_by
+  )
+
+  members <- lapply(layer_entries, function(e) {
+    list(
+      analysis_type = e$analysis_type,
+      parameter_hash = e$parameter_hash,
+      snapshot_id = e$snapshot_id,
+      input_hash = e$input_hash,
+      payload_hash = e$payload_hash,
+      schema_version = e$schema_version,
+      reproducibility_hash = e$reproducibility_hash,
+      role = "layer"
+    )
+  })
+
+  insert_files <- lapply(artifacts, function(a) {
+    list(
+      file_path = a$path,
+      content_sha256 = a$sha256,
+      byte_size = a$byte_size,
+      media_type = a$media_type,
+      content_gzip = memCompress(a$bytes, type = "gzip")
+    )
+  })
+
+  # H3(b): a concurrent identical build can win the insert race (both passed the
+  # step-6 idempotency probe). On a DB duplicate-key error, re-read by release_id:
+  # if the stored content_digest matches, this build is a no-op (idempotent 200);
+  # otherwise it is a genuine identity anomaly (re-raise -> 500).
+  insert_created <- tryCatch(
+    {
+      inserter(release_head, members, insert_files, conn)
+      TRUE
+    },
+    error = function(e) {
+      if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
+        existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
+        if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
+          return(FALSE) # idempotent: the concurrent winner stored the identical release
+        }
+      }
+      stop(e)
+    }
+  )
+
+  if (!isTRUE(insert_created)) {
+    return(list(
+      release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
+      created = FALSE
+    ))
+  }
+
+  if (isTRUE(publish)) {
+    analysis_release_publish(release_id, conn = conn)
+  }
+
+  list(
+    release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
+    created = TRUE
+  )
+}
diff --git a/api/functions/analysis-snapshot-repository.R b/api/functions/analysis-snapshot-repository.R
index 27c8fcb7..dda204a1 100644
--- a/api/functions/analysis-snapshot-repository.R
+++ b/api/functions/analysis-snapshot-repository.R
@@ -467,126 +467,84 @@ analysis_snapshot_public_exists <- function(analysis_type, parameter_hash, conn
 analysis_snapshot_public_manifest <- function(analysis_type,
                                               parameter_hash,
                                               conn = NULL,
                                               current_source_data_version = NULL) {
   manifest <- db_execute_query(
     "SELECT *
        FROM analysis_snapshot_manifest
       WHERE analysis_type = ?
         AND parameter_hash = ?
         AND public_ready = 1
         AND status = 'public_ready'
       ORDER BY activated_at DESC, snapshot_id DESC
       LIMIT 1",
     unname(list(analysis_type, parameter_hash)),
     conn = conn
   )
 
   if (nrow(manifest) == 0L) {
     return(NULL)
   }
 
   if (is.null(current_source_data_version) &&
     exists("analysis_snapshot_source_data_version", mode = "function")) {
     current_source_data_version <- tryCatch(
       analysis_snapshot_source_data_version(conn = conn),
       error = function(e) NULL
     )
   }
 
   manifest <- manifest[1, , drop = FALSE]
   if (!is.null(current_source_data_version)) {
     manifest$current_source_data_version <- as.character(current_source_data_version)[1]
   }
   manifest$status_code <- analysis_snapshot_status_code(manifest)
   manifest
 }
 
 #' Cheap "is the active public snapshot CURRENT?" probe.
 #'
 #' Unlike `analysis_snapshot_public_exists()` (which only checks that a
 #' public-ready row exists), this returns TRUE only when that row is also
 #' *current* — its computed `status_code` is `"available"`, not `snapshot_stale`
 #' or `source_version_mismatch`. Used as the skip predicate by the startup
 #' bootstrap and the non-force admin refresh so a STALE or VERSION-MISMATCHED
 #' snapshot is re-enqueued (self-heals on restart) instead of being treated as
 #' "already present" and left serving a permanent 503. The #420/#440 self-heal
 #' only covered `snapshot_missing`; a snapshot that aged past `stale_after`
 #' (default 7 days) never refreshed on its own. See AGENTS.md "Public analysis
 #' endpoints".
 #'
 #' @param manifest_fn Injectable manifest read (default
 #'   `analysis_snapshot_public_manifest`) so this is unit-testable without a DB.
 #' @return TRUE only when a public-ready snapshot exists and is current.
 #' @export
 analysis_snapshot_public_current <- function(analysis_type,
                                              parameter_hash,
                                              conn = NULL,
                                              manifest_fn = analysis_snapshot_public_manifest) {
   manifest <- tryCatch(
     manifest_fn(analysis_type, parameter_hash, conn = conn),
     error = function(e) NULL
   )
   if (is.null(manifest) ||
     (is.data.frame(manifest) && nrow(manifest) == 0L)) {
     return(FALSE)
   }
   identical(as.character(manifest$status_code)[1], "available")
 }
 
 analysis_snapshot_source_data_version <- function(conn = NULL) {
   result <- db_execute_query(
     "SELECT source_data_version
        FROM mcp_public_analysis_source_version
       LIMIT 1",
     conn = conn
   )
 
   as.character(result$source_data_version[[1]])
 }
 
-analysis_snapshot_prune <- function(analysis_type,
-                                    parameter_hash,
-                                    keep_public_ready = 3L,
-                                    keep_superseded_days = 14L,
-                                    conn = NULL) {
-  keep_public_ready <- max(1L, as.integer(keep_public_ready))
-  keep_superseded_days <- max(0L, as.integer(keep_superseded_days))
-
-  keep_rows <- db_execute_query(
-    "SELECT snapshot_id
-       FROM analysis_snapshot_manifest
-      WHERE analysis_type = ?
-        AND parameter_hash = ?
-        AND status IN ('public_ready', 'superseded')
-      ORDER BY COALESCE(activated_at, generated_at, created_at) DESC, snapshot_id DESC
-      LIMIT ?",
-    unname(list(analysis_type, parameter_hash, keep_public_ready)),
-    conn = conn
-  )
-  keep_ids <- as.numeric(keep_rows$snapshot_id %||% numeric())
-
-  cutoff_time <- as.POSIXct(Sys.time() - (keep_superseded_days * 86400), tz = "UTC")
-  cutoff <- format(cutoff_time, "%Y-%m-%d %H:%M:%OS6", tz = "UTC")
-  candidates <- db_execute_query(
-    "SELECT snapshot_id
-       FROM analysis_snapshot_manifest
-      WHERE analysis_type = ?
-        AND parameter_hash = ?
-        AND status = 'superseded'
-        AND COALESCE(superseded_at, updated_at, created_at) < ?",
-    unname(list(analysis_type, parameter_hash, cutoff)),
-    conn = conn
-  )
-
-  delete_ids <- setdiff(as.numeric(candidates$snapshot_id %||% numeric()), keep_ids)
-  if (length(delete_ids) == 0L) {
-    return(invisible(0L))
-  }
-
-  placeholders <- paste(rep("?", length(delete_ids)), collapse = ", ")
-  db_execute_statement(
-    paste0("DELETE FROM analysis_snapshot_manifest WHERE snapshot_id IN (", placeholders, ")"),
-    unname(as.list(delete_ids)),
-    conn = conn
-  )
-}
+# analysis_snapshot_prune() was extracted to
+# functions/analysis-snapshot-prune-helpers.R (#573 round-3 CI1) to keep this
+# file under the 600-line ceiling. It is sourced immediately after this file in
+# both bootstrap/load_modules.R and bootstrap/setup_workers.R.
diff --git a/api/services/analysis-snapshot-release-service.R b/api/services/analysis-snapshot-release-service.R
new file mode 100644
index 00000000..0e6bca72
--- /dev/null
+++ b/api/services/analysis-snapshot-release-service.R
@@ -0,0 +1,288 @@
+# services/analysis-snapshot-release-service.R
+#
+# Service layer for immutable, content-addressed public analysis-snapshot
+# RELEASES (#573 Slice A / Task A5). Shapes the A4 build orchestrator
+# (`functions/analysis-snapshot-release.R`) and the A3 repository
+# (`functions/analysis-snapshot-release-repository.R`) into problem+json HTTP
+# semantics for the endpoint layer (wired into `bootstrap/load_modules.R` by
+# Task A8).
+#
+# ERROR CONTRACT. Only the FOUR existing error classes exist in this repo:
+# 400 (`stop_for_bad_request`), 401, 403 (`stop_for_forbidden`, enforced by
+# the endpoint's `require_role()`, not here), and 404 (`stop_for_not_found`).
+# There is deliberately NO 409 class — a "sources not ready" build rejection
+# is a 400, not a conflict. The mounted errorHandler (`core/filters.R`)
+# serializes `conditionMessage(err)` (the classed condition's `message`) into
+# the problem+json body, NOT `detail` — so every user-facing reason is passed
+# as the `message` argument to `stop_for_*()`, never `detail`.
+#
+# BUILD MAPPING. `svc_release_build()` calls the A4 orchestrator inside a
+# `tryCatch()` that maps its five classed `release_*` conditions
+# (`release_snapshot_not_available`, `release_source_incoherent`,
+# `release_reproducibility_missing`, `release_source_version_mismatch`,
+# `release_dependency_lineage_mismatch`) to `stop_for_bad_request()`, passing
+# the ORIGINAL `conditionMessage()` through verbatim (it already names the
+# failing layer/analysis_type and the concrete reason). Any OTHER error is
+# left to propagate unmapped (falls through to the generic 500 path). A
+# DUPLICATE/idempotent build (`created = FALSE`) is NOT an error: the caller
+# gets 200 + the existing head instead of 201 + the new head.
+#
+# PUBLIC SURFACE. `svc_release_list/get/manifest/file/bundle()` are the
+# published-only public read surface: every repository call is pinned to
+# `status = "published"` / `include_draft = FALSE`, so a draft release (or an
+# unknown release id, or an unknown archive file path) is indistinguishable
+# from the caller's point of view — both resolve to a plain 404. Drafts are
+# NEVER returned publicly.
+#
+# ADMIN SURFACE. `svc_release_build/publish/set_doi/delete_draft()` are
+# admin-only from the caller's perspective (the endpoint layer is expected to
+# gate with `require_role(req, res, "Administrator")` before calling in, the
+# same pattern as the other `svc_*` admin services in this directory); this
+# file does not itself check roles.
+#
+# `svc_` prefix avoids shadowing the `analysis_release_*`/
+# `analysis_snapshot_release_build` repository/orchestrator functions in the
+# global search path (AGENTS.md service-prefix invariant).
+
+# --------------------------------------------------------------------------- #
+# Admin
+# --------------------------------------------------------------------------- #
+
+#' Build (and, by default, publish) a new analysis-snapshot release.
+#'
+#' Thin problem+json shim over `analysis_snapshot_release_build()`. On
+#' success mutates `res$status` (201 for a newly-created release, 200 for an
+#' idempotent duplicate) and returns the release head. On a gate failure
+#' (any of the five classed `release_*` conditions), raises a 400 whose
+#' message is the original `conditionMessage()` verbatim. Any other error
+#' propagates unmapped.
+#'
+#' @param res Plumber response, mutated in place (`$status`).
+#' @param layers Optional layer registry override; when `NULL` the
+#'   orchestrator's own default (`analysis_snapshot_release_layers()`) is
+#'   used — `layers` is only forwarded when the caller supplies one.
+#' @param title,scope_statement,license Presentation metadata.
+#' @param publish Whether to flip the inserted draft to `published`.
+#' @param created_by Optional user id recorded on the head row.
+#' @param conn A real DBIConnection (the orchestrator persists via A3).
+#' @return The release head (a named list).
+#' @export
+svc_release_build <- function(res,
+                               layers = NULL,
+                               title = NULL,
+                               scope_statement = NULL,
+                               license = "CC-BY-4.0",
+                               publish = TRUE,
+                               created_by = NULL,
+                               conn = NULL) {
+  build_args <- list(
+    title = title,
+    scope_statement = scope_statement,
+    license = license,
+    publish = publish,
+    created_by = created_by,
+    conn = conn
+  )
+  if (!is.null(layers)) {
+    build_args$layers <- layers
+  }
+
+  result <- tryCatch(
+    do.call(analysis_snapshot_release_build, build_args),
+    # `release_lock_unavailable` (H3): sources are mid-refresh — a transient 503
+    # with Retry-After, NOT a 400. Handled here (like the public capacity guard)
+    # via a direct res mutation because there is no 5xx classed error helper.
+    release_lock_unavailable = function(e) {
+      res$status <- 503L
+      res$setHeader("Retry-After", "5")
+      list(
+        error = "release_lock_unavailable",
+        message = conditionMessage(e)
+      )
+    },
+    release_snapshot_not_available = function(e) stop_for_bad_request(conditionMessage(e)),
+    release_source_incoherent = function(e) stop_for_bad_request(conditionMessage(e)),
+    release_reproducibility_missing = function(e) stop_for_bad_request(conditionMessage(e)),
+    release_source_version_mismatch = function(e) stop_for_bad_request(conditionMessage(e)),
+    release_dependency_lineage_mismatch = function(e) stop_for_bad_request(conditionMessage(e))
+  )
+
+  # The 503 handler already set res$status + body; return it verbatim.
+  if (!is.null(res$status) && identical(as.integer(res$status), 503L)) {
+    return(result)
+  }
+
+  res$status <- if (isTRUE(result$created)) 201L else 200L
+  result$release
+}
+
+#' Publish a draft release.
+#'
+#' Publishing an unknown release id is the only failure mode (404).
+#' Publishing an already-published release is an idempotent no-op (the
+#' repository's `analysis_release_publish()` already no-ops when the row is
+#' not currently a draft) — either way the caller gets the current head back.
+#'
+#' @param release_id Release id (`asr_<16 hex>`).
+#' @param conn A real DBIConnection.
+#' @return The (published) release head.
+#' @export
+svc_release_publish <- function(release_id, conn = NULL) {
+  analysis_release_publish(release_id, conn = conn)
+  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
+  if (is.null(head)) {
+    stop_for_not_found(sprintf("Release '%s' not found", release_id))
+  }
+  head
+}
+
+#' Record external Zenodo/DOI provenance on an existing release.
+#'
+#' Additive metadata only (forwarded verbatim to the repository, which never
+#' touches `content_digest`/`manifest_sha256` — release scientific identity
+#' is immutable once minted). Unknown release id -> 404.
+#'
+#' @param release_id Release id.
+#' @param doi_fields Named list, any subset of `zenodo_record_id`,
+#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
+#' @param conn A real DBIConnection.
+#' @return The updated release head.
+#' @export
+svc_release_set_doi <- function(release_id, doi_fields, conn = NULL) {
+  analysis_release_set_doi(release_id, doi_fields = doi_fields, conn = conn)
+  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
+  if (is.null(head)) {
+    stop_for_not_found(sprintf("Release '%s' not found", release_id))
+  }
+  head
+}
+
+#' Delete a draft release (e.g. a failed/aborted build).
+#'
+#' Unknown release id -> 404. A published release is immutable/retained
+#' indefinitely -> 400 (only drafts are deletable). A draft is deleted and
+#' `list(deleted = TRUE, release_id = release_id)` is returned.
+#'
+#' @param release_id Release id.
+#' @param conn A real DBIConnection.
+#' @return `list(deleted = TRUE, release_id = release_id)`.
+#' @export
+svc_release_delete_draft <- function(release_id, conn = NULL) {
+  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
+  if (is.null(head)) {
+    stop_for_not_found(sprintf("Release '%s' not found", release_id))
+  }
+  if (!identical(as.character(head$status), "draft")) {
+    stop_for_bad_request("Cannot delete a published release; only drafts are deletable")
+  }
+  analysis_release_delete_draft(release_id, conn = conn)
+  list(deleted = TRUE, release_id = release_id)
+}
+
+# --------------------------------------------------------------------------- #
+# Public (published-only)
+# --------------------------------------------------------------------------- #
+
+#' List published releases (newest first).
+#'
+#' `limit` is clamped to `[1, 100]` and `offset` to `>= 0` (L1: public
+#' pagination must never be unbounded or negative — this is the single source of
+#' the clamp). Each returned head is projected to the PUBLIC allowlist
+#' (`analysis_release_public_head`) so operational columns never leak.
+#'
+#' @param limit,offset Pagination (clamped).
+#' @param conn A real DBIConnection.
+#' @return A list of public-projected release-head-plus-layers entries; never
+#'   includes drafts.
+#' @export
+svc_release_list <- function(limit = 50, offset = 0, conn = NULL) {
+  limit <- svc_release_clamp_limit(limit)
+  offset <- svc_release_clamp_offset(offset)
+  rows <- analysis_release_list(status = "published", limit = limit, offset = offset, conn = conn)
+  lapply(rows, analysis_release_public_head)
+}
+
+#' Clamp a public list `limit` into `[1, 100]` (non-numeric -> default 50).
+#' @noRd
+svc_release_clamp_limit <- function(limit) {
+  value <- suppressWarnings(as.integer(limit))
+  if (length(value) == 0L || is.na(value)) {
+    value <- 50L
+  }
+  min(100L, max(1L, value))
+}
+
+#' Clamp a public list `offset` to `>= 0` (non-numeric -> 0).
+#' @noRd
+svc_release_clamp_offset <- function(offset) {
+  value <- suppressWarnings(as.integer(offset))
+  if (length(value) == 0L || is.na(value)) {
+    value <- 0L
+  }
+  max(0L, value)
+}
+
+#' Fetch one published release's head + parsed manifest.
+#'
+#' Unknown id OR a draft release -> 404 (indistinguishable to the caller;
+#' `include_draft = FALSE` makes the repository's own SQL filter the only
+#' source of truth for visibility).
+#'
+#' @param release_id Release id.
+#' @param conn A real DBIConnection.
+#' @return The release head (+ `$manifest`).
+#' @export
+svc_release_get <- function(release_id, conn = NULL) {
+  head <- analysis_release_get(release_id, include_draft = FALSE, conn = conn)
+  if (is.null(head)) {
+    stop_for_not_found("Release not found")
+  }
+  analysis_release_public_head(head)
+}
+
+#' Fetch a published release's stored `manifest.json` file.
+#'
+#' @param release_id Release id.
+#' @param conn A real DBIConnection.
+#' @return `list(bytes, media_type = "application/json", content_sha256)`.
+#' @export
+svc_release_manifest <- function(release_id, conn = NULL) {
+  file <- analysis_release_get_file(release_id, "manifest.json", include_draft = FALSE, conn = conn)
+  if (is.null(file)) {
+    stop_for_not_found("Release not found")
+  }
+  list(bytes = file$bytes, media_type = "application/json", content_sha256 = file$content_sha256)
+}
+
+#' Fetch one archive file's bytes from a published release by exact path.
+#'
+#' Unknown release, a draft release, or an unknown `file_path` all resolve to
+#' the same 404 (never distinguished for the caller).
+#'
+#' @param release_id Release id.
+#' @param file_path Exact archive-relative path (e.g. `"README.md"`,
+#'   `"functional_clusters/payload.json"`).
+#' @param conn A real DBIConnection.
+#' @return `list(bytes, media_type, content_sha256)`.
+#' @export
+svc_release_file <- function(release_id, file_path, conn = NULL) {
+  file <- analysis_release_get_file(release_id, file_path, include_draft = FALSE, conn = conn)
+  if (is.null(file)) {
+    stop_for_not_found(sprintf("Release file not found: %s", file_path))
+  }
+  list(bytes = file$bytes, media_type = file$media_type, content_sha256 = file$content_sha256)
+}
+
+#' Fetch a published release's whole archive (`bundle.tar.gz`) verbatim.
+#'
+#' @param release_id Release id.
+#' @param conn A real DBIConnection.
+#' @return `list(bytes, sha256, filename)`.
+#' @export
+svc_release_bundle <- function(release_id, conn = NULL) {
+  bundle <- analysis_release_get_bundle(release_id, include_draft = FALSE, conn = conn)
+  if (is.null(bundle)) {
+    stop_for_not_found("Release not found")
+  }
+  list(bytes = bundle$bytes, sha256 = bundle$sha256, filename = bundle$filename)
+}
diff --git a/db/migrations/045_add_analysis_snapshot_release.sql b/db/migrations/045_add_analysis_snapshot_release.sql
new file mode 100644
index 00000000..1dfd8cfb
--- /dev/null
+++ b/db/migrations/045_add_analysis_snapshot_release.sql
@@ -0,0 +1,69 @@
+-- Migration: 045_add_analysis_snapshot_release
+-- Description: Immutable, content-addressed public analysis-snapshot releases (#573).
+--   A release freezes canonical-JSON copies of the active coherent public snapshots
+--   (functional/phenotype clusters + phenotype-functional correlation) with per-file
+--   SHA-256 checksums and dependency lineage. Retained indefinitely; a later refresh
+--   mints a NEW release. DOI columns are additive external provenance.
+
+CREATE TABLE IF NOT EXISTS `analysis_snapshot_release` (
+  `release_id` VARCHAR(64) NOT NULL,
+  `release_version` VARCHAR(32) DEFAULT NULL,
+  `title` VARCHAR(255) DEFAULT NULL,
+  `status` ENUM('draft','published') NOT NULL DEFAULT 'draft',
+  `manifest_schema_version` VARCHAR(16) NOT NULL,
+  `content_digest` CHAR(64) NOT NULL,
+  `manifest_sha256` CHAR(64) NOT NULL,
+  `bundle_sha256` CHAR(64) NOT NULL,
+  `bundle_gzip` LONGBLOB NOT NULL,
+  `bundle_bytes` BIGINT NOT NULL,
+  `source_data_version` VARCHAR(128) DEFAULT NULL,
+  `db_release_version` VARCHAR(64) DEFAULT NULL,
+  `db_release_commit` VARCHAR(64) DEFAULT NULL,
+  `scope_statement` TEXT DEFAULT NULL,
+  `license` VARCHAR(64) NOT NULL DEFAULT 'CC-BY-4.0',
+  `file_count` INT NOT NULL DEFAULT 0,
+  `total_bytes` BIGINT NOT NULL DEFAULT 0,
+  `created_by_user_id` INT DEFAULT NULL,
+  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
+  `published_at` DATETIME(6) DEFAULT NULL,
+  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
+  `zenodo_record_id` VARCHAR(32) DEFAULT NULL,
+  `zenodo_record_url` VARCHAR(255) DEFAULT NULL,
+  `version_doi` VARCHAR(128) DEFAULT NULL,
+  `concept_doi` VARCHAR(128) DEFAULT NULL,
+  `last_error_message` TEXT DEFAULT NULL,
+  PRIMARY KEY (`release_id`),
+  KEY `idx_asr_status_created` (`status`, `created_at`),
+  KEY `idx_asr_content_digest` (`content_digest`),
+  CONSTRAINT `fk_asr_created_by`
+    FOREIGN KEY (`created_by_user_id`) REFERENCES `user` (`user_id`) ON DELETE SET NULL
+) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
+
+CREATE TABLE IF NOT EXISTS `analysis_snapshot_release_member` (
+  `release_id` VARCHAR(64) NOT NULL,
+  `analysis_type` VARCHAR(64) NOT NULL,
+  `parameter_hash` CHAR(64) NOT NULL,
+  `snapshot_id` BIGINT NOT NULL,
+  `input_hash` CHAR(64) NOT NULL,
+  `payload_hash` CHAR(64) NOT NULL,
+  `schema_version` VARCHAR(16) NOT NULL,
+  `reproducibility_hash` CHAR(64) DEFAULT NULL,
+  `role` ENUM('layer','dependency') NOT NULL DEFAULT 'layer',
+  PRIMARY KEY (`release_id`, `analysis_type`, `parameter_hash`),
+  KEY `idx_asrm_snapshot` (`snapshot_id`),
+  CONSTRAINT `fk_asrm_release`
+    FOREIGN KEY (`release_id`) REFERENCES `analysis_snapshot_release` (`release_id`) ON DELETE CASCADE
+) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
+
+CREATE TABLE IF NOT EXISTS `analysis_snapshot_release_file` (
+  `release_id` VARCHAR(64) NOT NULL,
+  `file_path` VARCHAR(255) NOT NULL,
+  `content_sha256` CHAR(64) NOT NULL,
+  `byte_size` INT NOT NULL,
+  `media_type` VARCHAR(64) NOT NULL DEFAULT 'application/json',
+  `content_gzip` LONGBLOB NOT NULL,
+  PRIMARY KEY (`release_id`, `file_path`),
+  KEY `idx_asrf_sha256` (`content_sha256`),
+  CONSTRAINT `fk_asrf_release`
+    FOREIGN KEY (`release_id`) REFERENCES `analysis_snapshot_release` (`release_id`) ON DELETE CASCADE
+) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

exec
/bin/bash -lc "sed -n '1,180p' api/functions/analysis-snapshot-prune-helpers.R && rg -n -C 3 'analysis-snapshot-prune-helpers|analysis_snapshot_prune|analysis_release_referenced_snapshot_ids' api/bootstrap api/functions api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R && git show 67cf6003:api/functions/analysis-snapshot-repository.R | wc -l && git show 67cf6003:api/functions/analysis-snapshot-repository.R | sed -n '480,620p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
# functions/analysis-snapshot-prune-helpers.R
#
# Retention / prune helper for public analysis-snapshot manifests. Extracted from
# `analysis-snapshot-repository.R` (#573 round-3 CI1) to keep that file under the
# 600-line ceiling; the logic is unchanged.
#
# `analysis_snapshot_prune()` keeps the newest `keep_public_ready`
# public_ready/superseded rows and deletes superseded rows older than
# `keep_superseded_days` — but NEVER deletes a snapshot a #573 release still
# references (its live reproducibility endpoint would then 503). The
# release-reference lookup (`analysis_release_referenced_snapshot_ids`) is
# `exists()`-guarded for mirai-pool parity: on the legacy mirai worker the release
# repository file is not sourced, so the guard degrades to "no release references"
# (the pre-existing behavior) rather than erroring.
#
# Registered in both `bootstrap/load_modules.R` (API + durable worker + MCP) and
# `bootstrap/setup_workers.R` (mirai `everywhere()`), immediately after
# `analysis-snapshot-repository.R`, because the snapshot builder calls this during
# a refresh on either execution path.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

analysis_snapshot_prune <- function(analysis_type,
                                    parameter_hash,
                                    keep_public_ready = 3L,
                                    keep_superseded_days = 14L,
                                    conn = NULL) {
  keep_public_ready <- max(1L, as.integer(keep_public_ready))
  keep_superseded_days <- max(0L, as.integer(keep_superseded_days))

  keep_rows <- db_execute_query(
    "SELECT snapshot_id
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND status IN ('public_ready', 'superseded')
      ORDER BY COALESCE(activated_at, generated_at, created_at) DESC, snapshot_id DESC
      LIMIT ?",
    unname(list(analysis_type, parameter_hash, keep_public_ready)),
    conn = conn
  )
  keep_ids <- as.numeric(keep_rows$snapshot_id %||% numeric())

  cutoff_time <- as.POSIXct(Sys.time() - (keep_superseded_days * 86400), tz = "UTC")
  cutoff <- format(cutoff_time, "%Y-%m-%d %H:%M:%OS6", tz = "UTC")
  candidates <- db_execute_query(
    "SELECT snapshot_id
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND status = 'superseded'
        AND COALESCE(superseded_at, updated_at, created_at) < ?",
    unname(list(analysis_type, parameter_hash, cutoff)),
    conn = conn
  )

  # Never prune a snapshot a release (#573) still references (its LIVE
  # reproducibility endpoint would 503). analysis_release_referenced_snapshot_ids()
  # is the single source of truth for this -- do not inline a NOT IN subquery.
  # exists()-guarded for mirai-pool parity (the release repository file is not
  # sourced on the legacy mirai worker), mirroring the lock-name guard.
  referenced_ids <- if (exists("analysis_release_referenced_snapshot_ids", mode = "function")) {
    as.numeric(analysis_release_referenced_snapshot_ids(conn = conn))
  } else {
    numeric()
  }

  delete_ids <- setdiff(as.numeric(candidates$snapshot_id %||% numeric()), union(keep_ids, referenced_ids))
  if (length(delete_ids) == 0L) {
    return(invisible(0L))
  }

  placeholders <- paste(rep("?", length(delete_ids)), collapse = ", ")
  db_execute_statement(
    paste0("DELETE FROM analysis_snapshot_manifest WHERE snapshot_id IN (", placeholders, ")"),
    unname(as.list(delete_ids)),
    conn = conn
  )
}
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-1-# tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-2-#
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-3-# Integration test for the #573 Slice A / Task A8 prune-protection guard:
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:4:# analysis_snapshot_prune() (functions/analysis-snapshot-repository.R) must
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-5-# never delete a superseded snapshot manifest row that a published/draft
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-6-# analysis-snapshot RELEASE still references via
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-7-# analysis_snapshot_release_member.snapshot_id. A release freezes its own
--
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-14-# Against the real test database (sysndd_db_test). Seeds the minimal public
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-15-# analysis-snapshot manifest schema (migration 024) and the release schema
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-16-# (migration 045) via the ensure_test_*_schema() helpers in helper-db.R, then
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:17:# exercises analysis_snapshot_prune() on a single plain (non-transactional)
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-18-# connection -- mirroring test-integration-analysis-snapshot-release-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-19-# repository.R's pattern. The release/member row is created via the real,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-20-# already-tested analysis_release_insert() repository function (A3) rather
--
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-31-source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-32-source(file.path("functions", "analysis-snapshot-release-repository.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-33-source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:34:source(file.path("functions", "analysis-snapshot-prune-helpers.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-35-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-36-# Test-only ids namespaced so a rerun only ever touches its own rows.
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-37-PRUNE_TEST_ANALYSIS_TYPE <- "functional_clusters"
--
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-107-  invisible(TRUE)
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-108-}
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-109-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:110:test_that("analysis_snapshot_prune never deletes a snapshot a release still references", {
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-111-  skip_if_no_test_db()
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-112-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-113-  schema_conn <- get_test_db_connection()
--
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-145-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-146-  .insert_prune_test_release_row(conn, referenced_id)
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-147-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:148:  analysis_snapshot_prune(
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-149-    PRUNE_TEST_ANALYSIS_TYPE, PRUNE_TEST_PARAMETER_HASH,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-150-    keep_public_ready = 1L, keep_superseded_days = 14L,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-151-    conn = conn
--
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-169-  expect_false(unreferenced_id %in% surviving_ids)
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-170-})
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-171-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:172:test_that("analysis_snapshot_prune still prunes normally with NO release rows at all (empty release_member table for this snapshot)", {
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-173-  # Regression guard for the reuse-the-repository-helper fix: with zero
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-174-  # releases referencing anything -- the state right after migration 045
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-175-  # lands and before any release has ever been built, i.e. the majority
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:176:  # production state -- analysis_release_referenced_snapshot_ids() returns
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-177-  # an empty set and pruning must behave exactly as it did before the #573
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-178-  # guard existed: an old, unreferenced superseded snapshot is still pruned.
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-179-  skip_if_no_test_db()
--
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-209-  # No analysis_release_insert() call here: this snapshot's id is never
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-210-  # written to analysis_snapshot_release_member.
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-211-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:212:  analysis_snapshot_prune(
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-213-    PRUNE_TEST_NO_RELEASE_ANALYSIS_TYPE, PRUNE_TEST_NO_RELEASE_PARAMETER_HASH,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-214-    keep_public_ready = 1L, keep_superseded_days = 14L,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-215-    conn = conn
--
api/bootstrap/setup_workers.R-126-    source("/app/functions/async-job-network-layout-handlers.R", local = FALSE)
api/bootstrap/setup_workers.R-127-    source("/app/functions/analysis-snapshot-presets.R", local = FALSE)
api/bootstrap/setup_workers.R-128-    source("/app/functions/analysis-snapshot-repository.R", local = FALSE)
api/bootstrap/setup_workers.R:129:    source("/app/functions/analysis-snapshot-prune-helpers.R", local = FALSE)
api/bootstrap/setup_workers.R-130-    source("/app/functions/analysis-snapshot-dependencies.R", local = FALSE)
api/bootstrap/setup_workers.R-131-    source("/app/functions/analysis-snapshot-builder.R", local = FALSE)
api/bootstrap/setup_workers.R-132-    source("/app/functions/analysis-reproducibility.R", local = FALSE)
--
api/bootstrap/load_modules.R-70-    "functions/auth-endpoint-throttle.R",
api/bootstrap/load_modules.R-71-    "functions/analysis-snapshot-presets.R",
api/bootstrap/load_modules.R-72-    "functions/analysis-snapshot-repository.R",
api/bootstrap/load_modules.R:73:    "functions/analysis-snapshot-prune-helpers.R",
api/bootstrap/load_modules.R-74-    "functions/analysis-snapshot-coherence.R",
api/bootstrap/load_modules.R-75-    "functions/analysis-snapshot-dependencies.R",
api/bootstrap/load_modules.R-76-    "functions/analysis-snapshot-builder.R",
--
api/functions/analysis-snapshot-release-repository.R-412-#' guard uses this to never delete a snapshot a release still points to).
api/functions/analysis-snapshot-release-repository.R-413-#' @return integer vector (possibly empty).
api/functions/analysis-snapshot-release-repository.R-414-#' @export
api/functions/analysis-snapshot-release-repository.R:415:analysis_release_referenced_snapshot_ids <- function(conn) {
api/functions/analysis-snapshot-release-repository.R-416-  rows <- DBI::dbGetQuery(
api/functions/analysis-snapshot-release-repository.R-417-    conn,
api/functions/analysis-snapshot-release-repository.R-418-    "SELECT DISTINCT snapshot_id FROM analysis_snapshot_release_member"
--
api/functions/analysis-snapshot-builder.R-571-        conn = txn_conn,
api/functions/analysis-snapshot-builder.R-572-        use_transaction = FALSE
api/functions/analysis-snapshot-builder.R-573-      )
api/functions/analysis-snapshot-builder.R:574:      pruned <- analysis_snapshot_prune(normalized$analysis_type, normalized$parameter_hash, conn = txn_conn)
api/functions/analysis-snapshot-builder.R-575-
api/functions/analysis-snapshot-builder.R-576-      list(snapshot_id = snapshot_id, pruned = pruned)
api/functions/analysis-snapshot-builder.R-577-    })
--
api/functions/analysis-snapshot-repository.R-544-  as.character(result$source_data_version[[1]])
api/functions/analysis-snapshot-repository.R-545-}
api/functions/analysis-snapshot-repository.R-546-
api/functions/analysis-snapshot-repository.R:547:# analysis_snapshot_prune() was extracted to
api/functions/analysis-snapshot-repository.R:548:# functions/analysis-snapshot-prune-helpers.R (#573 round-3 CI1) to keep this
api/functions/analysis-snapshot-repository.R-549-# file under the 600-line ceiling. It is sourced immediately after this file in
api/functions/analysis-snapshot-repository.R-550-# both bootstrap/load_modules.R and bootstrap/setup_workers.R.
--
api/functions/analysis-snapshot-prune-helpers.R:1:# functions/analysis-snapshot-prune-helpers.R
api/functions/analysis-snapshot-prune-helpers.R-2-#
api/functions/analysis-snapshot-prune-helpers.R-3-# Retention / prune helper for public analysis-snapshot manifests. Extracted from
api/functions/analysis-snapshot-prune-helpers.R-4-# `analysis-snapshot-repository.R` (#573 round-3 CI1) to keep that file under the
api/functions/analysis-snapshot-prune-helpers.R-5-# 600-line ceiling; the logic is unchanged.
api/functions/analysis-snapshot-prune-helpers.R-6-#
api/functions/analysis-snapshot-prune-helpers.R:7:# `analysis_snapshot_prune()` keeps the newest `keep_public_ready`
api/functions/analysis-snapshot-prune-helpers.R-8-# public_ready/superseded rows and deletes superseded rows older than
api/functions/analysis-snapshot-prune-helpers.R-9-# `keep_superseded_days` — but NEVER deletes a snapshot a #573 release still
api/functions/analysis-snapshot-prune-helpers.R-10-# references (its live reproducibility endpoint would then 503). The
api/functions/analysis-snapshot-prune-helpers.R:11:# release-reference lookup (`analysis_release_referenced_snapshot_ids`) is
api/functions/analysis-snapshot-prune-helpers.R-12-# `exists()`-guarded for mirai-pool parity: on the legacy mirai worker the release
api/functions/analysis-snapshot-prune-helpers.R-13-# repository file is not sourced, so the guard degrades to "no release references"
api/functions/analysis-snapshot-prune-helpers.R-14-# (the pre-existing behavior) rather than erroring.
--
api/functions/analysis-snapshot-prune-helpers.R-22-  `%||%` <- function(x, y) if (is.null(x)) y else x
api/functions/analysis-snapshot-prune-helpers.R-23-}
api/functions/analysis-snapshot-prune-helpers.R-24-
api/functions/analysis-snapshot-prune-helpers.R:25:analysis_snapshot_prune <- function(analysis_type,
api/functions/analysis-snapshot-prune-helpers.R-26-                                    parameter_hash,
api/functions/analysis-snapshot-prune-helpers.R-27-                                    keep_public_ready = 3L,
api/functions/analysis-snapshot-prune-helpers.R-28-                                    keep_superseded_days = 14L,
--
api/functions/analysis-snapshot-prune-helpers.R-57-  )
api/functions/analysis-snapshot-prune-helpers.R-58-
api/functions/analysis-snapshot-prune-helpers.R-59-  # Never prune a snapshot a release (#573) still references (its LIVE
api/functions/analysis-snapshot-prune-helpers.R:60:  # reproducibility endpoint would 503). analysis_release_referenced_snapshot_ids()
api/functions/analysis-snapshot-prune-helpers.R-61-  # is the single source of truth for this -- do not inline a NOT IN subquery.
api/functions/analysis-snapshot-prune-helpers.R-62-  # exists()-guarded for mirai-pool parity (the release repository file is not
api/functions/analysis-snapshot-prune-helpers.R-63-  # sourced on the legacy mirai worker), mirroring the lock-name guard.
api/functions/analysis-snapshot-prune-helpers.R:64:  referenced_ids <- if (exists("analysis_release_referenced_snapshot_ids", mode = "function")) {
api/functions/analysis-snapshot-prune-helpers.R:65:    as.numeric(analysis_release_referenced_snapshot_ids(conn = conn))
api/functions/analysis-snapshot-prune-helpers.R-66-  } else {
api/functions/analysis-snapshot-prune-helpers.R-67-    numeric()
api/functions/analysis-snapshot-prune-helpers.R-68-  }
592
    unname(list(analysis_type, parameter_hash)),
    conn = conn
  )

  if (nrow(manifest) == 0L) {
    return(NULL)
  }

  if (is.null(current_source_data_version) &&
    exists("analysis_snapshot_source_data_version", mode = "function")) {
    current_source_data_version <- tryCatch(
      analysis_snapshot_source_data_version(conn = conn),
      error = function(e) NULL
    )
  }

  manifest <- manifest[1, , drop = FALSE]
  if (!is.null(current_source_data_version)) {
    manifest$current_source_data_version <- as.character(current_source_data_version)[1]
  }
  manifest$status_code <- analysis_snapshot_status_code(manifest)
  manifest
}

#' Cheap "is the active public snapshot CURRENT?" probe.
#'
#' Unlike `analysis_snapshot_public_exists()` (which only checks that a
#' public-ready row exists), this returns TRUE only when that row is also
#' *current* — its computed `status_code` is `"available"`, not `snapshot_stale`
#' or `source_version_mismatch`. Used as the skip predicate by the startup
#' bootstrap and the non-force admin refresh so a STALE or VERSION-MISMATCHED
#' snapshot is re-enqueued (self-heals on restart) instead of being treated as
#' "already present" and left serving a permanent 503. The #420/#440 self-heal
#' only covered `snapshot_missing`; a snapshot that aged past `stale_after`
#' (default 7 days) never refreshed on its own. See AGENTS.md "Public analysis
#' endpoints".
#'
#' @param manifest_fn Injectable manifest read (default
#'   `analysis_snapshot_public_manifest`) so this is unit-testable without a DB.
#' @return TRUE only when a public-ready snapshot exists and is current.
#' @export
analysis_snapshot_public_current <- function(analysis_type,
                                             parameter_hash,
                                             conn = NULL,
                                             manifest_fn = analysis_snapshot_public_manifest) {
  manifest <- tryCatch(
    manifest_fn(analysis_type, parameter_hash, conn = conn),
    error = function(e) NULL
  )
  if (is.null(manifest) ||
    (is.data.frame(manifest) && nrow(manifest) == 0L)) {
    return(FALSE)
  }
  identical(as.character(manifest$status_code)[1], "available")
}

analysis_snapshot_source_data_version <- function(conn = NULL) {
  result <- db_execute_query(
    "SELECT source_data_version
       FROM mcp_public_analysis_source_version
      LIMIT 1",
    conn = conn
  )

  as.character(result$source_data_version[[1]])
}

analysis_snapshot_prune <- function(analysis_type,
                                    parameter_hash,
                                    keep_public_ready = 3L,
                                    keep_superseded_days = 14L,
                                    conn = NULL) {
  keep_public_ready <- max(1L, as.integer(keep_public_ready))
  keep_superseded_days <- max(0L, as.integer(keep_superseded_days))

  keep_rows <- db_execute_query(
    "SELECT snapshot_id
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND status IN ('public_ready', 'superseded')
      ORDER BY COALESCE(activated_at, generated_at, created_at) DESC, snapshot_id DESC
      LIMIT ?",
    unname(list(analysis_type, parameter_hash, keep_public_ready)),
    conn = conn
  )
  keep_ids <- as.numeric(keep_rows$snapshot_id %||% numeric())

  cutoff_time <- as.POSIXct(Sys.time() - (keep_superseded_days * 86400), tz = "UTC")
  cutoff <- format(cutoff_time, "%Y-%m-%d %H:%M:%OS6", tz = "UTC")
  candidates <- db_execute_query(
    "SELECT snapshot_id
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND status = 'superseded'
        AND COALESCE(superseded_at, updated_at, created_at) < ?",
    unname(list(analysis_type, parameter_hash, cutoff)),
    conn = conn
  )

  delete_ids <- setdiff(as.numeric(candidates$snapshot_id %||% numeric()), keep_ids)
  if (length(delete_ids) == 0L) {
    return(invisible(0L))
  }

  placeholders <- paste(rep("?", length(delete_ids)), collapse = ", ")
  db_execute_statement(
    paste0("DELETE FROM analysis_snapshot_manifest WHERE snapshot_id IN (", placeholders, ")"),
    unname(as.list(delete_ids)),
    conn = conn
  )
}

exec
/bin/bash -lc "sed -n '1,260p' api/functions/analysis-snapshot-coherence.R && sed -n '1,460p' api/functions/analysis-snapshot-release-materialize.R && sed -n '1,620p' api/functions/analysis-snapshot-release.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
# functions/analysis-snapshot-coherence.R
#
# Snapshot partition-coherence gate (#514).
#
# The clustering snapshot builder derives the SERVED membership from the memoised
# clustering function and the VALIDATION (per-cluster stability + partition metrics)
# from a separate, un-memoised validator. They are coherent-by-construction only when
# both ran the identical seeded clustering on the identical graph. A stale memoise
# disk-cache hit (fixed by the #514 fingerprint) broke that assumption in production:
# the served membership was the pre-#510 text-mining partition while the validation was
# the fresh exp+db partition, and the integer-keyed join then left real clusters with
# `n/a` stability.
#
# This module is the defense-in-depth: BEFORE the builder joins validation onto
# membership, assert that the two describe the SAME partition — the visible membership
# cluster set must equal the validation cluster set, and (functional axis) the channel
# the membership was clustered on must match the channel the validator used. On a
# mismatch the refresh throws, so the prior public-ready snapshot is retained and the
# new one is recorded as failed (observable) rather than published incoherent.
#
# `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE` (default "true") gates the hard failure; set it
# to "false" to downgrade to a warning as an operability escape hatch.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

.analysis_snapshot_require_coherence <- function() {
  val <- tolower(trimws(Sys.getenv("ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE", "true")))
  val %in% c("true", "1", "yes", "on")
}

#' Assert that a served membership and its validation describe the same partition.
#'
#' @param membership tibble with an integer `cluster` column (the served visible
#'   clusters, already filtered to >= min_size by the clustering function).
#' @param per_cluster the validator's per-cluster tibble with a `cluster_id` column.
#' @param kind "functional" or "phenotype" (for messages only).
#' @param membership_channel,validation_channel optional channel labels; when both are
#'   supplied they must be identical (functional axis coherence).
#' @param membership_members,validation_members optional named lists (cluster_id ->
#'   member-id character vector) for the served membership and the validated reference
#'   partition. When both are supplied, each shared cluster_id must have the SAME member
#'   set — this proves the two describe the same partition, not merely the same labels
#'   (guards against a stale membership whose cluster-id set happens to coincide).
#' @param require_coherence logical; NULL resolves from
#'   `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE`.
#' @return invisibly, a list(coherent, problems, missing_scores, orphan_scores).
#'   Throws (or warns, per the escape hatch) when incoherent.
#' @export
analysis_snapshot_assert_partition_coherent <- function(membership, per_cluster, kind,
                                                        membership_channel = NULL,
                                                        validation_channel = NULL,
                                                        membership_members = NULL,
                                                        validation_members = NULL,
                                                        require_coherence = NULL) {
  if (is.null(require_coherence)) require_coherence <- .analysis_snapshot_require_coherence()

  membership_ids <- if (is.null(membership) || !("cluster" %in% names(membership))) {
    character(0)
  } else {
    as.character(membership$cluster)
  }
  validation_ids <- if (is.null(per_cluster) || !("cluster_id" %in% names(per_cluster))) {
    character(0)
  } else {
    as.character(per_cluster$cluster_id)
  }

  missing_scores <- setdiff(membership_ids, validation_ids) # served clusters with no stability row
  orphan_scores <- setdiff(validation_ids, membership_ids) # validation clusters not served
  channel_mismatch <- !is.null(membership_channel) && !is.null(validation_channel) &&
    !identical(as.character(membership_channel), as.character(validation_channel))

  problems <- character(0)
  if (length(missing_scores)) {
    problems <- c(problems, sprintf(
      "%d visible %s cluster(s) have no validation/stability score (ids: %s)",
      length(missing_scores), kind, paste(missing_scores, collapse = ", ")
    ))
  }
  if (length(orphan_scores)) {
    problems <- c(problems, sprintf(
      "%d validation %s cluster(s) are not in the served membership (ids: %s)",
      length(orphan_scores), kind, paste(orphan_scores, collapse = ", ")
    ))
  }
  if (channel_mismatch) {
    problems <- c(problems, sprintf(
      "%s membership channel (%s) disagrees with the validation channel (%s)",
      kind, membership_channel, validation_channel
    ))
  }

  # Same-partition proof (not just same labels): for every shared cluster_id the
  # served membership and the validated reference partition must contain the SAME
  # member set. Catches a stale membership whose cluster-id labels coincide with the
  # fresh validation but whose contents differ.
  if (!is.null(membership_members) && !is.null(validation_members)) {
    shared <- intersect(names(membership_members), names(validation_members))
    content_mismatch <- character(0)
    for (cid in shared) {
      a <- unique(as.character(membership_members[[cid]]))
      b <- unique(as.character(validation_members[[cid]]))
      if (!setequal(a, b)) content_mismatch <- c(content_mismatch, cid)
    }
    if (length(content_mismatch)) {
      problems <- c(problems, sprintf(
        "%d %s cluster(s) have membership content that differs from the validated partition (ids: %s)",
        length(content_mismatch), kind, paste(content_mismatch, collapse = ", ")
      ))
    }
  }

  coherent <- length(problems) == 0L
  if (!coherent) {
    msg <- sprintf(
      paste0(
        "Incoherent %s partition snapshot: membership and validation describe ",
        "different partitions: %s. Refusing to publish (#514)."
      ),
      kind, paste(problems, collapse = "; ")
    )
    if (require_coherence) {
      stop(msg, call. = FALSE)
    } else {
      warning(msg, call. = FALSE)
    }
  }

  invisible(list(
    coherent = coherent,
    problems = problems,
    missing_scores = missing_scores,
    orphan_scores = orphan_scores
  ))
}

#' Partition-independent STRING_id -> {hgnc_id...} dictionary from served identifiers.
#'
#' Each served membership identifier row carries the fixed (STRING_id, hgnc_id)
#' gene pairing (from the STRING id table join); this pairing is a property of the
#' gene set, NOT of the partition, so it is reliable even for a stale membership.
#' One STRING protein can join MULTIPLE hgnc records (`non_alt_loci_set` has no
#' STRING_id uniqueness), and the served cluster_members then contain ALL of those
#' hgnc ids — so this returns a named LIST mapping each STRING_id to the SET of all
#' its hgnc_ids (MC1: a first-wins scalar dict would drop the others and
#' false-reject a coherent snapshot).
#' @return named list: STRING_id -> character vector of hgnc_ids.
#' @noRd
.analysis_snapshot_string_to_hgnc_dict <- function(membership) {
  if (is.null(membership) || !("identifiers" %in% names(membership))) {
    return(list())
  }
  pairs <- lapply(membership$identifiers, function(df) {
    if (is.data.frame(df) && all(c("STRING_id", "hgnc_id") %in% names(df))) {
      data.frame(
        STRING_id = as.character(df$STRING_id),
        hgnc_id = as.character(df$hgnc_id),
        stringsAsFactors = FALSE
      )
    } else {
      NULL
    }
  })
  pairs <- pairs[!vapply(pairs, is.null, logical(1))]
  if (length(pairs) == 0L) {
    return(list())
  }
  pairs <- do.call(rbind, pairs)
  pairs <- pairs[!is.na(pairs$STRING_id) & !is.na(pairs$hgnc_id), , drop = FALSE]
  if (nrow(pairs) == 0L) {
    return(list())
  }
  lapply(split(pairs$hgnc_id, pairs$STRING_id), function(h) unique(as.character(h)))
}

#' Express the validator's reference member sets in the STORED cluster_member id
#' space so a RELEASE can independently verify member-set coherence (#573 H4).
#'
#' The stored `analysis_snapshot_cluster_member` table keeps `hgnc_id` (functional)
#' or `entity_id` (phenotype). The validator's `reference_members` are STRING
#' protein ids (functional) / entity ids (phenotype). This maps them into the
#' stored space: phenotype is already entity_id; functional STRING_ids are mapped
#' to hgnc_id via the partition-independent gene dictionary, and any UNMAPPED
#' STRING_id is kept verbatim (fail-closed — it cannot equal a stored hgnc_id, so
#' an incoherent membership is never silently masked).
#'
#' @return A named list keyed by cluster_id (string) -> member-id character vector.
#' @noRd
analysis_snapshot_reference_members_store_space <- function(reference_members, membership, kind) {
  reference_members <- reference_members %||% list()
  if (length(reference_members) == 0L) {
    return(list())
  }
  if (identical(kind, "phenotype")) {
    return(lapply(reference_members, function(ids) unique(as.character(ids))))
  }
  dict <- .analysis_snapshot_string_to_hgnc_dict(membership)
  lapply(reference_members, function(sids) {
    sids <- as.character(sids)
    # Expand each STRING_id to the SET (union) of all its hgnc_ids so the mapped
    # reference set equals the served cluster_members set; an UNMAPPED STRING_id is
    # kept verbatim (fail-closed — it cannot equal a stored hgnc_id).
    mapped <- unlist(lapply(sids, function(s) {
      hg <- dict[[s]]
      if (is.null(hg) || length(hg) == 0L) s else hg
    }), use.names = FALSE)
    unique(as.character(mapped))
  })
}

#' Attach the additive partition provenance the join computed onto `partition`.
#'
#' Copies the served membership channel (#514, functional only — NA on the
#' phenotype axis is not stored) and the H4 reference member-set attestation
#' (#573, both axes) from the joined-tibble attributes onto `val$partition`, which
#' the builder persists into `validation_json`. `partition_validation` is excluded
#' from `payload_hash`, so this never churns `cluster_hash`.
#' @export
analysis_snapshot_attach_partition_provenance <- function(partition, joined) {
  channel <- attr(joined, "membership_weight_channel")
  if (!is.null(channel) && !all(is.na(channel))) {
    partition$membership_weight_channel <- channel
  }
  partition$reference_members <- attr(joined, "reference_members_store_space")
  partition
}

#' Gate then join the validator's per-cluster scores onto the served membership.
#'
#' Single choke-point for the builder's two clustering presets: it asserts partition
#' coherence FIRST (so an incoherent snapshot can never be published), then performs the
#' `cluster` <-> `cluster_id` left-join, and carries the served membership channel as a
#' `membership_weight_channel` attribute for additive provenance.
#'
#' @param membership tibble from the memoised clustering function (integer `cluster`,
#'   optional `weight_channel` attribute).
#' @param val the validator return list (`per_cluster` tibble + `partition` list).
#' @param kind "functional" or "phenotype".
#' @return the joined clusters tibble (validation columns merged; `cluster_id` dropped).
#' @export
analysis_snapshot_join_validated_clusters <- function(membership, val, kind) {
  membership_channel <- attr(membership, "weight_channel")
  validation_channel <- val$partition$weight_channel

  # Member id space differs per axis: functional clusters over STRING node ids, phenotype
  # clusters over entity ids. Extract the served per-cluster member set (keyed by the same
  # integer cluster label as val$reference_members) for the same-partition proof.
  member_col <- if (identical(kind, "functional")) "STRING_id" else "entity_id"
  membership_members <- NULL
  if (all(c("identifiers", "cluster") %in% names(membership))) {
    membership_members <- stats::setNames(
      lapply(membership$identifiers, function(df) {
        if (is.data.frame(df) && member_col %in% names(df)) {
          as.character(df[[member_col]])
        } else {
          character(0)
        }
      }),
# functions/analysis-snapshot-release-materialize.R
#
# Pure, DB-light helpers for the immutable analysis-snapshot RELEASE build
# orchestrator (#573 Slice A / Task A4). Split out of
# `analysis-snapshot-release.R` to keep both files under the 600-line ceiling.
#
# Contains: the classed-condition constructor, the manifest/loader extraction
# helpers, the best-effort HARD coherence-re-check default (`coherence_assert`
# seam default), the cross-layer lineage gates, and the per-layer file
# materialization (payload / reproducibility / README). No DB access, no network.
#
# Sourced together with `analysis-snapshot-release.R` (both registered in
# `bootstrap/load_modules.R` -- Task A8 -- and both sourced by the direct-source
# integration test).

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# --------------------------------------------------------------------------- #
# Classed conditions
# --------------------------------------------------------------------------- #

#' Construct a classed release-gate condition (`c(<class>,"error","condition")`).
#'
#' The five `release_*` gate classes are surfaced to the A5 service, which maps
#' them to HTTP 400 (`stop_for_bad_request`; the contract has no 409 class).
#' @noRd
.analysis_release_condition <- function(class, message, ...) {
  structure(
    list(message = message, call = NULL, ...),
    class = c(class, "error", "condition")
  )
}

# --------------------------------------------------------------------------- #
# Extraction helpers
# --------------------------------------------------------------------------- #

#' Scalar read of a manifest field (manifest is a 1-row data.frame / tibble).
#' @noRd
.analysis_release_manifest_scalar <- function(manifest, field, default = NA) {
  if (is.null(manifest)) {
    return(default)
  }
  if (!(field %in% names(manifest))) {
    return(default)
  }
  column <- manifest[[field]]
  if (length(column) == 0L) {
    return(default)
  }
  value <- column[[1]]
  if (is.null(value)) default else value
}

#' Take a consistent scalar of `field` across the loaded layer manifests.
#'
#' NA when no layer carries it. When `strict = TRUE` (M2), distinct non-empty
#' values that DISAGREE across layers raise `release_source_version_mismatch`
#' (mirroring the source_data_version gate — the service maps it to 400); empty
#' NA values are ignored (not a conflict). When `strict = FALSE`, a disagreement
#' silently takes the first non-empty value.
#' @noRd
.analysis_release_consistent_manifest_value <- function(loaded, field, strict = FALSE) {
  values <- vapply(
    loaded,
    function(e) as.character(.analysis_release_manifest_scalar(e$manifest, field, NA_character_)),
    character(1)
  )
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) {
    return(NA_character_)
  }
  distinct <- unique(values)
  if (isTRUE(strict) && length(distinct) > 1L) {
    stop(.analysis_release_condition(
      "release_source_version_mismatch",
      sprintf(
        "release layers disagree on %s (found: %s)",
        field, paste(distinct, collapse = ", ")
      )
    ))
  }
  values[[1]]
}

#' Coerce a possibly-NULL child tibble to a plain data.frame for serialization.
#' @noRd
.analysis_release_rows <- function(x) {
  if (is.null(x)) {
    return(data.frame())
  }
  as.data.frame(x, stringsAsFactors = FALSE)
}

#' Map a cluster analysis_type to its cluster_kind label.
#' @noRd
.analysis_release_layer_kind <- function(analysis_type) {
  switch(as.character(analysis_type[[1]]),
    functional_clusters = "functional",
    phenotype_clusters = "phenotype",
    NA_character_
  )
}

#' Extract the reproducibility_hash from a loader row (df or list), or NA.
#' @noRd
.analysis_release_repro_hash <- function(repro) {
  if (is.null(repro)) {
    return(NA_character_)
  }
  if (is.data.frame(repro) && nrow(repro) == 0L) {
    return(NA_character_)
  }
  hash <- repro$reproducibility_hash
  if (is.null(hash) || length(hash) == 0L) {
    return(NA_character_)
  }
  as.character(hash[[1]])
}

# --------------------------------------------------------------------------- #
# Default coherence seam (best-effort HARD re-check over the STORED snapshot).
#
# Two of the three #514 coherence components ARE reconstructable from the stored
# public snapshot and are re-checked here (HARD, require_coherence = TRUE,
# ignoring the ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE downgrade):
#   1. Cluster-set integrity: every visible cluster (by cluster_kind) must appear
#      in the membership AND carry a non-NA stability score (jaccard_mean) in its
#      metadata_json — directly catching the #514 symptom ("real clusters with n/a
#      stability") in stored form.
#   2. Channel match (functional axis): the served membership channel
#      (`membership_weight_channel`) and the validation channel (`weight_channel`)
#      are both persisted in the manifest `validation_json`; when both are present
#      they must agree, else the served membership was clustered on a different
#      STRING channel than the validation scored (the #514 text-mining-vs-exp+db
#      case that slips through when cluster-id labels coincide).
# The THIRD component — full member-set equality — is genuinely NOT
# reconstructable: the validator's `reference_members` is a sibling of `partition`
# and is never persisted. That check is left to the build-time gate; the dev-stack
# e2e exercises the true membership-vs-validation recompute path.
# --------------------------------------------------------------------------- #

#' Parse the manifest `validation_json` column to a plain list (or empty list).
#' @noRd
.analysis_release_parse_validation_json <- function(manifest) {
  raw <- suppressWarnings(as.character(.analysis_release_manifest_scalar(manifest, "validation_json", NA_character_)))
  if (length(raw) == 0L || is.na(raw[[1]]) || !nzchar(raw[[1]])) {
    return(list())
  }
  parsed <- tryCatch(jsonlite::fromJSON(raw[[1]], simplifyVector = TRUE), error = function(e) NULL)
  if (is.null(parsed) || !is.list(parsed)) {
    return(list())
  }
  parsed
}

#' @noRd
.analysis_release_cluster_has_stability <- function(metadata_json) {
  txt <- suppressWarnings(as.character(metadata_json))
  if (length(txt) == 0L || is.na(txt[[1]]) || !nzchar(txt[[1]])) {
    return(FALSE)
  }
  parsed <- tryCatch(jsonlite::fromJSON(txt[[1]], simplifyVector = TRUE), error = function(e) NULL)
  if (is.null(parsed)) {
    return(FALSE)
  }
  score <- parsed$jaccard_mean %||% parsed$stability %||% parsed$stability_score
  !is.null(score) && length(score) >= 1L && !is.na(suppressWarnings(as.numeric(score[[1]])))
}

#' Hard coherence re-check over a loaded cluster snapshot. Default `coherence_assert`.
#' @export
analysis_snapshot_release_assert_coherent <- function(snapshot, kind) {
  clusters <- .analysis_release_rows(snapshot$clusters)
  members <- .analysis_release_rows(snapshot$cluster_members)
  if ("cluster_kind" %in% names(clusters)) {
    clusters <- clusters[as.character(clusters$cluster_kind) == kind, , drop = FALSE]
  }
  if ("cluster_kind" %in% names(members)) {
    members <- members[as.character(members$cluster_kind) == kind, , drop = FALSE]
  }

  membership_ids <- if ("cluster_id" %in% names(members)) unique(as.character(members$cluster_id)) else character(0)
  membership <- tibble::tibble(cluster = membership_ids)

  valid_ids <- character(0)
  if (nrow(clusters) > 0L && "cluster_id" %in% names(clusters)) {
    metadata <- if ("metadata_json" %in% names(clusters)) clusters$metadata_json else rep(NA_character_, nrow(clusters))
    has_stability <- vapply(
      seq_len(nrow(clusters)),
      function(i) .analysis_release_cluster_has_stability(metadata[[i]]),
      logical(1)
    )
    valid_ids <- as.character(clusters$cluster_id[has_stability])
  }
  per_cluster <- tibble::tibble(cluster_id = valid_ids)

  validation <- .analysis_release_parse_validation_json(snapshot$manifest)

  # Channel match (functional axis only): both channels live in validation_json;
  # when both are present they must agree. Absent/older snapshots skip this
  # comparison (assert_partition_coherent only fires channel_mismatch when BOTH
  # membership_channel and validation_channel are non-NULL).
  membership_channel <- NULL
  validation_channel <- NULL
  if (identical(kind, "functional")) {
    membership_channel <- validation$membership_weight_channel
    validation_channel <- validation$weight_channel
  }

  # H4: MEMBER-SET proof. Reconstruct the served membership member sets from the
  # stored cluster_members (grouped by cluster_id, in the stored id space:
  # hgnc_id for functional / entity_id for phenotype) and compare them against the
  # persisted validator reference sets (validation_json$reference_members, same
  # stored space). When the attestation is ABSENT (legacy pre-#573 snapshot),
  # GRACEFULLY DEGRADE to the channel + stability check and WARN — never hard
  # reject a legacy snapshot (that would block every release until a full rebuild).
  member_col <- if (identical(kind, "functional")) "hgnc_id" else "entity_id"
  membership_members <- NULL
  if (all(c("cluster_id", member_col) %in% names(members)) && nrow(members) > 0L) {
    grouped <- split(as.character(members[[member_col]]), as.character(members$cluster_id))
    membership_members <- lapply(grouped, function(v) unique(v[!is.na(v) & nzchar(v)]))
  }
  validation_members <- validation$reference_members
  if (!is.null(validation_members) && length(validation_members) > 0L) {
    validation_members <- lapply(validation_members, function(v) unique(as.character(v)))
    # MC2: a PRESENT attestation must be COMPLETE — its cluster-id key set must
    # equal the served membership cluster set. A partial/malformed attestation
    # (missing a served cluster that would otherwise mismatch) must NOT slip
    # through the intersection-only same-partition proof: it is INCOHERENT, not
    # legacy-absent. (The served set == the validated per_cluster set is enforced
    # separately by the missing/orphan checks in assert_partition_coherent.)
    served_cluster_ids <- if (!is.null(membership_members)) names(membership_members) else membership_ids
    if (!setequal(names(validation_members), served_cluster_ids)) {
      stop(.analysis_release_condition(
        "release_source_incoherent",
        sprintf(
          "%s snapshot reference attestation is partial/malformed: cluster set does not cover the served membership",
          kind
        ),
        kind = kind
      ))
    }
  } else {
    validation_members <- NULL
    membership_members <- NULL # fully-absent (legacy) -> no reference to prove against
    warning(sprintf(
      paste0(
        "release coherence: %s snapshot carries no persisted reference member sets ",
        "(legacy snapshot); full member-set verification is unavailable, degraded to ",
        "channel + stability check. Rebuild the snapshot (worker-executed) to attest coherence."
      ),
      kind
    ), call. = FALSE)
  }

  tryCatch(
    analysis_snapshot_assert_partition_coherent(
      membership, per_cluster, kind,
      membership_channel = membership_channel,
      validation_channel = validation_channel,
      membership_members = membership_members,
      validation_members = validation_members,
      require_coherence = TRUE
    ),
    error = function(e) {
      stop(.analysis_release_condition(
        "release_source_incoherent",
        sprintf("%s snapshot failed hard coherence re-check: %s", kind, conditionMessage(e)),
        kind = kind
      ))
    }
  )
  invisible(TRUE)
}

# --------------------------------------------------------------------------- #
# Cross-layer lineage gates (step 2). Re-asserted immediately before insert.
# --------------------------------------------------------------------------- #

#' @noRd
.analysis_release_dep_matches <- function(dependencies, key, entry) {
  if (!is.list(dependencies)) {
    return(FALSE)
  }
  dep <- dependencies[[key]]
  if (!is.list(dep)) {
    return(FALSE)
  }
  dep_id <- suppressWarnings(as.integer(dep$snapshot_id %||% NA))
  dep_hash <- as.character(dep$payload_hash %||% "")
  entry_id <- suppressWarnings(as.integer(entry$snapshot_id))
  entry_hash <- as.character(entry$payload_hash %||% "")
  !is.na(dep_id) && !is.na(entry_id) && identical(dep_id, entry_id) &&
    nzchar(dep_hash) && nzchar(entry_hash) && identical(dep_hash, entry_hash)
}

#' Assert one shared source_data_version + correlation dependency lineage.
#' @noRd
.analysis_release_assert_lineage <- function(loaded) {
  versions <- vapply(
    loaded,
    function(e) as.character(e$source_data_version %||% NA_character_),
    character(1)
  )
  uniq <- unique(versions)
  if (length(uniq) != 1L || is.na(uniq[[1]]) || !nzchar(uniq[[1]])) {
    stop(.analysis_release_condition(
      "release_source_version_mismatch",
      sprintf(
        "release layers do not share one source_data_version (found: %s)",
        paste(ifelse(is.na(versions), "<NA>", versions), collapse = ", ")
      )
    ))
  }

  corr <- loaded[["phenotype_functional_correlations"]]
  func <- loaded[["functional_clusters"]]
  phen <- loaded[["phenotype_clusters"]]
  if (!is.null(corr) && !is.null(func) && !is.null(phen)) {
    dependencies <- analysis_snapshot_manifest_dependencies(corr$manifest)
    ok <- .analysis_release_dep_matches(dependencies, "functional_clusters", func) &&
      .analysis_release_dep_matches(dependencies, "phenotype_clusters", phen)
    if (!ok) {
      stop(.analysis_release_condition(
        "release_dependency_lineage_mismatch",
        paste(
          "correlation snapshot dependency lineage does not match the pinned",
          "functional/phenotype cluster snapshots (a cluster axis was refreshed",
          "after the correlation was computed)"
        )
      ))
    }
  }
  invisible(TRUE)
}

# --------------------------------------------------------------------------- #
# File materialization
# --------------------------------------------------------------------------- #

#' Layer-appropriate payload object (its own bytes; NOT the snapshot payload_hash).
#' @noRd
.analysis_release_layer_payload <- function(snapshot, layer) {
  if (isTRUE(layer$has_reproducibility)) {
    list(
      clusters = .analysis_release_rows(snapshot$clusters),
      cluster_members = .analysis_release_rows(snapshot$cluster_members)
    )
  } else if (grepl("correlation", layer$analysis_type, fixed = TRUE)) {
    list(correlations = .analysis_release_rows(snapshot$correlations))
  } else {
    list(
      network_nodes = .analysis_release_rows(snapshot$network_nodes),
      network_edges = .analysis_release_rows(snapshot$network_edges)
    )
  }
}

#' Assemble one materialized artifact with its own sha256 + byte_size.
#' @noRd
.analysis_release_artifact <- function(path, bytes, media_type) {
  # Every materialized file path flows through here — assert containment at this
  # single choke point (defense-in-depth alongside analysis_release_build_tar_gz).
  .analysis_release_assert_safe_path(path)
  list(
    path = path,
    bytes = bytes,
    media_type = media_type,
    sha256 = analysis_release_sha256(bytes),
    byte_size = length(bytes)
  )
}

#' README.md content bytes (scope + independent-verification recipe).
#' @noRd
.analysis_release_readme_bytes <- function(release_id, title, scope_statement, license,
                                           source_data_version, layer_entries) {
  layer_lines <- vapply(
    layer_entries,
    function(e) {
      sprintf(
        "- %s (snapshot_id %s, payload_hash %s)",
        e$analysis_type, as.character(e$snapshot_id), substr(e$payload_hash, 1, 12)
      )
    },
    character(1)
  )
  lines <- c(
    sprintf("# %s", title %||% "SysNDD analysis-snapshot release"),
    "",
    sprintf("Release: `%s`", release_id),
    sprintf("License: %s", license %||% "CC-BY-4.0"),
    sprintf("Source data version: %s", source_data_version %||% "unknown"),
    "",
    "## Scope",
    "",
    scope_statement %||% paste(
      "Immutable, content-addressed public export of the curated derived",
      "cluster-analysis snapshots served by the SysNDD analysis API."
    ),
    "",
    "## Layers",
    "",
    layer_lines,
    "",
    "## Verify",
    "",
    "1. `sha256sum -c checksums.sha256` verifies every file against its recorded digest.",
    "2. `manifest.json` records each layer's source snapshot lineage",
    "   (`snapshot_id`, `payload_hash`, `input_hash`) plus the reproducibility hash.",
    "3. Each cluster layer's `reproducibility.json` hashes exactly to its",
    "   `reproducibility_hash` and carries the inputs to independently recompute",
    "   the served separation metric (modularity / silhouette).",
    ""
  )
  charToRaw(enc2utf8(paste(lines, collapse = "\n")))
}
# functions/analysis-snapshot-release.R
#
# Build orchestrator for immutable, content-addressed public analysis-snapshot
# RELEASES (#573 Slice A / Task A4). This is the correctness-critical layer: it
# LOADS the active public snapshots, GATES them (available + hard coherence +
# reproducibility presence + shared source-data version + dependency lineage +
# TOCTOU), MATERIALIZES the release files, computes the content-addressed
# identity, and PERSISTS via the A3 repository.
#
# Reuses (sourced by callers before this file / registered in load_modules):
#   - analysis-snapshot-presets.R          : canonical JSON + parameter hashing
#   - analysis-snapshot-coherence.R        : analysis_snapshot_assert_partition_coherent
#   - analysis-snapshot-dependencies.R     : analysis_snapshot_manifest_dependencies
#   - analysis-reproducibility.R           : analysis_reproducibility_decode_raw
#   - analysis-snapshot-release-manifest.R : identity + manifest/checksums/tar helpers (A2)
#   - analysis-snapshot-release-repository.R: analysis_release_insert/get/exists/... (A3)
#
# DEPENDENCY-INJECTION SEAMS. The three collaborators below are injectable so the
# gates are deterministically unit-testable WITHOUT seeding the complex snapshot
# tables. Their call-time defaults are the real functions; the body always calls
# the seam, never the real function directly:
#   - loader(analysis_type, parameter_hash, conn)  -> loaded snapshot
#   - reproducibility_loader(snapshot_id, conn)    -> reproducibility row (or NULL)
#   - coherence_assert(snapshot, kind)             -> invisibly / throws
#
# ERROR CONTRACT. The five classed conditions below are `c(<name>,"error",
# "condition")`; the A5 service maps them to HTTP 400 (the contract has no 409):
#   release_snapshot_not_available, release_source_incoherent,
#   release_reproducibility_missing, release_source_version_mismatch,
#   release_dependency_lineage_mismatch.
# A DUPLICATE build is NOT an error: it returns the existing head with
# created = FALSE (service -> 200).

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Materialization / gate / coherence helpers live in the sibling file (kept
# separate so both stay under the 600-line ceiling). Registered together in
# bootstrap/load_modules.R -- Task A8 -- and sourced together by the integration test.

# --------------------------------------------------------------------------- #
# Advisory locks (TOCTOU): serialize a build against a concurrent axis refresh.
#
# The build acquires the SAME per-preset advisory lock the axis refresh holds —
# `analysis_snapshot_lock_name(analysis_type, parameter_hash)` — so a mid-flight
# refresh of a source preset blocks the read (MySQL 8 lets one session hold many
# named GET_LOCKs). Best-effort: engaged only on a real DBIConnection (a
# pooled/NULL conn cannot hold a session-scoped GET_LOCK meaningfully), and a
# lock-acquire timeout does NOT abort — the fresh pre-insert re-read below is the
# invariant that always catches a snapshot that changed under us.
# --------------------------------------------------------------------------- #

#' Per-preset lock name — identical to the axis-refresh lock so they collide.
#' @noRd
.analysis_release_preset_lock_name <- function(analysis_type, parameter_hash) {
  if (exists("analysis_snapshot_lock_name", mode = "function")) {
    return(analysis_snapshot_lock_name(analysis_type, parameter_hash))
  }
  # Byte-identical fallback for minimal/test envs where the repository file that
  # defines analysis_snapshot_lock_name() is not sourced.
  paste0("asr:", substr(as.character(parameter_hash[[1]]), 1, 56))
}

#' @noRd
.analysis_release_get_lock <- function(conn, name, timeout_seconds = 5L) {
  if (!inherits(conn, "DBIConnection")) {
    return(FALSE)
  }
  tryCatch(
    {
      rows <- DBI::dbGetQuery(
        conn, "SELECT GET_LOCK(?, ?) AS acquired",
        params = unname(list(name, as.integer(timeout_seconds)))
      )
      isTRUE(as.integer(rows$acquired[[1]]) == 1L)
    },
    error = function(e) FALSE
  )
}

#' @noRd
.analysis_release_release_named_lock <- function(conn, name) {
  if (!inherits(conn, "DBIConnection")) {
    return(invisible(FALSE))
  }
  tryCatch(
    DBI::dbGetQuery(
      conn, "SELECT RELEASE_LOCK(?) AS released",
      params = unname(list(name))
    ),
    error = function(e) NULL
  )
  invisible(TRUE)
}

#' Default `lock_acquire` seam: acquire every per-preset lock (all-or-nothing).
#'
#' @return `list(ok, acquired, skipped)`. On a non-DBIConnection the locks are
#'   skipped (`ok = TRUE, skipped = TRUE`) — the test/mirai path. On a real
#'   connection, a failed acquisition releases any partially-held locks and
#'   returns `ok = FALSE` so the caller raises `release_lock_unavailable`.
#' @noRd
.analysis_release_acquire_preset_locks <- function(conn, lock_names, timeout_seconds = 5L) {
  if (!inherits(conn, "DBIConnection")) {
    return(list(ok = TRUE, acquired = character(0), skipped = TRUE))
  }
  acquired <- character(0)
  for (lock_name in lock_names) {
    if (.analysis_release_get_lock(conn, lock_name, timeout_seconds)) {
      acquired <- c(acquired, lock_name)
    } else {
      for (held in acquired) .analysis_release_release_named_lock(conn, held)
      return(list(ok = FALSE, acquired = character(0), skipped = FALSE))
    }
  }
  list(ok = TRUE, acquired = acquired, skipped = FALSE)
}

#' Fresh pre-insert re-read: re-load each layer via the loader seam (NOT the
#' cached step-1 `loaded`) and confirm each layer's {snapshot_id, payload_hash}
#' and the correlation dependencies still equal the pinned lineage. Throws a
#' classed gate error if a source snapshot changed between the first read and the
#' insert (the real TOCTOU catch).
#' @noRd
.analysis_release_verify_lineage_unchanged <- function(layer_specs, loaded, loader, conn) {
  for (spec in layer_specs) {
    at <- spec$analysis_type
    entry <- loaded[[at]]
    fresh <- loader(at, spec$parameter_hash, conn = conn)
    status_code <- if (is.null(fresh)) "snapshot_missing" else (fresh$status_code %||% "snapshot_missing")
    if (!identical(status_code, "available")) {
      stop(.analysis_release_condition(
        "release_snapshot_not_available",
        sprintf("layer %s became unavailable before insert: %s", at, status_code),
        analysis_type = at, status_code = status_code
      ))
    }
    fresh_id <- suppressWarnings(as.integer(.analysis_release_manifest_scalar(fresh$manifest, "snapshot_id")))
    fresh_hash <- as.character(.analysis_release_manifest_scalar(fresh$manifest, "payload_hash", NA_character_))
    if (!identical(fresh_id, suppressWarnings(as.integer(entry$snapshot_id))) ||
      !identical(fresh_hash, entry$payload_hash)) {
      stop(.analysis_release_condition(
        "release_dependency_lineage_mismatch",
        sprintf(
          "layer %s snapshot changed between read and insert (was snapshot_id %s, now %s)",
          at, as.character(entry$snapshot_id), as.character(fresh_id)
        ),
        analysis_type = at
      ))
    }
    if (identical(at, "phenotype_functional_correlations") &&
      !is.null(loaded[["functional_clusters"]]) && !is.null(loaded[["phenotype_clusters"]])) {
      fresh_deps <- analysis_snapshot_manifest_dependencies(fresh$manifest)
      ok <- .analysis_release_dep_matches(fresh_deps, "functional_clusters", loaded[["functional_clusters"]]) &&
        .analysis_release_dep_matches(fresh_deps, "phenotype_clusters", loaded[["phenotype_clusters"]])
      if (!ok) {
        stop(.analysis_release_condition(
          "release_dependency_lineage_mismatch",
          "correlation dependency lineage changed between read and insert",
          analysis_type = at
        ))
      }
    }
  }
  invisible(TRUE)
}

# --------------------------------------------------------------------------- #
# Orchestrator
# --------------------------------------------------------------------------- #

#' Build (and optionally publish) an immutable analysis-snapshot release.
#'
#' @param layers Layer registry (default `analysis_snapshot_release_layers()`).
#' @param title,scope_statement,license Presentation metadata (excluded from the
#'   content digest / release identity).
#' @param publish If TRUE the inserted draft is flipped to `published`.
#' @param created_by Optional user id recorded on the head row.
#' @param conn A real DBIConnection (required for persistence; A5 checks one out).
#' @param layers Optional SELECTION of layers to include (NULL = full registry);
#'   resolved to authoritative registry entries by
#'   `analysis_snapshot_release_resolve_layers()` (caller cannot override policy).
#' @param loader,reproducibility_loader,coherence_assert,lock_acquire,inserter
#'   Injectable seams (see file header); call-time defaults are the real
#'   functions. `lock_acquire` returns `list(ok, acquired, skipped)`; `inserter`
#'   persists the head/members/files.
#' @return `list(release = <head>, created = TRUE|FALSE)`.
#' @export
analysis_snapshot_release_build <- function(layers = NULL,
                                            title = NULL,
                                            scope_statement = NULL,
                                            license = "CC-BY-4.0",
                                            publish = TRUE,
                                            created_by = NULL,
                                            conn = NULL,
                                            loader = analysis_snapshot_get_public,
                                            reproducibility_loader = analysis_snapshot_get_reproducibility,
                                            coherence_assert = analysis_snapshot_release_assert_coherent,
                                            lock_acquire = .analysis_release_acquire_preset_locks,
                                            inserter = analysis_release_insert) {
  # B1: a caller `layers` request is a SELECTION, never a policy redefinition —
  # resolve each selector to the AUTHORITATIVE registry entry (params /
  # files_prefix / has_reproducibility come from the registry, never the caller).
  layers <- analysis_snapshot_release_resolve_layers(layers)

  # Resolve (analysis_type, parameter_hash) per layer once (pure; validates params).
  layer_specs <- lapply(layers, function(layer) {
    at <- as.character(layer$analysis_type[[1]])
    list(
      analysis_type = at,
      layer = layer,
      parameter_hash = analysis_snapshot_normalize_params(at, layer$params %||% list())$parameter_hash
    )
  })

  # --- Step 0: per-preset TOCTOU advisory locks ----------------------------
  # Acquire the SAME per-preset lock the axis refresh holds, so a mid-flight
  # refresh of a source preset serializes against this read. On a REAL
  # DBIConnection a failed acquisition MUST NOT proceed unlocked (H3): it raises
  # `release_lock_unavailable`, which the service maps to 503 + Retry-After.
  # A non-DBI/test conn skips the lock (lock_state$skipped).
  lock_names <- vapply(
    layer_specs,
    function(spec) .analysis_release_preset_lock_name(spec$analysis_type, spec$parameter_hash),
    character(1)
  )
  lock_state <- lock_acquire(conn, lock_names)
  if (length(lock_state$acquired %||% character(0)) > 0L) {
    on.exit(
      for (lock_name in lock_state$acquired) .analysis_release_release_named_lock(conn, lock_name),
      add = TRUE
    )
  }
  if (!isTRUE(lock_state$ok)) {
    stop(.analysis_release_condition(
      "release_lock_unavailable",
      "source analysis snapshots are being refreshed; retry the release build shortly"
    ))
  }

  # --- Step 1/1b/1c: load + gate each layer --------------------------------
  loaded <- list()
  for (spec in layer_specs) {
    layer <- spec$layer
    at <- spec$analysis_type
    parameter_hash <- spec$parameter_hash

    snapshot <- loader(at, parameter_hash, conn = conn)
    status_code <- if (is.null(snapshot)) "snapshot_missing" else (snapshot$status_code %||% "snapshot_missing")
    if (!identical(status_code, "available")) {
      stop(.analysis_release_condition(
        "release_snapshot_not_available",
        sprintf("layer %s is not available for release: %s", at, status_code),
        analysis_type = at, status_code = status_code
      ))
    }

    manifest <- snapshot$manifest
    entry <- list(
      analysis_type = at,
      kind = .analysis_release_layer_kind(at),
      layer = layer,
      snapshot = snapshot,
      manifest = manifest,
      snapshot_id = .analysis_release_manifest_scalar(manifest, "snapshot_id"),
      payload_hash = as.character(.analysis_release_manifest_scalar(manifest, "payload_hash", NA_character_)),
      input_hash = as.character(.analysis_release_manifest_scalar(manifest, "input_hash", NA_character_)),
      schema_version = as.character(.analysis_release_manifest_scalar(manifest, "schema_version", NA_character_)),
      source_data_version = as.character(
        .analysis_release_manifest_scalar(manifest, "source_data_version", NA_character_)
      ),
      parameter_hash = parameter_hash,
      reproducibility_hash = NULL,
      dependencies = NULL,
      reproducibility_bundle = NULL
    )

    if (isTRUE(layer$has_reproducibility)) {
      # 1b: HARD coherence re-check (any failure -> release_source_incoherent).
      tryCatch(
        coherence_assert(snapshot, entry$kind),
        release_source_incoherent = function(e) stop(e),
        error = function(e) {
          stop(.analysis_release_condition(
            "release_source_incoherent",
            sprintf("layer %s failed the hard coherence re-check: %s", at, conditionMessage(e)),
            analysis_type = at
          ))
        }
      )

      # 1c: reproducibility bundle presence.
      repro <- reproducibility_loader(entry$snapshot_id, conn = conn)
      repro_hash <- .analysis_release_repro_hash(repro)
      if (is.na(repro_hash) || !nzchar(repro_hash)) {
        stop(.analysis_release_condition(
          "release_reproducibility_missing",
          sprintf("layer %s has no reproducibility bundle; the release requires one", at),
          analysis_type = at
        ))
      }
      entry$reproducibility_hash <- repro_hash
      entry$reproducibility_bundle <- repro$bundle_gzip_json
    }

    loaded[[at]] <- entry
  }

  # --- Step 2: shared source version + correlation dependency lineage ------
  .analysis_release_assert_lineage(loaded)
  shared_source_version <- unique(vapply(
    loaded, function(e) as.character(e$source_data_version), character(1)
  ))[[1]]

  # M1/M2: DB release provenance — carried on each pinned snapshot manifest.
  # strict = TRUE: distinct non-empty values that DISAGREE across layers reject
  # the build (release_source_version_mismatch -> 400), like source_data_version.
  shared_db_release_version <- .analysis_release_consistent_manifest_value(loaded, "db_release_version", strict = TRUE)
  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit", strict = TRUE)

  # For the correlation layer, pin the actual dependency lineage into its entry.
  corr <- loaded[["phenotype_functional_correlations"]]
  if (!is.null(corr)) {
    loaded[["phenotype_functional_correlations"]]$dependencies <-
      analysis_snapshot_manifest_dependencies(corr$manifest)
  }

  # --- Step 3/4/5: materialize per-layer files + README, build layer_entries
  artifacts <- list()
  layer_entries <- list()

  for (layer in layers) {
    at <- as.character(layer$analysis_type[[1]])
    entry <- loaded[[at]]
    prefix <- layer$files_prefix %||% at

    payload_bytes <- analysis_release_canonical_bytes(.analysis_release_layer_payload(entry$snapshot, layer))
    artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
      paste0(prefix, "/payload.json"), payload_bytes, "application/json"
    )

    if (isTRUE(layer$has_reproducibility)) {
      repro_bytes <- charToRaw(analysis_reproducibility_decode_raw(entry$reproducibility_bundle))
      # H2: the LOCKED equality `sha256(reproducibility.json) == reproducibility_hash`
      # must HOLD, not merely be present — verify the decoded bytes hash to the
      # stored hash (a corrupt/restored bundle whose bytes drifted from its hash
      # is rejected, not published).
      computed_repro_hash <- analysis_release_sha256(repro_bytes)
      if (!identical(computed_repro_hash, entry$reproducibility_hash)) {
        stop(.analysis_release_condition(
          "release_reproducibility_missing",
          sprintf(
            "layer %s reproducibility bytes do not hash to the stored reproducibility_hash (bundle corrupt)",
            at
          ),
          analysis_type = at
        ))
      }
      artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
        paste0(prefix, "/reproducibility.json"), repro_bytes, "application/json"
      )
    }

    layer_entries[[length(layer_entries) + 1L]] <- list(
      analysis_type = at,
      parameter_hash = entry$parameter_hash,
      snapshot_id = entry$snapshot_id,
      input_hash = entry$input_hash,
      payload_hash = entry$payload_hash,
      schema_version = entry$schema_version,
      reproducibility_hash = entry$reproducibility_hash,
      dependencies = entry$dependencies
    )
  }

  # --- Step 6: content_digest -> release_id + idempotency ------------------
  content_digest <- analysis_release_content_digest(
    layer_entries, shared_source_version, ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION
  )
  release_id <- analysis_release_id(content_digest)

  if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
    existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
    if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
      return(list(release = existing, created = FALSE))
    }
    stop(sprintf(
      "release id %s already exists with a different content_digest (identity anomaly)",
      release_id
    ), call. = FALSE)
  }

  # README carries the resolved release_id now that it is known.
  readme_bytes <- .analysis_release_readme_bytes(
    release_id, title, scope_statement, license, shared_source_version, layer_entries
  )
  artifacts <- c(
    list(.analysis_release_artifact("README.md", readme_bytes, "text/markdown")),
    artifacts
  )

  created_at <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  # --- Step 7: manifest.json (files[] excludes manifest + checksums) -------
  content_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256, bytes = a$byte_size))
  manifest_obj <- analysis_release_build_manifest(list(
    release_id = release_id,
    release_version = NULL,
    title = title,
    created_at = created_at,
    license = license %||% "CC-BY-4.0",
    scope_statement = scope_statement,
    generator = list(
      name = "sysndd-analysis-snapshot-release-build",
      manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
      reproducibility_schema_version = if (exists("ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION")) {
        ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION
      } else {
        NULL
      }
    ),
    source = list(
      source_data_version = shared_source_version,
      db_release = list(
        version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
      ),
      snapshots = lapply(layer_entries, function(e) {
        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
      })
    ),
    layers = layer_entries,
    files = content_files,
    content_digest = content_digest
  ))
  manifest_bytes <- analysis_release_canonical_bytes(manifest_obj)
  manifest_artifact <- .analysis_release_artifact("manifest.json", manifest_bytes, "application/json")
  manifest_sha256 <- manifest_artifact$sha256
  artifacts[[length(artifacts) + 1L]] <- manifest_artifact

  # --- Step 8: checksums.sha256 (all files incl. manifest, excl. checksums)-
  checksum_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256))
  checksums_bytes <- charToRaw(enc2utf8(analysis_release_checksums_text(checksum_files)))
  artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
    "checksums.sha256", checksums_bytes, "text/plain"
  )

  # --- Step 9: bundle.tar.gz (all files) -----------------------------------
  named_raw <- stats::setNames(
    lapply(artifacts, function(a) a$bytes),
    vapply(artifacts, function(a) a$path, character(1))
  )
  bundle_gzip <- analysis_release_build_tar_gz(named_raw)
  bundle_sha256 <- analysis_release_sha256(bundle_gzip)

  # --- Step 2 (re-assert immediately before insert) ------------------------
  # A FRESH DB re-read via the loader seam (not the cached `loaded`) so a source
  # snapshot that was refreshed between the first read and now is caught. Combined
  # with the per-preset locks above, this closes the TOCTOU window.
  .analysis_release_assert_lineage(loaded)
  .analysis_release_verify_lineage_unchanged(layer_specs, loaded, loader, conn)

  # --- Step 10: persist ----------------------------------------------------
  release_head <- list(
    release_id = release_id,
    release_version = NULL,
    title = title,
    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
    content_digest = content_digest,
    manifest_sha256 = manifest_sha256,
    bundle_sha256 = bundle_sha256,
    bundle_gzip = bundle_gzip,
    source_data_version = shared_source_version,
    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
    scope_statement = scope_statement,
    license = license %||% "CC-BY-4.0",
    created_by_user_id = created_by
  )

  members <- lapply(layer_entries, function(e) {
    list(
      analysis_type = e$analysis_type,
      parameter_hash = e$parameter_hash,
      snapshot_id = e$snapshot_id,
      input_hash = e$input_hash,
      payload_hash = e$payload_hash,
      schema_version = e$schema_version,
      reproducibility_hash = e$reproducibility_hash,
      role = "layer"
    )
  })

  insert_files <- lapply(artifacts, function(a) {
    list(
      file_path = a$path,
      content_sha256 = a$sha256,
      byte_size = a$byte_size,
      media_type = a$media_type,
      content_gzip = memCompress(a$bytes, type = "gzip")
    )
  })

  # H3(b): a concurrent identical build can win the insert race (both passed the
  # step-6 idempotency probe). On a DB duplicate-key error, re-read by release_id:
  # if the stored content_digest matches, this build is a no-op (idempotent 200);
  # otherwise it is a genuine identity anomaly (re-raise -> 500).
  insert_created <- tryCatch(
    {
      inserter(release_head, members, insert_files, conn)
      TRUE
    },
    error = function(e) {
      if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
        existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
        if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
          return(FALSE) # idempotent: the concurrent winner stored the identical release
        }
      }
      stop(e)
    }
  )

  if (!isTRUE(insert_created)) {
    return(list(
      release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
      created = FALSE
    ))
  }

  if (isTRUE(publish)) {
    analysis_release_publish(release_id, conn = conn)
  }

  list(
    release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
    created = TRUE
  )
}

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-coherence.R | sed -n '170,330p'; nl -ba api/functions/analysis-snapshot-release-materialize.R | sed -n '100,460p'; nl -ba api/functions/analysis-snapshot-release.R | sed -n '1,320p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
   170	  pairs <- do.call(rbind, pairs)
   171	  pairs <- pairs[!is.na(pairs$STRING_id) & !is.na(pairs$hgnc_id), , drop = FALSE]
   172	  if (nrow(pairs) == 0L) {
   173	    return(list())
   174	  }
   175	  lapply(split(pairs$hgnc_id, pairs$STRING_id), function(h) unique(as.character(h)))
   176	}
   177	
   178	#' Express the validator's reference member sets in the STORED cluster_member id
   179	#' space so a RELEASE can independently verify member-set coherence (#573 H4).
   180	#'
   181	#' The stored `analysis_snapshot_cluster_member` table keeps `hgnc_id` (functional)
   182	#' or `entity_id` (phenotype). The validator's `reference_members` are STRING
   183	#' protein ids (functional) / entity ids (phenotype). This maps them into the
   184	#' stored space: phenotype is already entity_id; functional STRING_ids are mapped
   185	#' to hgnc_id via the partition-independent gene dictionary, and any UNMAPPED
   186	#' STRING_id is kept verbatim (fail-closed — it cannot equal a stored hgnc_id, so
   187	#' an incoherent membership is never silently masked).
   188	#'
   189	#' @return A named list keyed by cluster_id (string) -> member-id character vector.
   190	#' @noRd
   191	analysis_snapshot_reference_members_store_space <- function(reference_members, membership, kind) {
   192	  reference_members <- reference_members %||% list()
   193	  if (length(reference_members) == 0L) {
   194	    return(list())
   195	  }
   196	  if (identical(kind, "phenotype")) {
   197	    return(lapply(reference_members, function(ids) unique(as.character(ids))))
   198	  }
   199	  dict <- .analysis_snapshot_string_to_hgnc_dict(membership)
   200	  lapply(reference_members, function(sids) {
   201	    sids <- as.character(sids)
   202	    # Expand each STRING_id to the SET (union) of all its hgnc_ids so the mapped
   203	    # reference set equals the served cluster_members set; an UNMAPPED STRING_id is
   204	    # kept verbatim (fail-closed — it cannot equal a stored hgnc_id).
   205	    mapped <- unlist(lapply(sids, function(s) {
   206	      hg <- dict[[s]]
   207	      if (is.null(hg) || length(hg) == 0L) s else hg
   208	    }), use.names = FALSE)
   209	    unique(as.character(mapped))
   210	  })
   211	}
   212	
   213	#' Attach the additive partition provenance the join computed onto `partition`.
   214	#'
   215	#' Copies the served membership channel (#514, functional only — NA on the
   216	#' phenotype axis is not stored) and the H4 reference member-set attestation
   217	#' (#573, both axes) from the joined-tibble attributes onto `val$partition`, which
   218	#' the builder persists into `validation_json`. `partition_validation` is excluded
   219	#' from `payload_hash`, so this never churns `cluster_hash`.
   220	#' @export
   221	analysis_snapshot_attach_partition_provenance <- function(partition, joined) {
   222	  channel <- attr(joined, "membership_weight_channel")
   223	  if (!is.null(channel) && !all(is.na(channel))) {
   224	    partition$membership_weight_channel <- channel
   225	  }
   226	  partition$reference_members <- attr(joined, "reference_members_store_space")
   227	  partition
   228	}
   229	
   230	#' Gate then join the validator's per-cluster scores onto the served membership.
   231	#'
   232	#' Single choke-point for the builder's two clustering presets: it asserts partition
   233	#' coherence FIRST (so an incoherent snapshot can never be published), then performs the
   234	#' `cluster` <-> `cluster_id` left-join, and carries the served membership channel as a
   235	#' `membership_weight_channel` attribute for additive provenance.
   236	#'
   237	#' @param membership tibble from the memoised clustering function (integer `cluster`,
   238	#'   optional `weight_channel` attribute).
   239	#' @param val the validator return list (`per_cluster` tibble + `partition` list).
   240	#' @param kind "functional" or "phenotype".
   241	#' @return the joined clusters tibble (validation columns merged; `cluster_id` dropped).
   242	#' @export
   243	analysis_snapshot_join_validated_clusters <- function(membership, val, kind) {
   244	  membership_channel <- attr(membership, "weight_channel")
   245	  validation_channel <- val$partition$weight_channel
   246	
   247	  # Member id space differs per axis: functional clusters over STRING node ids, phenotype
   248	  # clusters over entity ids. Extract the served per-cluster member set (keyed by the same
   249	  # integer cluster label as val$reference_members) for the same-partition proof.
   250	  member_col <- if (identical(kind, "functional")) "STRING_id" else "entity_id"
   251	  membership_members <- NULL
   252	  if (all(c("identifiers", "cluster") %in% names(membership))) {
   253	    membership_members <- stats::setNames(
   254	      lapply(membership$identifiers, function(df) {
   255	        if (is.data.frame(df) && member_col %in% names(df)) {
   256	          as.character(df[[member_col]])
   257	        } else {
   258	          character(0)
   259	        }
   260	      }),
   261	      as.character(membership$cluster)
   262	    )
   263	  }
   264	
   265	  analysis_snapshot_assert_partition_coherent(
   266	    membership, val$per_cluster, kind,
   267	    membership_channel = membership_channel,
   268	    validation_channel = validation_channel,
   269	    membership_members = membership_members,
   270	    validation_members = val$reference_members
   271	  )
   272	
   273	  joined <- dplyr::left_join(
   274	    dplyr::mutate(membership, cluster_id = as.character(cluster)),
   275	    val$per_cluster,
   276	    by = "cluster_id"
   277	  )
   278	  joined <- dplyr::select(joined, -cluster_id)
   279	  attr(joined, "membership_weight_channel") <- membership_channel %||% NA_character_
   280	  # #573 H4: carry the validator's reference member sets, expressed in the STORED
   281	  # cluster_member id space, so the builder can persist them into validation_json
   282	  # and a RELEASE can later re-prove member-set coherence independently. Attached
   283	  # as an attribute (not mutated onto `val`, which is a by-value copy here).
   284	  attr(joined, "reference_members_store_space") <- analysis_snapshot_reference_members_store_space(
   285	    val$reference_members, membership, kind
   286	  )
   287	  joined
   288	}
   100	  switch(as.character(analysis_type[[1]]),
   101	    functional_clusters = "functional",
   102	    phenotype_clusters = "phenotype",
   103	    NA_character_
   104	  )
   105	}
   106	
   107	#' Extract the reproducibility_hash from a loader row (df or list), or NA.
   108	#' @noRd
   109	.analysis_release_repro_hash <- function(repro) {
   110	  if (is.null(repro)) {
   111	    return(NA_character_)
   112	  }
   113	  if (is.data.frame(repro) && nrow(repro) == 0L) {
   114	    return(NA_character_)
   115	  }
   116	  hash <- repro$reproducibility_hash
   117	  if (is.null(hash) || length(hash) == 0L) {
   118	    return(NA_character_)
   119	  }
   120	  as.character(hash[[1]])
   121	}
   122	
   123	# --------------------------------------------------------------------------- #
   124	# Default coherence seam (best-effort HARD re-check over the STORED snapshot).
   125	#
   126	# Two of the three #514 coherence components ARE reconstructable from the stored
   127	# public snapshot and are re-checked here (HARD, require_coherence = TRUE,
   128	# ignoring the ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE downgrade):
   129	#   1. Cluster-set integrity: every visible cluster (by cluster_kind) must appear
   130	#      in the membership AND carry a non-NA stability score (jaccard_mean) in its
   131	#      metadata_json — directly catching the #514 symptom ("real clusters with n/a
   132	#      stability") in stored form.
   133	#   2. Channel match (functional axis): the served membership channel
   134	#      (`membership_weight_channel`) and the validation channel (`weight_channel`)
   135	#      are both persisted in the manifest `validation_json`; when both are present
   136	#      they must agree, else the served membership was clustered on a different
   137	#      STRING channel than the validation scored (the #514 text-mining-vs-exp+db
   138	#      case that slips through when cluster-id labels coincide).
   139	# The THIRD component — full member-set equality — is genuinely NOT
   140	# reconstructable: the validator's `reference_members` is a sibling of `partition`
   141	# and is never persisted. That check is left to the build-time gate; the dev-stack
   142	# e2e exercises the true membership-vs-validation recompute path.
   143	# --------------------------------------------------------------------------- #
   144	
   145	#' Parse the manifest `validation_json` column to a plain list (or empty list).
   146	#' @noRd
   147	.analysis_release_parse_validation_json <- function(manifest) {
   148	  raw <- suppressWarnings(as.character(.analysis_release_manifest_scalar(manifest, "validation_json", NA_character_)))
   149	  if (length(raw) == 0L || is.na(raw[[1]]) || !nzchar(raw[[1]])) {
   150	    return(list())
   151	  }
   152	  parsed <- tryCatch(jsonlite::fromJSON(raw[[1]], simplifyVector = TRUE), error = function(e) NULL)
   153	  if (is.null(parsed) || !is.list(parsed)) {
   154	    return(list())
   155	  }
   156	  parsed
   157	}
   158	
   159	#' @noRd
   160	.analysis_release_cluster_has_stability <- function(metadata_json) {
   161	  txt <- suppressWarnings(as.character(metadata_json))
   162	  if (length(txt) == 0L || is.na(txt[[1]]) || !nzchar(txt[[1]])) {
   163	    return(FALSE)
   164	  }
   165	  parsed <- tryCatch(jsonlite::fromJSON(txt[[1]], simplifyVector = TRUE), error = function(e) NULL)
   166	  if (is.null(parsed)) {
   167	    return(FALSE)
   168	  }
   169	  score <- parsed$jaccard_mean %||% parsed$stability %||% parsed$stability_score
   170	  !is.null(score) && length(score) >= 1L && !is.na(suppressWarnings(as.numeric(score[[1]])))
   171	}
   172	
   173	#' Hard coherence re-check over a loaded cluster snapshot. Default `coherence_assert`.
   174	#' @export
   175	analysis_snapshot_release_assert_coherent <- function(snapshot, kind) {
   176	  clusters <- .analysis_release_rows(snapshot$clusters)
   177	  members <- .analysis_release_rows(snapshot$cluster_members)
   178	  if ("cluster_kind" %in% names(clusters)) {
   179	    clusters <- clusters[as.character(clusters$cluster_kind) == kind, , drop = FALSE]
   180	  }
   181	  if ("cluster_kind" %in% names(members)) {
   182	    members <- members[as.character(members$cluster_kind) == kind, , drop = FALSE]
   183	  }
   184	
   185	  membership_ids <- if ("cluster_id" %in% names(members)) unique(as.character(members$cluster_id)) else character(0)
   186	  membership <- tibble::tibble(cluster = membership_ids)
   187	
   188	  valid_ids <- character(0)
   189	  if (nrow(clusters) > 0L && "cluster_id" %in% names(clusters)) {
   190	    metadata <- if ("metadata_json" %in% names(clusters)) clusters$metadata_json else rep(NA_character_, nrow(clusters))
   191	    has_stability <- vapply(
   192	      seq_len(nrow(clusters)),
   193	      function(i) .analysis_release_cluster_has_stability(metadata[[i]]),
   194	      logical(1)
   195	    )
   196	    valid_ids <- as.character(clusters$cluster_id[has_stability])
   197	  }
   198	  per_cluster <- tibble::tibble(cluster_id = valid_ids)
   199	
   200	  validation <- .analysis_release_parse_validation_json(snapshot$manifest)
   201	
   202	  # Channel match (functional axis only): both channels live in validation_json;
   203	  # when both are present they must agree. Absent/older snapshots skip this
   204	  # comparison (assert_partition_coherent only fires channel_mismatch when BOTH
   205	  # membership_channel and validation_channel are non-NULL).
   206	  membership_channel <- NULL
   207	  validation_channel <- NULL
   208	  if (identical(kind, "functional")) {
   209	    membership_channel <- validation$membership_weight_channel
   210	    validation_channel <- validation$weight_channel
   211	  }
   212	
   213	  # H4: MEMBER-SET proof. Reconstruct the served membership member sets from the
   214	  # stored cluster_members (grouped by cluster_id, in the stored id space:
   215	  # hgnc_id for functional / entity_id for phenotype) and compare them against the
   216	  # persisted validator reference sets (validation_json$reference_members, same
   217	  # stored space). When the attestation is ABSENT (legacy pre-#573 snapshot),
   218	  # GRACEFULLY DEGRADE to the channel + stability check and WARN — never hard
   219	  # reject a legacy snapshot (that would block every release until a full rebuild).
   220	  member_col <- if (identical(kind, "functional")) "hgnc_id" else "entity_id"
   221	  membership_members <- NULL
   222	  if (all(c("cluster_id", member_col) %in% names(members)) && nrow(members) > 0L) {
   223	    grouped <- split(as.character(members[[member_col]]), as.character(members$cluster_id))
   224	    membership_members <- lapply(grouped, function(v) unique(v[!is.na(v) & nzchar(v)]))
   225	  }
   226	  validation_members <- validation$reference_members
   227	  if (!is.null(validation_members) && length(validation_members) > 0L) {
   228	    validation_members <- lapply(validation_members, function(v) unique(as.character(v)))
   229	    # MC2: a PRESENT attestation must be COMPLETE — its cluster-id key set must
   230	    # equal the served membership cluster set. A partial/malformed attestation
   231	    # (missing a served cluster that would otherwise mismatch) must NOT slip
   232	    # through the intersection-only same-partition proof: it is INCOHERENT, not
   233	    # legacy-absent. (The served set == the validated per_cluster set is enforced
   234	    # separately by the missing/orphan checks in assert_partition_coherent.)
   235	    served_cluster_ids <- if (!is.null(membership_members)) names(membership_members) else membership_ids
   236	    if (!setequal(names(validation_members), served_cluster_ids)) {
   237	      stop(.analysis_release_condition(
   238	        "release_source_incoherent",
   239	        sprintf(
   240	          "%s snapshot reference attestation is partial/malformed: cluster set does not cover the served membership",
   241	          kind
   242	        ),
   243	        kind = kind
   244	      ))
   245	    }
   246	  } else {
   247	    validation_members <- NULL
   248	    membership_members <- NULL # fully-absent (legacy) -> no reference to prove against
   249	    warning(sprintf(
   250	      paste0(
   251	        "release coherence: %s snapshot carries no persisted reference member sets ",
   252	        "(legacy snapshot); full member-set verification is unavailable, degraded to ",
   253	        "channel + stability check. Rebuild the snapshot (worker-executed) to attest coherence."
   254	      ),
   255	      kind
   256	    ), call. = FALSE)
   257	  }
   258	
   259	  tryCatch(
   260	    analysis_snapshot_assert_partition_coherent(
   261	      membership, per_cluster, kind,
   262	      membership_channel = membership_channel,
   263	      validation_channel = validation_channel,
   264	      membership_members = membership_members,
   265	      validation_members = validation_members,
   266	      require_coherence = TRUE
   267	    ),
   268	    error = function(e) {
   269	      stop(.analysis_release_condition(
   270	        "release_source_incoherent",
   271	        sprintf("%s snapshot failed hard coherence re-check: %s", kind, conditionMessage(e)),
   272	        kind = kind
   273	      ))
   274	    }
   275	  )
   276	  invisible(TRUE)
   277	}
   278	
   279	# --------------------------------------------------------------------------- #
   280	# Cross-layer lineage gates (step 2). Re-asserted immediately before insert.
   281	# --------------------------------------------------------------------------- #
   282	
   283	#' @noRd
   284	.analysis_release_dep_matches <- function(dependencies, key, entry) {
   285	  if (!is.list(dependencies)) {
   286	    return(FALSE)
   287	  }
   288	  dep <- dependencies[[key]]
   289	  if (!is.list(dep)) {
   290	    return(FALSE)
   291	  }
   292	  dep_id <- suppressWarnings(as.integer(dep$snapshot_id %||% NA))
   293	  dep_hash <- as.character(dep$payload_hash %||% "")
   294	  entry_id <- suppressWarnings(as.integer(entry$snapshot_id))
   295	  entry_hash <- as.character(entry$payload_hash %||% "")
   296	  !is.na(dep_id) && !is.na(entry_id) && identical(dep_id, entry_id) &&
   297	    nzchar(dep_hash) && nzchar(entry_hash) && identical(dep_hash, entry_hash)
   298	}
   299	
   300	#' Assert one shared source_data_version + correlation dependency lineage.
   301	#' @noRd
   302	.analysis_release_assert_lineage <- function(loaded) {
   303	  versions <- vapply(
   304	    loaded,
   305	    function(e) as.character(e$source_data_version %||% NA_character_),
   306	    character(1)
   307	  )
   308	  uniq <- unique(versions)
   309	  if (length(uniq) != 1L || is.na(uniq[[1]]) || !nzchar(uniq[[1]])) {
   310	    stop(.analysis_release_condition(
   311	      "release_source_version_mismatch",
   312	      sprintf(
   313	        "release layers do not share one source_data_version (found: %s)",
   314	        paste(ifelse(is.na(versions), "<NA>", versions), collapse = ", ")
   315	      )
   316	    ))
   317	  }
   318	
   319	  corr <- loaded[["phenotype_functional_correlations"]]
   320	  func <- loaded[["functional_clusters"]]
   321	  phen <- loaded[["phenotype_clusters"]]
   322	  if (!is.null(corr) && !is.null(func) && !is.null(phen)) {
   323	    dependencies <- analysis_snapshot_manifest_dependencies(corr$manifest)
   324	    ok <- .analysis_release_dep_matches(dependencies, "functional_clusters", func) &&
   325	      .analysis_release_dep_matches(dependencies, "phenotype_clusters", phen)
   326	    if (!ok) {
   327	      stop(.analysis_release_condition(
   328	        "release_dependency_lineage_mismatch",
   329	        paste(
   330	          "correlation snapshot dependency lineage does not match the pinned",
   331	          "functional/phenotype cluster snapshots (a cluster axis was refreshed",
   332	          "after the correlation was computed)"
   333	        )
   334	      ))
   335	    }
   336	  }
   337	  invisible(TRUE)
   338	}
   339	
   340	# --------------------------------------------------------------------------- #
   341	# File materialization
   342	# --------------------------------------------------------------------------- #
   343	
   344	#' Layer-appropriate payload object (its own bytes; NOT the snapshot payload_hash).
   345	#' @noRd
   346	.analysis_release_layer_payload <- function(snapshot, layer) {
   347	  if (isTRUE(layer$has_reproducibility)) {
   348	    list(
   349	      clusters = .analysis_release_rows(snapshot$clusters),
   350	      cluster_members = .analysis_release_rows(snapshot$cluster_members)
   351	    )
   352	  } else if (grepl("correlation", layer$analysis_type, fixed = TRUE)) {
   353	    list(correlations = .analysis_release_rows(snapshot$correlations))
   354	  } else {
   355	    list(
   356	      network_nodes = .analysis_release_rows(snapshot$network_nodes),
   357	      network_edges = .analysis_release_rows(snapshot$network_edges)
   358	    )
   359	  }
   360	}
   361	
   362	#' Assemble one materialized artifact with its own sha256 + byte_size.
   363	#' @noRd
   364	.analysis_release_artifact <- function(path, bytes, media_type) {
   365	  # Every materialized file path flows through here — assert containment at this
   366	  # single choke point (defense-in-depth alongside analysis_release_build_tar_gz).
   367	  .analysis_release_assert_safe_path(path)
   368	  list(
   369	    path = path,
   370	    bytes = bytes,
   371	    media_type = media_type,
   372	    sha256 = analysis_release_sha256(bytes),
   373	    byte_size = length(bytes)
   374	  )
   375	}
   376	
   377	#' README.md content bytes (scope + independent-verification recipe).
   378	#' @noRd
   379	.analysis_release_readme_bytes <- function(release_id, title, scope_statement, license,
   380	                                           source_data_version, layer_entries) {
   381	  layer_lines <- vapply(
   382	    layer_entries,
   383	    function(e) {
   384	      sprintf(
   385	        "- %s (snapshot_id %s, payload_hash %s)",
   386	        e$analysis_type, as.character(e$snapshot_id), substr(e$payload_hash, 1, 12)
   387	      )
   388	    },
   389	    character(1)
   390	  )
   391	  lines <- c(
   392	    sprintf("# %s", title %||% "SysNDD analysis-snapshot release"),
   393	    "",
   394	    sprintf("Release: `%s`", release_id),
   395	    sprintf("License: %s", license %||% "CC-BY-4.0"),
   396	    sprintf("Source data version: %s", source_data_version %||% "unknown"),
   397	    "",
   398	    "## Scope",
   399	    "",
   400	    scope_statement %||% paste(
   401	      "Immutable, content-addressed public export of the curated derived",
   402	      "cluster-analysis snapshots served by the SysNDD analysis API."
   403	    ),
   404	    "",
   405	    "## Layers",
   406	    "",
   407	    layer_lines,
   408	    "",
   409	    "## Verify",
   410	    "",
   411	    "1. `sha256sum -c checksums.sha256` verifies every file against its recorded digest.",
   412	    "2. `manifest.json` records each layer's source snapshot lineage",
   413	    "   (`snapshot_id`, `payload_hash`, `input_hash`) plus the reproducibility hash.",
   414	    "3. Each cluster layer's `reproducibility.json` hashes exactly to its",
   415	    "   `reproducibility_hash` and carries the inputs to independently recompute",
   416	    "   the served separation metric (modularity / silhouette).",
   417	    ""
   418	  )
   419	  charToRaw(enc2utf8(paste(lines, collapse = "\n")))
   420	}
     1	# functions/analysis-snapshot-release.R
     2	#
     3	# Build orchestrator for immutable, content-addressed public analysis-snapshot
     4	# RELEASES (#573 Slice A / Task A4). This is the correctness-critical layer: it
     5	# LOADS the active public snapshots, GATES them (available + hard coherence +
     6	# reproducibility presence + shared source-data version + dependency lineage +
     7	# TOCTOU), MATERIALIZES the release files, computes the content-addressed
     8	# identity, and PERSISTS via the A3 repository.
     9	#
    10	# Reuses (sourced by callers before this file / registered in load_modules):
    11	#   - analysis-snapshot-presets.R          : canonical JSON + parameter hashing
    12	#   - analysis-snapshot-coherence.R        : analysis_snapshot_assert_partition_coherent
    13	#   - analysis-snapshot-dependencies.R     : analysis_snapshot_manifest_dependencies
    14	#   - analysis-reproducibility.R           : analysis_reproducibility_decode_raw
    15	#   - analysis-snapshot-release-manifest.R : identity + manifest/checksums/tar helpers (A2)
    16	#   - analysis-snapshot-release-repository.R: analysis_release_insert/get/exists/... (A3)
    17	#
    18	# DEPENDENCY-INJECTION SEAMS. The three collaborators below are injectable so the
    19	# gates are deterministically unit-testable WITHOUT seeding the complex snapshot
    20	# tables. Their call-time defaults are the real functions; the body always calls
    21	# the seam, never the real function directly:
    22	#   - loader(analysis_type, parameter_hash, conn)  -> loaded snapshot
    23	#   - reproducibility_loader(snapshot_id, conn)    -> reproducibility row (or NULL)
    24	#   - coherence_assert(snapshot, kind)             -> invisibly / throws
    25	#
    26	# ERROR CONTRACT. The five classed conditions below are `c(<name>,"error",
    27	# "condition")`; the A5 service maps them to HTTP 400 (the contract has no 409):
    28	#   release_snapshot_not_available, release_source_incoherent,
    29	#   release_reproducibility_missing, release_source_version_mismatch,
    30	#   release_dependency_lineage_mismatch.
    31	# A DUPLICATE build is NOT an error: it returns the existing head with
    32	# created = FALSE (service -> 200).
    33	
    34	if (!exists("%||%", mode = "function")) {
    35	  `%||%` <- function(x, y) if (is.null(x)) y else x
    36	}
    37	
    38	# Materialization / gate / coherence helpers live in the sibling file (kept
    39	# separate so both stay under the 600-line ceiling). Registered together in
    40	# bootstrap/load_modules.R -- Task A8 -- and sourced together by the integration test.
    41	
    42	# --------------------------------------------------------------------------- #
    43	# Advisory locks (TOCTOU): serialize a build against a concurrent axis refresh.
    44	#
    45	# The build acquires the SAME per-preset advisory lock the axis refresh holds —
    46	# `analysis_snapshot_lock_name(analysis_type, parameter_hash)` — so a mid-flight
    47	# refresh of a source preset blocks the read (MySQL 8 lets one session hold many
    48	# named GET_LOCKs). Best-effort: engaged only on a real DBIConnection (a
    49	# pooled/NULL conn cannot hold a session-scoped GET_LOCK meaningfully), and a
    50	# lock-acquire timeout does NOT abort — the fresh pre-insert re-read below is the
    51	# invariant that always catches a snapshot that changed under us.
    52	# --------------------------------------------------------------------------- #
    53	
    54	#' Per-preset lock name — identical to the axis-refresh lock so they collide.
    55	#' @noRd
    56	.analysis_release_preset_lock_name <- function(analysis_type, parameter_hash) {
    57	  if (exists("analysis_snapshot_lock_name", mode = "function")) {
    58	    return(analysis_snapshot_lock_name(analysis_type, parameter_hash))
    59	  }
    60	  # Byte-identical fallback for minimal/test envs where the repository file that
    61	  # defines analysis_snapshot_lock_name() is not sourced.
    62	  paste0("asr:", substr(as.character(parameter_hash[[1]]), 1, 56))
    63	}
    64	
    65	#' @noRd
    66	.analysis_release_get_lock <- function(conn, name, timeout_seconds = 5L) {
    67	  if (!inherits(conn, "DBIConnection")) {
    68	    return(FALSE)
    69	  }
    70	  tryCatch(
    71	    {
    72	      rows <- DBI::dbGetQuery(
    73	        conn, "SELECT GET_LOCK(?, ?) AS acquired",
    74	        params = unname(list(name, as.integer(timeout_seconds)))
    75	      )
    76	      isTRUE(as.integer(rows$acquired[[1]]) == 1L)
    77	    },
    78	    error = function(e) FALSE
    79	  )
    80	}
    81	
    82	#' @noRd
    83	.analysis_release_release_named_lock <- function(conn, name) {
    84	  if (!inherits(conn, "DBIConnection")) {
    85	    return(invisible(FALSE))
    86	  }
    87	  tryCatch(
    88	    DBI::dbGetQuery(
    89	      conn, "SELECT RELEASE_LOCK(?) AS released",
    90	      params = unname(list(name))
    91	    ),
    92	    error = function(e) NULL
    93	  )
    94	  invisible(TRUE)
    95	}
    96	
    97	#' Default `lock_acquire` seam: acquire every per-preset lock (all-or-nothing).
    98	#'
    99	#' @return `list(ok, acquired, skipped)`. On a non-DBIConnection the locks are
   100	#'   skipped (`ok = TRUE, skipped = TRUE`) — the test/mirai path. On a real
   101	#'   connection, a failed acquisition releases any partially-held locks and
   102	#'   returns `ok = FALSE` so the caller raises `release_lock_unavailable`.
   103	#' @noRd
   104	.analysis_release_acquire_preset_locks <- function(conn, lock_names, timeout_seconds = 5L) {
   105	  if (!inherits(conn, "DBIConnection")) {
   106	    return(list(ok = TRUE, acquired = character(0), skipped = TRUE))
   107	  }
   108	  acquired <- character(0)
   109	  for (lock_name in lock_names) {
   110	    if (.analysis_release_get_lock(conn, lock_name, timeout_seconds)) {
   111	      acquired <- c(acquired, lock_name)
   112	    } else {
   113	      for (held in acquired) .analysis_release_release_named_lock(conn, held)
   114	      return(list(ok = FALSE, acquired = character(0), skipped = FALSE))
   115	    }
   116	  }
   117	  list(ok = TRUE, acquired = acquired, skipped = FALSE)
   118	}
   119	
   120	#' Fresh pre-insert re-read: re-load each layer via the loader seam (NOT the
   121	#' cached step-1 `loaded`) and confirm each layer's {snapshot_id, payload_hash}
   122	#' and the correlation dependencies still equal the pinned lineage. Throws a
   123	#' classed gate error if a source snapshot changed between the first read and the
   124	#' insert (the real TOCTOU catch).
   125	#' @noRd
   126	.analysis_release_verify_lineage_unchanged <- function(layer_specs, loaded, loader, conn) {
   127	  for (spec in layer_specs) {
   128	    at <- spec$analysis_type
   129	    entry <- loaded[[at]]
   130	    fresh <- loader(at, spec$parameter_hash, conn = conn)
   131	    status_code <- if (is.null(fresh)) "snapshot_missing" else (fresh$status_code %||% "snapshot_missing")
   132	    if (!identical(status_code, "available")) {
   133	      stop(.analysis_release_condition(
   134	        "release_snapshot_not_available",
   135	        sprintf("layer %s became unavailable before insert: %s", at, status_code),
   136	        analysis_type = at, status_code = status_code
   137	      ))
   138	    }
   139	    fresh_id <- suppressWarnings(as.integer(.analysis_release_manifest_scalar(fresh$manifest, "snapshot_id")))
   140	    fresh_hash <- as.character(.analysis_release_manifest_scalar(fresh$manifest, "payload_hash", NA_character_))
   141	    if (!identical(fresh_id, suppressWarnings(as.integer(entry$snapshot_id))) ||
   142	      !identical(fresh_hash, entry$payload_hash)) {
   143	      stop(.analysis_release_condition(
   144	        "release_dependency_lineage_mismatch",
   145	        sprintf(
   146	          "layer %s snapshot changed between read and insert (was snapshot_id %s, now %s)",
   147	          at, as.character(entry$snapshot_id), as.character(fresh_id)
   148	        ),
   149	        analysis_type = at
   150	      ))
   151	    }
   152	    if (identical(at, "phenotype_functional_correlations") &&
   153	      !is.null(loaded[["functional_clusters"]]) && !is.null(loaded[["phenotype_clusters"]])) {
   154	      fresh_deps <- analysis_snapshot_manifest_dependencies(fresh$manifest)
   155	      ok <- .analysis_release_dep_matches(fresh_deps, "functional_clusters", loaded[["functional_clusters"]]) &&
   156	        .analysis_release_dep_matches(fresh_deps, "phenotype_clusters", loaded[["phenotype_clusters"]])
   157	      if (!ok) {
   158	        stop(.analysis_release_condition(
   159	          "release_dependency_lineage_mismatch",
   160	          "correlation dependency lineage changed between read and insert",
   161	          analysis_type = at
   162	        ))
   163	      }
   164	    }
   165	  }
   166	  invisible(TRUE)
   167	}
   168	
   169	# --------------------------------------------------------------------------- #
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

exec
/bin/bash -lc "rg -n -C 6 'attach_partition|reference_members|partition_validation|validation_json' api/functions/analysis-snapshot-builder.R api/functions/analysis-snapshot-coherence.R api/tests/testthat/test-unit-analysis-snapshot-coherence.R api/tests/testthat/test-integration-analysis-snapshot-release-build.R api/tests/testthat/test-unit-analysis-snapshot-release-service.R && rg -n -C 8 'reference_members' api/functions/analysis-cluster-validation.R api/functions/analysis-phenotype-functions.R api/functions/analyses-functions.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-187-    phenotype_functional_correlations = make_corr_snap()
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-188-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-189-  snaps <- utils::modifyList(base, overrides)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-190-  function(analysis_type, parameter_hash, conn = NULL) snaps[[analysis_type]]
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-191-}
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-192-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:193:# A functional cluster snapshot whose manifest validation_json carries the served
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-194-# membership channel + the validation channel (the exp+db-vs-text-mining #514 case).
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-195-make_functional_snap_with_channels <- function(membership_channel, validation_channel) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-196-  snap <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:197:  snap$manifest$validation_json <- analysis_snapshot_canonical_json(list(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-198-    weight_channel = validation_channel,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-199-    membership_weight_channel = membership_channel
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-200-  ))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-201-  snap
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-202-}
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-203-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:204:# A functional cluster snapshot whose validation_json carries the H4 reference
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-205-# member-set attestation (in the stored hgnc_id space) + matching channels.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:206:make_functional_snap_with_reference <- function(reference_members) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-207-  snap <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:208:  snap$manifest$validation_json <- analysis_snapshot_canonical_json(list(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-209-    weight_channel = "experimental_database",
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-210-    membership_weight_channel = "experimental_database",
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:211:    reference_members = reference_members
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-212-  ))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-213-  snap
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-214-}
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-215-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-216-# A STATEFUL loader: returns the original snapshot on the first read of each
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-217-# preset, then a DIFFERENT {snapshot_id, payload_hash} for `changed_type` on the
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-355-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-356-    class = "release_lock_unavailable"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-357-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-358-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-359-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-360-test_that("build refuses a functional snapshot whose served channel != validation channel", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:361:  # Real coherence default reads validation_json; membership (combined_score) was
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-362-  # clustered on a different STRING channel than the validation scored (exp+db).
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-363-  loader <- make_loader(list(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-364-    functional_clusters = make_functional_snap_with_channels(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-365-      membership_channel = "combined_score", validation_channel = "experimental_database"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-366-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-367-  ))
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-475-  mismatched <- make_functional_snap_with_channels("combined_score", "experimental_database")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-476-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-477-    analysis_snapshot_release_assert_coherent(mismatched, "functional"),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-478-    class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-479-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-480-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:481:  # No validation_json -> channel comparison skipped (older snapshots still pass).
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-482-  no_channels <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-483-  expect_invisible(analysis_snapshot_release_assert_coherent(no_channels, "functional"))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-484-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-485-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-486-# --------------------------------------------------------------------------- #
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-487-# Success + idempotency (real release persistence).
--
api/functions/analysis-snapshot-coherence.R-176-}
api/functions/analysis-snapshot-coherence.R-177-
api/functions/analysis-snapshot-coherence.R-178-#' Express the validator's reference member sets in the STORED cluster_member id
api/functions/analysis-snapshot-coherence.R-179-#' space so a RELEASE can independently verify member-set coherence (#573 H4).
api/functions/analysis-snapshot-coherence.R-180-#'
api/functions/analysis-snapshot-coherence.R-181-#' The stored `analysis_snapshot_cluster_member` table keeps `hgnc_id` (functional)
api/functions/analysis-snapshot-coherence.R:182:#' or `entity_id` (phenotype). The validator's `reference_members` are STRING
api/functions/analysis-snapshot-coherence.R-183-#' protein ids (functional) / entity ids (phenotype). This maps them into the
api/functions/analysis-snapshot-coherence.R-184-#' stored space: phenotype is already entity_id; functional STRING_ids are mapped
api/functions/analysis-snapshot-coherence.R-185-#' to hgnc_id via the partition-independent gene dictionary, and any UNMAPPED
api/functions/analysis-snapshot-coherence.R-186-#' STRING_id is kept verbatim (fail-closed — it cannot equal a stored hgnc_id, so
api/functions/analysis-snapshot-coherence.R-187-#' an incoherent membership is never silently masked).
api/functions/analysis-snapshot-coherence.R-188-#'
api/functions/analysis-snapshot-coherence.R-189-#' @return A named list keyed by cluster_id (string) -> member-id character vector.
api/functions/analysis-snapshot-coherence.R-190-#' @noRd
api/functions/analysis-snapshot-coherence.R:191:analysis_snapshot_reference_members_store_space <- function(reference_members, membership, kind) {
api/functions/analysis-snapshot-coherence.R:192:  reference_members <- reference_members %||% list()
api/functions/analysis-snapshot-coherence.R:193:  if (length(reference_members) == 0L) {
api/functions/analysis-snapshot-coherence.R-194-    return(list())
api/functions/analysis-snapshot-coherence.R-195-  }
api/functions/analysis-snapshot-coherence.R-196-  if (identical(kind, "phenotype")) {
api/functions/analysis-snapshot-coherence.R:197:    return(lapply(reference_members, function(ids) unique(as.character(ids))))
api/functions/analysis-snapshot-coherence.R-198-  }
api/functions/analysis-snapshot-coherence.R-199-  dict <- .analysis_snapshot_string_to_hgnc_dict(membership)
api/functions/analysis-snapshot-coherence.R:200:  lapply(reference_members, function(sids) {
api/functions/analysis-snapshot-coherence.R-201-    sids <- as.character(sids)
api/functions/analysis-snapshot-coherence.R-202-    # Expand each STRING_id to the SET (union) of all its hgnc_ids so the mapped
api/functions/analysis-snapshot-coherence.R-203-    # reference set equals the served cluster_members set; an UNMAPPED STRING_id is
api/functions/analysis-snapshot-coherence.R-204-    # kept verbatim (fail-closed — it cannot equal a stored hgnc_id).
api/functions/analysis-snapshot-coherence.R-205-    mapped <- unlist(lapply(sids, function(s) {
api/functions/analysis-snapshot-coherence.R-206-      hg <- dict[[s]]
--
api/functions/analysis-snapshot-coherence.R-212-
api/functions/analysis-snapshot-coherence.R-213-#' Attach the additive partition provenance the join computed onto `partition`.
api/functions/analysis-snapshot-coherence.R-214-#'
api/functions/analysis-snapshot-coherence.R-215-#' Copies the served membership channel (#514, functional only — NA on the
api/functions/analysis-snapshot-coherence.R-216-#' phenotype axis is not stored) and the H4 reference member-set attestation
api/functions/analysis-snapshot-coherence.R-217-#' (#573, both axes) from the joined-tibble attributes onto `val$partition`, which
api/functions/analysis-snapshot-coherence.R:218:#' the builder persists into `validation_json`. `partition_validation` is excluded
api/functions/analysis-snapshot-coherence.R-219-#' from `payload_hash`, so this never churns `cluster_hash`.
api/functions/analysis-snapshot-coherence.R-220-#' @export
api/functions/analysis-snapshot-coherence.R:221:analysis_snapshot_attach_partition_provenance <- function(partition, joined) {
api/functions/analysis-snapshot-coherence.R-222-  channel <- attr(joined, "membership_weight_channel")
api/functions/analysis-snapshot-coherence.R-223-  if (!is.null(channel) && !all(is.na(channel))) {
api/functions/analysis-snapshot-coherence.R-224-    partition$membership_weight_channel <- channel
api/functions/analysis-snapshot-coherence.R-225-  }
api/functions/analysis-snapshot-coherence.R:226:  partition$reference_members <- attr(joined, "reference_members_store_space")
api/functions/analysis-snapshot-coherence.R-227-  partition
api/functions/analysis-snapshot-coherence.R-228-}
api/functions/analysis-snapshot-coherence.R-229-
api/functions/analysis-snapshot-coherence.R-230-#' Gate then join the validator's per-cluster scores onto the served membership.
api/functions/analysis-snapshot-coherence.R-231-#'
api/functions/analysis-snapshot-coherence.R-232-#' Single choke-point for the builder's two clustering presets: it asserts partition
--
api/functions/analysis-snapshot-coherence.R-243-analysis_snapshot_join_validated_clusters <- function(membership, val, kind) {
api/functions/analysis-snapshot-coherence.R-244-  membership_channel <- attr(membership, "weight_channel")
api/functions/analysis-snapshot-coherence.R-245-  validation_channel <- val$partition$weight_channel
api/functions/analysis-snapshot-coherence.R-246-
api/functions/analysis-snapshot-coherence.R-247-  # Member id space differs per axis: functional clusters over STRING node ids, phenotype
api/functions/analysis-snapshot-coherence.R-248-  # clusters over entity ids. Extract the served per-cluster member set (keyed by the same
api/functions/analysis-snapshot-coherence.R:249:  # integer cluster label as val$reference_members) for the same-partition proof.
api/functions/analysis-snapshot-coherence.R-250-  member_col <- if (identical(kind, "functional")) "STRING_id" else "entity_id"
api/functions/analysis-snapshot-coherence.R-251-  membership_members <- NULL
api/functions/analysis-snapshot-coherence.R-252-  if (all(c("identifiers", "cluster") %in% names(membership))) {
api/functions/analysis-snapshot-coherence.R-253-    membership_members <- stats::setNames(
api/functions/analysis-snapshot-coherence.R-254-      lapply(membership$identifiers, function(df) {
api/functions/analysis-snapshot-coherence.R-255-        if (is.data.frame(df) && member_col %in% names(df)) {
--
api/functions/analysis-snapshot-coherence.R-264-
api/functions/analysis-snapshot-coherence.R-265-  analysis_snapshot_assert_partition_coherent(
api/functions/analysis-snapshot-coherence.R-266-    membership, val$per_cluster, kind,
api/functions/analysis-snapshot-coherence.R-267-    membership_channel = membership_channel,
api/functions/analysis-snapshot-coherence.R-268-    validation_channel = validation_channel,
api/functions/analysis-snapshot-coherence.R-269-    membership_members = membership_members,
api/functions/analysis-snapshot-coherence.R:270:    validation_members = val$reference_members
api/functions/analysis-snapshot-coherence.R-271-  )
api/functions/analysis-snapshot-coherence.R-272-
api/functions/analysis-snapshot-coherence.R-273-  joined <- dplyr::left_join(
api/functions/analysis-snapshot-coherence.R-274-    dplyr::mutate(membership, cluster_id = as.character(cluster)),
api/functions/analysis-snapshot-coherence.R-275-    val$per_cluster,
api/functions/analysis-snapshot-coherence.R-276-    by = "cluster_id"
api/functions/analysis-snapshot-coherence.R-277-  )
api/functions/analysis-snapshot-coherence.R-278-  joined <- dplyr::select(joined, -cluster_id)
api/functions/analysis-snapshot-coherence.R-279-  attr(joined, "membership_weight_channel") <- membership_channel %||% NA_character_
api/functions/analysis-snapshot-coherence.R-280-  # #573 H4: carry the validator's reference member sets, expressed in the STORED
api/functions/analysis-snapshot-coherence.R:281:  # cluster_member id space, so the builder can persist them into validation_json
api/functions/analysis-snapshot-coherence.R-282-  # and a RELEASE can later re-prove member-set coherence independently. Attached
api/functions/analysis-snapshot-coherence.R-283-  # as an attribute (not mutated onto `val`, which is a by-value copy here).
api/functions/analysis-snapshot-coherence.R:284:  attr(joined, "reference_members_store_space") <- analysis_snapshot_reference_members_store_space(
api/functions/analysis-snapshot-coherence.R:285:    val$reference_members, membership, kind
api/functions/analysis-snapshot-coherence.R-286-  )
api/functions/analysis-snapshot-coherence.R-287-  joined
api/functions/analysis-snapshot-coherence.R-288-}
--
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-116-mk_val_with_members <- function(members, channel = "experimental_database") {
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-117-  ids <- names(members)
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-118-  list(
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-119-    per_cluster = tibble::tibble(
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-120-      cluster_id = ids, jaccard_mean = rep(0.8, length(ids)), jaccard_n_resamples = rep(50L, length(ids))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-121-    ),
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:122:    reference_members = lapply(members, as.character),
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-123-    partition = list(weight_channel = channel)
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-124-  )
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-125-}
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-126-
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-127-test_that("same cluster-id labels but DIFFERENT member content is refused (same-partition proof)", {
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-128-  # ids match, channels match, but cluster 1 holds different members on each side.
--
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-160-  expect_error(analysis_snapshot_join_validated_clusters(mbad, v, kind = "functional"),
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-161-               "content", ignore.case = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-162-})
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-163-
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-164-# --- #573 H4: reference member sets expressed in the STORED id space ---
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-165-
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:166:test_that("reference_members_store_space maps functional STRING_id -> hgnc_id via served identifiers", {
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-167-  membership <- tibble::tibble(
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-168-    cluster = c(1L, 2L),
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-169-    identifiers = list(
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-170-      tibble::tibble(STRING_id = c("9606.A", "9606.B"), hgnc_id = c("HGNC:1", "HGNC:2")),
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-171-      tibble::tibble(STRING_id = c("9606.C"), hgnc_id = c("HGNC:3"))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-172-    )
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-173-  )
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-174-  ref <- list("1" = c("9606.A", "9606.B"), "2" = c("9606.C"))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:175:  out <- analysis_snapshot_reference_members_store_space(ref, membership, "functional")
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-176-  expect_setequal(out[["1"]], c("HGNC:1", "HGNC:2"))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-177-  expect_setequal(out[["2"]], "HGNC:3")
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-178-
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-179-  # an UNMAPPED STRING_id is kept verbatim (fail-closed: cannot equal a stored hgnc_id)
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-180-  ref2 <- list("1" = c("9606.A", "9606.UNKNOWN"))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:181:  out2 <- analysis_snapshot_reference_members_store_space(ref2, membership, "functional")
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-182-  expect_setequal(out2[["1"]], c("HGNC:1", "9606.UNKNOWN"))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-183-})
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-184-
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:185:test_that("reference_members_store_space passes phenotype entity ids through unchanged", {
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-186-  ref <- list("1" = c("10", "11"), "2" = c("12"))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:187:  out <- analysis_snapshot_reference_members_store_space(ref, NULL, "phenotype")
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-188-  expect_setequal(out[["1"]], c("10", "11"))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-189-  expect_setequal(out[["2"]], "12")
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:190:  expect_equal(length(analysis_snapshot_reference_members_store_space(list(), NULL, "phenotype")), 0L)
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-191-})
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-192-
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-193-test_that("join attaches the store-space reference attestation for the builder to persist", {
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-194-  members <- list("1" = c("9606.A", "9606.B"), "2" = c("9606.C", "9606.D"))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-195-  m <- mk_membership_with_members(members, id_col = "STRING_id")
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-196-  v <- mk_val_with_members(members)
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-197-  joined <- analysis_snapshot_join_validated_clusters(m, v, kind = "functional")
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:198:  attest <- attr(joined, "reference_members_store_space")
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-199-  expect_false(is.null(attest))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-200-  expect_setequal(names(attest), c("1", "2"))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-201-})
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-202-
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:203:test_that("reference_members_store_space expands a one-to-many STRING_id to ALL its hgnc_ids (MC1)", {
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-204-  # A STRING protein that joins two hgnc records: the served cluster_members hold
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-205-  # BOTH, so the mapped reference must hold BOTH (a first-wins dict false-rejects).
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-206-  membership <- tibble::tibble(
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-207-    cluster = 1L,
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-208-    identifiers = list(tibble::tibble(
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-209-      STRING_id = c("9606.A", "9606.A", "9606.B"),
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-210-      hgnc_id = c("HGNC:1", "HGNC:1b", "HGNC:2")
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-211-    ))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-212-  )
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-213-  ref <- list("1" = c("9606.A", "9606.B"))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:214:  out <- analysis_snapshot_reference_members_store_space(ref, membership, "functional")
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-215-  expect_setequal(out[["1"]], c("HGNC:1", "HGNC:1b", "HGNC:2"))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R-216-})
--
api/functions/analysis-snapshot-builder.R-395-      val <- validate_functional_clusters(gene_ids, resolution = 1.0, n_resamples = n_res)
api/functions/analysis-snapshot-builder.R-396-      # #514: refuse to publish an incoherent snapshot (stale membership vs fresh
api/functions/analysis-snapshot-builder.R-397-      # validation, or a channel disagreement) BEFORE joining. Also carries the served
api/functions/analysis-snapshot-builder.R-398-      # membership channel forward as a `membership_weight_channel` attribute.
api/functions/analysis-snapshot-builder.R-399-      clusters <- analysis_snapshot_join_validated_clusters(clusters, val, kind = "functional")
api/functions/analysis-snapshot-builder.R-400-      # Additive provenance (#514 channel + #573 H4 reference member sets) into
api/functions/analysis-snapshot-builder.R:401:      # validation_json; excluded from payload_hash, so no cluster_hash churn.
api/functions/analysis-snapshot-builder.R:402:      val$partition <- analysis_snapshot_attach_partition_provenance(val$partition, clusters)
api/functions/analysis-snapshot-builder.R-403-      built <- analysis_snapshot_build_cluster_rows(clusters, cluster_kind = "functional")
api/functions/analysis-snapshot-builder.R-404-      # #512: additive self-reproducing bundle (LCC edge list + full membership +
api/functions/analysis-snapshot-builder.R-405-      # served modularity). Best-effort; a NULL bundle never blocks the refresh.
api/functions/analysis-snapshot-builder.R-406-      reproducibility <- analysis_snapshot_functional_reproducibility(
api/functions/analysis-snapshot-builder.R-407-        gene_ids, val = val, params = list(algorithm = params$algorithm)
api/functions/analysis-snapshot-builder.R-408-      )
api/functions/analysis-snapshot-builder.R-409-      list(kind = "clusters", raw = clusters, clusters = built$clusters,
api/functions/analysis-snapshot-builder.R-410-           members = built$members, row_counts = built$row_counts,
api/functions/analysis-snapshot-builder.R:411:           partition_validation = val$partition, reproducibility = reproducibility)
api/functions/analysis-snapshot-builder.R-412-    },
api/functions/analysis-snapshot-builder.R-413-    phenotype_clusters = {
api/functions/analysis-snapshot-builder.R-414-      clusters <- generate_phenotype_clusters()
api/functions/analysis-snapshot-builder.R-415-      n_res <- as.integer(Sys.getenv("ANALYSIS_CLUSTER_VALIDATION_RESAMPLES", "100"))
api/functions/analysis-snapshot-builder.R-416-      input_matrix <- generate_phenotype_cluster_input()$matrix
api/functions/analysis-snapshot-builder.R-417-      val <- validate_phenotype_clusters(
api/functions/analysis-snapshot-builder.R-418-        input_matrix,
api/functions/analysis-snapshot-builder.R-419-        quali_sup_var = 1:1, quanti_sup_var = 2:4, n_resamples = n_res
api/functions/analysis-snapshot-builder.R-420-      )
api/functions/analysis-snapshot-builder.R-421-      # #514: same coherence gate as the functional axis (phenotype has no channel).
api/functions/analysis-snapshot-builder.R-422-      clusters <- analysis_snapshot_join_validated_clusters(clusters, val, kind = "phenotype")
api/functions/analysis-snapshot-builder.R:423:      val$partition <- analysis_snapshot_attach_partition_provenance(val$partition, clusters)
api/functions/analysis-snapshot-builder.R-424-      built <- analysis_snapshot_build_cluster_rows(clusters, cluster_kind = "phenotype")
api/functions/analysis-snapshot-builder.R-425-      # #512: additive bundle (MCA coords + membership + served silhouette).
api/functions/analysis-snapshot-builder.R-426-      reproducibility <- analysis_snapshot_phenotype_reproducibility(
api/functions/analysis-snapshot-builder.R-427-        input_matrix, clusters, val = val
api/functions/analysis-snapshot-builder.R-428-      )
api/functions/analysis-snapshot-builder.R-429-      list(kind = "clusters", raw = clusters, clusters = built$clusters,
api/functions/analysis-snapshot-builder.R-430-           members = built$members, row_counts = built$row_counts,
api/functions/analysis-snapshot-builder.R:431:           partition_validation = val$partition, reproducibility = reproducibility)
api/functions/analysis-snapshot-builder.R-432-    },
api/functions/analysis-snapshot-builder.R-433-    phenotype_correlations = {
api/functions/analysis-snapshot-builder.R-434-      rows <- generate_phenotype_correlations_mem(
api/functions/analysis-snapshot-builder.R-435-        filter = params$filter,
api/functions/analysis-snapshot-builder.R-436-        min_abs_correlation = NULL
api/functions/analysis-snapshot-builder.R-437-      )
--
api/functions/analysis-snapshot-builder.R-497-      row_counts$network_metadata <- payload$metadata %||% list()
api/functions/analysis-snapshot-builder.R-498-    }
api/functions/analysis-snapshot-builder.R-499-    # `reproducibility` is an ADDITIVE artifact (raw gzip blob) and must stay out
api/functions/analysis-snapshot-builder.R-500-    # of the payload hash so it never perturbs the cluster/payload hash (#512 is a
api/functions/analysis-snapshot-builder.R-501-    # Wave-1 additive change: no cluster_hash churn, no LLM-cache invalidation).
api/functions/analysis-snapshot-builder.R-502-    payload_hash <- analysis_snapshot_payload_hash(
api/functions/analysis-snapshot-builder.R:503:      payload[setdiff(names(payload), c("raw", "partition_validation", "reproducibility"))]
api/functions/analysis-snapshot-builder.R-504-    )
api/functions/analysis-snapshot-builder.R-505-    input_provenance <- list(
api/functions/analysis-snapshot-builder.R-506-      analysis_type = normalized$analysis_type,
api/functions/analysis-snapshot-builder.R-507-      params = normalized$params,
api/functions/analysis-snapshot-builder.R-508-      source_data_version = source_data_version
api/functions/analysis-snapshot-builder.R-509-    )
--
api/functions/analysis-snapshot-builder.R-541-          source_data_version = source_data_version,
api/functions/analysis-snapshot-builder.R-542-          parameters_json = normalized$parameters_json,
api/functions/analysis-snapshot-builder.R-543-          input_hash = input_hash,
api/functions/analysis-snapshot-builder.R-544-          payload_hash = payload_hash,
api/functions/analysis-snapshot-builder.R-545-          algorithm_name = normalized$params$algorithm %||% normalized$params$cluster_type %||% NA_character_,
api/functions/analysis-snapshot-builder.R-546-          row_counts = row_counts,
api/functions/analysis-snapshot-builder.R:547:          validation = payload$partition_validation,   # NULL for non-clustering presets
api/functions/analysis-snapshot-builder.R-548-          db_release_version = db_release_version,
api/functions/analysis-snapshot-builder.R-549-          db_release_commit  = db_release_commit
api/functions/analysis-snapshot-builder.R-550-        ),
api/functions/analysis-snapshot-builder.R-551-        conn = txn_conn
api/functions/analysis-snapshot-builder.R-552-      )
api/functions/analysis-snapshot-builder.R-553-
api/functions/analysis-cluster-validation.R-22-
api/functions/analysis-cluster-validation.R-23-# Mean over the non-NA recoveries; NA_real_ when a cluster was never testable in
api/functions/analysis-cluster-validation.R-24-# any resample (avoids NaN from mean(<all-NA>, na.rm = TRUE)).
api/functions/analysis-cluster-validation.R-25-jaccard_mean_non_na <- function(v) {
api/functions/analysis-cluster-validation.R-26-  v <- v[!is.na(v)]
api/functions/analysis-cluster-validation.R-27-  if (length(v)) mean(v) else NA_real_
api/functions/analysis-cluster-validation.R-28-}
api/functions/analysis-cluster-validation.R-29-
api/functions/analysis-cluster-validation.R:30:cluster_max_jaccard <- function(reference_members, bootstrap_clusters, present_ids) {
api/functions/analysis-cluster-validation.R-31-  jac <- function(a, b) {
api/functions/analysis-cluster-validation.R-32-    a <- intersect(a, present_ids)
api/functions/analysis-cluster-validation.R-33-    if (length(a) == 0) return(NA_real_)
api/functions/analysis-cluster-validation.R-34-    inter <- length(intersect(a, b))
api/functions/analysis-cluster-validation.R-35-    union <- length(union(a, b))
api/functions/analysis-cluster-validation.R-36-    if (union == 0) 0 else inter / union
api/functions/analysis-cluster-validation.R-37-  }
api/functions/analysis-cluster-validation.R:38:  vapply(reference_members, function(ref) {
api/functions/analysis-cluster-validation.R-39-    if (length(bootstrap_clusters) == 0) return(NA_real_)
api/functions/analysis-cluster-validation.R-40-    vals <- vapply(bootstrap_clusters, function(bc) jac(ref, bc), numeric(1))
api/functions/analysis-cluster-validation.R-41-    vals <- vals[!is.na(vals)]
api/functions/analysis-cluster-validation.R-42-    # A reference cluster with no members present in this subsample yields an
api/functions/analysis-cluster-validation.R-43-    # all-NA recovery vector; report NA_real_ (not max(numeric(0)) == -Inf, which
api/functions/analysis-cluster-validation.R-44-    # would poison the per-cluster mean) so this resample is simply not counted
api/functions/analysis-cluster-validation.R-45-    # for that cluster.
api/functions/analysis-cluster-validation.R-46-    if (length(vals) == 0) return(NA_real_)
--
api/functions/analysis-cluster-validation.R-169-    jaccard_n_resamples = vapply(per_cluster_acc, function(v) sum(!is.na(v)), integer(1)),
api/functions/analysis-cluster-validation.R-170-    bootstrap_seed = seed
api/functions/analysis-cluster-validation.R-171-  )
api/functions/analysis-cluster-validation.R-172-  list(
api/functions/analysis-cluster-validation.R-173-    per_cluster = per_cluster,
api/functions/analysis-cluster-validation.R-174-    # #514: the reference partition members (STRING node ids) keyed by cluster_id, so
api/functions/analysis-cluster-validation.R-175-    # the snapshot coherence gate can prove the served membership describes the SAME
api/functions/analysis-cluster-validation.R-176-    # partition the validation scored — not merely the same cluster-id labels.
api/functions/analysis-cluster-validation.R:177:    reference_members = lapply(ref_members, as.character),
api/functions/analysis-cluster-validation.R-178-    partition = list(
api/functions/analysis-cluster-validation.R-179-      validation_schema_version = "2.0",
api/functions/analysis-cluster-validation.R-180-      algorithm = "leiden", weighted = TRUE, n_iterations = -1L,
api/functions/analysis-cluster-validation.R-181-      resolution_parameter = resolution,
api/functions/analysis-cluster-validation.R-182-      modularity = modularity, modularity_scope = "full_partition",
api/functions/analysis-cluster-validation.R-183-      # The z-score/null/giant-component below are computed on the LARGEST
api/functions/analysis-cluster-validation.R-184-      # CONNECTED COMPONENT; `modularity_lcc` is that LCC Q_obs so a consumer can
api/functions/analysis-cluster-validation.R-185-      # reconcile the z with a modularity value (the headline `modularity` above is
--
api/functions/analysis-cluster-validation.R-394-    jaccard_n_resamples = vapply(per_cluster_acc, function(v) sum(!is.na(v)), integer(1)),
api/functions/analysis-cluster-validation.R-395-    bootstrap_seed = seed,
api/functions/analysis-cluster-validation.R-396-    silhouette_mean = per_sil
api/functions/analysis-cluster-validation.R-397-  )
api/functions/analysis-cluster-validation.R-398-  list(
api/functions/analysis-cluster-validation.R-399-    per_cluster = per_cluster,
api/functions/analysis-cluster-validation.R-400-    # #514: reference partition members (entity ids) keyed by cluster_id for the
api/functions/analysis-cluster-validation.R-401-    # snapshot coherence gate (same-partition proof, not just same labels).
api/functions/analysis-cluster-validation.R:402:    reference_members = lapply(ref_members, as.character),
api/functions/analysis-cluster-validation.R-403-    partition = list(
api/functions/analysis-cluster-validation.R-404-      validation_schema_version = "2.0",
api/functions/analysis-cluster-validation.R-405-      algorithm = "mca_hcpc", k = n_clusters, k_selected = as.integer(data_driven_k),
api/functions/analysis-cluster-validation.R-406-      hcpc_nb_clust = as.integer(data_driven_k),
api/functions/analysis-cluster-validation.R-407-      # kk = Inf -> full Ward tree + real k-means consolidation actually runs (#509).
api/functions/analysis-cluster-validation.R-408-      hcpc_kk = "Inf", consolidation = TRUE,
api/functions/analysis-cluster-validation.R-409-      active_feature_set = mca_prov,
api/functions/analysis-cluster-validation.R-410-      ncp_used = 8L,

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-manifest.R | sed -n '1,360p'; nl -ba api/functions/analysis-snapshot-release-repository.R | sed -n '1,540p'; nl -ba api/endpoints/analysis_endpoints.R | sed -n '1,420p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
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
   261	  on.exit(unlink(src_dir, recursive = TRUE, force = TRUE), add = TRUE)
   262	
   263	  for (path in paths) {
   264	    full_path <- file.path(src_dir, path)
   265	    dir.create(dirname(full_path), recursive = TRUE, showWarnings = FALSE)
   266	    writeBin(named_raw_list[[path]], full_path)
   267	  }
   268	
   269	  tar_file <- tempfile("analysis-release-", fileext = ".tar")
   270	  on.exit(unlink(tar_file, force = TRUE), add = TRUE)
   271	
   272	  previous_wd <- setwd(src_dir)
   273	  on.exit(setwd(previous_wd), add = TRUE)
   274	  # tar = "internal" forces R's built-in (pure-R) tar writer so the archive
   275	  # never depends on a system `tar` binary being present/compatible.
   276	  utils::tar(tarfile = tar_file, files = paths, compression = "none", tar = "internal")
   277	
   278	  memCompress(readBin(tar_file, "raw", n = file.info(tar_file)$size), type = "gzip")
   279	}
     1	# functions/analysis-snapshot-release-repository.R
     2	#
     3	# DB persistence for immutable public analysis-snapshot RELEASES (#573 Slice
     4	# A / Task A3). Reads/writes the three tables added by migration
     5	# `045_add_analysis_snapshot_release.sql`: `analysis_snapshot_release` (head),
     6	# `analysis_snapshot_release_member` (per-layer lineage), and
     7	# `analysis_snapshot_release_file` (per-archive-file blob + checksum).
     8	#
     9	# Deliberately self-contained: uses raw `DBI::dbGetQuery()` / `DBI::dbExecute()`
    10	# with bound `?` params (never string-interpolated identifiers) instead of the
    11	# `db_execute_query()`/`db_execute_statement()` wrappers in `db-helpers.R`.
    12	# Those wrappers eagerly stringify every param for a DEBUG log line — fine for
    13	# scalar params, but for a LONGBLOB param (`list(<raw>)`) that would deparse
    14	# the whole multi-MB blob on every call, mirroring the exact trap already
    15	# documented in `analysis-reproducibility.R`'s
    16	# `analysis_snapshot_insert_reproducibility()`. Blob columns (`bundle_gzip`,
    17	# `content_gzip`) are always bound as `list(<raw vector>)`, per DBI's blob
    18	# binding convention (verified against RMariaDB).
    19	#
    20	# `conn` is a REQUIRED, explicit DBI connection on every function here (no
    21	# `conn = NULL` global-pool fallback like the sibling
    22	# `analysis-snapshot-repository.R`). Two reasons: (1) `analysis_release_insert()`
    23	# wraps its writes in one `DBI::dbWithTransaction(conn, {...})`, which needs a
    24	# real `DBIConnection`, not a `Pool`; and (2) blob binding via
    25	# `list(<raw vector>)` needs the same. Callers (services, later tasks) are
    26	# responsible for resolving/checking out a real connection before calling in.
    27	#
    28	# IMPORTANT test/caller trap (verified live against RMariaDB): calling
    29	# `analysis_release_insert()` on a connection that already has an open
    30	# transaction raises "Nested transactions not supported" (RMariaDB's
    31	# `dbBegin()` rejects it) — the same trap documented in
    32	# `test-integration-additive-ontology-terms.R` /
    33	# `test-integration-ontology-mapping-refresh.R`. Never call it from inside
    34	# `with_test_db_transaction()`.
    35	
    36	if (!exists("%||%", mode = "function")) {
    37	  `%||%` <- function(x, y) if (is.null(x)) y else x
    38	}
    39	
    40	# --------------------------------------------------------------------------- #
    41	# Internal helpers
    42	# --------------------------------------------------------------------------- #
    43	
    44	#' Unwrap a single-row blob column value to its raw vector.
    45	#' @noRd
    46	.analysis_release_blob <- function(x) {
    47	  if (is.list(x)) x <- x[[1]]
    48	  x
    49	}
    50	
    51	#' Coerce a possibly-NULL scalar to a bindable value, defaulting to NA.
    52	#' @noRd
    53	.analysis_release_chr <- function(x) {
    54	  if (is.null(x) || length(x) == 0L) return(NA_character_)
    55	  as.character(x[[1]])
    56	}
    57	
    58	#' Head-table column list shared by SELECTs (excludes the `bundle_gzip` blob
    59	#' so metadata reads never pull the multi-MB bundle unless explicitly asked
    60	#' for via `analysis_release_get_bundle()`).
    61	#' @noRd
    62	.analysis_release_head_columns <- paste(
    63	  "release_id, release_version, title, status, manifest_schema_version,",
    64	  "content_digest, manifest_sha256, bundle_sha256, bundle_bytes,",
    65	  "source_data_version, db_release_version, db_release_commit, scope_statement,",
    66	  "license, file_count, total_bytes, created_by_user_id, created_at,",
    67	  "published_at, updated_at, zenodo_record_id, zenodo_record_url,",
    68	  "version_doi, concept_doi, last_error_message"
    69	)
    70	
    71	#' Convert a single-row data.frame (as returned by dbGetQuery) into a plain
    72	#' named list, one element per column.
    73	#' @noRd
    74	.analysis_release_row_to_list <- function(rows, i = 1L) {
    75	  as.list(rows[i, , drop = FALSE])
    76	}
    77	
    78	# --------------------------------------------------------------------------- #
    79	# Write
    80	# --------------------------------------------------------------------------- #
    81	
    82	#' Insert a release head + its members + its files in ONE transaction.
    83	#'
    84	#' `release_head` is a named list with (at least) `release_id`,
    85	#' `manifest_schema_version`, `content_digest`, `manifest_sha256`,
    86	#' `bundle_sha256`, `bundle_gzip` (raw), plus optional `release_version`,
    87	#' `title`, `source_data_version`, `db_release_version`, `db_release_commit`,
    88	#' `scope_statement`, `license` (defaults `"CC-BY-4.0"`),
    89	#' `created_by_user_id`. Always inserted with `status = 'draft'` —
    90	#' `analysis_release_publish()` is the only way to flip it.
    91	#'
    92	#' `bundle_bytes`, `file_count`, `total_bytes` are derived here (not trusted
    93	#' from the caller) from `bundle_gzip`/`files` directly, so they can never
    94	#' drift from the actual stored bytes.
    95	#'
    96	#' `members` is a list of `list(analysis_type, parameter_hash, snapshot_id,
    97	#' input_hash, payload_hash, schema_version, reproducibility_hash = NULL,
    98	#' role = "layer")`.
    99	#'
   100	#' `files` is a list of `list(file_path, content_sha256, byte_size,
   101	#' media_type = "application/json", content_gzip)` (`content_gzip` a raw
   102	#' vector).
   103	#'
   104	#' @return chr, the inserted `release_id`.
   105	#' @export
   106	analysis_release_insert <- function(release_head, members = list(), files = list(), conn) {
   107	  release_id <- .analysis_release_chr(release_head$release_id)
   108	  if (is.na(release_id) || !nzchar(release_id)) {
   109	    stop("release_head$release_id is required", call. = FALSE)
   110	  }
   111	  bundle_gzip <- release_head$bundle_gzip
   112	  if (!is.raw(bundle_gzip)) {
   113	    stop("release_head$bundle_gzip must be a raw vector", call. = FALSE)
   114	  }
   115	
   116	  file_count <- length(files)
   117	  total_bytes <- sum(vapply(files, function(f) as.numeric(f$byte_size %||% 0), numeric(1)))
   118	
   119	  DBI::dbWithTransaction(conn, {
   120	    DBI::dbExecute(
   121	      conn,
   122	      "INSERT INTO analysis_snapshot_release (
   123	         release_id, release_version, title, status, manifest_schema_version,
   124	         content_digest, manifest_sha256, bundle_sha256, bundle_gzip, bundle_bytes,
   125	         source_data_version, db_release_version, db_release_commit, scope_statement,
   126	         license, file_count, total_bytes, created_by_user_id
   127	       ) VALUES (?, ?, ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
   128	      params = unname(list(
   129	        release_id,
   130	        .analysis_release_chr(release_head$release_version),
   131	        .analysis_release_chr(release_head$title),
   132	        .analysis_release_chr(release_head$manifest_schema_version),
   133	        .analysis_release_chr(release_head$content_digest),
   134	        .analysis_release_chr(release_head$manifest_sha256),
   135	        .analysis_release_chr(release_head$bundle_sha256),
   136	        list(bundle_gzip),
   137	        length(bundle_gzip),
   138	        .analysis_release_chr(release_head$source_data_version),
   139	        .analysis_release_chr(release_head$db_release_version),
   140	        .analysis_release_chr(release_head$db_release_commit),
   141	        .analysis_release_chr(release_head$scope_statement),
   142	        release_head$license %||% "CC-BY-4.0",
   143	        as.integer(file_count),
   144	        as.numeric(total_bytes),
   145	        if (is.null(release_head$created_by_user_id)) NA_integer_ else as.integer(release_head$created_by_user_id)
   146	      ))
   147	    )
   148	
   149	    for (m in members) {
   150	      DBI::dbExecute(
   151	        conn,
   152	        "INSERT INTO analysis_snapshot_release_member (
   153	           release_id, analysis_type, parameter_hash, snapshot_id, input_hash,
   154	           payload_hash, schema_version, reproducibility_hash, role
   155	         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
   156	        params = unname(list(
   157	          release_id,
   158	          .analysis_release_chr(m$analysis_type),
   159	          .analysis_release_chr(m$parameter_hash),
   160	          as.numeric(m$snapshot_id),
   161	          .analysis_release_chr(m$input_hash),
   162	          .analysis_release_chr(m$payload_hash),
   163	          .analysis_release_chr(m$schema_version),
   164	          .analysis_release_chr(m$reproducibility_hash),
   165	          m$role %||% "layer"
   166	        ))
   167	      )
   168	    }
   169	
   170	    for (f in files) {
   171	      DBI::dbExecute(
   172	        conn,
   173	        "INSERT INTO analysis_snapshot_release_file (
   174	           release_id, file_path, content_sha256, byte_size, media_type, content_gzip
   175	         ) VALUES (?, ?, ?, ?, ?, ?)",
   176	        params = unname(list(
   177	          release_id,
   178	          .analysis_release_chr(f$file_path),
   179	          .analysis_release_chr(f$content_sha256),
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
   481	    params = unname(list(as.character(release_id)))
   482	  )
   483	  affected > 0L
   484	}
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
   361	#* - Approved-public data only.
   362	#* - See the functional sibling above for why these routes live in this file.
   363	#*
   364	#* @tag analysis
   365	#* @serializer json list(na="string", auto_unbox=TRUE)
   366	#*
   367	#* @response 200 OK. Returns { reproducibility_hash, kind, byte_size, snapshot_id, bundle }.
   368	#* @response 404 Not Found. No public snapshot or no reproducibility bundle yet.
   369	#*
   370	#* @get phenotype_clustering/reproducibility
   371	function(res) {
   372	  analysis_reproducibility_endpoint("phenotype_clusters", res)
   373	}
   374	
   375	
   376	## -------------------------------------------------------------------##
   377	## Analysis-snapshot RELEASES: public read routes (#573 Slice A / Task A6)
   378	## -------------------------------------------------------------------##
   379	#
   380	# Immutable, content-addressed public releases of the analysis snapshots
   381	# above (see services/analysis-snapshot-release-service.R for the full
   382	# contract). DB-only, published-only: every svc_release_* read is pinned to
   383	# status = "published", so an unknown release id and a draft release id are
   384	# indistinguishable to the caller -- both resolve to a plain 404. `conn =
   385	# pool` mirrors the established global-pool endpoint pattern (see
   386	# endpoints/seo_endpoints.R) -- the A3 release repository requires an
   387	# explicit connection on every call (no NULL/global-pool fallback), unlike
   388	# the sibling analysis-snapshot-repository.R.
   389	#
   390	# DECLARATION ORDER IS LOAD-BEARING: `releases/latest` MUST stay declared
   391	# before `releases/<release_id>` below -- Plumber matches routes in
   392	# declaration order, so the dynamic `<release_id>` segment would otherwise
   393	# shadow the literal "latest" segment (the same class of bug documented in
   394	# AGENTS.md's `/status/_list` vs `/status/<status_id_requested>` lesson). A
   395	# static test (test-integration-analysis-release-endpoints.R) guards this
   396	# ordering directly against this source file.
   397	
   398	analysis_release_query_int <- function(value, default) {
   399	  parsed <- suppressWarnings(as.integer(analysis_endpoint_scalar(value, default)))
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

exec
/bin/bash -lc "nl -ba api/endpoints/analysis_endpoints.R | sed -n '398,580p'; nl -ba api/functions/analysis-snapshot-release-repository.R | sed -n '100,490p'; nl -ba api/endpoints/admin_analysis_snapshot_endpoints.R | sed -n '115,400p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
   398	analysis_release_query_int <- function(value, default) {
   399	  parsed <- suppressWarnings(as.integer(analysis_endpoint_scalar(value, default)))
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
   100	#' `files` is a list of `list(file_path, content_sha256, byte_size,
   101	#' media_type = "application/json", content_gzip)` (`content_gzip` a raw
   102	#' vector).
   103	#'
   104	#' @return chr, the inserted `release_id`.
   105	#' @export
   106	analysis_release_insert <- function(release_head, members = list(), files = list(), conn) {
   107	  release_id <- .analysis_release_chr(release_head$release_id)
   108	  if (is.na(release_id) || !nzchar(release_id)) {
   109	    stop("release_head$release_id is required", call. = FALSE)
   110	  }
   111	  bundle_gzip <- release_head$bundle_gzip
   112	  if (!is.raw(bundle_gzip)) {
   113	    stop("release_head$bundle_gzip must be a raw vector", call. = FALSE)
   114	  }
   115	
   116	  file_count <- length(files)
   117	  total_bytes <- sum(vapply(files, function(f) as.numeric(f$byte_size %||% 0), numeric(1)))
   118	
   119	  DBI::dbWithTransaction(conn, {
   120	    DBI::dbExecute(
   121	      conn,
   122	      "INSERT INTO analysis_snapshot_release (
   123	         release_id, release_version, title, status, manifest_schema_version,
   124	         content_digest, manifest_sha256, bundle_sha256, bundle_gzip, bundle_bytes,
   125	         source_data_version, db_release_version, db_release_commit, scope_statement,
   126	         license, file_count, total_bytes, created_by_user_id
   127	       ) VALUES (?, ?, ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
   128	      params = unname(list(
   129	        release_id,
   130	        .analysis_release_chr(release_head$release_version),
   131	        .analysis_release_chr(release_head$title),
   132	        .analysis_release_chr(release_head$manifest_schema_version),
   133	        .analysis_release_chr(release_head$content_digest),
   134	        .analysis_release_chr(release_head$manifest_sha256),
   135	        .analysis_release_chr(release_head$bundle_sha256),
   136	        list(bundle_gzip),
   137	        length(bundle_gzip),
   138	        .analysis_release_chr(release_head$source_data_version),
   139	        .analysis_release_chr(release_head$db_release_version),
   140	        .analysis_release_chr(release_head$db_release_commit),
   141	        .analysis_release_chr(release_head$scope_statement),
   142	        release_head$license %||% "CC-BY-4.0",
   143	        as.integer(file_count),
   144	        as.numeric(total_bytes),
   145	        if (is.null(release_head$created_by_user_id)) NA_integer_ else as.integer(release_head$created_by_user_id)
   146	      ))
   147	    )
   148	
   149	    for (m in members) {
   150	      DBI::dbExecute(
   151	        conn,
   152	        "INSERT INTO analysis_snapshot_release_member (
   153	           release_id, analysis_type, parameter_hash, snapshot_id, input_hash,
   154	           payload_hash, schema_version, reproducibility_hash, role
   155	         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
   156	        params = unname(list(
   157	          release_id,
   158	          .analysis_release_chr(m$analysis_type),
   159	          .analysis_release_chr(m$parameter_hash),
   160	          as.numeric(m$snapshot_id),
   161	          .analysis_release_chr(m$input_hash),
   162	          .analysis_release_chr(m$payload_hash),
   163	          .analysis_release_chr(m$schema_version),
   164	          .analysis_release_chr(m$reproducibility_hash),
   165	          m$role %||% "layer"
   166	        ))
   167	      )
   168	    }
   169	
   170	    for (f in files) {
   171	      DBI::dbExecute(
   172	        conn,
   173	        "INSERT INTO analysis_snapshot_release_file (
   174	           release_id, file_path, content_sha256, byte_size, media_type, content_gzip
   175	         ) VALUES (?, ?, ?, ?, ?, ?)",
   176	        params = unname(list(
   177	          release_id,
   178	          .analysis_release_chr(f$file_path),
   179	          .analysis_release_chr(f$content_sha256),
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
   481	    params = unname(list(as.character(release_id)))
   482	  )
   483	  affected > 0L
   484	}
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

codex
I found one edge case in the attestation gate that needs a closer pass: an explicitly empty/malformed attestation currently follows the legacy-absent path. I’m checking whether that can be produced by the normal snapshot build and whether any worker source path weakens the extracted prune guard.
exec
/bin/bash -lc "rg -n -C 5 'analysis_snapshot_build\\(|analysis_snapshot_prune\\(|setup_workers|mirai|analysis_snapshot_release' api | head -n 1200 && nl -ba api/bootstrap/setup_workers.R | sed -n '1,220p' && rg -n -C 8 'analysis_snapshot_refresh|analysis_snapshot_build' api/functions/async-job-analysis-snapshot-handlers.R api/functions/async-job-worker.R api/bootstrap/start_async_worker.R api/bootstrap/setup_workers.R api/functions/job-manager.R api/functions/async-job-service.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 exited 2 in 0ms:
api/start_sysndd_api.R-7-# lives in api/bootstrap/*.R. This script:
api/start_sysndd_api.R-8-#   1. attaches libraries + resolves the environment-specific config
api/start_sysndd_api.R-9-#   2. sources every application module (repositories, core, services,
api/start_sysndd_api.R-10-#      filters) via api/bootstrap/load_modules.R
api/start_sysndd_api.R-11-#   3. builds the DB pool, runs migrations, configures the memoise cache
api/start_sysndd_api.R:12:#   4. spawns the mirai daemon pool and pre-sources worker deps
api/start_sysndd_api.R-13-#   5. mounts every endpoint onto the root router
api/start_sysndd_api.R-14-#   6. starts Plumber
api/start_sysndd_api.R-15-#
api/start_sysndd_api.R-16-# Every bootstrap module returns its result. The composer binds the
api/start_sysndd_api.R-17-# returned value at script top level (which IS .GlobalEnv), so
--
api/start_sysndd_api.R-30-source("bootstrap/load_modules.R",    local = FALSE)
api/start_sysndd_api.R-31-source("bootstrap/create_pool.R",     local = FALSE)
api/start_sysndd_api.R-32-source("bootstrap/run_migrations.R",  local = FALSE)
api/start_sysndd_api.R-33-source("bootstrap/init_globals.R",    local = FALSE)
api/start_sysndd_api.R-34-source("bootstrap/init_cache.R",      local = FALSE)
api/start_sysndd_api.R:35:source("bootstrap/setup_workers.R",   local = FALSE)
api/start_sysndd_api.R-36-source("bootstrap/mount_endpoints.R", local = FALSE)
api/start_sysndd_api.R-37-
api/start_sysndd_api.R-38-bootstrap_init_libraries()
api/start_sysndd_api.R-39-
api/start_sysndd_api.R-40-## -------------------------------------------------------------------##
--
api/start_sysndd_api.R-126-nest_pubtator_gene_tibble_mem  <- memoised$nest_pubtator_gene_tibble_mem
api/start_sysndd_api.R-127-
api/start_sysndd_api.R-128-## -------------------------------------------------------------------##
api/start_sysndd_api.R-129-# 8) Mirai daemon pool + worker-side source files.
api/start_sysndd_api.R-130-## -------------------------------------------------------------------##
api/start_sysndd_api.R:131:worker_context <- bootstrap_setup_workers()
api/start_sysndd_api.R-132-
api/start_sysndd_api.R-133-# Hourly job cleanup (schedule_cleanup defined in functions/job-manager.R).
api/start_sysndd_api.R-134-schedule_cleanup(3600)
api/start_sysndd_api.R-135-
api/start_sysndd_api.R-136-## -------------------------------------------------------------------##
--
api/bootstrap/init_libraries.R-6-# Attaches every library the Plumber runtime needs on its search
api/bootstrap/init_libraries.R-7-# path. Kept in one place so the top-level composer stays thin.
api/bootstrap/init_libraries.R-8-#
api/bootstrap/init_libraries.R-9-# The ordering mirrors the pre-refactor script. Tidyverse is loaded
api/bootstrap/init_libraries.R-10-# LAST so it wins over packages that mask dplyr::select (STRINGdb,
api/bootstrap/init_libraries.R:11:# biomaRt → AnnotationDbi). For the mirai worker side the same
api/bootstrap/init_libraries.R:12:# ordering is enforced in api/bootstrap/setup_workers.R.
api/bootstrap/init_libraries.R-13-## -------------------------------------------------------------------##
api/bootstrap/init_libraries.R-14-
api/bootstrap/init_libraries.R-15-#' Attach every library the Plumber runtime needs.
api/bootstrap/init_libraries.R-16-#'
api/bootstrap/init_libraries.R-17-#' Also loads the `.env` file if present, so environment variables
--
api/bootstrap/init_libraries.R-63-  library(httr)
api/bootstrap/init_libraries.R-64-  library(httr2)
api/bootstrap/init_libraries.R-65-  library(ellipsis)
api/bootstrap/init_libraries.R-66-  library(ontologyIndex)
api/bootstrap/init_libraries.R-67-  library(httpproblems)
api/bootstrap/init_libraries.R:68:  library(mirai)
api/bootstrap/init_libraries.R-69-  library(promises)
api/bootstrap/init_libraries.R-70-  library(uuid)
api/bootstrap/init_libraries.R-71-
api/bootstrap/init_libraries.R-72-  options_plumber(trailingSlash = TRUE)
api/bootstrap/init_libraries.R-73-
--
api/bootstrap/mount_endpoints.R-6-# Builds the root Plumber router:
api/bootstrap/mount_endpoints.R-7-#   - attaches the RFC 9457 error handler + 404 handler
api/bootstrap/mount_endpoints.R-8-#   - wires the OpenAPI spec callback (reads version_spec.json)
api/bootstrap/mount_endpoints.R-9-#   - attaches the `cors` and `require_auth` filters
api/bootstrap/mount_endpoints.R-10-#   - installs the exit hook that closes the DB pool and the
api/bootstrap/mount_endpoints.R:11:#     mirai daemon pool
api/bootstrap/mount_endpoints.R-12-#   - mounts every endpoint file under /api/<subpath>
api/bootstrap/mount_endpoints.R-13-#   - installs the preroute/postroute timing + logging hook
api/bootstrap/mount_endpoints.R-14-#
api/bootstrap/mount_endpoints.R-15-# The composer in start_sysndd_api.R passes the pool and the
api/bootstrap/mount_endpoints.R-16-# temporary log-file path; they are captured by closure so the
--
api/bootstrap/mount_endpoints.R-35-  cleanupHook <- function(pr) {
api/bootstrap/mount_endpoints.R-36-    pr %>%
api/bootstrap/mount_endpoints.R-37-      plumber::pr_hook("exit", function() {
api/bootstrap/mount_endpoints.R-38-        pool::poolClose(pool)
api/bootstrap/mount_endpoints.R-39-        message("Disconnected from DB")
api/bootstrap/mount_endpoints.R:40:        mirai::daemons(0) # Shutdown mirai daemon pool
api/bootstrap/mount_endpoints.R:41:        message("Shutdown mirai daemon pool")
api/bootstrap/mount_endpoints.R-42-      })
api/bootstrap/mount_endpoints.R-43-  }
api/bootstrap/mount_endpoints.R-44-
api/bootstrap/mount_endpoints.R-45-  # Build a mounted endpoint sub-router that inherits the API's RFC 9457 error
api/bootstrap/mount_endpoints.R-46-  # and 404 handling. Plumber does NOT propagate the root router's error/404
--
api/bootstrap/setup_workers.R-1-## -------------------------------------------------------------------##
api/bootstrap/setup_workers.R:2:# api/bootstrap/setup_workers.R
api/bootstrap/setup_workers.R-3-#
api/bootstrap/setup_workers.R-4-# Part of the Phase D.D6 extract-bootstrap refactor.
api/bootstrap/setup_workers.R-5-#
api/bootstrap/setup_workers.R:6:# Initialises the mirai daemon pool and pre-loads every package /
api/bootstrap/setup_workers.R-7-# source file that background jobs (HGNC/PubTator/ontology/LLM)
api/bootstrap/setup_workers.R-8-# need to execute standalone.
api/bootstrap/setup_workers.R-9-#
api/bootstrap/setup_workers.R:10:# IMPORTANT (from CLAUDE.md): mirai workers have no access to the
api/bootstrap/setup_workers.R-11-# main process's application context. Each daemon sources the
api/bootstrap/setup_workers.R-12-# files listed here ONCE at daemon start-up. If code run inside a
api/bootstrap/setup_workers.R-13-# daemon changes, the api container must be restarted so the
api/bootstrap/setup_workers.R-14-# daemon re-sources the updated file from disk.
api/bootstrap/setup_workers.R-15-#
--
api/bootstrap/setup_workers.R-18-# LAST so their functions win. Do NOT reorder the everywhere({...})
api/bootstrap/setup_workers.R-19-# block — the ordering is a deliberate workaround for a long-
api/bootstrap/setup_workers.R-20-# standing namespace-shadowing bug documented in CLAUDE.md.
api/bootstrap/setup_workers.R-21-## -------------------------------------------------------------------##
api/bootstrap/setup_workers.R-22-
api/bootstrap/setup_workers.R:23:#' Start the mirai daemon pool and pre-source worker dependencies.
api/bootstrap/setup_workers.R-24-#'
api/bootstrap/setup_workers.R-25-#' `MIRAI_WORKERS` governs daemon count (default 2, clamped 1–8).
api/bootstrap/setup_workers.R-26-#' Tune for host RAM — see CLAUDE.md "Memory / Worker Tuning".
api/bootstrap/setup_workers.R-27-#'
api/bootstrap/setup_workers.R-28-#' @return A list describing the worker configuration (for
api/bootstrap/setup_workers.R-29-#'   logging / diagnostics): `count` (daemon count) and
api/bootstrap/setup_workers.R-30-#'   `dispatcher` (TRUE when dispatcher mode is enabled).
api/bootstrap/setup_workers.R-31-#' @export
api/bootstrap/setup_workers.R:32:bootstrap_setup_workers <- function() {
api/bootstrap/setup_workers.R-33-  worker_count <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))
api/bootstrap/setup_workers.R-34-
api/bootstrap/setup_workers.R-35-  # Handle NA from invalid input (e.g., "abc")
api/bootstrap/setup_workers.R-36-  if (is.na(worker_count)) worker_count <- 2L
api/bootstrap/setup_workers.R-37-
api/bootstrap/setup_workers.R-38-  # Validate bounds (minimum 1, maximum 8)
api/bootstrap/setup_workers.R-39-  worker_count <- max(1L, min(worker_count, 8L))
api/bootstrap/setup_workers.R-40-
api/bootstrap/setup_workers.R:41:  mirai::daemons(
api/bootstrap/setup_workers.R-42-    n = worker_count,
api/bootstrap/setup_workers.R-43-    dispatcher = TRUE, # Enable for variable-length jobs
api/bootstrap/setup_workers.R-44-    autoexit = tools::SIGINT
api/bootstrap/setup_workers.R-45-  )
api/bootstrap/setup_workers.R-46-  message(sprintf(
api/bootstrap/setup_workers.R:47:    "[%s] Started mirai daemon pool with %d workers",
api/bootstrap/setup_workers.R-48-    Sys.time(), worker_count
api/bootstrap/setup_workers.R-49-  ))
api/bootstrap/setup_workers.R-50-
api/bootstrap/setup_workers.R-51-  # Export required packages and functions to all daemons.
api/bootstrap/setup_workers.R-52-  # NOTE: Load packages that mask dplyr::select FIRST (STRINGdb, biomaRt
api/bootstrap/setup_workers.R-53-  # load AnnotationDbi), then load dplyr/tidyverse LAST so their
api/bootstrap/setup_workers.R-54-  # functions win. Do not reorder — see module header.
api/bootstrap/setup_workers.R:55:  mirai::everywhere({
api/bootstrap/setup_workers.R-56-    library(DBI)
api/bootstrap/setup_workers.R-57-    library(RMariaDB)
api/bootstrap/setup_workers.R-58-    library(STRINGdb)
api/bootstrap/setup_workers.R-59-    library(biomaRt)
api/bootstrap/setup_workers.R-60-    library(FactoMineR)
--
api/bootstrap/setup_workers.R-135-    source("/app/functions/async-job-force-apply-payload.R", local = FALSE)
api/bootstrap/setup_workers.R-136-    source("/app/functions/async-job-provider-handlers.R", local = FALSE)
api/bootstrap/setup_workers.R-137-    source("/app/functions/async-job-maintenance-handlers.R", local = FALSE)
api/bootstrap/setup_workers.R-138-    source("/app/functions/async-job-handlers.R", local = FALSE)
api/bootstrap/setup_workers.R-139-    source("/app/functions/async-job-worker.R", local = FALSE)
api/bootstrap/setup_workers.R:140:    # Source transitional progress shim for legacy mirai async code paths
api/bootstrap/setup_workers.R-141-    source("/app/functions/job-progress.R", local = FALSE)
api/bootstrap/setup_workers.R-142-    # Source PubTator functions for async update jobs (client + parser before orchestrator)
api/bootstrap/setup_workers.R-143-    source("/app/functions/pubtator-client.R", local = FALSE)
api/bootstrap/setup_workers.R-144-    source("/app/functions/pubtator-parser.R", local = FALSE)
api/bootstrap/setup_workers.R-145-    source("/app/functions/pubtator-functions.R", local = FALSE)
--
api/bootstrap/setup_workers.R-162-    source("/app/functions/llm-judge.R", local = FALSE)
api/bootstrap/setup_workers.R-163-    source("/app/functions/llm-batch-cluster-data.R", local = FALSE)
api/bootstrap/setup_workers.R-164-    source("/app/functions/llm-batch-generator.R", local = FALSE)
api/bootstrap/setup_workers.R-165-  })
api/bootstrap/setup_workers.R-166-  message(sprintf(
api/bootstrap/setup_workers.R:167:    "[%s] Exported packages and functions to mirai daemons",
api/bootstrap/setup_workers.R-168-    Sys.time()
api/bootstrap/setup_workers.R-169-  ))
api/bootstrap/setup_workers.R-170-
api/bootstrap/setup_workers.R-171-  list(count = worker_count, dispatcher = TRUE)
api/bootstrap/setup_workers.R-172-}
--
api/endpoints/admin_analysis_snapshot_endpoints.R-88-#'
api/endpoints/admin_analysis_snapshot_endpoints.R-89-#' This matters specifically for `POST /releases`'s optional `layers` array
api/endpoints/admin_analysis_snapshot_endpoints.R-90-#' override. Verified live: `simplifyVector = TRUE` collapses a JSON array of
api/endpoints/admin_analysis_snapshot_endpoints.R-91-#' layer-override objects into a *data.frame* -- and a nested object field
api/endpoints/admin_analysis_snapshot_endpoints.R-92-#' (e.g. `params`) collapses into its OWN nested data.frame column when every
api/endpoints/admin_analysis_snapshot_endpoints.R:93:#' layer shares the same param keys. `analysis_snapshot_release_build()`
api/endpoints/admin_analysis_snapshot_endpoints.R-94-#' iterates its `layers` argument with `lapply(layers, function(layer)
api/endpoints/admin_analysis_snapshot_endpoints.R-95-#' layer$analysis_type[[1]])`; iterating a data.frame with `lapply()` walks
api/endpoints/admin_analysis_snapshot_endpoints.R-96-#' the data.frame's COLUMNS (atomic vectors), the same "$ operator is invalid
api/endpoints/admin_analysis_snapshot_endpoints.R-97-#' for atomic vectors" trap AGENTS.md documents for the force-apply payload
api/endpoints/admin_analysis_snapshot_endpoints.R-98-#' helpers (`functions/async-job-force-apply-payload.R`). Re-parsing the raw
api/endpoints/admin_analysis_snapshot_endpoints.R-99-#' body text with `simplifyVector = FALSE` instead -- the same call
api/endpoints/admin_analysis_snapshot_endpoints.R-100-#' `core/logging_sanitizer.R`'s `sanitize_post_body_for_log()` already makes
api/endpoints/admin_analysis_snapshot_endpoints.R-101-#' on `req$postBody` -- yields the EXACT list-of-named-lists shape
api/endpoints/admin_analysis_snapshot_endpoints.R:102:#' `analysis_snapshot_release_layers()` itself returns (each layer's `params`
api/endpoints/admin_analysis_snapshot_endpoints.R-103-#' comes back as a genuine named list too), so a caller-supplied `layers`
api/endpoints/admin_analysis_snapshot_endpoints.R-104-#' override needs no further normalization before being forwarded to
api/endpoints/admin_analysis_snapshot_endpoints.R-105-#' `svc_release_build()`. `req$postBody` is populated by Plumber's default
api/endpoints/admin_analysis_snapshot_endpoints.R-106-#' `bodyFilter` for every request with a body, independent of any `@parser`
api/endpoints/admin_analysis_snapshot_endpoints.R-107-#' annotation on this route.
--
api/endpoints/admin_analysis_snapshot_endpoints.R-147-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-148-#* JSON body (all fields optional): `{ layers?: [...], title?,
api/endpoints/admin_analysis_snapshot_endpoints.R-149-#* scope_statement?, license?, publish? }`. `publish` defaults to `true`;
api/endpoints/admin_analysis_snapshot_endpoints.R-150-#* `false` stages a draft for review before a Zenodo run. `license` defaults
api/endpoints/admin_analysis_snapshot_endpoints.R-151-#* to `"CC-BY-4.0"`. Omitting `layers` uses the fixed default registry
api/endpoints/admin_analysis_snapshot_endpoints.R:152:#* (`analysis_snapshot_release_layers()`).
api/endpoints/admin_analysis_snapshot_endpoints.R-153-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-154-#* @tag admin
api/endpoints/admin_analysis_snapshot_endpoints.R-155-#* @serializer unboxedJSON
api/endpoints/admin_analysis_snapshot_endpoints.R-156-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-157-#* @post /releases
--
api/endpoints/admin_analysis_snapshot_endpoints.R-159-  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-160-
api/endpoints/admin_analysis_snapshot_endpoints.R-161-  body <- .admin_release_parse_json_body(req)
api/endpoints/admin_analysis_snapshot_endpoints.R-162-  publish_flag <- if (is.null(body$publish)) TRUE else isTRUE(body$publish)
api/endpoints/admin_analysis_snapshot_endpoints.R-163-
api/endpoints/admin_analysis_snapshot_endpoints.R:164:  # analysis_snapshot_release_build() ultimately calls
api/endpoints/admin_analysis_snapshot_endpoints.R-165-  # analysis_release_insert(), which wraps its writes in ONE
api/endpoints/admin_analysis_snapshot_endpoints.R-166-  # DBI::dbWithTransaction() and binds blob params via list(<raw>) -- both
api/endpoints/admin_analysis_snapshot_endpoints.R-167-  # need a real DBIConnection, never the global `pool` Pool object directly
api/endpoints/admin_analysis_snapshot_endpoints.R-168-  # (see functions/analysis-snapshot-release-repository.R's file header).
api/endpoints/admin_analysis_snapshot_endpoints.R-169-  # The other 5 admin routes below issue single non-transactional
--
api/bootstrap/load_modules.R-15-# (A service that accidentally drops its prefix will shadow the
api/bootstrap/load_modules.R-16-# repository function — see CLAUDE.md.)
api/bootstrap/load_modules.R-17-#
api/bootstrap/load_modules.R-18-# Mirai daemon workers do NOT use this module. They re-source a
api/bootstrap/load_modules.R-19-# hand-picked subset of functions/* via `everywhere({...})` in
api/bootstrap/load_modules.R:20:# api/bootstrap/setup_workers.R. Changes here do not automatically
api/bootstrap/load_modules.R:21:# propagate to workers — update setup_workers.R as well when a
api/bootstrap/load_modules.R-22-# function file is needed inside a daemon.
api/bootstrap/load_modules.R-23-## -------------------------------------------------------------------##
api/bootstrap/load_modules.R-24-
api/bootstrap/load_modules.R-25-#' Source a file into .GlobalEnv with a helpful error if missing.
api/bootstrap/load_modules.R-26-#'
--
api/bootstrap/load_modules.R-76-    "functions/analysis-snapshot-builder.R",
api/bootstrap/load_modules.R-77-    "functions/analysis-reproducibility.R",
api/bootstrap/load_modules.R-78-    # Immutable, content-addressed public analysis-snapshot releases (#573
api/bootstrap/load_modules.R-79-    # Slice A). Synchronous admin/API-only build path (svc_release_build(),
api/bootstrap/load_modules.R-80-    # called directly from the admin endpoint) -- NOT a durable async-job
api/bootstrap/load_modules.R:81:    # handler and NOT a mirai daemon job, so (unlike the sibling
api/bootstrap/load_modules.R-82-    # analysis-snapshot-*.R files above) these are intentionally absent from
api/bootstrap/load_modules.R:83:    # bootstrap/setup_workers.R's mirai everywhere() block. Registered here
api/bootstrap/load_modules.R-84-    # only, which still covers the durable worker (start_async_worker.R) and
api/bootstrap/load_modules.R-85-    # the MCP sidecar (start_sysndd_mcp.R) via this shared loader. Order:
api/bootstrap/load_modules.R-86-    # manifest (content digest / canonical JSON / tar.gz) -> repository (DB
api/bootstrap/load_modules.R-87-    # CRUD) -> materialize (coherence assertions + file/README building) ->
api/bootstrap/load_modules.R-88-    # release (orchestrator, depends on all three).
--
api/bootstrap/load_modules.R-114-    "functions/phenotype-endpoint-functions.R",
api/bootstrap/load_modules.R-115-    "functions/panels-endpoint-functions.R",
api/bootstrap/load_modules.R-116-    "functions/endpoint-functions.R",
api/bootstrap/load_modules.R-117-    "functions/comparisons-list.R",
api/bootstrap/load_modules.R-118-    # Comparisons refresh write-path (durable `comparisons_update` job). These
api/bootstrap/load_modules.R:119:    # were historically only loaded into the mirai daemon pool via
api/bootstrap/load_modules.R:120:    # setup_workers.R, but create_job() now submits comparisons_update as a
api/bootstrap/load_modules.R-121-    # durable System B job, so the async worker (which loads via this list) must
api/bootstrap/load_modules.R-122-    # define comparisons_update_async() and its helpers too. Order: sources +
api/bootstrap/load_modules.R-123-    # parsers + omim before comparisons-functions.R (which uses them).
api/bootstrap/load_modules.R-124-    "functions/omim-functions.R",
api/bootstrap/load_modules.R-125-    "functions/comparisons-sources.R",
--
api/bootstrap/create_pool.R-11-
api/bootstrap/create_pool.R-12-#' Create the application-wide MariaDB connection pool.
api/bootstrap/create_pool.R-13-#'
api/bootstrap/create_pool.R-14-#' Pool sizing is driven by the `DB_POOL_SIZE` environment variable
api/bootstrap/create_pool.R-15-#' (default 5). Single-threaded R rarely needs >1–2 concurrent
api/bootstrap/create_pool.R:16:#' connections, but up to 5 accommodates burst load from mirai
api/bootstrap/create_pool.R-17-#' workers. Keeping an explicit upper bound prevents unbounded
api/bootstrap/create_pool.R-18-#' connection growth from exhausting MySQL's `max_connections`.
api/bootstrap/create_pool.R-19-#'
api/bootstrap/create_pool.R-20-#' @param dw A list from `config::get()` with `dbname`, `host`,
api/bootstrap/create_pool.R-21-#'   `user`, `password`, `server`, `port`.
--
api/renv.lock-6329-        "crayon",
api/renv.lock-6330-        "devtools",
api/renv.lock-6331-        "glue",
api/renv.lock-6332-        "jsonlite",
api/renv.lock-6333-        "knitr",
api/renv.lock:6334:        "mirai (>= 1.3.0)",
api/renv.lock-6335-        "pander",
api/renv.lock-6336-        "parallel",
api/renv.lock-6337-        "R.utils",
api/renv.lock-6338-        "rmarkdown",
api/renv.lock-6339-        "roxygen2",
--
api/renv.lock-6583-      "NeedsCompilation": "yes",
api/renv.lock-6584-      "Repository": "RSPM",
api/renv.lock-6585-      "Author": "Douglas Bates [aut], Katharine M. Mullen [aut, cre], John C. Nash [aut], Ravi Varadhan [aut]",
api/renv.lock-6586-      "Encoding": "UTF-8"
api/renv.lock-6587-    },
api/renv.lock:6588:    "mirai": {
api/renv.lock:6589:      "Package": "mirai",
api/renv.lock-6590-      "Version": "2.6.1",
api/renv.lock-6591-      "Source": "Repository",
api/renv.lock-6592-      "Type": "Package",
api/renv.lock-6593-      "Title": "Minimalist Async Evaluation Framework for R",
api/renv.lock-6594-      "Authors@R": "c( person(\"Charlie\", \"Gao\", , \"charlie.gao@posit.co\", role = c(\"aut\", \"cre\"), comment = c(ORCID = \"0000-0002-0750-061X\")), person(\"Joe\", \"Cheng\", , \"joe@posit.co\", role = \"ctb\"), person(\"Posit Software, PBC\", role = c(\"cph\", \"fnd\"), comment = c(ROR = \"03wc8by49\")), person(\"Hibiki AI Limited\", role = \"cph\") )",
api/renv.lock:6595:      "Description": "Designed for simplicity, a 'mirai' evaluates an R expression asynchronously, locally or distributed over the network. Built on 'nanonext' and 'NNG' for modern networking and concurrency, scales efficiently to millions of tasks over thousands of parallel processes. Provides optimal scheduling over fast 'IPC', TCP, and TLS connections, integrating with SSH or cluster managers. Implements event-driven promises for reactive programming, and supports custom serialization for cross-language data types.",
api/renv.lock-6596-      "License": "MIT + file LICENSE",
api/renv.lock:6597:      "URL": "https://mirai.r-lib.org, https://github.com/r-lib/mirai",
api/renv.lock:6598:      "BugReports": "https://github.com/r-lib/mirai/issues",
api/renv.lock-6599-      "Depends": [
api/renv.lock-6600-        "R (>= 3.6)"
api/renv.lock-6601-      ],
api/renv.lock-6602-      "Imports": [
api/renv.lock-6603-        "nanonext (>= 1.8.0)"
--
api/renv.lock-7798-        "rlang"
api/renv.lock-7799-      ],
api/renv.lock-7800-      "Suggests": [
api/renv.lock-7801-        "future (>= 1.21.0)",
api/renv.lock-7802-        "knitr",
api/renv.lock:7803:        "mirai",
api/renv.lock-7804-        "otelsdk (>= 0.2.0)",
api/renv.lock-7805-        "purrr",
api/renv.lock-7806-        "Rcpp",
api/renv.lock-7807-        "rmarkdown",
api/renv.lock-7808-        "spelling",
--
api/renv.lock-7872-        "covr",
api/renv.lock-7873-        "dplyr (>= 0.7.8)",
api/renv.lock-7874-        "httr",
api/renv.lock-7875-        "knitr",
api/renv.lock-7876-        "lubridate",
api/renv.lock:7877:        "mirai (>= 2.5.1)",
api/renv.lock-7878-        "rmarkdown",
api/renv.lock-7879-        "testthat (>= 3.0.0)",
api/renv.lock-7880-        "tibble",
api/renv.lock-7881-        "tidyselect"
api/renv.lock-7882-      ],
--
api/endpoints/health_endpoints.R-212-#*
api/endpoints/health_endpoints.R-213-#* Returns performance metrics including worker pool status and cache statistics.
api/endpoints/health_endpoints.R-214-#* Use this endpoint to monitor optimization impact and diagnose performance issues.
api/endpoints/health_endpoints.R-215-#*
api/endpoints/health_endpoints.R-216-#* # `Details`
api/endpoints/health_endpoints.R:217:#* - Worker pool: Shows mirai daemon pool utilization
api/endpoints/health_endpoints.R-218-#* - Cache: Shows file-based cache statistics in results/ directory
api/endpoints/health_endpoints.R-219-#* - Timestamp: Current server time for correlation with logs
api/endpoints/health_endpoints.R-220-#*
api/endpoints/health_endpoints.R-221-#* @tag health
api/endpoints/health_endpoints.R-222-#* @serializer json list(na="string")
--
api/endpoints/health_endpoints.R-228-  # Read configured worker count from environment (same logic as start_sysndd_api.R)
api/endpoints/health_endpoints.R-229-  configured_workers <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))
api/endpoints/health_endpoints.R-230-  if (is.na(configured_workers)) configured_workers <- 2L
api/endpoints/health_endpoints.R-231-  configured_workers <- max(1L, min(configured_workers, 8L))
api/endpoints/health_endpoints.R-232-
api/endpoints/health_endpoints.R:233:  # Check worker pool status via mirai
api/endpoints/health_endpoints.R-234-  worker_status <- tryCatch(
api/endpoints/health_endpoints.R-235-    {
api/endpoints/health_endpoints.R:236:      status <- mirai::status()
api/endpoints/health_endpoints.R-237-      list(
api/endpoints/health_endpoints.R-238-        configured = configured_workers,
api/endpoints/health_endpoints.R-239-        connections = status$connections,
api/endpoints/health_endpoints.R-240-        # Dispatcher handles task distribution
api/endpoints/health_endpoints.R-241-        dispatcher_active = TRUE
--
api/bootstrap/init_cache.R-74-#' that used to sit in `start_sysndd_api.R`. They are returned as a
api/bootstrap/init_cache.R-75-#' named list so the composer can bind each name at top level
api/bootstrap/init_cache.R-76-#' (which is .GlobalEnv, so endpoints keep finding them by bare name).
api/bootstrap/init_cache.R-77-#'
api/bootstrap/init_cache.R-78-#' `get_string_db()` is an unrelated singleton defined in
api/bootstrap/init_cache.R:79:#' analyses-functions.R and shared with mirai workers — it is not
api/bootstrap/init_cache.R-80-#' memoised here.
api/bootstrap/init_cache.R-81-#'
api/bootstrap/init_cache.R-82-#' @param cache_dir Directory path (default "/app/cache").
api/bootstrap/init_cache.R-83-#' @return Named list of memoised functions.
api/bootstrap/init_cache.R-84-#' @export
--
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-1-# tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-2-#
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-3-# Integration test for the #573 Slice A / Task A8 prune-protection guard:
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:4:# analysis_snapshot_prune() (functions/analysis-snapshot-repository.R) must
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-5-# never delete a superseded snapshot manifest row that a published/draft
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-6-# analysis-snapshot RELEASE still references via
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:7:# analysis_snapshot_release_member.snapshot_id. A release freezes its own
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-8-# content-addressed copies of a snapshot's payload, so release INTEGRITY does
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-9-# not depend on the source manifest row surviving -- but the LIVE
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-10-# reproducibility endpoint for that still-cited snapshot
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-11-# (GET /api/analysis/<type>/reproducibility) would start 503-ing
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-12-# (`snapshot_missing`) if its manifest row disappeared out from under it.
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-13-#
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-14-# Against the real test database (sysndd_db_test). Seeds the minimal public
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-15-# analysis-snapshot manifest schema (migration 024) and the release schema
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-16-# (migration 045) via the ensure_test_*_schema() helpers in helper-db.R, then
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:17:# exercises analysis_snapshot_prune() on a single plain (non-transactional)
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-18-# connection -- mirroring test-integration-analysis-snapshot-release-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-19-# repository.R's pattern. The release/member row is created via the real,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-20-# already-tested analysis_release_insert() repository function (A3) rather
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:21:# than hand-rolled SQL, since analysis_snapshot_release_member has no FK to
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-22-# analysis_snapshot_manifest (see migration 045) -- only the manifest rows
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-23-# (which analysis_release_insert() knows nothing about) are inserted directly.
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-24-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-25-prune_release_guard_test_wd <- getwd()
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-26-setwd(get_api_dir())
--
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-45-PRUNE_TEST_NO_RELEASE_PARAMETER_HASH <- analysis_release_sha256("prune-release-guard-test-params-no-release")
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-46-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-47-.prune_guard_cleanup <- function(conn) {
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-48-  DBI::dbExecute(
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-49-    conn,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:50:    "DELETE FROM analysis_snapshot_release WHERE release_id = ?",
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-51-    params = unname(list(PRUNE_TEST_RELEASE_ID))
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-52-  )
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-53-  DBI::dbExecute(
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-54-    conn,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-55-    "DELETE FROM analysis_snapshot_manifest WHERE (analysis_type = ? AND parameter_hash = ?)
--
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-143-    label = "unreferenced"
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-144-  )
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-145-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-146-  .insert_prune_test_release_row(conn, referenced_id)
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-147-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:148:  analysis_snapshot_prune(
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-149-    PRUNE_TEST_ANALYSIS_TYPE, PRUNE_TEST_PARAMETER_HASH,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-150-    keep_public_ready = 1L, keep_superseded_days = 14L,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-151-    conn = conn
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-152-  )
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-153-
--
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-205-    analysis_type = PRUNE_TEST_NO_RELEASE_ANALYSIS_TYPE,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-206-    parameter_hash = PRUNE_TEST_NO_RELEASE_PARAMETER_HASH
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-207-  )
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-208-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-209-  # No analysis_release_insert() call here: this snapshot's id is never
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:210:  # written to analysis_snapshot_release_member.
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-211-
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:212:  analysis_snapshot_prune(
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-213-    PRUNE_TEST_NO_RELEASE_ANALYSIS_TYPE, PRUNE_TEST_NO_RELEASE_PARAMETER_HASH,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-214-    keep_public_ready = 1L, keep_superseded_days = 14L,
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-215-    conn = conn
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-216-  )
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R-217-
--
api/tests/testthat/test-unit-analysis-snapshot-repository.R-368-  }
api/tests/testthat/test-unit-analysis-snapshot-repository.R-369-  env$db_execute_statement <- function(sql, params = list(), conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-repository.R-370-    deleted_ids <<- unlist(params)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-371-    length(deleted_ids)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-372-  }
api/tests/testthat/test-unit-analysis-snapshot-repository.R:373:  # analysis_snapshot_prune() must reuse this repository function (the #573
api/tests/testthat/test-unit-analysis-snapshot-repository.R-374-  # release repository's single source of truth for "which snapshot ids are
api/tests/testthat/test-unit-analysis-snapshot-repository.R-375-  # release-referenced") rather than an inline NOT IN subquery -- assert it
api/tests/testthat/test-unit-analysis-snapshot-repository.R-376-  # is actually called, with the SAME conn, instead of only asserting on its
api/tests/testthat/test-unit-analysis-snapshot-repository.R-377-  # RETURN VALUE (which a reintroduced inline subquery could accidentally
api/tests/testthat/test-unit-analysis-snapshot-repository.R-378-  # keep matching).
api/tests/testthat/test-unit-analysis-snapshot-repository.R-379-  env$analysis_release_referenced_snapshot_ids <- function(conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-repository.R-380-    referenced_ids_conn <<- conn
api/tests/testthat/test-unit-analysis-snapshot-repository.R-381-    integer(0)
api/tests/testthat/test-unit-analysis-snapshot-repository.R-382-  }
api/tests/testthat/test-unit-analysis-snapshot-repository.R-383-
api/tests/testthat/test-unit-analysis-snapshot-repository.R:384:  result <- env$analysis_snapshot_prune(
api/tests/testthat/test-unit-analysis-snapshot-repository.R-385-    "phenotype_clusters",
api/tests/testthat/test-unit-analysis-snapshot-repository.R-386-    "hash",
api/tests/testthat/test-unit-analysis-snapshot-repository.R-387-    keep_public_ready = 1L,
api/tests/testthat/test-unit-analysis-snapshot-repository.R-388-    keep_superseded_days = 14L,
api/tests/testthat/test-unit-analysis-snapshot-repository.R-389-    conn = fake_conn
--
api/tests/testthat/test-unit-mirai-workers.R:1:# tests/testthat/test-unit-mirai-workers.R
api/tests/testthat/test-unit-mirai-workers.R-2-# Unit tests for MIRAI_WORKERS environment variable parsing
api/tests/testthat/test-unit-mirai-workers.R-3-#
api/tests/testthat/test-unit-mirai-workers.R-4-# Tests verify that the worker count configuration:
api/tests/testthat/test-unit-mirai-workers.R-5-# - Defaults to 2 when not set
api/tests/testthat/test-unit-mirai-workers.R-6-# - Handles invalid (non-numeric) values by falling back to default
--
api/tests/testthat/test-unit-mirai-workers.R-20-#'
api/tests/testthat/test-unit-mirai-workers.R-21-#' This function replicates the logic from start_sysndd_api.R for testing.
api/tests/testthat/test-unit-mirai-workers.R-22-#' The actual implementation is inline in the API startup script.
api/tests/testthat/test-unit-mirai-workers.R-23-#'
api/tests/testthat/test-unit-mirai-workers.R-24-#' @return Integer worker count (1-8)
api/tests/testthat/test-unit-mirai-workers.R:25:parse_mirai_workers <- function() {
api/tests/testthat/test-unit-mirai-workers.R-26-  worker_count <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))
api/tests/testthat/test-unit-mirai-workers.R-27-  if (is.na(worker_count)) worker_count <- 2L
api/tests/testthat/test-unit-mirai-workers.R-28-  max(1L, min(worker_count, 8L))
api/tests/testthat/test-unit-mirai-workers.R-29-}
api/tests/testthat/test-unit-mirai-workers.R-30-
--
api/tests/testthat/test-unit-mirai-workers.R-35-describe("MIRAI_WORKERS parsing", {
api/tests/testthat/test-unit-mirai-workers.R-36-
api/tests/testthat/test-unit-mirai-workers.R-37-  it("defaults to 2 when not set", {
api/tests/testthat/test-unit-mirai-workers.R-38-    withr::local_envvar(MIRAI_WORKERS = NA)  # Unset
api/tests/testthat/test-unit-mirai-workers.R-39-
api/tests/testthat/test-unit-mirai-workers.R:40:    result <- parse_mirai_workers()
api/tests/testthat/test-unit-mirai-workers.R-41-    expect_equal(result, 2L)
api/tests/testthat/test-unit-mirai-workers.R-42-  })
api/tests/testthat/test-unit-mirai-workers.R-43-
api/tests/testthat/test-unit-mirai-workers.R-44-  it("defaults to 2 when set to empty string", {
api/tests/testthat/test-unit-mirai-workers.R-45-    withr::local_envvar(MIRAI_WORKERS = "")
api/tests/testthat/test-unit-mirai-workers.R-46-
api/tests/testthat/test-unit-mirai-workers.R:47:    result <- parse_mirai_workers()
api/tests/testthat/test-unit-mirai-workers.R-48-    expect_equal(result, 2L)
api/tests/testthat/test-unit-mirai-workers.R-49-  })
api/tests/testthat/test-unit-mirai-workers.R-50-
api/tests/testthat/test-unit-mirai-workers.R-51-  it("parses valid integer values", {
api/tests/testthat/test-unit-mirai-workers.R-52-    withr::local_envvar(MIRAI_WORKERS = "4")
api/tests/testthat/test-unit-mirai-workers.R:53:    expect_equal(parse_mirai_workers(), 4L)
api/tests/testthat/test-unit-mirai-workers.R-54-
api/tests/testthat/test-unit-mirai-workers.R-55-    withr::local_envvar(MIRAI_WORKERS = "1")
api/tests/testthat/test-unit-mirai-workers.R:56:    expect_equal(parse_mirai_workers(), 1L)
api/tests/testthat/test-unit-mirai-workers.R-57-
api/tests/testthat/test-unit-mirai-workers.R-58-    withr::local_envvar(MIRAI_WORKERS = "8")
api/tests/testthat/test-unit-mirai-workers.R:59:    expect_equal(parse_mirai_workers(), 8L)
api/tests/testthat/test-unit-mirai-workers.R-60-  })
api/tests/testthat/test-unit-mirai-workers.R-61-
api/tests/testthat/test-unit-mirai-workers.R-62-  it("handles non-numeric values by defaulting to 2", {
api/tests/testthat/test-unit-mirai-workers.R-63-    withr::local_envvar(MIRAI_WORKERS = "abc")
api/tests/testthat/test-unit-mirai-workers.R:64:    expect_equal(suppressWarnings(parse_mirai_workers()), 2L)
api/tests/testthat/test-unit-mirai-workers.R-65-
api/tests/testthat/test-unit-mirai-workers.R-66-    withr::local_envvar(MIRAI_WORKERS = "two")
api/tests/testthat/test-unit-mirai-workers.R:67:    expect_equal(suppressWarnings(parse_mirai_workers()), 2L)
api/tests/testthat/test-unit-mirai-workers.R-68-
api/tests/testthat/test-unit-mirai-workers.R-69-    withr::local_envvar(MIRAI_WORKERS = "4.5")  # Float strings
api/tests/testthat/test-unit-mirai-workers.R:70:    expect_equal(parse_mirai_workers(), 4L)  # as.integer truncates
api/tests/testthat/test-unit-mirai-workers.R-71-  })
api/tests/testthat/test-unit-mirai-workers.R-72-
api/tests/testthat/test-unit-mirai-workers.R-73-  it("bounds value to minimum of 1", {
api/tests/testthat/test-unit-mirai-workers.R-74-    withr::local_envvar(MIRAI_WORKERS = "0")
api/tests/testthat/test-unit-mirai-workers.R:75:    expect_equal(parse_mirai_workers(), 1L)
api/tests/testthat/test-unit-mirai-workers.R-76-
api/tests/testthat/test-unit-mirai-workers.R-77-    withr::local_envvar(MIRAI_WORKERS = "-1")
api/tests/testthat/test-unit-mirai-workers.R:78:    expect_equal(parse_mirai_workers(), 1L)
api/tests/testthat/test-unit-mirai-workers.R-79-
api/tests/testthat/test-unit-mirai-workers.R-80-    withr::local_envvar(MIRAI_WORKERS = "-99")
api/tests/testthat/test-unit-mirai-workers.R:81:    expect_equal(parse_mirai_workers(), 1L)
api/tests/testthat/test-unit-mirai-workers.R-82-  })
api/tests/testthat/test-unit-mirai-workers.R-83-
api/tests/testthat/test-unit-mirai-workers.R-84-  it("bounds value to maximum of 8", {
api/tests/testthat/test-unit-mirai-workers.R-85-    withr::local_envvar(MIRAI_WORKERS = "9")
api/tests/testthat/test-unit-mirai-workers.R:86:    expect_equal(parse_mirai_workers(), 8L)
api/tests/testthat/test-unit-mirai-workers.R-87-
api/tests/testthat/test-unit-mirai-workers.R-88-    withr::local_envvar(MIRAI_WORKERS = "10")
api/tests/testthat/test-unit-mirai-workers.R:89:    expect_equal(parse_mirai_workers(), 8L)
api/tests/testthat/test-unit-mirai-workers.R-90-
api/tests/testthat/test-unit-mirai-workers.R-91-    withr::local_envvar(MIRAI_WORKERS = "100")
api/tests/testthat/test-unit-mirai-workers.R:92:    expect_equal(parse_mirai_workers(), 8L)
api/tests/testthat/test-unit-mirai-workers.R-93-  })
api/tests/testthat/test-unit-mirai-workers.R-94-
api/tests/testthat/test-unit-mirai-workers.R-95-  it("handles edge cases at boundaries", {
api/tests/testthat/test-unit-mirai-workers.R-96-    # Exactly at minimum
api/tests/testthat/test-unit-mirai-workers.R-97-    withr::local_envvar(MIRAI_WORKERS = "1")
api/tests/testthat/test-unit-mirai-workers.R:98:    expect_equal(parse_mirai_workers(), 1L)
api/tests/testthat/test-unit-mirai-workers.R-99-
api/tests/testthat/test-unit-mirai-workers.R-100-    # Exactly at maximum
api/tests/testthat/test-unit-mirai-workers.R-101-    withr::local_envvar(MIRAI_WORKERS = "8")
api/tests/testthat/test-unit-mirai-workers.R:102:    expect_equal(parse_mirai_workers(), 8L)
api/tests/testthat/test-unit-mirai-workers.R-103-
api/tests/testthat/test-unit-mirai-workers.R-104-    # One below minimum (should bound)
api/tests/testthat/test-unit-mirai-workers.R-105-    withr::local_envvar(MIRAI_WORKERS = "0")
api/tests/testthat/test-unit-mirai-workers.R:106:    expect_equal(parse_mirai_workers(), 1L)
api/tests/testthat/test-unit-mirai-workers.R-107-
api/tests/testthat/test-unit-mirai-workers.R-108-    # One above maximum (should bound)
api/tests/testthat/test-unit-mirai-workers.R-109-    withr::local_envvar(MIRAI_WORKERS = "9")
api/tests/testthat/test-unit-mirai-workers.R:110:    expect_equal(parse_mirai_workers(), 8L)
api/tests/testthat/test-unit-mirai-workers.R-111-  })
api/tests/testthat/test-unit-mirai-workers.R-112-
api/tests/testthat/test-unit-mirai-workers.R-113-  it("handles whitespace around value", {
api/tests/testthat/test-unit-mirai-workers.R-114-    withr::local_envvar(MIRAI_WORKERS = "  4  ")
api/tests/testthat/test-unit-mirai-workers.R:115:    expect_equal(parse_mirai_workers(), 4L)
api/tests/testthat/test-unit-mirai-workers.R-116-
api/tests/testthat/test-unit-mirai-workers.R-117-    withr::local_envvar(MIRAI_WORKERS = "\t3\n")
api/tests/testthat/test-unit-mirai-workers.R:118:    expect_equal(parse_mirai_workers(), 3L)
api/tests/testthat/test-unit-mirai-workers.R-119-  })
api/tests/testthat/test-unit-mirai-workers.R-120-
api/tests/testthat/test-unit-mirai-workers.R-121-  it("handles mixed valid and invalid characters", {
api/tests/testthat/test-unit-mirai-workers.R-122-    # as.integer will fail on these, so should default to 2
api/tests/testthat/test-unit-mirai-workers.R-123-    withr::local_envvar(MIRAI_WORKERS = "4workers")
api/tests/testthat/test-unit-mirai-workers.R:124:    expect_equal(suppressWarnings(parse_mirai_workers()), 2L)
api/tests/testthat/test-unit-mirai-workers.R-125-
api/tests/testthat/test-unit-mirai-workers.R-126-    withr::local_envvar(MIRAI_WORKERS = "workers4")
api/tests/testthat/test-unit-mirai-workers.R:127:    expect_equal(suppressWarnings(parse_mirai_workers()), 2L)
api/tests/testthat/test-unit-mirai-workers.R-128-  })
api/tests/testthat/test-unit-mirai-workers.R-129-})
--
api/tests/testthat/test-unit-job-endpoint-services.R-12-# Each service is sourced directly into an isolated environment via sys.source()
api/tests/testthat/test-unit-job-endpoint-services.R-13-# (mirrors test-unit-job-status-result-mode.R), and every bare global name the service
api/tests/testthat/test-unit-job-endpoint-services.R-14-# body references (pool, dw, check_duplicate_job, create_job, async_job_capacity_exceeded,
api/tests/testthat/test-unit-job-endpoint-services.R-15-# async_job_active_count, async_job_service_store_completed, gen_string_clust_obj_mem,
api/tests/testthat/test-unit-job-endpoint-services.R-16-# gen_mca_clust_obj_mem, log_warn, ...) is stubbed in that environment, so the tests
api/tests/testthat/test-unit-job-endpoint-services.R:17:# exercise pure request/response logic without a live DB or mirai daemon pool.
api/tests/testthat/test-unit-job-endpoint-services.R-18-
api/tests/testthat/test-unit-job-endpoint-services.R-19-# Resolve api_dir robustly so the file runs both under the full suite and a single-file
api/tests/testthat/test-unit-job-endpoint-services.R-20-# testthat::test_file(), then source the shared fixtures.
api/tests/testthat/test-unit-job-endpoint-services.R-21-if (exists("get_api_dir")) {
api/tests/testthat/test-unit-job-endpoint-services.R-22-  api_dir <- get_api_dir()
--
api/tests/testthat/test-unit-analysis-snapshot-builder.R-118-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-119-  env$analysis_snapshot_acquire_lock <- function(analysis_type, parameter_hash, timeout_seconds = 30L, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-120-    record_conn("acquire", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-121-    TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-122-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R:123:  env$analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-124-    record_conn("release", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-125-    TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-126-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-127-  env$analysis_snapshot_source_data_version <- function(conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-128-    record_conn("source_version", conn)
--
api/tests/testthat/test-unit-analysis-snapshot-builder.R-227-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-228-  env$analysis_snapshot_acquire_lock <- function(analysis_type, parameter_hash, timeout_seconds = 30L, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-229-    record_conn("acquire", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-230-    TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-231-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R:232:  env$analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-233-    record_conn("release", conn)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-234-    TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-235-  }
api/tests/testthat/test-unit-analysis-snapshot-builder.R-236-  env$analysis_snapshot_source_data_version <- function(conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-237-    record_conn("source_version", conn)
--
api/tests/testthat/test-unit-analysis-snapshot-builder.R-297-  refresh_conn <- structure(list(label = "refresh"), class = "DBIConnection")
api/tests/testthat/test-unit-analysis-snapshot-builder.R-298-  clusters <- tibble::tibble(cluster = 1L, identifiers = list(tibble::tibble(hgnc_id = "HGNC:1")))
api/tests/testthat/test-unit-analysis-snapshot-builder.R-299-  env$get_db_connection <- function() refresh_conn
api/tests/testthat/test-unit-analysis-snapshot-builder.R-300-  env$db_with_transaction <- function(code, pool_obj = NULL) code(pool_obj)
api/tests/testthat/test-unit-analysis-snapshot-builder.R-301-  env$analysis_snapshot_acquire_lock <- function(...) TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R:302:  env$analysis_snapshot_release_lock <- function(...) TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R-303-  env$analysis_snapshot_source_data_version <- function(...) "source-v1"
api/tests/testthat/test-unit-analysis-snapshot-builder.R-304-  env$analysis_snapshot_build_payload <- function(...) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R-305-    list(
api/tests/testthat/test-unit-analysis-snapshot-builder.R-306-      kind = "clusters",
api/tests/testthat/test-unit-analysis-snapshot-builder.R-307-      raw = clusters,
--
api/tests/testthat/helper-db.R-156-
api/tests/testthat/helper-db.R-157-  invisible(TRUE)
api/tests/testthat/helper-db.R-158-}
api/tests/testthat/helper-db.R-159-
api/tests/testthat/helper-db.R-160-
api/tests/testthat/helper-db.R:161:test_analysis_snapshot_release_migration_path <- function() {
api/tests/testthat/helper-db.R-162-  candidates <- c(
api/tests/testthat/helper-db.R:163:    file.path(get_api_dir(), "..", "db", "migrations", "045_add_analysis_snapshot_release.sql"),
api/tests/testthat/helper-db.R:164:    file.path(get_api_dir(), "db", "migrations", "045_add_analysis_snapshot_release.sql")
api/tests/testthat/helper-db.R-165-  )
api/tests/testthat/helper-db.R-166-
api/tests/testthat/helper-db.R-167-  for (candidate in candidates) {
api/tests/testthat/helper-db.R-168-    if (file.exists(candidate)) {
api/tests/testthat/helper-db.R-169-      return(candidate)
--
api/tests/testthat/helper-db.R-172-
api/tests/testthat/helper-db.R-173-  candidates[[1]]
api/tests/testthat/helper-db.R-174-}
api/tests/testthat/helper-db.R-175-
api/tests/testthat/helper-db.R-176-
api/tests/testthat/helper-db.R:177:apply_test_analysis_snapshot_release_migration <- function(conn) {
api/tests/testthat/helper-db.R-178-  if (!exists("split_sql_statements", mode = "function")) {
api/tests/testthat/helper-db.R-179-    source_api_file("functions/migration-runner.R", local = FALSE, envir = .GlobalEnv)
api/tests/testthat/helper-db.R-180-  }
api/tests/testthat/helper-db.R-181-
api/tests/testthat/helper-db.R:182:  migration_path <- test_analysis_snapshot_release_migration_path()
api/tests/testthat/helper-db.R-183-  if (!file.exists(migration_path)) {
api/tests/testthat/helper-db.R-184-    stop("analysis-snapshot-release migration file is missing: ", migration_path)
api/tests/testthat/helper-db.R-185-  }
api/tests/testthat/helper-db.R-186-
api/tests/testthat/helper-db.R-187-  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")
--
api/tests/testthat/helper-db.R-194-
api/tests/testthat/helper-db.R-195-
api/tests/testthat/helper-db.R-196-#' Ensure the analysis-snapshot RELEASE schema (migration 045) exists
api/tests/testthat/helper-db.R-197-#'
api/tests/testthat/helper-db.R-198-#' Idempotent: migration 045's `CREATE TABLE IF NOT EXISTS` statements are a
api/tests/testthat/helper-db.R:199:#' no-op when the three release tables already exist. `analysis_snapshot_release`
api/tests/testthat/helper-db.R-200-#' has an FK to `user(user_id)`, so the minimal user fixture table is ensured
api/tests/testthat/helper-db.R-201-#' first. Call this on its OWN plain connection, separate from (and before)
api/tests/testthat/helper-db.R-202-#' any `with_test_db_transaction()` block — DDL auto-commits and cannot be
api/tests/testthat/helper-db.R-203-#' rolled back, so mixing it into a transactional test connection would break
api/tests/testthat/helper-db.R-204-#' isolation (see the `with_test_db_transaction()` docs above).
api/tests/testthat/helper-db.R-205-#'
api/tests/testthat/helper-db.R-206-#' @param conn DBI connection to the test database
api/tests/testthat/helper-db.R-207-#' @return Invisibly TRUE
api/tests/testthat/helper-db.R-208-ensure_test_release_schema <- function(conn) {
api/tests/testthat/helper-db.R-209-  ensure_test_user_table(conn)
api/tests/testthat/helper-db.R:210:  apply_test_analysis_snapshot_release_migration(conn)
api/tests/testthat/helper-db.R-211-  invisible(TRUE)
api/tests/testthat/helper-db.R-212-}
api/tests/testthat/helper-db.R-213-
api/tests/testthat/helper-db.R-214-
api/tests/testthat/helper-db.R-215-test_analysis_snapshot_manifest_migration_path <- function() {
--
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-1-analysis_snapshot_test_wd <- getwd()
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-2-setwd(get_api_dir())
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-3-withr::defer(setwd(analysis_snapshot_test_wd), testthat::teardown_env())
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-4-
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-5-test_that("async workers preload analysis snapshot refresh dependencies before handlers", {
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R:6:  lines <- readLines(file.path("bootstrap", "setup_workers.R"), warn = FALSE)
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-7-
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-8-  expected_sources <- c(
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-9-    'source("/app/functions/analysis-snapshot-presets.R", local = FALSE)',
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-10-    'source("/app/functions/analysis-snapshot-repository.R", local = FALSE)',
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-11-    'source("/app/functions/analysis-snapshot-builder.R", local = FALSE)',
--
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-32-# ---------------------------------------------------------------------------
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-33-# #346 Wave 4: async_job_handler_registry binds provider/maintenance handler
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-34-# functions by bare symbol inside an eagerly-evaluated list(), so both
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-35-# extracted modules must be sourced BEFORE async-job-handlers.R at every
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-36-# worker entrypoint, exactly once, in this relative order. These two checks
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R:37:# cover BOTH worker entrypoints: the mirai bootstrap (bootstrap/setup_workers.R)
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-38-# and the durable async worker's guarded fallback chain
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-39-# (functions/async-job-worker.R). Wiring those two files is an explicitly
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-40-# separate, coordinated step (owned outside this handler-split task, alongside
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-41-# load_modules.R and start_async_worker.R, to avoid parallel-worktree merge
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-42-# conflicts across the other #346 Wave 4 file splits) -- so each check
--
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-44-# lines, rather than hard-failing on work that is intentionally out of scope
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-45-# here. Once the wiring lands, these upgrade automatically from SKIP to a real
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-46-# assertion.
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-47-# ---------------------------------------------------------------------------
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-48-
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R:49:test_that("mirai bootstrap preloads provider/maintenance handlers before the shell, exactly once", {
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R:50:  lines <- readLines(file.path("bootstrap", "setup_workers.R"), warn = FALSE)
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-51-
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-52-  expected_sources <- c(
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-53-    'source("/app/functions/async-job-provider-handlers.R", local = FALSE)',
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-54-    'source("/app/functions/async-job-maintenance-handlers.R", local = FALSE)',
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-55-    'source("/app/functions/async-job-handlers.R", local = FALSE)'
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-56-  )
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-57-
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-58-  if (!any(trimws(lines) == expected_sources[[1]])) {
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-59-    skip(paste(
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R:60:      "bootstrap/setup_workers.R does not yet source async-job-provider-handlers.R",
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-61-      "-- pending coordinated #346 Wave 4 bootstrap wiring"
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-62-    ))
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-63-  }
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-64-
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-65-  positions <- vapply(
--
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-103-  expect_lt(provider_pos, shell_pos)
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-104-  expect_lt(maintenance_pos, shell_pos)
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-105-})
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-106-
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-107-test_that("async workers preload LLM model configuration before LLM clients", {
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R:108:  lines <- trimws(readLines(file.path("bootstrap", "setup_workers.R"), warn = FALSE))
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-109-
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-110-  model_config_pos <- which(lines == 'source("/app/functions/llm-model-config.R", local = FALSE)')
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-111-  client_pos <- which(lines == 'source("/app/functions/llm-client.R", local = FALSE)')
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-112-  service_pos <- which(lines == 'source("/app/functions/llm-service.R", local = FALSE)')
api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R-113-
--
api/tests/testthat/test-unit-analysis-snapshot-migration.R-4-withr::defer(setwd(analysis_snapshot_test_wd), testthat::teardown_env())
api/tests/testthat/test-unit-analysis-snapshot-migration.R-5-
api/tests/testthat/test-unit-analysis-snapshot-migration.R-6-test_that("migration manifest tracks the latest migration", {
api/tests/testthat/test-unit-analysis-snapshot-migration.R-7-  source(file.path("functions", "migration-manifest.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-migration.R-8-
api/tests/testthat/test-unit-analysis-snapshot-migration.R:9:  expect_equal(EXPECTED_LATEST_MIGRATION, "045_add_analysis_snapshot_release.sql")
api/tests/testthat/test-unit-analysis-snapshot-migration.R-10-  expect_equal(EXPECTED_MIGRATION_COUNT, 43L)
api/tests/testthat/test-unit-analysis-snapshot-migration.R-11-})
api/tests/testthat/test-unit-analysis-snapshot-migration.R-12-
api/tests/testthat/test-unit-analysis-snapshot-migration.R-13-test_that("migration 041 adds the reproducibility bundle table", {
api/tests/testthat/test-unit-analysis-snapshot-migration.R-14-  migration_path <- file.path(
--
api/tests/testthat/test-mcp-select-principal-projections.R-175-  expect_identical(mcp_readonly_llm_summary_json_keys(), allowed_json_keys)
api/tests/testthat/test-mcp-select-principal-projections.R-176-  expect_false(grepl("judge|reasoning|validation_status", paste(allowed_json_keys, collapse = "|")))
api/tests/testthat/test-mcp-select-principal-projections.R-177-})
api/tests/testthat/test-mcp-select-principal-projections.R-178-
api/tests/testthat/test-mcp-select-principal-projections.R-179-test_that("manifest advances contiguously to migration 045", {
api/tests/testthat/test-mcp-select-principal-projections.R:180:  expect_identical(EXPECTED_LATEST_MIGRATION, "045_add_analysis_snapshot_release.sql")
api/tests/testthat/test-mcp-select-principal-projections.R-181-  expect_identical(EXPECTED_MIGRATION_COUNT, 43L)
api/tests/testthat/test-mcp-select-principal-projections.R-182-})
--
api/tests/testthat/test-unit-core-views-manifest.R-9-migration_test_api_dir <- Sys.getenv("MCP_API_TEST_ROOT", get_api_dir())
api/tests/testthat/test-unit-core-views-manifest.R-10-source(file.path(migration_test_api_dir, "functions", "migration-manifest.R"), local = FALSE)
api/tests/testthat/test-unit-core-views-manifest.R-11-source(file.path(migration_test_api_dir, "functions", "migration-runner.R"), local = FALSE)
api/tests/testthat/test-unit-core-views-manifest.R-12-
api/tests/testthat/test-unit-core-views-manifest.R-13-test_that("manifest expects migration 045 as latest", {
api/tests/testthat/test-unit-core-views-manifest.R:14:  expect_equal(EXPECTED_LATEST_MIGRATION, "045_add_analysis_snapshot_release.sql")
api/tests/testthat/test-unit-core-views-manifest.R-15-  expect_equal(EXPECTED_MIGRATION_COUNT, 43L)
api/tests/testthat/test-unit-core-views-manifest.R-16-})
api/tests/testthat/test-unit-core-views-manifest.R-17-
api/tests/testthat/test-unit-core-views-manifest.R-18-test_that("migration manifest validates against db/migrations", {
api/tests/testthat/test-unit-core-views-manifest.R-19-  migrations_dir <- file.path(migration_test_api_dir, "..", "db", "migrations")
api/tests/testthat/test-unit-core-views-manifest.R-20-  res <- validate_migration_manifest(migrations_dir = migrations_dir)
api/tests/testthat/test-unit-core-views-manifest.R-21-  expect_true(res$ok)
api/tests/testthat/test-unit-core-views-manifest.R:22:  expect_identical(res$latest, "045_add_analysis_snapshot_release.sql")
api/tests/testthat/test-unit-core-views-manifest.R-23-})
api/tests/testthat/test-unit-core-views-manifest.R-24-
api/tests/testthat/test-unit-core-views-manifest.R-25-test_that("migration 036 file exists and contains disease_ontology_mapping table", {
api/tests/testthat/test-unit-core-views-manifest.R-26-  migration_path <- file.path(
api/tests/testthat/test-unit-core-views-manifest.R-27-    migration_test_api_dir, "..", "db", "migrations",
--
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-1-# tests/testthat/test-unit-analysis-snapshot-release-migration.R
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-2-#
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:3:# Migration smoke test for 045_add_analysis_snapshot_release.sql (#573).
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-4-#
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-5-# Applies migration 045 directly to the test database (mirroring the
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-6-# apply_test_async_job_migration() idiom in helper-db.R) and asserts the
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-7-# three release tables exist with their key columns. Migration 045 has an
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-8-# FK to `user(user_id)`, so the minimal user fixture table is created first
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-9-# via ensure_test_user_table(). Because the migration's CREATE TABLE
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-10-# statements are guarded with IF NOT EXISTS (DDL auto-commits and cannot be
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-11-# rolled back), the test drops the three release tables itself at the end
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-12-# so reruns stay idempotent.
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-13-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:14:analysis_snapshot_release_migration_path <- function() {
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-15-  candidates <- c(
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:16:    file.path(get_api_dir(), "..", "db", "migrations", "045_add_analysis_snapshot_release.sql"),
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:17:    file.path(get_api_dir(), "db", "migrations", "045_add_analysis_snapshot_release.sql")
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-18-  )
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-19-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-20-  for (candidate in candidates) {
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-21-    if (file.exists(candidate)) {
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-22-      return(candidate)
--
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-24-  }
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-25-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-26-  candidates[[1]]
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-27-}
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-28-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:29:apply_analysis_snapshot_release_migration <- function(conn) {
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-30-  if (!exists("split_sql_statements", mode = "function")) {
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-31-    source_api_file("functions/migration-runner.R", local = FALSE, envir = .GlobalEnv)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-32-  }
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-33-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:34:  migration_path <- analysis_snapshot_release_migration_path()
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-35-  if (!file.exists(migration_path)) {
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-36-    stop("analysis-snapshot-release migration file is missing: ", migration_path)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-37-  }
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-38-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-39-  sql <- paste(readLines(migration_path, warn = FALSE), collapse = "\n")
--
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-42-  }
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-43-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-44-  invisible(TRUE)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-45-}
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-46-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:47:drop_analysis_snapshot_release_tables <- function(conn) {
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-48-  # Children first, then the head table (FK ON DELETE CASCADE dependency order).
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-49-  for (tbl in c(
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:50:    "analysis_snapshot_release_file",
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:51:    "analysis_snapshot_release_member",
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:52:    "analysis_snapshot_release"
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-53-  )) {
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-54-    if (DBI::dbExistsTable(conn, tbl)) {
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-55-      DBI::dbExecute(conn, paste0("DROP TABLE `", tbl, "`"), immediate = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-56-    }
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-57-  }
--
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-66-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-67-  ensure_test_user_table(conn)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-68-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-69-  # Clean slate: drop any leftovers from a prior interrupted run so the
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-70-  # CREATE TABLE IF NOT EXISTS statements actually create fresh tables here.
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:71:  drop_analysis_snapshot_release_tables(conn)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:72:  withr::defer(drop_analysis_snapshot_release_tables(conn))
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-73-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:74:  apply_analysis_snapshot_release_migration(conn)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-75-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:76:  expect_true(DBI::dbExistsTable(conn, "analysis_snapshot_release"))
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:77:  expect_true(DBI::dbExistsTable(conn, "analysis_snapshot_release_member"))
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:78:  expect_true(DBI::dbExistsTable(conn, "analysis_snapshot_release_file"))
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-79-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:80:  head_cols <- DBI::dbListFields(conn, "analysis_snapshot_release")
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-81-  expect_true("content_digest" %in% head_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-82-  expect_true("bundle_gzip" %in% head_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-83-  expect_true("manifest_sha256" %in% head_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-84-  expect_true("bundle_sha256" %in% head_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-85-  expect_true("status" %in% head_cols)
--
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-87-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-88-  # status is a MySQL ENUM('draft','published').
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-89-  status_type <- DBI::dbGetQuery(
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-90-    conn,
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-91-    "SELECT COLUMN_TYPE FROM information_schema.COLUMNS
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:92:     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'analysis_snapshot_release'
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-93-       AND COLUMN_NAME = 'status'"
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-94-  )$COLUMN_TYPE
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-95-  expect_match(status_type, "^enum\\('draft','published'\\)$")
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-96-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:97:  member_cols <- DBI::dbListFields(conn, "analysis_snapshot_release_member")
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-98-  expect_true("release_id" %in% member_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-99-  expect_true("analysis_type" %in% member_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-100-  expect_true("parameter_hash" %in% member_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-101-  expect_true("snapshot_id" %in% member_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-102-  expect_true("payload_hash" %in% member_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-103-  expect_true("role" %in% member_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-104-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:105:  file_cols <- DBI::dbListFields(conn, "analysis_snapshot_release_file")
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-106-  expect_true("release_id" %in% file_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-107-  expect_true("file_path" %in% file_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-108-  expect_true("content_sha256" %in% file_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-109-  expect_true("content_gzip" %in% file_cols)
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-110-})
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-39-TEST_RELEASE_ID_2 <- "asr_test0000000002"
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-40-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-41-.delete_test_releases <- function(conn) {
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-42-  DBI::dbExecute(
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-43-    conn,
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:44:    "DELETE FROM analysis_snapshot_release WHERE release_id IN (?, ?)",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-45-    params = unname(list(TEST_RELEASE_ID, TEST_RELEASE_ID_2))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-46-  )
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-47-}
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-48-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-49-make_gzip_file <- function(file_path, text, media_type = "application/json") {
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-295-  expect_null(analysis_release_get(TEST_RELEASE_ID_2, include_draft = TRUE, conn = conn))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-296-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-297-  # children cascaded: no orphaned member/file rows survive
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-298-  member_count <- DBI::dbGetQuery(
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-299-    conn,
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:300:    "SELECT COUNT(*) AS n FROM analysis_snapshot_release_member WHERE release_id = ?",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-301-    params = unname(list(TEST_RELEASE_ID_2))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-302-  )$n
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-303-  file_count <- DBI::dbGetQuery(
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-304-    conn,
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:305:    "SELECT COUNT(*) AS n FROM analysis_snapshot_release_file WHERE release_id = ?",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-306-    params = unname(list(TEST_RELEASE_ID_2))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-307-  )$n
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-308-  expect_equal(as.integer(member_count), 0L)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-309-  expect_equal(as.integer(file_count), 0L)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-310-
--
api/tests/testthat/test-integration-analysis-release-endpoints.R-67-TEST_DRAFT_RELEASE_ID <- "asr_test0000000602"
api/tests/testthat/test-integration-analysis-release-endpoints.R-68-
api/tests/testthat/test-integration-analysis-release-endpoints.R-69-.delete_test_a6_releases <- function(conn) {
api/tests/testthat/test-integration-analysis-release-endpoints.R-70-  DBI::dbExecute(
api/tests/testthat/test-integration-analysis-release-endpoints.R-71-    conn,
api/tests/testthat/test-integration-analysis-release-endpoints.R:72:    "DELETE FROM analysis_snapshot_release WHERE release_id IN (?, ?)",
api/tests/testthat/test-integration-analysis-release-endpoints.R-73-    params = unname(list(TEST_RELEASE_ID, TEST_DRAFT_RELEASE_ID))
api/tests/testthat/test-integration-analysis-release-endpoints.R-74-  )
api/tests/testthat/test-integration-analysis-release-endpoints.R-75-}
api/tests/testthat/test-integration-analysis-release-endpoints.R-76-
api/tests/testthat/test-integration-analysis-release-endpoints.R-77-make_gzip_file <- function(file_path, text, media_type = "application/json") {
--
api/tests/testthat/test-llm-batch.R-71-    symbols = c("BRCA1,TP53", "MECP2,FOXG1"),
api/tests/testthat/test-llm-batch.R-72-    term_enrichment = c("{}", "{}")
api/tests/testthat/test-llm-batch.R-73-  )
api/tests/testthat/test-llm-batch.R-74-
api/tests/testthat/test-llm-batch.R-75-  # Function should not error when GEMINI_API_KEY is set
api/tests/testthat/test-llm-batch.R:76:  # Note: Actual job creation requires mirai daemons, so we just test that it doesn't error
api/tests/testthat/test-llm-batch.R-77-  expect_error(
api/tests/testthat/test-llm-batch.R-78-    trigger_llm_batch_generation(
api/tests/testthat/test-llm-batch.R-79-      clusters = clusters,
api/tests/testthat/test-llm-batch.R-80-      cluster_type = "functional",
api/tests/testthat/test-llm-batch.R-81-      parent_job_id = "test-123"
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-1-# tests/testthat/test-integration-analysis-snapshot-release-build.R
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-2-#
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-3-# Tests for the analysis-snapshot RELEASE build orchestrator (#573 Slice A /
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:4:# Task A4): analysis_snapshot_release_build().
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-5-#
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-6-# ARCHITECTURE: the orchestrator has three dependency-injection seams so the
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-7-# correctness-critical GATES are deterministically unit-testable WITHOUT seeding
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-8-# the (very complex) analysis_snapshot_* source tables:
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-9-#   - loader(analysis_type, parameter_hash, conn)  (default analysis_snapshot_get_public)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-10-#   - reproducibility_loader(snapshot_id, conn)    (default analysis_snapshot_get_reproducibility)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:11:#   - coherence_assert(snapshot, kind)             (default analysis_snapshot_release_assert_coherent)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-12-# Every gate branch is driven by injecting fakes. PERSISTENCE (analysis_release_*)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-13-# runs against the REAL release tables (ensure_test_release_schema), so
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-14-# idempotency/persistence is genuinely exercised even while the snapshot SOURCE is
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-15-# faked. The real seam DEFAULTS are exercised by the post-slice dev-stack e2e.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-16-#
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-241-      "phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-242-      status_code = "snapshot_stale"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-243-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-244-  ))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-245-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:246:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-247-      conn = NULL, publish = TRUE,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-248-      loader = loader, reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-249-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-250-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-251-    class = "release_snapshot_not_available"
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-253-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-254-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-255-test_that("build refuses an available-but-incoherent snapshot (hard coherence re-check)", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-256-  throwing_coherence <- function(snapshot, kind) stop("planted incoherence")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-257-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:258:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-259-      conn = NULL, publish = TRUE,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-260-      loader = make_loader(), reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-261-      coherence_assert = throwing_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-262-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-263-    class = "release_source_incoherent"
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-270-      return(NULL)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-271-    }
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-272-    present_repro_loader(snapshot_id, conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-273-  }
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-274-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:275:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-276-      conn = NULL, publish = TRUE,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-277-      loader = make_loader(), reproducibility_loader = missing_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-278-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-279-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-280-    class = "release_reproducibility_missing"
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-287-      "phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-288-      source_data_version = "srcv-DIFFERENT"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-289-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-290-  ))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-291-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:292:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-293-      conn = NULL, publish = TRUE,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-294-      loader = loader, reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-295-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-296-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-297-    class = "release_source_version_mismatch"
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-302-  # Correlation manifest pins a functional snapshot_id that no longer matches.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-303-  loader <- make_loader(list(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-304-    phenotype_functional_correlations = make_corr_snap(func_id = 999L)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-305-  ))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-306-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:307:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-308-      conn = NULL, publish = TRUE,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-309-      loader = loader, reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-310-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-311-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-312-    class = "release_dependency_lineage_mismatch"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-313-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-314-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-315-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-316-test_that("build rejects an unknown requested layer (selection, not redefinition) with 400", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-317-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:318:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-319-      conn = NULL, publish = TRUE, layers = list(list(analysis_type = "not_a_layer")),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-320-      loader = make_loader(), reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-321-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-322-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-323-    class = "error_400"
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-333-    }
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-334-    row$reproducibility_hash <- analysis_release_sha256("this-hash-does-not-match-the-bytes")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-335-    row
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-336-  }
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-337-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:338:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-339-      conn = NULL, publish = TRUE,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-340-      loader = make_loader(), reproducibility_loader = corrupt_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-341-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-342-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-343-    class = "release_reproducibility_missing"
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-346-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-347-test_that("build refuses to proceed unlocked when the advisory lock cannot be acquired (H3a)", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-348-  # Inject a lock seam that reports acquisition FAILED (a source preset is mid-refresh).
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-349-  failing_lock <- function(conn, lock_names) list(ok = FALSE, acquired = character(0), skipped = FALSE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-350-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:351:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-352-      conn = NULL, publish = TRUE,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-353-      loader = make_loader(), reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-354-      coherence_assert = pass_coherence, lock_acquire = failing_lock
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-355-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-356-    class = "release_lock_unavailable"
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-364-    functional_clusters = make_functional_snap_with_channels(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-365-      membership_channel = "combined_score", validation_channel = "experimental_database"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-366-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-367-  ))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-368-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:369:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-370-      conn = NULL, publish = TRUE,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-371-      loader = loader, reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:372:      coherence_assert = analysis_snapshot_release_assert_coherent # the REAL default
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-373-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-374-    class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-375-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-376-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-377-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-378-# --------------------------------------------------------------------------- #
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-379-# Real default coherence seam: pass when internally consistent, throw
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-380-# release_source_incoherent when a visible cluster lacks a stability score.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-381-# --------------------------------------------------------------------------- #
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-382-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:383:test_that("analysis_snapshot_release_assert_coherent gates stored-snapshot integrity", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-384-  ok <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:385:  expect_invisible(analysis_snapshot_release_assert_coherent(ok, "functional"))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-386-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-387-  incoherent <- make_cluster_snap(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-388-    "functional_clusters", "functional", FUNC_ID, FUNC_HASH,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-389-    stability_ok = FALSE
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-390-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-391-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:392:    analysis_snapshot_release_assert_coherent(incoherent, "functional"),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-393-    class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-394-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-395-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-396-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:397:test_that("analysis_snapshot_release_assert_coherent runs the H4 member-set proof when attested", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-398-  # served functional cluster_members: cluster 1 = {HGNC:1,2,3}, cluster 2 = {HGNC:4,5}.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-399-  coherent_ref <- list("1" = c("HGNC:1", "HGNC:2", "HGNC:3"), "2" = c("HGNC:4", "HGNC:5"))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-400-  incoherent_ref <- list("1" = c("HGNC:1", "HGNC:2", "HGNC:99"), "2" = c("HGNC:4", "HGNC:5"))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-401-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-402-  # (b) coherent attestation -> passes, no member-set warning.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-403-  expect_invisible(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:404:    analysis_snapshot_release_assert_coherent(make_functional_snap_with_reference(coherent_ref), "functional")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-405-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-406-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-407-  # (a) attested snapshot whose served members differ in CONTENT (same cluster-ids)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-408-  #     -> refuse, EVEN with the build-time coherence env downgraded to false.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-409-  withr::with_envvar(list(ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE = "false"), {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-410-    expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:411:      analysis_snapshot_release_assert_coherent(make_functional_snap_with_reference(incoherent_ref), "functional"),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-412-      class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-413-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-414-  })
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-415-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-416-  # (c) legacy snapshot WITHOUT the attestation -> degrades + warns (never refuses).
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-417-  legacy <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-418-  expect_warning(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:419:    expect_invisible(analysis_snapshot_release_assert_coherent(legacy, "functional")),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-420-    "member-set verification is unavailable"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-421-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-422-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-423-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-424-test_that("a PARTIAL/incomplete reference attestation is treated as incoherent, not degraded (MC2)", {
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-428-  partial_ref <- list("1" = c("HGNC:1", "HGNC:2", "HGNC:3")) # missing served cluster "2"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-429-  snap <- make_functional_snap_with_reference(partial_ref)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-430-  # If it were mis-treated as legacy-absent it would degrade + PASS; expect_error
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-431-  # proves it hard-fails instead.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-432-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:433:    analysis_snapshot_release_assert_coherent(snap, "functional"),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-434-    class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-435-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-436-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-437-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-438-test_that("build refuses an attested snapshot whose member set differs from the reference (H4)", {
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-441-      list("1" = c("HGNC:1", "HGNC:2", "HGNC:99"), "2" = c("HGNC:4", "HGNC:5"))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-442-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-443-  ))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-444-  withr::with_envvar(list(ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE = "false"), {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-445-    expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:446:      analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-447-        conn = NULL, publish = TRUE,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-448-        loader = loader, reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:449:        coherence_assert = analysis_snapshot_release_assert_coherent # REAL default
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-450-      ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-451-      class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-452-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-453-  })
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-454-})
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-456-test_that("build rejects layers with conflicting db_release provenance (M2)", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-457-  phen <- make_cluster_snap("phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-458-  phen$manifest$db_release_version <- "9.9.9" # conflicts with functional's 1.0.0
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-459-  loader <- make_loader(list(phenotype_clusters = phen))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-460-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:461:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-462-      conn = NULL, publish = TRUE,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-463-      loader = loader, reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-464-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-465-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-466-    class = "release_source_version_mismatch"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-467-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-468-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-469-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:470:test_that("analysis_snapshot_release_assert_coherent enforces the functional channel match", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-471-  # Both channels present + equal -> passes; present + differ -> throws; absent -> skip.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-472-  matched <- make_functional_snap_with_channels("experimental_database", "experimental_database")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:473:  expect_invisible(analysis_snapshot_release_assert_coherent(matched, "functional"))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-474-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-475-  mismatched <- make_functional_snap_with_channels("combined_score", "experimental_database")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-476-  expect_error(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:477:    analysis_snapshot_release_assert_coherent(mismatched, "functional"),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-478-    class = "release_source_incoherent"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-479-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-480-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-481-  # No validation_json -> channel comparison skipped (older snapshots still pass).
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-482-  no_channels <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:483:  expect_invisible(analysis_snapshot_release_assert_coherent(no_channels, "functional"))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-484-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-485-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-486-# --------------------------------------------------------------------------- #
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-487-# Success + idempotency (real release persistence).
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-488-# --------------------------------------------------------------------------- #
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-494-  ensure_test_release_schema(schema_conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-495-  DBI::dbDisconnect(schema_conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-496-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-497-  conn <- get_test_db_connection()
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-498-  withr::defer(DBI::dbDisconnect(conn))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:499:  DBI::dbExecute(conn, "DELETE FROM analysis_snapshot_release")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:500:  withr::defer(DBI::dbExecute(conn, "DELETE FROM analysis_snapshot_release"))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-501-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-502-  code(conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-503-}
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-504-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-505-test_that("build materializes a content-addressed release; repro hash + payload lineage anchor hold", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-506-  with_release_build_db(function(conn) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:507:    result <- analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-508-      conn = conn, publish = TRUE, title = "SysNDD analysis snapshot release",
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-509-      scope_statement = "Curated derived cluster analysis.",
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-510-      loader = make_loader(), reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-511-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-512-    )
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-560-    args <- list(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-561-      conn = conn, publish = TRUE,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-562-      loader = make_loader(), reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-563-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-564-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:565:    r1 <- do.call(analysis_snapshot_release_build, args)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-566-    expect_true(r1$created)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-567-    expect_match(r1$release$release_id, "^asr_[0-9a-f]{16}$")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-568-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:569:    r2 <- do.call(analysis_snapshot_release_build, args)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-570-    expect_false(r2$created)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-571-    expect_identical(r1$release$release_id, r2$release$release_id)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-572-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-573-    published <- analysis_release_list(status = "published", conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-574-    expect_identical(1L, length(published))
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-579-  with_release_build_db(function(conn) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-580-    # The stateful loader returns snapshot_id 101 on the first functional read but
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-581-    # snapshot_id 999 on the pre-insert re-read: if the re-read were tautological
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
rg: api/bootstrap/start_async_worker.R: No such file or directory (os error 2)
api/functions/async-job-service.R-78-
api/functions/async-job-service.R-79-# Latency-sensitive / user-visible interactive job types. They stay on the
api/functions/async-job-service.R-80-# "default" lane but get the LOWEST priority number so a worker claims them ahead
api/functions/async-job-service.R-81-# of any maintenance job that happens to share the queue.
api/functions/async-job-service.R-82-ASYNC_INTERACTIVE_JOB_TYPES <- c(
api/functions/async-job-service.R-83-  "clustering",
api/functions/async-job-service.R-84-  "phenotype_clustering",
api/functions/async-job-service.R-85-  "llm_generation",
api/functions/async-job-service.R:86:  "analysis_snapshot_refresh",
api/functions/async-job-service.R-87-  "network_layout_prewarm"
api/functions/async-job-service.R-88-)
api/functions/async-job-service.R-89-
api/functions/async-job-service.R-90-# Priority tiers (lower number = claimed first; the claim query orders
api/functions/async-job-service.R-91-# `priority ASC`). interactive < maintenance < everything-else default.
api/functions/async-job-service.R-92-ASYNC_PRIORITY_INTERACTIVE <- 10L
api/functions/async-job-service.R-93-ASYNC_PRIORITY_MAINTENANCE <- 50L
api/functions/async-job-service.R-94-ASYNC_PRIORITY_DEFAULT <- 100L
--
api/functions/async-job-analysis-snapshot-handlers.R-1-# functions/async-job-analysis-snapshot-handlers.R
api/functions/async-job-analysis-snapshot-handlers.R-2-
api/functions/async-job-analysis-snapshot-handlers.R-3-if (!exists("%||%", mode = "function")) {
api/functions/async-job-analysis-snapshot-handlers.R-4-  `%||%` <- function(x, y) if (is.null(x)) y else x
api/functions/async-job-analysis-snapshot-handlers.R-5-}
api/functions/async-job-analysis-snapshot-handlers.R-6-
api/functions/async-job-analysis-snapshot-handlers.R:7:.async_job_run_analysis_snapshot_refresh <- function(job, payload, state, worker_config) {
api/functions/async-job-analysis-snapshot-handlers.R-8-  analysis_type <- as.character(payload$analysis_type[[1]] %||% payload$analysis_type)
api/functions/async-job-analysis-snapshot-handlers.R-9-  params <- payload$params %||% list()
api/functions/async-job-analysis-snapshot-handlers.R-10-  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 2)
api/functions/async-job-analysis-snapshot-handlers.R-11-
api/functions/async-job-analysis-snapshot-handlers.R-12-  progress("snapshot_start", paste("Refreshing analysis snapshot", analysis_type), current = 0, total = 3)
api/functions/async-job-analysis-snapshot-handlers.R-13-  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
api/functions/async-job-analysis-snapshot-handlers.R-14-  progress("snapshot_build", paste("Building analysis snapshot", analysis_type), current = 1, total = 3)
api/functions/async-job-analysis-snapshot-handlers.R:15:  result <- analysis_snapshot_refresh(
api/functions/async-job-analysis-snapshot-handlers.R-16-    analysis_type = normalized$analysis_type,
api/functions/async-job-analysis-snapshot-handlers.R-17-    params = normalized$params,
api/functions/async-job-analysis-snapshot-handlers.R-18-    job_id = job$job_id[[1]]
api/functions/async-job-analysis-snapshot-handlers.R-19-  )
api/functions/async-job-analysis-snapshot-handlers.R-20-  progress("snapshot_complete", paste("Analysis snapshot refreshed", analysis_type), current = 3, total = 3)
api/functions/async-job-analysis-snapshot-handlers.R-21-
api/functions/async-job-analysis-snapshot-handlers.R-22-  result
api/functions/async-job-analysis-snapshot-handlers.R-23-}

exec
/bin/bash -lc "rg -n -C 4 'mirai::mirai|\\.async_job_run_analysis_snapshot_refresh|async_job_run|analysis_snapshot_refresh\\(' api/endpoints api/functions api/services | head -n 1000 && rg --files api | rg 'start.*worker|worker.*start|async-worker' && sed -n '1,180p' api/scripts/start_async_worker.R 2>/dev/null || true && rg -n -C 5 'analysis_snapshot_refresh' api/functions/job-manager.R api/functions/async-job-worker.R api/functions/async-job-handlers.R api/functions/async-job-repository.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
api/services/job-maintenance-submission-service.R-11-# place: status + headers) and return the JSON payload.
api/services/job-maintenance-submission-service.R-12-#
api/services/job-maintenance-submission-service.R-13-# DB credentials (#535 S2b): `hgnc_update` and `comparisons_update` no longer
api/services/job-maintenance-submission-service.R-14-# marshal a `db_config` into the job payload. Their durable handlers
api/services/job-maintenance-submission-service.R:15:# (.async_job_run_hgnc_update / comparisons_update_async) resolve DB creds at
api/services/job-maintenance-submission-service.R-16-# run time from the worker's runtime config via `async_job_db_connect()`, so no
api/services/job-maintenance-submission-service.R-17-# password is ever persisted in `async_jobs.request_payload_json`. They also
api/services/job-maintenance-submission-service.R-18-# dedupe via job-type single-flight (`async_job_service_duplicate_by_type()`),
api/services/job-maintenance-submission-service.R-19-# not a payload hash, so a full-table-replace maintenance job never runs
--
api/services/admin-publication-refresh-endpoint-service.R-5-#
api/services/admin-publication-refresh-endpoint-service.R-6-# `create_job()` (functions/job-manager.R) is a durable-job compatibility
api/services/admin-publication-refresh-endpoint-service.R-7-# facade: it routes through `async_job_service_submit(job_type = operation,
api/services/admin-publication-refresh-endpoint-service.R-8-# request_payload = params)`. The real, currently-executed handler is
api/services/admin-publication-refresh-endpoint-service.R:9:# `.async_job_run_publication_refresh()` in functions/async-job-handlers.R
api/services/admin-publication-refresh-endpoint-service.R-10-# (registered in `async_job_handler_registry`), which already has the
api/services/admin-publication-refresh-endpoint-service.R-11-# publication_date_source fix, the same 350ms rate limit, and its own DB
api/services/admin-publication-refresh-endpoint-service.R-12-# connection lifecycle.
api/services/admin-publication-refresh-endpoint-service.R-13-#
--
api/services/backup-endpoint-service.R-12-# functions/job-progress.R (create_progress_reporter), and
api/services/backup-endpoint-service.R-13-# functions/backup-functions.R (list_backup_files, get_backup_metadata,
api/services/backup-endpoint-service.R-14-# is_valid_backup_filename). These svc_ functions only SUBMIT durable jobs:
api/services/backup-endpoint-service.R-15-# create_job() enqueues a durable async job that the worker executes via the
api/services/backup-endpoint-service.R:16:# registered handlers .async_job_run_backup_create /
api/services/backup-endpoint-service.R:17:# .async_job_run_backup_restore (functions/async-job-maintenance-handlers.R).
api/services/backup-endpoint-service.R-18-# The job payload carries NO DB credential (#535 P1-1); the worker resolves it
api/services/backup-endpoint-service.R-19-# at run time via async_job_worker_db_config().
api/services/backup-endpoint-service.R-20-
api/services/backup-endpoint-service.R-21-#' Shared 202/503 response shaping for the /create and /restore job
--
api/services/backup-endpoint-service.R-140-
api/services/backup-endpoint-service.R-141-  backup_filename <- sprintf("manual_%s.sql", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"))
api/services/backup-endpoint-service.R-142-
api/services/backup-endpoint-service.R-143-  # No DB credential in the job payload (#535 P1-1): the durable handler
api/services/backup-endpoint-service.R:144:  # .async_job_run_backup_create resolves it from runtime config; execution is
api/services/backup-endpoint-service.R-145-  # delegated to the registered durable handler.
api/services/backup-endpoint-service.R-146-  result <- create_job(
api/services/backup-endpoint-service.R-147-    operation = "backup_create",
api/services/backup-endpoint-service.R-148-    params = list(
--
api/services/backup-endpoint-service.R-198-    ))
api/services/backup-endpoint-service.R-199-  }
api/services/backup-endpoint-service.R-200-
api/services/backup-endpoint-service.R-201-  # No DB credential in the job payload (#535 P1-1): the durable handler
api/services/backup-endpoint-service.R:202:  # .async_job_run_backup_restore resolves it from runtime config and performs
api/services/backup-endpoint-service.R-203-  # the pre-restore safety backup (BKUP-05); execution is delegated to the
api/services/backup-endpoint-service.R-204-  # registered durable handler.
api/services/backup-endpoint-service.R-205-  result <- create_job(
api/services/backup-endpoint-service.R-206-    operation = "backup_restore",
--
api/functions/hgnc-enrichment-gnomad.R-262-#' Convenience wrapper for callers that want the gnomAD fallback
api/functions/hgnc-enrichment-gnomad.R-263-#' recovered/unresolved counts as explicit return values rather than reading
api/functions/hgnc-enrichment-gnomad.R-264-#' them from attributes on the enriched tibble. The current job paths
api/functions/hgnc-enrichment-gnomad.R-265-#' (`update_process_hgnc_data` → inline executor in `jobs_endpoints.R` and
api/functions/hgnc-enrichment-gnomad.R:266:#' the durable handler `.async_job_run_hgnc_update`) read the counts via
api/functions/hgnc-enrichment-gnomad.R-267-#' `attr(hgnc_data, ...)` directly because the broader pipeline preserves
api/functions/hgnc-enrichment-gnomad.R-268-#' attribute survival through dplyr cleanup; this wrapper is provided for
api/functions/hgnc-enrichment-gnomad.R-269-#' callers that prefer not to depend on that contract.
api/functions/hgnc-enrichment-gnomad.R-270-#'
--
api/functions/async-job-analysis-snapshot-handlers.R-3-if (!exists("%||%", mode = "function")) {
api/functions/async-job-analysis-snapshot-handlers.R-4-  `%||%` <- function(x, y) if (is.null(x)) y else x
api/functions/async-job-analysis-snapshot-handlers.R-5-}
api/functions/async-job-analysis-snapshot-handlers.R-6-
api/functions/async-job-analysis-snapshot-handlers.R:7:.async_job_run_analysis_snapshot_refresh <- function(job, payload, state, worker_config) {
api/functions/async-job-analysis-snapshot-handlers.R-8-  analysis_type <- as.character(payload$analysis_type[[1]] %||% payload$analysis_type)
api/functions/async-job-analysis-snapshot-handlers.R-9-  params <- payload$params %||% list()
api/functions/async-job-analysis-snapshot-handlers.R-10-  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 2)
api/functions/async-job-analysis-snapshot-handlers.R-11-
api/functions/async-job-analysis-snapshot-handlers.R-12-  progress("snapshot_start", paste("Refreshing analysis snapshot", analysis_type), current = 0, total = 3)
api/functions/async-job-analysis-snapshot-handlers.R-13-  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
api/functions/async-job-analysis-snapshot-handlers.R-14-  progress("snapshot_build", paste("Building analysis snapshot", analysis_type), current = 1, total = 3)
api/functions/async-job-analysis-snapshot-handlers.R:15:  result <- analysis_snapshot_refresh(
api/functions/async-job-analysis-snapshot-handlers.R-16-    analysis_type = normalized$analysis_type,
api/functions/async-job-analysis-snapshot-handlers.R-17-    params = normalized$params,
api/functions/async-job-analysis-snapshot-handlers.R-18-    job_id = job$job_id[[1]]
api/functions/async-job-analysis-snapshot-handlers.R-19-  )
--
api/functions/async-job-maintenance-handlers.R-10-# MUST be sourced BEFORE functions/async-job-handlers.R at every worker
api/functions/async-job-maintenance-handlers.R-11-# entrypoint (API bootstrap does not need it; the API never dispatches
api/functions/async-job-maintenance-handlers.R-12-# handlers, only submits jobs).
api/functions/async-job-maintenance-handlers.R-13-
api/functions/async-job-maintenance-handlers.R:14:.async_job_run_backup_create <- function(job, payload, state, worker_config) {
api/functions/async-job-maintenance-handlers.R-15-  progress <- .async_job_progress_reporter(job$job_id[[1]])
api/functions/async-job-maintenance-handlers.R-16-
api/functions/async-job-maintenance-handlers.R-17-  # Resolve DB credentials from runtime config, not the job payload (#535 P1-1).
api/functions/async-job-maintenance-handlers.R-18-  db_config <- async_job_worker_db_config()
--
api/functions/async-job-maintenance-handlers.R-37-    compressed = result$compressed
api/functions/async-job-maintenance-handlers.R-38-  )
api/functions/async-job-maintenance-handlers.R-39-}
api/functions/async-job-maintenance-handlers.R-40-
api/functions/async-job-maintenance-handlers.R:41:.async_job_run_backup_restore <- function(job, payload, state, worker_config) {
api/functions/async-job-maintenance-handlers.R-42-  progress <- .async_job_progress_reporter(job$job_id[[1]])
api/functions/async-job-maintenance-handlers.R-43-
api/functions/async-job-maintenance-handlers.R-44-  # Resolve DB credentials from runtime config, not the job payload (#535 P1-1).
api/functions/async-job-maintenance-handlers.R-45-  db_config <- async_job_worker_db_config()
--
api/functions/async-job-maintenance-handlers.R-131-    post_restore_scrub = scrub_outcome
api/functions/async-job-maintenance-handlers.R-132-  )
api/functions/async-job-maintenance-handlers.R-133-}
api/functions/async-job-maintenance-handlers.R-134-
api/functions/async-job-maintenance-handlers.R:135:.async_job_run_publication_refresh <- function(job, payload, state, worker_config) {
api/functions/async-job-maintenance-handlers.R-136-  reporter <- .async_job_progress_reporter(job$job_id[[1]])
api/functions/async-job-maintenance-handlers.R-137-  pmids <- payload$pmids
api/functions/async-job-maintenance-handlers.R-138-  total <- length(pmids)
api/functions/async-job-maintenance-handlers.R-139-  results <- vector("list", total)
--
api/functions/async-job-maintenance-handlers.R-211-# (lock_held) returns successfully; a hard DB failure OR a systemic fetch outage
api/functions/async-job-maintenance-handlers.R-212-# (every targeted PMID failed to fetch -> classed publication_backfill_systemic_failure)
api/functions/async-job-maintenance-handlers.R-213-# propagates and marks the job failed (observable in job history). A partial fetch
api/functions/async-job-maintenance-handlers.R-214-# failure returns success with skipped_count/skipped_pmids/skipped_errors in the summary.
api/functions/async-job-maintenance-handlers.R:215:.async_job_run_publication_date_backfill <- function(job, payload, state, worker_config) {
api/functions/async-job-maintenance-handlers.R-216-  reporter <- .async_job_progress_reporter(job$job_id[[1]])
api/functions/async-job-maintenance-handlers.R-217-
api/functions/async-job-maintenance-handlers.R-218-  # Resolve DB creds from the worker runtime config at run time (#535 S2b).
api/functions/async-job-maintenance-handlers.R-219-  sysndd_db <- async_job_db_connect()
--
api/functions/async-job-network-layout-handlers.R-12-
api/functions/async-job-network-layout-handlers.R-13-  value[[1]]
api/functions/async-job-network-layout-handlers.R-14-}
api/functions/async-job-network-layout-handlers.R-15-
api/functions/async-job-network-layout-handlers.R:16:.async_job_run_network_layout_prewarm <- function(job, payload, state, worker_config) {
api/functions/async-job-network-layout-handlers.R-17-  cluster_type <- as.character(.async_job_network_layout_or(payload$cluster_type, "clusters"))
api/functions/async-job-network-layout-handlers.R-18-  min_confidence <- as.integer(.async_job_network_layout_or(payload$min_confidence, 400L))
api/functions/async-job-network-layout-handlers.R-19-  max_edges <- as.integer(.async_job_network_layout_or(payload$max_edges, 10000L))
api/functions/async-job-network-layout-handlers.R-20-  force <- isTRUE(.async_job_network_layout_or(payload$force, FALSE))
--
api/functions/async-job-provider-handlers.R-80-    )
api/functions/async-job-provider-handlers.R-81-  )
api/functions/async-job-provider-handlers.R-82-}
api/functions/async-job-provider-handlers.R-83-
api/functions/async-job-provider-handlers.R:84:.async_job_run_hgnc_update <- function(job, payload, state, worker_config) {
api/functions/async-job-provider-handlers.R-85-  progress <- .async_job_progress_reporter(job$job_id[[1]])
api/functions/async-job-provider-handlers.R-86-  hgnc_data <- update_process_hgnc_data(progress_fn = progress)
api/functions/async-job-provider-handlers.R-87-  progress("db_write", "Writing to database...", current = 9, total = 9)
api/functions/async-job-provider-handlers.R-88-
--
api/functions/async-job-provider-handlers.R-101-    message = "HGNC data updated and written to database successfully"
api/functions/async-job-provider-handlers.R-102-  )
api/functions/async-job-provider-handlers.R-103-}
api/functions/async-job-provider-handlers.R-104-
api/functions/async-job-provider-handlers.R:105:.async_job_run_pubtator <- function(job, payload, state, worker_config) {
api/functions/async-job-provider-handlers.R-106-  progress <- .async_job_progress_reporter(job$job_id[[1]])
api/functions/async-job-provider-handlers.R-107-  progress("init", "Initializing PubTator fetch...", current = 0, total = payload$max_pages)
api/functions/async-job-provider-handlers.R-108-
api/functions/async-job-provider-handlers.R-109-  result <- pubtator_db_update_async(
--
api/functions/async-job-provider-handlers.R-146-
api/functions/async-job-provider-handlers.R-147-  stop("NDDScore import functions are not loaded", call. = FALSE)
api/functions/async-job-provider-handlers.R-148-}
api/functions/async-job-provider-handlers.R-149-
api/functions/async-job-provider-handlers.R:150:.async_job_run_nddscore_import <- function(job, payload, state, worker_config) {
api/functions/async-job-provider-handlers.R-151-  .async_job_ensure_nddscore_import_loaded()
api/functions/async-job-provider-handlers.R-152-
api/functions/async-job-provider-handlers.R-153-  record_id <- .async_job_payload_scalar(payload, "record_id")
api/functions/async-job-provider-handlers.R-154-  validate_only <- isTRUE(.async_job_payload_scalar(
--
api/functions/async-job-provider-handlers.R-208-    }
api/functions/async-job-provider-handlers.R-209-  )
api/functions/async-job-provider-handlers.R-210-}
api/functions/async-job-provider-handlers.R-211-
api/functions/async-job-provider-handlers.R:212:.async_job_run_pubtator_enrichment <- function(job, payload, state, worker_config) {
api/functions/async-job-provider-handlers.R-213-  pubtator_enrichment_job_run(job, .async_job_progress_reporter)
api/functions/async-job-provider-handlers.R-214-}
api/functions/async-job-provider-handlers.R-215-
api/functions/async-job-provider-handlers.R:216:.async_job_run_pubtatornidd_nightly <- function(job, payload, state, worker_config) {
api/functions/async-job-provider-handlers.R-217-  pubtatornidd_nightly_job_run(job, payload, .async_job_progress_reporter)
api/functions/async-job-provider-handlers.R-218-}
api/functions/async-job-provider-handlers.R-219-
api/functions/async-job-provider-handlers.R:220:.async_job_run_disease_ontology_mapping_refresh <- function(job, payload, state, worker_config) {
api/functions/async-job-provider-handlers.R-221-  progress <- .async_job_progress_reporter(job$job_id[[1]])
api/functions/async-job-provider-handlers.R-222-  disease_ontology_mapping_refresh_run(job, payload, progress)
api/functions/async-job-provider-handlers.R-223-}
api/functions/async-job-provider-handlers.R-224-
--
api/functions/async-job-provider-handlers.R-255-  )
api/functions/async-job-provider-handlers.R-256-  invisible(NULL)
api/functions/async-job-provider-handlers.R-257-}
api/functions/async-job-provider-handlers.R-258-
api/functions/async-job-provider-handlers.R:259:.async_job_run_omim_update <- function(job, payload, state, worker_config) {
api/functions/async-job-provider-handlers.R-260-  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
api/functions/async-job-provider-handlers.R-261-  progress("prepare", "Processing OMIM ontology update...", 0, 5)
api/functions/async-job-provider-handlers.R-262-
api/functions/async-job-provider-handlers.R-263-  disease_ontology_set_update <- process_combine_ontology(
--
api/functions/async-job-provider-handlers.R-349-# functions/async-job-force-apply-payload.R, sourced before this file at every
api/functions/async-job-provider-handlers.R-350-# worker entrypoint. Keeping them out of this file avoids growing it past the
api/functions/async-job-provider-handlers.R-351-# AGENTS.md soft ceiling.
api/functions/async-job-provider-handlers.R-352-
api/functions/async-job-provider-handlers.R:353:.async_job_run_force_apply_ontology <- function(job, payload, state, worker_config) {
api/functions/async-job-provider-handlers.R-354-  disease_ontology_set_update <- readr::read_csv(
api/functions/async-job-provider-handlers.R-355-    payload$csv_path,
api/functions/async-job-provider-handlers.R-356-    na = "NULL",
api/functions/async-job-provider-handlers.R-357-    show_col_types = FALSE
--
api/functions/async-job-handlers.R-90-
api/functions/async-job-handlers.R-91-  categories
api/functions/async-job-handlers.R-92-}
api/functions/async-job-handlers.R-93-
api/functions/async-job-handlers.R:94:.async_job_run_clustering <- function(job, payload, state, worker_config) {
api/functions/async-job-handlers.R-95-  genes <- .async_job_payload_field(payload, "genes")
api/functions/async-job-handlers.R-96-  algorithm <- .async_job_payload_scalar(payload, "algorithm")
api/functions/async-job-handlers.R-97-  string_id_table <- .async_job_payload_field(payload, "string_id_table", required = FALSE)
api/functions/async-job-handlers.R-98-  category_links <- .async_job_payload_field(payload, "category_links", required = FALSE)
--
api/functions/async-job-handlers.R-190-
api/functions/async-job-handlers.R-191-  phenotype_df
api/functions/async-job-handlers.R-192-}
api/functions/async-job-handlers.R-193-
api/functions/async-job-handlers.R:194:.async_job_run_phenotype_clustering <- function(job, payload, state, worker_config) {
api/functions/async-job-handlers.R-195-  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 0)
api/functions/async-job-handlers.R-196-
api/functions/async-job-handlers.R-197-  progress("prepare_matrix", "Preparing phenotype matrix...", current = 0, total = 2)
api/functions/async-job-handlers.R-198-  phenotype_matrix <- .async_job_phenotype_matrix(payload)
--
api/functions/async-job-handlers.R-209-    dplyr::left_join(identifiers, by = "entity_id") |>
api/functions/async-job-handlers.R-210-    tidyr::nest(identifiers = c(entity_id, hgnc_id, symbol))
api/functions/async-job-handlers.R-211-}
api/functions/async-job-handlers.R-212-
api/functions/async-job-handlers.R:213:.async_job_run_ontology_update <- function(job, payload, state, worker_config) {
api/functions/async-job-handlers.R-214-  progress <- .async_job_progress_reporter(job$job_id[[1]])
api/functions/async-job-handlers.R-215-
api/functions/async-job-handlers.R-216-  progress("init", "Preparing ontology update", current = 0, total = 4)
api/functions/async-job-handlers.R-217-  disease_ontology_set <- process_combine_ontology(
--
api/functions/async-job-handlers.R-230-    output_file = paste0("data/disease_ontology_set.", format(Sys.Date(), "%Y-%m-%d"), ".csv")
api/functions/async-job-handlers.R-231-  )
api/functions/async-job-handlers.R-232-}
api/functions/async-job-handlers.R-233-
api/functions/async-job-handlers.R:234:.async_job_run_passthrough <- function(fn_name) {
api/functions/async-job-handlers.R-235-  force(fn_name)
api/functions/async-job-handlers.R-236-
api/functions/async-job-handlers.R-237-  function(job, payload, state, worker_config) {
api/functions/async-job-handlers.R-238-    fn <- base::get(fn_name, mode = "function")
--
api/functions/async-job-handlers.R-242-
api/functions/async-job-handlers.R-243-async_job_handler_registry <- list(
api/functions/async-job-handlers.R-244-  clustering = list(
api/functions/async-job-handlers.R-245-    cancel_mode = "best_effort",
api/functions/async-job-handlers.R:246:    run = .async_job_run_clustering,
api/functions/async-job-handlers.R-247-    after_success = function(result, job, payload, state, worker_config) {
api/functions/async-job-handlers.R-248-      .async_job_chain_llm(result, job, cluster_type = "functional")
api/functions/async-job-handlers.R-249-    }
api/functions/async-job-handlers.R-250-  ),
api/functions/async-job-handlers.R-251-  phenotype_clustering = list(
api/functions/async-job-handlers.R-252-    cancel_mode = "best_effort",
api/functions/async-job-handlers.R:253:    run = .async_job_run_phenotype_clustering,
api/functions/async-job-handlers.R-254-    after_success = function(result, job, payload, state, worker_config) {
api/functions/async-job-handlers.R-255-      .async_job_chain_llm(result, job, cluster_type = "phenotype")
api/functions/async-job-handlers.R-256-    }
api/functions/async-job-handlers.R-257-  ),
api/functions/async-job-handlers.R-258-  ontology_update = list(
api/functions/async-job-handlers.R-259-    cancel_mode = "non_interruptible",
api/functions/async-job-handlers.R:260:    run = .async_job_run_ontology_update,
api/functions/async-job-handlers.R-261-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-262-  ),
api/functions/async-job-handlers.R-263-  hgnc_update = list(
api/functions/async-job-handlers.R-264-    cancel_mode = "non_interruptible",
api/functions/async-job-handlers.R:265:    run = .async_job_run_hgnc_update,
api/functions/async-job-handlers.R-266-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-267-  ),
api/functions/async-job-handlers.R-268-  comparisons_update = list(
api/functions/async-job-handlers.R-269-    cancel_mode = "non_interruptible",
api/functions/async-job-handlers.R:270:    run = .async_job_run_passthrough("comparisons_update_async"),
api/functions/async-job-handlers.R-271-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-272-  ),
api/functions/async-job-handlers.R-273-  pubtator_update = list(
api/functions/async-job-handlers.R-274-    cancel_mode = "best_effort",
api/functions/async-job-handlers.R:275:    run = .async_job_run_pubtator,
api/functions/async-job-handlers.R-276-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-277-  ),
api/functions/async-job-handlers.R-278-  pubtator_enrichment_refresh = list(
api/functions/async-job-handlers.R-279-    cancel_mode = "best_effort",
api/functions/async-job-handlers.R:280:    run = .async_job_run_pubtator_enrichment,
api/functions/async-job-handlers.R-281-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-282-  ),
api/functions/async-job-handlers.R-283-  pubtatornidd_nightly = list(
api/functions/async-job-handlers.R-284-    cancel_mode = "non_interruptible",
api/functions/async-job-handlers.R:285:    run = .async_job_run_pubtatornidd_nightly,
api/functions/async-job-handlers.R-286-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-287-  ),
api/functions/async-job-handlers.R-288-  disease_ontology_mapping_refresh = list(
api/functions/async-job-handlers.R-289-    cancel_mode = "non_interruptible",
api/functions/async-job-handlers.R:290:    run = .async_job_run_disease_ontology_mapping_refresh,
api/functions/async-job-handlers.R-291-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-292-  ),
api/functions/async-job-handlers.R-293-  nddscore_import = list(
api/functions/async-job-handlers.R-294-    cancel_mode = "non_interruptible",
api/functions/async-job-handlers.R:295:    run = .async_job_run_nddscore_import,
api/functions/async-job-handlers.R-296-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-297-  ),
api/functions/async-job-handlers.R-298-  llm_generation = list(
api/functions/async-job-handlers.R-299-    cancel_mode = "best_effort",
api/functions/async-job-handlers.R:300:    run = .async_job_run_passthrough("llm_batch_executor"),
api/functions/async-job-handlers.R-301-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-302-  ),
api/functions/async-job-handlers.R-303-  network_layout_prewarm = list(
api/functions/async-job-handlers.R-304-    cancel_mode = "best_effort",
api/functions/async-job-handlers.R:305:    run = function(...) .async_job_run_network_layout_prewarm(...),
api/functions/async-job-handlers.R-306-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-307-  ),
api/functions/async-job-handlers.R-308-  analysis_snapshot_refresh = list(
api/functions/async-job-handlers.R-309-    cancel_mode = "best_effort",
api/functions/async-job-handlers.R:310:    run = function(...) .async_job_run_analysis_snapshot_refresh(...),
api/functions/async-job-handlers.R-311-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-312-  ),
api/functions/async-job-handlers.R-313-  backup_create = list(
api/functions/async-job-handlers.R-314-    cancel_mode = "non_interruptible",
api/functions/async-job-handlers.R:315:    run = .async_job_run_backup_create,
api/functions/async-job-handlers.R-316-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-317-  ),
api/functions/async-job-handlers.R-318-  backup_restore = list(
api/functions/async-job-handlers.R-319-    cancel_mode = "non_interruptible",
api/functions/async-job-handlers.R:320:    run = .async_job_run_backup_restore,
api/functions/async-job-handlers.R-321-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-322-  ),
api/functions/async-job-handlers.R-323-  omim_update = list(
api/functions/async-job-handlers.R-324-    cancel_mode = "non_interruptible",
api/functions/async-job-handlers.R:325:    run = .async_job_run_omim_update,
api/functions/async-job-handlers.R-326-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-327-  ),
api/functions/async-job-handlers.R-328-  force_apply_ontology = list(
api/functions/async-job-handlers.R-329-    cancel_mode = "non_interruptible",
api/functions/async-job-handlers.R:330:    run = .async_job_run_force_apply_ontology,
api/functions/async-job-handlers.R-331-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-332-  ),
api/functions/async-job-handlers.R-333-  publication_refresh = list(
api/functions/async-job-handlers.R-334-    cancel_mode = "best_effort",
api/functions/async-job-handlers.R:335:    run = .async_job_run_publication_refresh,
api/functions/async-job-handlers.R-336-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-337-  ),
api/functions/async-job-handlers.R-338-  publication_date_backfill = list(
api/functions/async-job-handlers.R-339-    cancel_mode = "non_interruptible",
api/functions/async-job-handlers.R:340:    run = .async_job_run_publication_date_backfill,
api/functions/async-job-handlers.R-341-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-342-  )
api/functions/async-job-handlers.R-343-)
api/functions/async-job-handlers.R-344-
api/start_async_worker.R
api/functions/async-job-handlers.R-8-# Family-specific handler definitions live in sibling files sourced BEFORE
api/functions/async-job-handlers.R-9-# this one at every worker entrypoint, because the registry list below
api/functions/async-job-handlers.R-10-# references handler functions by bare symbol and R evaluates a list()
api/functions/async-job-handlers.R-11-# literal's elements eagerly at construction time:
api/functions/async-job-handlers.R-12-#   - functions/async-job-network-layout-handlers.R (network_layout_prewarm)
api/functions/async-job-handlers.R:13:#   - functions/async-job-analysis-snapshot-handlers.R (analysis_snapshot_refresh)
api/functions/async-job-handlers.R-14-#   - functions/async-job-omim-apply.R (OMIM DB-write / additive-terms helpers)
api/functions/async-job-handlers.R-15-#   - functions/async-job-force-apply-payload.R (force-apply payload-shape helpers)
api/functions/async-job-handlers.R-16-#   - functions/async-job-provider-handlers.R (HGNC, PubTator, NDDScore,
api/functions/async-job-handlers.R-17-#     disease-ontology mapping, OMIM update, force-apply-ontology)
api/functions/async-job-handlers.R-18-#   - functions/async-job-maintenance-handlers.R (backup create/restore,
--
api/functions/async-job-handlers.R-303-  network_layout_prewarm = list(
api/functions/async-job-handlers.R-304-    cancel_mode = "best_effort",
api/functions/async-job-handlers.R-305-    run = function(...) .async_job_run_network_layout_prewarm(...),
api/functions/async-job-handlers.R-306-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-307-  ),
api/functions/async-job-handlers.R:308:  analysis_snapshot_refresh = list(
api/functions/async-job-handlers.R-309-    cancel_mode = "best_effort",
api/functions/async-job-handlers.R:310:    run = function(...) .async_job_run_analysis_snapshot_refresh(...),
api/functions/async-job-handlers.R-311-    after_success = .async_job_after_success_noop
api/functions/async-job-handlers.R-312-  ),
api/functions/async-job-handlers.R-313-  backup_create = list(
api/functions/async-job-handlers.R-314-    cancel_mode = "non_interruptible",
api/functions/async-job-handlers.R-315-    run = .async_job_run_backup_create,

exec
/bin/bash -lc "rg -n -C 8 'mirai::mirai|mirai\\(' api --glob '*.R' && nl -ba api/start_async_worker.R | sed -n '1,260p' && nl -ba api/functions/async-job-worker.R | sed -n '1,360p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 exited 1 in 0ms:
exec
/bin/bash -lc "nl -ba api/start_async_worker.R | sed -n '1,260p'
nl -ba api/functions/async-job-worker.R | sed -n '1,360p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
     1	source("bootstrap/init_libraries.R", local = FALSE)
     2	source("bootstrap/create_pool.R", local = FALSE)
     3	source("bootstrap/load_modules.R", local = FALSE)
     4	
     5	bootstrap_init_libraries()
     6	bootstrap_load_modules()
     7	source("bootstrap/init_cache.R", local = FALSE)
     8	bootstrap_init_cache_version()
     9	bootstrap_bind_memoised(envir = .GlobalEnv)
    10	source("functions/async-job-progress.R", local = FALSE)
    11	source("functions/async-job-omim-apply.R", local = FALSE)
    12	source("functions/async-job-force-apply-payload.R", local = FALSE)
    13	source("functions/async-job-provider-handlers.R", local = FALSE)
    14	source("functions/async-job-maintenance-handlers.R", local = FALSE)
    15	source("functions/async-job-handlers.R", local = FALSE)
    16	source("functions/async-job-worker.R", local = FALSE)
    17	
    18	env_mode <- Sys.getenv("ENVIRONMENT", "local")
    19	
    20	if (tolower(env_mode) == "production") {
    21	  Sys.setenv(API_CONFIG = "sysndd_db")
    22	} else if (tolower(env_mode) == "development") {
    23	  Sys.setenv(API_CONFIG = "sysndd_db_dev")
    24	} else {
    25	  Sys.setenv(API_CONFIG = "sysndd_db_local")
    26	}
    27	
    28	dw <- config::get(Sys.getenv("API_CONFIG"))
    29	
    30	if (!is.null(dw$workdir)) {
    31	  setwd(dw$workdir)
    32	}
    33	
    34	pool <- bootstrap_create_pool(dw)
    35	on.exit(pool::poolClose(pool), add = TRUE)
    36	
    37	worker_config <- async_job_worker_config_from_env()
    38	if (!is.null(worker_config$drain_file) && nzchar(worker_config$drain_file)) {
    39	  unlink(worker_config$drain_file, force = TRUE)
    40	}
    41	
    42	# Remove any mode-0600 MySQL option files a previously-crashed worker left
    43	# behind (#535 P1-1 L1). Best-effort.
    44	if (exists("async_job_backup_cleanup_stale_option_files")) {
    45	  async_job_backup_cleanup_stale_option_files()
    46	}
    47	message(sprintf(
    48	  "[async-worker] starting worker_id=%s queues=%s",
    49	  worker_config$worker_id,
    50	  paste(worker_config$queues, collapse = ",")
    51	))
    52	
    53	async_job_worker_main(worker_config = worker_config)
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
   126	    return(value[[1]])
   127	  }
   128	
   129	  value[[1]]
   130	}
   131	
   132	.async_job_worker_encode_result <- function(result) {
   133	  jsonlite::toJSON(
   134	    result,
   135	    auto_unbox = TRUE,
   136	    null = "null",
   137	    dataframe = "rows",
   138	    POSIXt = "ISO8601"
   139	  )
   140	}
   141	
   142	.async_job_worker_decode_payload <- function(payload_json) {
   143	  if (is.null(payload_json) || !nzchar(payload_json)) {
   144	    return(list())
   145	  }
   146	
   147	  jsonlite::fromJSON(payload_json, simplifyVector = TRUE)
   148	}
   149	
   150	.async_job_worker_fail_safe <- function(
   151	  fail_fn,
   152	  job_id,
   153	  claim_token,
   154	  error_code,
   155	  error_message
   156	) {
   157	  tryCatch(
   158	    {
   159	      fail_fn(
   160	        job_id = job_id,
   161	        error_code = error_code,
   162	        error_message = error_message,
   163	        claim_token = claim_token
   164	      )
   165	    },
   166	    error = function(error) {
   167	      warning(
   168	        sprintf(
   169	          "Failed to persist async job failure for job %s: %s",
   170	          job_id,
   171	          conditionMessage(error)
   172	        ),
   173	        call. = FALSE
   174	      )
   175	      0L
   176	    }
   177	  )
   178	}
   179	
   180	.async_job_worker_append_event_safe <- function(
   181	  append_event_fn,
   182	  job_id,
   183	  event_type,
   184	  event_message = NULL,
   185	  event_payload = NULL
   186	) {
   187	  tryCatch(
   188	    {
   189	      append_event_fn(
   190	        job_id = job_id,
   191	        event_type = event_type,
   192	        event_message = event_message,
   193	        event_payload = event_payload
   194	      )
   195	    },
   196	    error = function(error) {
   197	      warning(
   198	        sprintf(
   199	          "Failed to append async job event '%s' for job %s: %s",
   200	          event_type,
   201	          job_id,
   202	          conditionMessage(error)
   203	        ),
   204	        call. = FALSE
   205	      )
   206	      0L
   207	    }
   208	  )
   209	}
   210	
   211	#' Build durable async worker configuration from environment variables
   212	#'
   213	#' @return Named list of worker runtime settings.
   214	#' @export
   215	async_job_worker_config_from_env <- function() {
   216	  hostname <- Sys.info()[["nodename"]]
   217	  hostname <- if (is.null(hostname) || !nzchar(hostname)) "unknown-host" else hostname
   218	
   219	  queues <- trimws(strsplit(Sys.getenv("ASYNC_JOB_QUEUES", "default"), ",", fixed = TRUE)[[1]])
   220	  queues <- queues[nzchar(queues)]
   221	  if (length(queues) == 0) {
   222	    queues <- "default"
   223	  }
   224	
   225	  list(
   226	    worker_id = sprintf("%s:%s", hostname, .async_job_worker_uuid()),
   227	    hostname = hostname,
   228	    lease_seconds = max(1L, .async_job_worker_int_env("ASYNC_JOB_LEASE_SECONDS", "60")),
   229	    job_run_lease_seconds = max(1L, .async_job_worker_int_env("ASYNC_JOB_RUN_LEASE_SECONDS", "900")),
   230	    idle_sleep_seconds = max(0, .async_job_worker_num_env("ASYNC_JOB_IDLE_SLEEP_SECONDS", "2")),
   231	    max_jobs_per_worker = max(1L, .async_job_worker_int_env("MAX_JOBS_PER_WORKER", "50")),
   232	    max_worker_lifetime_seconds = max(1L, .async_job_worker_int_env("MAX_WORKER_LIFETIME", "3600")),
   233	    queues = queues,
   234	    drain_file = Sys.getenv("ASYNC_JOB_DRAIN_FILE", "/tmp/sysndd_async_worker_drain")
   235	  )
   236	}
   237	
   238	.async_job_worker_lease_seconds <- function(worker_config) {
   239	  run_lease <- suppressWarnings(as.integer(worker_config$job_run_lease_seconds))
   240	  default_lease <- suppressWarnings(as.integer(worker_config$lease_seconds))
   241	
   242	  if (length(default_lease) != 1L || is.na(default_lease) || default_lease < 1L) {
   243	    default_lease <- 60L
   244	  }
   245	
   246	  if (length(run_lease) != 1L || is.na(run_lease) || run_lease < 1L) {
   247	    return(default_lease)
   248	  }
   249	
   250	  max(default_lease, run_lease)
   251	}
   252	
   253	#' Create mutable state for a durable async worker process
   254	#'
   255	#' @param started_at POSIXct worker start time.
   256	#'
   257	#' @return Environment tracking runtime state.
   258	#' @export
   259	async_job_worker_state <- function(started_at = Sys.time()) {
   260	  state <- new.env(parent = emptyenv())
   261	  state$started_at <- started_at
   262	  state$jobs_processed <- 0L
   263	  state$shutdown_requested <- FALSE
   264	  state$draining <- FALSE
   265	  state$current_job_claim <- NULL
   266	  state
   267	}
   268	
   269	#' Request graceful drain for the current worker process
   270	#'
   271	#' @param state Worker state environment.
   272	#' @param shutdown Logical; also set shutdown flag.
   273	#'
   274	#' @return Invisibly returns state.
   275	#' @export
   276	async_job_worker_request_drain <- function(state, shutdown = FALSE) {
   277	  state$draining <- TRUE
   278	  if (isTRUE(shutdown)) {
   279	    state$shutdown_requested <- TRUE
   280	  }
   281	
   282	  invisible(state)
   283	}
   284	
   285	#' Determine whether the worker should stop before claiming more jobs
   286	#'
   287	#' @param state Worker state environment.
   288	#' @param worker_config Named worker configuration list.
   289	#' @param now Current POSIXct timestamp.
   290	#'
   291	#' @return Logical.
   292	#' @export
   293	async_job_worker_should_exit <- function(state, worker_config, now = Sys.time()) {
   294	  lifetime_seconds <- as.numeric(difftime(now, state$started_at, units = "secs"))
   295	  lifetime_exceeded <- lifetime_seconds >= worker_config$max_worker_lifetime_seconds
   296	  jobs_exceeded <- state$jobs_processed >= worker_config$max_jobs_per_worker
   297	  idle_only <- is.null(state$current_job_claim)
   298	
   299	  isTRUE(state$shutdown_requested) ||
   300	    (((isTRUE(state$draining) || lifetime_exceeded || jobs_exceeded) && idle_only))
   301	}
   302	
   303	#' Claim one job for this worker if claims are allowed
   304	#'
   305	#' @param state Worker state environment.
   306	#' @param worker_config Named worker configuration list.
   307	#' @param claim_fn Repository claim function.
   308	#'
   309	#' @return Claimed job tibble or NULL when no claim is made.
   310	#' @export
   311	async_job_worker_claim_once <- function(
   312	  state,
   313	  worker_config,
   314	  claim_fn = async_job_repository_claim_next
   315	) {
   316	  if (isTRUE(state$draining) || isTRUE(state$shutdown_requested)) {
   317	    return(NULL)
   318	  }
   319	
   320	  claimed <- claim_fn(
   321	    worker_id = worker_config$worker_id,
   322	    worker_hostname = worker_config$hostname,
   323	    worker_pid = as.integer(Sys.getpid()),
   324	    lease_seconds = worker_config$lease_seconds,
   325	    queues = worker_config$queues
   326	  )
   327	
   328	  if (is.null(claimed) || nrow(claimed) == 0) {
   329	    return(NULL)
   330	  }
   331	
   332	  claimed
   333	}
   334	
   335	async_job_worker_sync_drain_signal <- function(state, worker_config) {
   336	  drain_file <- worker_config$drain_file
   337	
   338	  if (!is.null(drain_file) && nzchar(drain_file) && file.exists(drain_file)) {
   339	    async_job_worker_request_drain(state, shutdown = TRUE)
   340	  }
   341	
   342	  invisible(state)
   343	}
   344	
   345	#' Heartbeat the currently running claimed job
   346	#'
   347	#' @param claimed_job Claimed job row.
   348	#' @param worker_config Named worker configuration list.
   349	#' @param heartbeat_fn Repository heartbeat function.
   350	#'
   351	#' @return Integer affected rows.
   352	#' @export
   353	async_job_worker_heartbeat <- function(
   354	  claimed_job,
   355	  worker_config,
   356	  heartbeat_fn = async_job_repository_heartbeat
   357	) {
   358	  heartbeat_fn(
   359	    job_id = .async_job_worker_job_field(claimed_job, "job_id"),
   360	    lease_seconds = .async_job_worker_lease_seconds(worker_config),

exec
/bin/bash -lc 'git show --check --stat bb757756
git show --format=fuller --find-renames --find-copies --unified=80 bb757756 -- api/functions/analysis-snapshot-coherence.R api/functions/analysis-snapshot-release-materialize.R api/tests/testthat/test-unit-analysis-snapshot-coherence.R api/tests/testthat/test-integration-analysis-snapshot-release-build.R
git show --check --stat 8765302c
git show --format=fuller --unified=50 8765302c -- api/functions/analysis-snapshot-repository.R api/functions/analysis-snapshot-prune-helpers.R api/bootstrap/load_modules.R api/bootstrap/setup_workers.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
commit bb75775667d4925161d922776ef93b68319a028d
Author: Bernt Popp <bernt.popp@gmail.com>
Date:   Sat Jul 18 22:48:53 2026 +0200

    fix(api): one-to-many STRING->hgnc mapping + reject partial coherence attestation (#573)
    
    Codex round-3 MC1 + MC2.
    
    MC1 (false-rejected a coherent snapshot): .analysis_snapshot_string_to_hgnc_dict
    deduped by STRING_id (first-wins). A STRING protein that joins MULTIPLE hgnc
    records (non_alt_loci_set has no STRING_id uniqueness) puts ALL those hgnc ids in
    the served cluster_members but only the FIRST in the attestation -> false
    release_source_incoherent. The dict now maps STRING_id -> the SET of all its
    hgnc_ids, and analysis_snapshot_reference_members_store_space expands each
    reference STRING_id to the UNION so the mapped reference equals the served set
    (unmapped ids still kept verbatim = fail-closed).
    
    MC2 (partial attestation masked incoherence): the same-partition proof only
    iterates the intersection of membership/validation cluster ids, so a
    present-but-PARTIAL attestation (omitting a served cluster that would mismatch)
    passed the hard check. The release re-check now requires a PRESENT attestation's
    cluster-id key set to EQUAL the served membership cluster set; a partial/malformed
    attestation -> release_source_incoherent (NOT the legacy-absent degrade path,
    which is reserved for a fully-absent NULL/empty attestation).
    
    Tests: one-to-many STRING->hgnc expansion; a partial attestation -> release refuses.
    
    Claude-Session: https://claude.ai/code/session_01Shab9CYtSFmHhb7yzqBGNn

commit bb75775667d4925161d922776ef93b68319a028d
Author:     Bernt Popp <bernt.popp@gmail.com>
AuthorDate: Sat Jul 18 22:48:53 2026 +0200
Commit:     Bernt Popp <bernt.popp@gmail.com>
CommitDate: Sat Jul 18 22:48:53 2026 +0200

    fix(api): one-to-many STRING->hgnc mapping + reject partial coherence attestation (#573)
    
    Codex round-3 MC1 + MC2.
    
    MC1 (false-rejected a coherent snapshot): .analysis_snapshot_string_to_hgnc_dict
    deduped by STRING_id (first-wins). A STRING protein that joins MULTIPLE hgnc
    records (non_alt_loci_set has no STRING_id uniqueness) puts ALL those hgnc ids in
    the served cluster_members but only the FIRST in the attestation -> false
    release_source_incoherent. The dict now maps STRING_id -> the SET of all its
    hgnc_ids, and analysis_snapshot_reference_members_store_space expands each
    reference STRING_id to the UNION so the mapped reference equals the served set
    (unmapped ids still kept verbatim = fail-closed).
    
    MC2 (partial attestation masked incoherence): the same-partition proof only
    iterates the intersection of membership/validation cluster ids, so a
    present-but-PARTIAL attestation (omitting a served cluster that would mismatch)
    passed the hard check. The release re-check now requires a PRESENT attestation's
    cluster-id key set to EQUAL the served membership cluster set; a partial/malformed
    attestation -> release_source_incoherent (NOT the legacy-absent degrade path,
    which is reserved for a fully-absent NULL/empty attestation).
    
    Tests: one-to-many STRING->hgnc expansion; a partial attestation -> release refuses.
    
    Claude-Session: https://claude.ai/code/session_01Shab9CYtSFmHhb7yzqBGNn

diff --git a/api/functions/analysis-snapshot-coherence.R b/api/functions/analysis-snapshot-coherence.R
index 97441e3b..c977618f 100644
--- a/api/functions/analysis-snapshot-coherence.R
+++ b/api/functions/analysis-snapshot-coherence.R
@@ -59,217 +59,230 @@ analysis_snapshot_assert_partition_coherent <- function(membership, per_cluster,
   membership_ids <- if (is.null(membership) || !("cluster" %in% names(membership))) {
     character(0)
   } else {
     as.character(membership$cluster)
   }
   validation_ids <- if (is.null(per_cluster) || !("cluster_id" %in% names(per_cluster))) {
     character(0)
   } else {
     as.character(per_cluster$cluster_id)
   }
 
   missing_scores <- setdiff(membership_ids, validation_ids) # served clusters with no stability row
   orphan_scores <- setdiff(validation_ids, membership_ids) # validation clusters not served
   channel_mismatch <- !is.null(membership_channel) && !is.null(validation_channel) &&
     !identical(as.character(membership_channel), as.character(validation_channel))
 
   problems <- character(0)
   if (length(missing_scores)) {
     problems <- c(problems, sprintf(
       "%d visible %s cluster(s) have no validation/stability score (ids: %s)",
       length(missing_scores), kind, paste(missing_scores, collapse = ", ")
     ))
   }
   if (length(orphan_scores)) {
     problems <- c(problems, sprintf(
       "%d validation %s cluster(s) are not in the served membership (ids: %s)",
       length(orphan_scores), kind, paste(orphan_scores, collapse = ", ")
     ))
   }
   if (channel_mismatch) {
     problems <- c(problems, sprintf(
       "%s membership channel (%s) disagrees with the validation channel (%s)",
       kind, membership_channel, validation_channel
     ))
   }
 
   # Same-partition proof (not just same labels): for every shared cluster_id the
   # served membership and the validated reference partition must contain the SAME
   # member set. Catches a stale membership whose cluster-id labels coincide with the
   # fresh validation but whose contents differ.
   if (!is.null(membership_members) && !is.null(validation_members)) {
     shared <- intersect(names(membership_members), names(validation_members))
     content_mismatch <- character(0)
     for (cid in shared) {
       a <- unique(as.character(membership_members[[cid]]))
       b <- unique(as.character(validation_members[[cid]]))
       if (!setequal(a, b)) content_mismatch <- c(content_mismatch, cid)
     }
     if (length(content_mismatch)) {
       problems <- c(problems, sprintf(
         "%d %s cluster(s) have membership content that differs from the validated partition (ids: %s)",
         length(content_mismatch), kind, paste(content_mismatch, collapse = ", ")
       ))
     }
   }
 
   coherent <- length(problems) == 0L
   if (!coherent) {
     msg <- sprintf(
       paste0(
         "Incoherent %s partition snapshot: membership and validation describe ",
         "different partitions: %s. Refusing to publish (#514)."
       ),
       kind, paste(problems, collapse = "; ")
     )
     if (require_coherence) {
       stop(msg, call. = FALSE)
     } else {
       warning(msg, call. = FALSE)
     }
   }
 
   invisible(list(
     coherent = coherent,
     problems = problems,
     missing_scores = missing_scores,
     orphan_scores = orphan_scores
   ))
 }
 
-#' Partition-independent STRING_id -> hgnc_id dictionary from served identifiers.
+#' Partition-independent STRING_id -> {hgnc_id...} dictionary from served identifiers.
 #'
 #' Each served membership identifier row carries the fixed (STRING_id, hgnc_id)
 #' gene pairing (from the STRING id table join); this pairing is a property of the
 #' gene set, NOT of the partition, so it is reliable even for a stale membership.
+#' One STRING protein can join MULTIPLE hgnc records (`non_alt_loci_set` has no
+#' STRING_id uniqueness), and the served cluster_members then contain ALL of those
+#' hgnc ids — so this returns a named LIST mapping each STRING_id to the SET of all
+#' its hgnc_ids (MC1: a first-wins scalar dict would drop the others and
+#' false-reject a coherent snapshot).
+#' @return named list: STRING_id -> character vector of hgnc_ids.
 #' @noRd
 .analysis_snapshot_string_to_hgnc_dict <- function(membership) {
-  empty <- stats::setNames(character(0), character(0))
   if (is.null(membership) || !("identifiers" %in% names(membership))) {
-    return(empty)
+    return(list())
   }
   pairs <- lapply(membership$identifiers, function(df) {
     if (is.data.frame(df) && all(c("STRING_id", "hgnc_id") %in% names(df))) {
       data.frame(
         STRING_id = as.character(df$STRING_id),
         hgnc_id = as.character(df$hgnc_id),
         stringsAsFactors = FALSE
       )
     } else {
       NULL
     }
   })
   pairs <- pairs[!vapply(pairs, is.null, logical(1))]
   if (length(pairs) == 0L) {
-    return(empty)
+    return(list())
   }
   pairs <- do.call(rbind, pairs)
   pairs <- pairs[!is.na(pairs$STRING_id) & !is.na(pairs$hgnc_id), , drop = FALSE]
-  pairs <- pairs[!duplicated(pairs$STRING_id), , drop = FALSE]
-  stats::setNames(pairs$hgnc_id, pairs$STRING_id)
+  if (nrow(pairs) == 0L) {
+    return(list())
+  }
+  lapply(split(pairs$hgnc_id, pairs$STRING_id), function(h) unique(as.character(h)))
 }
 
 #' Express the validator's reference member sets in the STORED cluster_member id
 #' space so a RELEASE can independently verify member-set coherence (#573 H4).
 #'
 #' The stored `analysis_snapshot_cluster_member` table keeps `hgnc_id` (functional)
 #' or `entity_id` (phenotype). The validator's `reference_members` are STRING
 #' protein ids (functional) / entity ids (phenotype). This maps them into the
 #' stored space: phenotype is already entity_id; functional STRING_ids are mapped
 #' to hgnc_id via the partition-independent gene dictionary, and any UNMAPPED
 #' STRING_id is kept verbatim (fail-closed — it cannot equal a stored hgnc_id, so
 #' an incoherent membership is never silently masked).
 #'
 #' @return A named list keyed by cluster_id (string) -> member-id character vector.
 #' @noRd
 analysis_snapshot_reference_members_store_space <- function(reference_members, membership, kind) {
   reference_members <- reference_members %||% list()
   if (length(reference_members) == 0L) {
     return(list())
   }
   if (identical(kind, "phenotype")) {
     return(lapply(reference_members, function(ids) unique(as.character(ids))))
   }
   dict <- .analysis_snapshot_string_to_hgnc_dict(membership)
   lapply(reference_members, function(sids) {
     sids <- as.character(sids)
-    mapped <- unname(dict[sids])
-    unique(as.character(ifelse(is.na(mapped), sids, mapped)))
+    # Expand each STRING_id to the SET (union) of all its hgnc_ids so the mapped
+    # reference set equals the served cluster_members set; an UNMAPPED STRING_id is
+    # kept verbatim (fail-closed — it cannot equal a stored hgnc_id).
+    mapped <- unlist(lapply(sids, function(s) {
+      hg <- dict[[s]]
+      if (is.null(hg) || length(hg) == 0L) s else hg
+    }), use.names = FALSE)
+    unique(as.character(mapped))
   })
 }
 
 #' Attach the additive partition provenance the join computed onto `partition`.
 #'
 #' Copies the served membership channel (#514, functional only — NA on the
 #' phenotype axis is not stored) and the H4 reference member-set attestation
 #' (#573, both axes) from the joined-tibble attributes onto `val$partition`, which
 #' the builder persists into `validation_json`. `partition_validation` is excluded
 #' from `payload_hash`, so this never churns `cluster_hash`.
 #' @export
 analysis_snapshot_attach_partition_provenance <- function(partition, joined) {
   channel <- attr(joined, "membership_weight_channel")
   if (!is.null(channel) && !all(is.na(channel))) {
     partition$membership_weight_channel <- channel
   }
   partition$reference_members <- attr(joined, "reference_members_store_space")
   partition
 }
 
 #' Gate then join the validator's per-cluster scores onto the served membership.
 #'
 #' Single choke-point for the builder's two clustering presets: it asserts partition
 #' coherence FIRST (so an incoherent snapshot can never be published), then performs the
 #' `cluster` <-> `cluster_id` left-join, and carries the served membership channel as a
 #' `membership_weight_channel` attribute for additive provenance.
 #'
 #' @param membership tibble from the memoised clustering function (integer `cluster`,
 #'   optional `weight_channel` attribute).
 #' @param val the validator return list (`per_cluster` tibble + `partition` list).
 #' @param kind "functional" or "phenotype".
 #' @return the joined clusters tibble (validation columns merged; `cluster_id` dropped).
 #' @export
 analysis_snapshot_join_validated_clusters <- function(membership, val, kind) {
   membership_channel <- attr(membership, "weight_channel")
   validation_channel <- val$partition$weight_channel
 
   # Member id space differs per axis: functional clusters over STRING node ids, phenotype
   # clusters over entity ids. Extract the served per-cluster member set (keyed by the same
   # integer cluster label as val$reference_members) for the same-partition proof.
   member_col <- if (identical(kind, "functional")) "STRING_id" else "entity_id"
   membership_members <- NULL
   if (all(c("identifiers", "cluster") %in% names(membership))) {
     membership_members <- stats::setNames(
       lapply(membership$identifiers, function(df) {
         if (is.data.frame(df) && member_col %in% names(df)) {
           as.character(df[[member_col]])
         } else {
           character(0)
         }
       }),
       as.character(membership$cluster)
     )
   }
 
   analysis_snapshot_assert_partition_coherent(
     membership, val$per_cluster, kind,
     membership_channel = membership_channel,
     validation_channel = validation_channel,
     membership_members = membership_members,
     validation_members = val$reference_members
   )
 
   joined <- dplyr::left_join(
     dplyr::mutate(membership, cluster_id = as.character(cluster)),
     val$per_cluster,
     by = "cluster_id"
   )
   joined <- dplyr::select(joined, -cluster_id)
   attr(joined, "membership_weight_channel") <- membership_channel %||% NA_character_
   # #573 H4: carry the validator's reference member sets, expressed in the STORED
   # cluster_member id space, so the builder can persist them into validation_json
   # and a RELEASE can later re-prove member-set coherence independently. Attached
   # as an attribute (not mutated onto `val`, which is a by-value copy here).
   attr(joined, "reference_members_store_space") <- analysis_snapshot_reference_members_store_space(
     val$reference_members, membership, kind
   )
   joined
 }
diff --git a/api/functions/analysis-snapshot-release-materialize.R b/api/functions/analysis-snapshot-release-materialize.R
index 2efecb47..94c1dbbf 100644
--- a/api/functions/analysis-snapshot-release-materialize.R
+++ b/api/functions/analysis-snapshot-release-materialize.R
@@ -149,163 +149,180 @@ if (!exists("%||%", mode = "function")) {
   if (length(raw) == 0L || is.na(raw[[1]]) || !nzchar(raw[[1]])) {
     return(list())
   }
   parsed <- tryCatch(jsonlite::fromJSON(raw[[1]], simplifyVector = TRUE), error = function(e) NULL)
   if (is.null(parsed) || !is.list(parsed)) {
     return(list())
   }
   parsed
 }
 
 #' @noRd
 .analysis_release_cluster_has_stability <- function(metadata_json) {
   txt <- suppressWarnings(as.character(metadata_json))
   if (length(txt) == 0L || is.na(txt[[1]]) || !nzchar(txt[[1]])) {
     return(FALSE)
   }
   parsed <- tryCatch(jsonlite::fromJSON(txt[[1]], simplifyVector = TRUE), error = function(e) NULL)
   if (is.null(parsed)) {
     return(FALSE)
   }
   score <- parsed$jaccard_mean %||% parsed$stability %||% parsed$stability_score
   !is.null(score) && length(score) >= 1L && !is.na(suppressWarnings(as.numeric(score[[1]])))
 }
 
 #' Hard coherence re-check over a loaded cluster snapshot. Default `coherence_assert`.
 #' @export
 analysis_snapshot_release_assert_coherent <- function(snapshot, kind) {
   clusters <- .analysis_release_rows(snapshot$clusters)
   members <- .analysis_release_rows(snapshot$cluster_members)
   if ("cluster_kind" %in% names(clusters)) {
     clusters <- clusters[as.character(clusters$cluster_kind) == kind, , drop = FALSE]
   }
   if ("cluster_kind" %in% names(members)) {
     members <- members[as.character(members$cluster_kind) == kind, , drop = FALSE]
   }
 
   membership_ids <- if ("cluster_id" %in% names(members)) unique(as.character(members$cluster_id)) else character(0)
   membership <- tibble::tibble(cluster = membership_ids)
 
   valid_ids <- character(0)
   if (nrow(clusters) > 0L && "cluster_id" %in% names(clusters)) {
     metadata <- if ("metadata_json" %in% names(clusters)) clusters$metadata_json else rep(NA_character_, nrow(clusters))
     has_stability <- vapply(
       seq_len(nrow(clusters)),
       function(i) .analysis_release_cluster_has_stability(metadata[[i]]),
       logical(1)
     )
     valid_ids <- as.character(clusters$cluster_id[has_stability])
   }
   per_cluster <- tibble::tibble(cluster_id = valid_ids)
 
   validation <- .analysis_release_parse_validation_json(snapshot$manifest)
 
   # Channel match (functional axis only): both channels live in validation_json;
   # when both are present they must agree. Absent/older snapshots skip this
   # comparison (assert_partition_coherent only fires channel_mismatch when BOTH
   # membership_channel and validation_channel are non-NULL).
   membership_channel <- NULL
   validation_channel <- NULL
   if (identical(kind, "functional")) {
     membership_channel <- validation$membership_weight_channel
     validation_channel <- validation$weight_channel
   }
 
   # H4: MEMBER-SET proof. Reconstruct the served membership member sets from the
   # stored cluster_members (grouped by cluster_id, in the stored id space:
   # hgnc_id for functional / entity_id for phenotype) and compare them against the
   # persisted validator reference sets (validation_json$reference_members, same
   # stored space). When the attestation is ABSENT (legacy pre-#573 snapshot),
   # GRACEFULLY DEGRADE to the channel + stability check and WARN — never hard
   # reject a legacy snapshot (that would block every release until a full rebuild).
   member_col <- if (identical(kind, "functional")) "hgnc_id" else "entity_id"
   membership_members <- NULL
   if (all(c("cluster_id", member_col) %in% names(members)) && nrow(members) > 0L) {
     grouped <- split(as.character(members[[member_col]]), as.character(members$cluster_id))
     membership_members <- lapply(grouped, function(v) unique(v[!is.na(v) & nzchar(v)]))
   }
   validation_members <- validation$reference_members
   if (!is.null(validation_members) && length(validation_members) > 0L) {
     validation_members <- lapply(validation_members, function(v) unique(as.character(v)))
+    # MC2: a PRESENT attestation must be COMPLETE — its cluster-id key set must
+    # equal the served membership cluster set. A partial/malformed attestation
+    # (missing a served cluster that would otherwise mismatch) must NOT slip
+    # through the intersection-only same-partition proof: it is INCOHERENT, not
+    # legacy-absent. (The served set == the validated per_cluster set is enforced
+    # separately by the missing/orphan checks in assert_partition_coherent.)
+    served_cluster_ids <- if (!is.null(membership_members)) names(membership_members) else membership_ids
+    if (!setequal(names(validation_members), served_cluster_ids)) {
+      stop(.analysis_release_condition(
+        "release_source_incoherent",
+        sprintf(
+          "%s snapshot reference attestation is partial/malformed: cluster set does not cover the served membership",
+          kind
+        ),
+        kind = kind
+      ))
+    }
   } else {
     validation_members <- NULL
-    membership_members <- NULL # no reference to prove against
+    membership_members <- NULL # fully-absent (legacy) -> no reference to prove against
     warning(sprintf(
       paste0(
         "release coherence: %s snapshot carries no persisted reference member sets ",
         "(legacy snapshot); full member-set verification is unavailable, degraded to ",
         "channel + stability check. Rebuild the snapshot (worker-executed) to attest coherence."
       ),
       kind
     ), call. = FALSE)
   }
 
   tryCatch(
     analysis_snapshot_assert_partition_coherent(
       membership, per_cluster, kind,
       membership_channel = membership_channel,
       validation_channel = validation_channel,
       membership_members = membership_members,
       validation_members = validation_members,
       require_coherence = TRUE
     ),
     error = function(e) {
       stop(.analysis_release_condition(
         "release_source_incoherent",
         sprintf("%s snapshot failed hard coherence re-check: %s", kind, conditionMessage(e)),
         kind = kind
       ))
     }
   )
   invisible(TRUE)
 }
 
 # --------------------------------------------------------------------------- #
 # Cross-layer lineage gates (step 2). Re-asserted immediately before insert.
 # --------------------------------------------------------------------------- #
 
 #' @noRd
 .analysis_release_dep_matches <- function(dependencies, key, entry) {
   if (!is.list(dependencies)) {
     return(FALSE)
   }
   dep <- dependencies[[key]]
   if (!is.list(dep)) {
     return(FALSE)
   }
   dep_id <- suppressWarnings(as.integer(dep$snapshot_id %||% NA))
   dep_hash <- as.character(dep$payload_hash %||% "")
   entry_id <- suppressWarnings(as.integer(entry$snapshot_id))
   entry_hash <- as.character(entry$payload_hash %||% "")
   !is.na(dep_id) && !is.na(entry_id) && identical(dep_id, entry_id) &&
     nzchar(dep_hash) && nzchar(entry_hash) && identical(dep_hash, entry_hash)
 }
 
 #' Assert one shared source_data_version + correlation dependency lineage.
 #' @noRd
 .analysis_release_assert_lineage <- function(loaded) {
   versions <- vapply(
     loaded,
     function(e) as.character(e$source_data_version %||% NA_character_),
     character(1)
   )
   uniq <- unique(versions)
   if (length(uniq) != 1L || is.na(uniq[[1]]) || !nzchar(uniq[[1]])) {
     stop(.analysis_release_condition(
       "release_source_version_mismatch",
       sprintf(
         "release layers do not share one source_data_version (found: %s)",
         paste(ifelse(is.na(versions), "<NA>", versions), collapse = ", ")
       )
     ))
   }
 
   corr <- loaded[["phenotype_functional_correlations"]]
   func <- loaded[["functional_clusters"]]
   phen <- loaded[["phenotype_clusters"]]
   if (!is.null(corr) && !is.null(func) && !is.null(phen)) {
     dependencies <- analysis_snapshot_manifest_dependencies(corr$manifest)
     ok <- .analysis_release_dep_matches(dependencies, "functional_clusters", func) &&
       .analysis_release_dep_matches(dependencies, "phenotype_clusters", phen)
     if (!ok) {
       stop(.analysis_release_condition(
         "release_dependency_lineage_mismatch",
diff --git a/api/tests/testthat/test-integration-analysis-snapshot-release-build.R b/api/tests/testthat/test-integration-analysis-snapshot-release-build.R
index 9b45715b..fc45ef45 100644
--- a/api/tests/testthat/test-integration-analysis-snapshot-release-build.R
+++ b/api/tests/testthat/test-integration-analysis-snapshot-release-build.R
@@ -344,160 +344,174 @@ test_that("build rejects a reproducibility bundle whose bytes do not hash to rep
   )
 })
 
 test_that("build refuses to proceed unlocked when the advisory lock cannot be acquired (H3a)", {
   # Inject a lock seam that reports acquisition FAILED (a source preset is mid-refresh).
   failing_lock <- function(conn, lock_names) list(ok = FALSE, acquired = character(0), skipped = FALSE)
   expect_error(
     analysis_snapshot_release_build(
       conn = NULL, publish = TRUE,
       loader = make_loader(), reproducibility_loader = present_repro_loader,
       coherence_assert = pass_coherence, lock_acquire = failing_lock
     ),
     class = "release_lock_unavailable"
   )
 })
 
 test_that("build refuses a functional snapshot whose served channel != validation channel", {
   # Real coherence default reads validation_json; membership (combined_score) was
   # clustered on a different STRING channel than the validation scored (exp+db).
   loader <- make_loader(list(
     functional_clusters = make_functional_snap_with_channels(
       membership_channel = "combined_score", validation_channel = "experimental_database"
     )
   ))
   expect_error(
     analysis_snapshot_release_build(
       conn = NULL, publish = TRUE,
       loader = loader, reproducibility_loader = present_repro_loader,
       coherence_assert = analysis_snapshot_release_assert_coherent # the REAL default
     ),
     class = "release_source_incoherent"
   )
 })
 
 # --------------------------------------------------------------------------- #
 # Real default coherence seam: pass when internally consistent, throw
 # release_source_incoherent when a visible cluster lacks a stability score.
 # --------------------------------------------------------------------------- #
 
 test_that("analysis_snapshot_release_assert_coherent gates stored-snapshot integrity", {
   ok <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
   expect_invisible(analysis_snapshot_release_assert_coherent(ok, "functional"))
 
   incoherent <- make_cluster_snap(
     "functional_clusters", "functional", FUNC_ID, FUNC_HASH,
     stability_ok = FALSE
   )
   expect_error(
     analysis_snapshot_release_assert_coherent(incoherent, "functional"),
     class = "release_source_incoherent"
   )
 })
 
 test_that("analysis_snapshot_release_assert_coherent runs the H4 member-set proof when attested", {
   # served functional cluster_members: cluster 1 = {HGNC:1,2,3}, cluster 2 = {HGNC:4,5}.
   coherent_ref <- list("1" = c("HGNC:1", "HGNC:2", "HGNC:3"), "2" = c("HGNC:4", "HGNC:5"))
   incoherent_ref <- list("1" = c("HGNC:1", "HGNC:2", "HGNC:99"), "2" = c("HGNC:4", "HGNC:5"))
 
   # (b) coherent attestation -> passes, no member-set warning.
   expect_invisible(
     analysis_snapshot_release_assert_coherent(make_functional_snap_with_reference(coherent_ref), "functional")
   )
 
   # (a) attested snapshot whose served members differ in CONTENT (same cluster-ids)
   #     -> refuse, EVEN with the build-time coherence env downgraded to false.
   withr::with_envvar(list(ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE = "false"), {
     expect_error(
       analysis_snapshot_release_assert_coherent(make_functional_snap_with_reference(incoherent_ref), "functional"),
       class = "release_source_incoherent"
     )
   })
 
   # (c) legacy snapshot WITHOUT the attestation -> degrades + warns (never refuses).
   legacy <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
   expect_warning(
     expect_invisible(analysis_snapshot_release_assert_coherent(legacy, "functional")),
     "member-set verification is unavailable"
   )
 })
 
+test_that("a PARTIAL/incomplete reference attestation is treated as incoherent, not degraded (MC2)", {
+  # served cluster_members have clusters 1 AND 2; the attestation omits cluster 2.
+  # It must NOT slip through the intersection-only proof as "legacy-absent" — a
+  # present-but-partial attestation is INCOHERENT (release_source_incoherent).
+  partial_ref <- list("1" = c("HGNC:1", "HGNC:2", "HGNC:3")) # missing served cluster "2"
+  snap <- make_functional_snap_with_reference(partial_ref)
+  # If it were mis-treated as legacy-absent it would degrade + PASS; expect_error
+  # proves it hard-fails instead.
+  expect_error(
+    analysis_snapshot_release_assert_coherent(snap, "functional"),
+    class = "release_source_incoherent"
+  )
+})
+
 test_that("build refuses an attested snapshot whose member set differs from the reference (H4)", {
   loader <- make_loader(list(
     functional_clusters = make_functional_snap_with_reference(
       list("1" = c("HGNC:1", "HGNC:2", "HGNC:99"), "2" = c("HGNC:4", "HGNC:5"))
     )
   ))
   withr::with_envvar(list(ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE = "false"), {
     expect_error(
       analysis_snapshot_release_build(
         conn = NULL, publish = TRUE,
         loader = loader, reproducibility_loader = present_repro_loader,
         coherence_assert = analysis_snapshot_release_assert_coherent # REAL default
       ),
       class = "release_source_incoherent"
     )
   })
 })
 
 test_that("build rejects layers with conflicting db_release provenance (M2)", {
   phen <- make_cluster_snap("phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH)
   phen$manifest$db_release_version <- "9.9.9" # conflicts with functional's 1.0.0
   loader <- make_loader(list(phenotype_clusters = phen))
   expect_error(
     analysis_snapshot_release_build(
       conn = NULL, publish = TRUE,
       loader = loader, reproducibility_loader = present_repro_loader,
       coherence_assert = pass_coherence
     ),
     class = "release_source_version_mismatch"
   )
 })
 
 test_that("analysis_snapshot_release_assert_coherent enforces the functional channel match", {
   # Both channels present + equal -> passes; present + differ -> throws; absent -> skip.
   matched <- make_functional_snap_with_channels("experimental_database", "experimental_database")
   expect_invisible(analysis_snapshot_release_assert_coherent(matched, "functional"))
 
   mismatched <- make_functional_snap_with_channels("combined_score", "experimental_database")
   expect_error(
     analysis_snapshot_release_assert_coherent(mismatched, "functional"),
     class = "release_source_incoherent"
   )
 
   # No validation_json -> channel comparison skipped (older snapshots still pass).
   no_channels <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
   expect_invisible(analysis_snapshot_release_assert_coherent(no_channels, "functional"))
 })
 
 # --------------------------------------------------------------------------- #
 # Success + idempotency (real release persistence).
 # --------------------------------------------------------------------------- #
 
 with_release_build_db <- function(code) {
   skip_if_no_test_db()
 
   schema_conn <- get_test_db_connection()
   ensure_test_release_schema(schema_conn)
   DBI::dbDisconnect(schema_conn)
 
   conn <- get_test_db_connection()
   withr::defer(DBI::dbDisconnect(conn))
   DBI::dbExecute(conn, "DELETE FROM analysis_snapshot_release")
   withr::defer(DBI::dbExecute(conn, "DELETE FROM analysis_snapshot_release"))
 
   code(conn)
 }
 
 test_that("build materializes a content-addressed release; repro hash + payload lineage anchor hold", {
   with_release_build_db(function(conn) {
     result <- analysis_snapshot_release_build(
       conn = conn, publish = TRUE, title = "SysNDD analysis snapshot release",
       scope_statement = "Curated derived cluster analysis.",
       loader = make_loader(), reproducibility_loader = present_repro_loader,
       coherence_assert = pass_coherence
     )
     expect_true(result$created)
     release_id <- result$release$release_id
     expect_match(release_id, "^asr_[0-9a-f]{16}$")
     expect_equal(result$release$status, "published")
 
diff --git a/api/tests/testthat/test-unit-analysis-snapshot-coherence.R b/api/tests/testthat/test-unit-analysis-snapshot-coherence.R
index ebf60579..0751ba6d 100644
--- a/api/tests/testthat/test-unit-analysis-snapshot-coherence.R
+++ b/api/tests/testthat/test-unit-analysis-snapshot-coherence.R
@@ -122,80 +122,95 @@ mk_val_with_members <- function(members, channel = "experimental_database") {
     reference_members = lapply(members, as.character),
     partition = list(weight_channel = channel)
   )
 }
 
 test_that("same cluster-id labels but DIFFERENT member content is refused (same-partition proof)", {
   # ids match, channels match, but cluster 1 holds different members on each side.
   mm <- list("1" = c("A", "B", "C"), "2" = c("D", "E"))
   vm <- list("1" = c("A", "B", "X"), "2" = c("D", "E")) # cluster 1 content differs
   expect_error(
     analysis_snapshot_assert_partition_coherent(
       mk_membership(c(1, 2)), mk_val(c(1, 2))$per_cluster, kind = "functional",
       membership_members = mm, validation_members = vm
     ),
     "content", ignore.case = TRUE
   )
 })
 
 test_that("identical member content passes the same-partition proof", {
   same <- list("1" = c("A", "B", "C"), "2" = c("D", "E"))
   res <- analysis_snapshot_assert_partition_coherent(
     mk_membership(c(1, 2)), mk_val(c(1, 2))$per_cluster, kind = "functional",
     membership_members = same, validation_members = same
   )
   expect_true(res$coherent)
 })
 
 test_that("join helper enforces member content coherence end to end (functional STRING_id)", {
   members <- list("1" = c("9606.A", "9606.B"), "2" = c("9606.C", "9606.D"))
   m <- mk_membership_with_members(members, id_col = "STRING_id")
   v <- mk_val_with_members(members)
   joined <- analysis_snapshot_join_validated_clusters(m, v, kind = "functional")
   expect_equal(nrow(joined), 2L)
 
   # now corrupt one cluster's membership content -> must be refused
   bad <- members
   bad[["1"]] <- c("9606.A", "9606.Z")
   mbad <- mk_membership_with_members(bad, id_col = "STRING_id")
   expect_error(analysis_snapshot_join_validated_clusters(mbad, v, kind = "functional"),
                "content", ignore.case = TRUE)
 })
 
 # --- #573 H4: reference member sets expressed in the STORED id space ---
 
 test_that("reference_members_store_space maps functional STRING_id -> hgnc_id via served identifiers", {
   membership <- tibble::tibble(
     cluster = c(1L, 2L),
     identifiers = list(
       tibble::tibble(STRING_id = c("9606.A", "9606.B"), hgnc_id = c("HGNC:1", "HGNC:2")),
       tibble::tibble(STRING_id = c("9606.C"), hgnc_id = c("HGNC:3"))
     )
   )
   ref <- list("1" = c("9606.A", "9606.B"), "2" = c("9606.C"))
   out <- analysis_snapshot_reference_members_store_space(ref, membership, "functional")
   expect_setequal(out[["1"]], c("HGNC:1", "HGNC:2"))
   expect_setequal(out[["2"]], "HGNC:3")
 
   # an UNMAPPED STRING_id is kept verbatim (fail-closed: cannot equal a stored hgnc_id)
   ref2 <- list("1" = c("9606.A", "9606.UNKNOWN"))
   out2 <- analysis_snapshot_reference_members_store_space(ref2, membership, "functional")
   expect_setequal(out2[["1"]], c("HGNC:1", "9606.UNKNOWN"))
 })
 
 test_that("reference_members_store_space passes phenotype entity ids through unchanged", {
   ref <- list("1" = c("10", "11"), "2" = c("12"))
   out <- analysis_snapshot_reference_members_store_space(ref, NULL, "phenotype")
   expect_setequal(out[["1"]], c("10", "11"))
   expect_setequal(out[["2"]], "12")
   expect_equal(length(analysis_snapshot_reference_members_store_space(list(), NULL, "phenotype")), 0L)
 })
 
 test_that("join attaches the store-space reference attestation for the builder to persist", {
   members <- list("1" = c("9606.A", "9606.B"), "2" = c("9606.C", "9606.D"))
   m <- mk_membership_with_members(members, id_col = "STRING_id")
   v <- mk_val_with_members(members)
   joined <- analysis_snapshot_join_validated_clusters(m, v, kind = "functional")
   attest <- attr(joined, "reference_members_store_space")
   expect_false(is.null(attest))
   expect_setequal(names(attest), c("1", "2"))
 })
+
+test_that("reference_members_store_space expands a one-to-many STRING_id to ALL its hgnc_ids (MC1)", {
+  # A STRING protein that joins two hgnc records: the served cluster_members hold
+  # BOTH, so the mapped reference must hold BOTH (a first-wins dict false-rejects).
+  membership <- tibble::tibble(
+    cluster = 1L,
+    identifiers = list(tibble::tibble(
+      STRING_id = c("9606.A", "9606.A", "9606.B"),
+      hgnc_id = c("HGNC:1", "HGNC:1b", "HGNC:2")
+    ))
+  )
+  ref <- list("1" = c("9606.A", "9606.B"))
+  out <- analysis_snapshot_reference_members_store_space(ref, membership, "functional")
+  expect_setequal(out[["1"]], c("HGNC:1", "HGNC:1b", "HGNC:2"))
+})
commit 8765302cfdd367b6fc5508bad9d2dc85bf1ecc67
Author: Bernt Popp <bernt.popp@gmail.com>
Date:   Sat Jul 18 22:48:41 2026 +0200

    refactor(api): extract analysis_snapshot_prune to keep repository under 600 lines (#573)
    
    Codex round-3 CI1 (would fail make code-quality-audit): the WB-M1 mirai-parity
    guard pushed analysis-snapshot-repository.R to 603 lines (>600, not
    baseline-allowlisted). Moved analysis_snapshot_prune() verbatim into a new
    functions/analysis-snapshot-prune-helpers.R (repository.R now 550), registered
    immediately after analysis-snapshot-repository.R in BOTH bootstrap/load_modules.R
    and bootstrap/setup_workers.R (the snapshot builder calls prune during a refresh
    on either the durable-worker or the mirai path). The release-reference lookup
    stays exists()-guarded inside prune, so the direct-source repository test that
    stubs analysis_release_referenced_snapshot_ids still exercises it. Behavior
    unchanged; the two prune tests source the new file.
    
    make code-quality-audit: clean.
    
    Claude-Session: https://claude.ai/code/session_01Shab9CYtSFmHhb7yzqBGNn

commit 8765302cfdd367b6fc5508bad9d2dc85bf1ecc67
Author:     Bernt Popp <bernt.popp@gmail.com>
AuthorDate: Sat Jul 18 22:48:41 2026 +0200
Commit:     Bernt Popp <bernt.popp@gmail.com>
CommitDate: Sat Jul 18 22:48:41 2026 +0200

    refactor(api): extract analysis_snapshot_prune to keep repository under 600 lines (#573)
    
    Codex round-3 CI1 (would fail make code-quality-audit): the WB-M1 mirai-parity
    guard pushed analysis-snapshot-repository.R to 603 lines (>600, not
    baseline-allowlisted). Moved analysis_snapshot_prune() verbatim into a new
    functions/analysis-snapshot-prune-helpers.R (repository.R now 550), registered
    immediately after analysis-snapshot-repository.R in BOTH bootstrap/load_modules.R
    and bootstrap/setup_workers.R (the snapshot builder calls prune during a refresh
    on either the durable-worker or the mirai path). The release-reference lookup
    stays exists()-guarded inside prune, so the direct-source repository test that
    stubs analysis_release_referenced_snapshot_ids still exercises it. Behavior
    unchanged; the two prune tests source the new file.
    
    make code-quality-audit: clean.
    
    Claude-Session: https://claude.ai/code/session_01Shab9CYtSFmHhb7yzqBGNn

diff --git a/api/bootstrap/load_modules.R b/api/bootstrap/load_modules.R
index 7da91260..512a3065 100644
--- a/api/bootstrap/load_modules.R
+++ b/api/bootstrap/load_modules.R
@@ -23,100 +23,101 @@
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
+    "functions/analysis-snapshot-prune-helpers.R",
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
diff --git a/api/bootstrap/setup_workers.R b/api/bootstrap/setup_workers.R
index d353f0fe..d4b2b58f 100644
--- a/api/bootstrap/setup_workers.R
+++ b/api/bootstrap/setup_workers.R
@@ -79,93 +79,94 @@ bootstrap_setup_workers <- function() {
       library(ellmer)
     }
     # Load pdftools for PDF parsing in comparisons update (optional)
     if (requireNamespace("pdftools", quietly = TRUE)) {
       library(pdftools)
     }
     # Source data-helpers (generate_panel_hash, generate_json_hash, generate_function_hash, etc.)
     source("/app/functions/data-helpers.R", local = FALSE)
     # Source entity-helpers (nest_gene_tibble, nest_pubtator_gene_tibble, etc.)
     source("/app/functions/entity-helpers.R", local = FALSE)
     # Source file functions (check_file_age, get_newest_file)
     source("/app/functions/file-functions.R", local = FALSE)
     # Source the analysis functions (gen_string_clust_obj, gen_mca_clust_obj)
     source("/app/functions/analysis-string-channels.R", local = FALSE)
     source("/app/functions/analysis-cache-fingerprint.R", local = FALSE)
     source("/app/functions/analyses-functions.R", local = FALSE)
     source("/app/functions/analysis-phenotype-mca-prep.R", local = FALSE)
     source("/app/functions/analysis-phenotype-functions.R", local = FALSE)
     source("/app/functions/analysis-null-models.R", local = FALSE)
     source("/app/functions/analysis-cluster-validation.R", local = FALSE)
     source("/app/functions/analysis-network-functions.R", local = FALSE)
     # Source shared external proxy infrastructure (validate_gene_symbol, cache backends, throttle)
     source("/app/functions/external-proxy-functions.R", local = FALSE)
     # Source gnomAD proxy functions (fetch_gnomad_constraints + memoised wrapper)
     source("/app/functions/external-proxy-gnomad.R", local = FALSE)
     # Source batched gnomAD GraphQL fallback (used by HGNC enrichment for chrX/Y/M genes
     # absent from the autosomes-only bulk constraint TSV). Load order: depends on
     # external-proxy-functions.R (cache_static, validate_gene_symbol) sourced earlier.
     source("/app/functions/external-proxy-gnomad-batch.R", local = FALSE)
     # Source gnomAD/AlphaFold enrichment functions for HGNC update pipeline
     source("/app/functions/hgnc-enrichment-gnomad.R", local = FALSE)
     # Source HGNC functions (update_process_hgnc_data)
     source("/app/functions/hgnc-functions.R", local = FALSE)
     # Source Ensembl functions (gene_coordinates_from_ensembl, gene_coordinates_from_symbol)
     source("/app/functions/ensembl-functions.R", local = FALSE)
     # Source db-helpers for parameterized queries
     source("/app/functions/db-helpers.R", local = FALSE)
     # Source metadata refresh helpers for rollback-safe table replacement
     source("/app/functions/metadata-refresh.R", local = FALSE)
     # Source durable async-job repository for worker-side lease/progress operations
     source("/app/functions/async-job-repository.R", local = FALSE)
     # Runtime DB-credential resolver + historical-payload scrub (#535 P1-1):
     # handlers resolve creds from runtime `dw`, never from the job payload.
     source("/app/functions/async-job-db-config.R", local = FALSE)
     source("/app/functions/async-job-payload-scrub.R", local = FALSE)
     # Source durable async-job runtime helpers before the compatibility shim
     source("/app/functions/async-job-progress.R", local = FALSE)
     source("/app/functions/async-job-network-layout-handlers.R", local = FALSE)
     source("/app/functions/analysis-snapshot-presets.R", local = FALSE)
     source("/app/functions/analysis-snapshot-repository.R", local = FALSE)
+    source("/app/functions/analysis-snapshot-prune-helpers.R", local = FALSE)
     source("/app/functions/analysis-snapshot-dependencies.R", local = FALSE)
     source("/app/functions/analysis-snapshot-builder.R", local = FALSE)
     source("/app/functions/analysis-reproducibility.R", local = FALSE)
     source("/app/functions/async-job-analysis-snapshot-handlers.R", local = FALSE)
     source("/app/functions/async-job-omim-apply.R", local = FALSE)
     source("/app/functions/async-job-force-apply-payload.R", local = FALSE)
     source("/app/functions/async-job-provider-handlers.R", local = FALSE)
     source("/app/functions/async-job-maintenance-handlers.R", local = FALSE)
     source("/app/functions/async-job-handlers.R", local = FALSE)
     source("/app/functions/async-job-worker.R", local = FALSE)
     # Source transitional progress shim for legacy mirai async code paths
     source("/app/functions/job-progress.R", local = FALSE)
     # Source PubTator functions for async update jobs (client + parser before orchestrator)
     source("/app/functions/pubtator-client.R", local = FALSE)
     source("/app/functions/pubtator-parser.R", local = FALSE)
     source("/app/functions/pubtator-functions.R", local = FALSE)
     # Source OMIM functions (download_genemap2, parse_genemap2, download_hpoa) for comparisons
     source("/app/functions/omim-functions.R", local = FALSE)
     # Source comparisons functions for async comparisons update jobs
     source("/app/functions/comparisons-sources.R", local = FALSE)
     source("/app/functions/comparisons-parsers.R", local = FALSE)
     source("/app/functions/comparisons-omim.R", local = FALSE)
     source("/app/functions/comparisons-functions.R", local = FALSE)
     # Source LLM-related functions for async LLM batch generation jobs
     source("/app/functions/llm-summary-config.R", local = FALSE)
     source("/app/functions/llm-cache-repository.R", local = FALSE)
     source("/app/functions/llm-validation.R", local = FALSE)
     source("/app/functions/llm-rate-limiter.R", local = FALSE)
     source("/app/functions/llm-types.R", local = FALSE)
     source("/app/functions/llm-model-config.R", local = FALSE)
     source("/app/functions/llm-client.R", local = FALSE)
     source("/app/functions/llm-service.R", local = FALSE)
     source("/app/functions/llm-judge.R", local = FALSE)
     source("/app/functions/llm-batch-cluster-data.R", local = FALSE)
     source("/app/functions/llm-batch-generator.R", local = FALSE)
   })
   message(sprintf(
     "[%s] Exported packages and functions to mirai daemons",
     Sys.time()
   ))
 
   list(count = worker_count, dispatcher = TRUE)
 }
diff --git a/api/functions/analysis-snapshot-prune-helpers.R b/api/functions/analysis-snapshot-prune-helpers.R
new file mode 100644
index 00000000..515359a0
--- /dev/null
+++ b/api/functions/analysis-snapshot-prune-helpers.R
@@ -0,0 +1,81 @@
+# functions/analysis-snapshot-prune-helpers.R
+#
+# Retention / prune helper for public analysis-snapshot manifests. Extracted from
+# `analysis-snapshot-repository.R` (#573 round-3 CI1) to keep that file under the
+# 600-line ceiling; the logic is unchanged.
+#
+# `analysis_snapshot_prune()` keeps the newest `keep_public_ready`
+# public_ready/superseded rows and deletes superseded rows older than
+# `keep_superseded_days` — but NEVER deletes a snapshot a #573 release still
+# references (its live reproducibility endpoint would then 503). The
+# release-reference lookup (`analysis_release_referenced_snapshot_ids`) is
+# `exists()`-guarded for mirai-pool parity: on the legacy mirai worker the release
+# repository file is not sourced, so the guard degrades to "no release references"
+# (the pre-existing behavior) rather than erroring.
+#
+# Registered in both `bootstrap/load_modules.R` (API + durable worker + MCP) and
+# `bootstrap/setup_workers.R` (mirai `everywhere()`), immediately after
+# `analysis-snapshot-repository.R`, because the snapshot builder calls this during
+# a refresh on either execution path.
+
+if (!exists("%||%", mode = "function")) {
+  `%||%` <- function(x, y) if (is.null(x)) y else x
+}
+
+analysis_snapshot_prune <- function(analysis_type,
+                                    parameter_hash,
+                                    keep_public_ready = 3L,
+                                    keep_superseded_days = 14L,
+                                    conn = NULL) {
+  keep_public_ready <- max(1L, as.integer(keep_public_ready))
+  keep_superseded_days <- max(0L, as.integer(keep_superseded_days))
+
+  keep_rows <- db_execute_query(
+    "SELECT snapshot_id
+       FROM analysis_snapshot_manifest
+      WHERE analysis_type = ?
+        AND parameter_hash = ?
+        AND status IN ('public_ready', 'superseded')
+      ORDER BY COALESCE(activated_at, generated_at, created_at) DESC, snapshot_id DESC
+      LIMIT ?",
+    unname(list(analysis_type, parameter_hash, keep_public_ready)),
+    conn = conn
+  )
+  keep_ids <- as.numeric(keep_rows$snapshot_id %||% numeric())
+
+  cutoff_time <- as.POSIXct(Sys.time() - (keep_superseded_days * 86400), tz = "UTC")
+  cutoff <- format(cutoff_time, "%Y-%m-%d %H:%M:%OS6", tz = "UTC")
+  candidates <- db_execute_query(
+    "SELECT snapshot_id
+       FROM analysis_snapshot_manifest
+      WHERE analysis_type = ?
+        AND parameter_hash = ?
+        AND status = 'superseded'
+        AND COALESCE(superseded_at, updated_at, created_at) < ?",
+    unname(list(analysis_type, parameter_hash, cutoff)),
+    conn = conn
+  )
+
+  # Never prune a snapshot a release (#573) still references (its LIVE
+  # reproducibility endpoint would 503). analysis_release_referenced_snapshot_ids()
+  # is the single source of truth for this -- do not inline a NOT IN subquery.
+  # exists()-guarded for mirai-pool parity (the release repository file is not
+  # sourced on the legacy mirai worker), mirroring the lock-name guard.
+  referenced_ids <- if (exists("analysis_release_referenced_snapshot_ids", mode = "function")) {
+    as.numeric(analysis_release_referenced_snapshot_ids(conn = conn))
+  } else {
+    numeric()
+  }
+
+  delete_ids <- setdiff(as.numeric(candidates$snapshot_id %||% numeric()), union(keep_ids, referenced_ids))
+  if (length(delete_ids) == 0L) {
+    return(invisible(0L))
+  }
+
+  placeholders <- paste(rep("?", length(delete_ids)), collapse = ", ")
+  db_execute_statement(
+    paste0("DELETE FROM analysis_snapshot_manifest WHERE snapshot_id IN (", placeholders, ")"),
+    unname(as.list(delete_ids)),
+    conn = conn
+  )
+}
diff --git a/api/functions/analysis-snapshot-repository.R b/api/functions/analysis-snapshot-repository.R
index 9638d127..dda204a1 100644
--- a/api/functions/analysis-snapshot-repository.R
+++ b/api/functions/analysis-snapshot-repository.R
@@ -497,107 +497,54 @@ analysis_snapshot_public_manifest <- function(analysis_type,
   if (!is.null(current_source_data_version)) {
     manifest$current_source_data_version <- as.character(current_source_data_version)[1]
   }
   manifest$status_code <- analysis_snapshot_status_code(manifest)
   manifest
 }
 
 #' Cheap "is the active public snapshot CURRENT?" probe.
 #'
 #' Unlike `analysis_snapshot_public_exists()` (which only checks that a
 #' public-ready row exists), this returns TRUE only when that row is also
 #' *current* — its computed `status_code` is `"available"`, not `snapshot_stale`
 #' or `source_version_mismatch`. Used as the skip predicate by the startup
 #' bootstrap and the non-force admin refresh so a STALE or VERSION-MISMATCHED
 #' snapshot is re-enqueued (self-heals on restart) instead of being treated as
 #' "already present" and left serving a permanent 503. The #420/#440 self-heal
 #' only covered `snapshot_missing`; a snapshot that aged past `stale_after`
 #' (default 7 days) never refreshed on its own. See AGENTS.md "Public analysis
 #' endpoints".
 #'
 #' @param manifest_fn Injectable manifest read (default
 #'   `analysis_snapshot_public_manifest`) so this is unit-testable without a DB.
 #' @return TRUE only when a public-ready snapshot exists and is current.
 #' @export
 analysis_snapshot_public_current <- function(analysis_type,
                                              parameter_hash,
                                              conn = NULL,
                                              manifest_fn = analysis_snapshot_public_manifest) {
   manifest <- tryCatch(
     manifest_fn(analysis_type, parameter_hash, conn = conn),
     error = function(e) NULL
   )
   if (is.null(manifest) ||
     (is.data.frame(manifest) && nrow(manifest) == 0L)) {
     return(FALSE)
   }
   identical(as.character(manifest$status_code)[1], "available")
 }
 
 analysis_snapshot_source_data_version <- function(conn = NULL) {
   result <- db_execute_query(
     "SELECT source_data_version
        FROM mcp_public_analysis_source_version
       LIMIT 1",
     conn = conn
   )
 
   as.character(result$source_data_version[[1]])
 }
 
-analysis_snapshot_prune <- function(analysis_type,
-                                    parameter_hash,
-                                    keep_public_ready = 3L,
-                                    keep_superseded_days = 14L,
-                                    conn = NULL) {
-  keep_public_ready <- max(1L, as.integer(keep_public_ready))
-  keep_superseded_days <- max(0L, as.integer(keep_superseded_days))
-
-  keep_rows <- db_execute_query(
-    "SELECT snapshot_id
-       FROM analysis_snapshot_manifest
-      WHERE analysis_type = ?
-        AND parameter_hash = ?
-        AND status IN ('public_ready', 'superseded')
-      ORDER BY COALESCE(activated_at, generated_at, created_at) DESC, snapshot_id DESC
-      LIMIT ?",
-    unname(list(analysis_type, parameter_hash, keep_public_ready)),
-    conn = conn
-  )
-  keep_ids <- as.numeric(keep_rows$snapshot_id %||% numeric())
-
-  cutoff_time <- as.POSIXct(Sys.time() - (keep_superseded_days * 86400), tz = "UTC")
-  cutoff <- format(cutoff_time, "%Y-%m-%d %H:%M:%OS6", tz = "UTC")
-  candidates <- db_execute_query(
-    "SELECT snapshot_id
-       FROM analysis_snapshot_manifest
-      WHERE analysis_type = ?
-        AND parameter_hash = ?
-        AND status = 'superseded'
-        AND COALESCE(superseded_at, updated_at, created_at) < ?",
-    unname(list(analysis_type, parameter_hash, cutoff)),
-    conn = conn
-  )
-
-  # Never prune a snapshot a release (#573) still references (its LIVE
-  # reproducibility endpoint would 503). analysis_release_referenced_snapshot_ids()
-  # is the single source of truth for this -- do not inline a NOT IN subquery.
-  # exists()-guarded for mirai-pool parity (the release repository file is not
-  # sourced on the legacy mirai worker), mirroring the lock-name guard.
-  referenced_ids <- if (exists("analysis_release_referenced_snapshot_ids", mode = "function")) {
-    as.numeric(analysis_release_referenced_snapshot_ids(conn = conn))
-  } else {
-    numeric()
-  }
-
-  delete_ids <- setdiff(as.numeric(candidates$snapshot_id %||% numeric()), union(keep_ids, referenced_ids))
-  if (length(delete_ids) == 0L) {
-    return(invisible(0L))
-  }
-
-  placeholders <- paste(rep("?", length(delete_ids)), collapse = ", ")
-  db_execute_statement(
-    paste0("DELETE FROM analysis_snapshot_manifest WHERE snapshot_id IN (", placeholders, ")"),
-    unname(as.list(delete_ids)),
-    conn = conn
-  )
-}
+# analysis_snapshot_prune() was extracted to
+# functions/analysis-snapshot-prune-helpers.R (#573 round-3 CI1) to keep this
+# file under the 600-line ceiling. It is sourced immediately after this file in
+# both bootstrap/load_modules.R and bootstrap/setup_workers.R.

codex
The extracted helper is sourced in both normal and mirai worker bootstrap paths; normal release-aware processes retain the DB-backed guard. The one-to-many mapping correctly expands each STRING ID to the full HGNC union, and the non-empty partial-attestation path now rejects before the intersection-only comparison. I’m doing the final diff/verification pass now.
exec
/bin/bash -lc "sed -n '1,320p' /home/bernt-popp/.understand-anything/repo/understand-anything-plugin/skills/understand-diff/SKILL.md && sed -n '1,320p' /home/bernt-popp/.codex/superpowers/skills/verification-before-completion/SKILL.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
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
---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
---

# Verification Before Completion

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- **ANY wording implying success without having run verification**

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**Tests:**
```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**
```
✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**
```
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report
```

## Why This Matters

From 24 failure memories:
- your human partner said "I don't believe you" - trust broken
- Undefined functions shipped - would crash
- Missing requirements shipped - incomplete features
- Time wasted on false completion → redirect → rework
- Violates: "Honesty is a core value. If you lie, you'll be replaced."

## When To Apply

**ALWAYS before:**
- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

**Rule applies to:**
- Exact phrases
- Paraphrases and synonyms
- Implications of success
- ANY communication suggesting completion/correctness

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.

codex
I’m using the diff-analysis guide to cross-check dependency blast radius. Its dashboard-overlay output cannot be written in this read-only workspace, so this remains a read-only review.
exec
/bin/bash -lc "if [ -f .understand-anything/knowledge-graph.json ]; then rg -n -m 1 '\"project\"' .understand-anything/knowledge-graph.json; else echo 'knowledge graph unavailable'; fi
rg -n 'analysis-snapshot-prune-helpers\\.R|analysis-snapshot-coherence\\.R|analysis-snapshot-release-materialize\\.R|analysis-snapshot-release\\.R|analysis-snapshot-release-repository\\.R|analysis-snapshot-release-service\\.R' .understand-anything/knowledge-graph.json 2>/dev/null | head -n 160 || true
git diff --check 67cf6003..HEAD
printf 'repository lines: '; wc -l < api/functions/analysis-snapshot-repository.R
printf 'new handwritten function files over 600 lines: '; find api/functions api/services api/endpoints -type f -name '*.R' -print0 | xargs -0 wc -l | awk '"'$1 > 600 && $2 != "total" {print $2 ":" $1}'"'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
knowledge graph unavailable
repository lines: 550
new handwritten function files over 600 lines: 
codex
No BLOCKER or HIGH findings.

- `analysis-snapshot-repository.R` is 550 lines; prune helper is registered and preserves the release-reference exclusion.
- One-to-many STRING→HGNC mapping expands to the full union.
- Present nonempty partial/malformed attestations fail key-set coherence; legacy absent/empty attestation degrades as intended.
- `git diff --check 67cf6003..HEAD` is clean.

`make code-quality-audit` could not run because this read-only sandbox forbids its temporary directory creation; no source-file size breach was found by static line count.

SHIP
tokens used
132,660
No BLOCKER or HIGH findings.

- `analysis-snapshot-repository.R` is 550 lines; prune helper is registered and preserves the release-reference exclusion.
- One-to-many STRING→HGNC mapping expands to the full union.
- Present nonempty partial/malformed attestations fail key-set coherence; legacy absent/empty attestation degrades as intended.
- `git diff --check 67cf6003..HEAD` is clean.

`make code-quality-audit` could not run because this read-only sandbox forbids its temporary directory creation; no source-file size breach was found by static line count.

SHIP
