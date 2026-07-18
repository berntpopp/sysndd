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
session id: 019f76d3-0c66-7a93-b525-f51bf0ee97c7
--------
user
# Codex re-review — #573 Slice A, verify DO-NOT-SHIP findings are resolved

You previously reviewed this branch (#573 Slice A, immutable public analysis-snapshot releases backend) and returned DO-NOT-SHIP with 1 BLOCKER + 3 HIGH + 1 MEDIUM + 1 LOW. Fix commits were then applied. Re-review `git diff 67cf6003..HEAD` (whole Slice A) and specifically CONFIRM each prior finding is now correctly resolved, AND scan the fix commits (git log 49eb025b..HEAD) for any REGRESSION or NEW issue the fixes introduced (e.g. the layer-resolution, the public-head projection allowlist, the 503 lock path, the duplicate-key insert seam, the reproducibility-hash assertion, the db_release provenance, the pagination clamp).

Prior findings to verify RESOLVED:
- BLOCKER: caller `layers` redefining `has_reproducibility`/`files_prefix` (gate-bypass + path traversal). Now `analysis_snapshot_release_resolve_layers()` resolves to the authoritative registry (caller policy fields ignored; unknown/dup -> 400) + `.analysis_release_assert_safe_path()` in the tar builder. Verify no residual path an Admin body could use to skip a gate or write outside the archive root; verify duplicate/omission handling.
- HIGH: public list/detail/latest leaking `created_by_user_id`/`last_error_message`. Now `analysis_release_public_head()` allowlist in `svc_release_list`/`svc_release_get`. Verify the admin path still returns full head and NO public path returns internal fields (incl. the manifest object and the `layers` summary).
- HIGH: build not asserting `sha256(repro bytes)==reproducibility_hash`. Now asserted at build. Verify it uses the RAW decoded bytes (not the parsing decode) and rejects on mismatch.
- HIGH: idempotency race (unlocked-proceed + raw-500 on PK collision). Now failed lock on a real conn -> 503; duplicate-key insert -> re-read -> idempotent-200-or-500. Verify the lock is actually required on the real path, the 503 maps correctly, and the dup-key path returns the existing row only when content_digest matches.
- MEDIUM: db_release_version/commit unpopulated. Now sourced from pinned snapshot manifests. Verify consistency handling.
- LOW: unbounded pagination. Now clamped. Verify bounds.

Focus areas unchanged from the first pass (authz/exposure, SQL/injection, gate soundness, hashing invariants, byte-serving, resource/lock/pool safety, adjacent same-class siblings). Group findings BLOCKER/HIGH/MEDIUM/LOW; for each `file:line` + failure scenario + fix. If all prior findings are resolved and no new BLOCKER/HIGH exists, say so and end with SHIP. Read-only; do not modify files.
codex
I’m reviewing the full Slice A diff and the follow-up fixes read-only. I’ll use the repository’s analysis-snapshot and security review guidance, plus the required general workflow guidance, to trace each previously reported issue through the actual public/admin paths.
exec
/bin/bash -lc "for skill_file in /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md .agents/skills/sysndd-analysis-snapshots/SKILL.md .agents/skills/sysndd-security-bug-scan/SKILL.md /home/bernt-popp/.understand-anything/repo/understand-anything-plugin/skills/understand-diff/SKILL.md; do printf '\\n--- %s ---\\n' \""'$skill_file"; sed -n '"'1,240p' \""'$skill_file"; done
printf '"'\\n--- AGENTS ---\\n'
sed -n '1,260p' AGENTS.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:

--- /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md ---
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

--- .agents/skills/sysndd-analysis-snapshots/SKILL.md ---
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

--- .agents/skills/sysndd-security-bug-scan/SKILL.md ---
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

--- /home/bernt-popp/.understand-anything/repo/understand-anything-plugin/skills/understand-diff/SKILL.md ---
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

--- AGENTS ---
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

exec
/bin/bash -lc 'wc -l AGENTS.md /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md .agents/skills/sysndd-analysis-snapshots/SKILL.md .agents/skills/sysndd-security-bug-scan/SKILL.md /home/bernt-popp/.understand-anything/repo/understand-anything-plugin/skills/understand-diff/SKILL.md
git diff --name-only 67cf6003..HEAD
git log --oneline --decorate 49eb025b..HEAD' in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
   282 AGENTS.md
   117 /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md
    49 .agents/skills/sysndd-analysis-snapshots/SKILL.md
    64 .agents/skills/sysndd-security-bug-scan/SKILL.md
    72 /home/bernt-popp/.understand-anything/repo/understand-anything-plugin/skills/understand-diff/SKILL.md
   584 total
.gitignore
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-prompt.md
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-reconciliation.md
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md
.planning/reviews/2026-07-18-category-clustering-universes-574-codex-prompt.md
.planning/reviews/2026-07-18-category-clustering-universes-574-codex-reconciliation.md
.planning/reviews/2026-07-18-category-clustering-universes-574-codex-review.md
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md
.planning/superpowers/plans/2026-07-18-category-clustering-universes-574-plan.md
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md
.planning/superpowers/specs/2026-07-18-category-clustering-universes-574-design.md
AGENTS.md
CHANGELOG.md
README.md
api/bootstrap/load_modules.R
api/endpoints/admin_analysis_snapshot_endpoints.R
api/endpoints/analysis_endpoints.R
api/functions/analysis-reproducibility.R
api/functions/analysis-snapshot-release-manifest.R
api/functions/analysis-snapshot-release-materialize.R
api/functions/analysis-snapshot-release-repository.R
api/functions/analysis-snapshot-release.R
api/functions/analysis-snapshot-repository.R
api/functions/migration-manifest.R
api/services/analysis-snapshot-release-service.R
api/tests/testthat/helper-db.R
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R
api/tests/testthat/test-integration-analysis-release-endpoints.R
api/tests/testthat/test-integration-analysis-snapshot-release-build.R
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R
api/tests/testthat/test-mcp-select-principal-projections.R
api/tests/testthat/test-unit-admin-snapshot-endpoint-guard.R
api/tests/testthat/test-unit-analysis-reproducibility.R
api/tests/testthat/test-unit-analysis-snapshot-migration.R
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R
api/tests/testthat/test-unit-analysis-snapshot-release-service.R
api/tests/testthat/test-unit-analysis-snapshot-repository.R
api/tests/testthat/test-unit-cheap-route-isolation.R
api/tests/testthat/test-unit-core-views-manifest.R
api/version_spec.json
app/package-lock.json
app/package.json
db/migrations/045_add_analysis_snapshot_release.sql
db/migrations/README.md
documentation/08-development.qmd
documentation/09-deployment.qmd
f5224285 (HEAD -> worktree-analysis-snapshot-releases-573-slice-a) fix(api): release public-surface hardening — head projection, 503 lock path, pagination clamp, prune guard (#573)
44455711 fix(api): release build hardening — layer selection, path containment, repro-hash verify, TOCTOU idempotency, DB provenance (#573)

exec
/bin/bash -lc "sed -n '1,140p' /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md
sed -n '1,100p' .agents/skills/sysndd-analysis-snapshots/SKILL.md
sed -n '1,110p' .agents/skills/sysndd-security-bug-scan/SKILL.md
sed -n '1,110p' /home/bernt-popp/.understand-anything/repo/understand-anything-plugin/skills/understand-diff/SKILL.md
sed -n '1,150p' AGENTS.md
sed -n '151,330p' AGENTS.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
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

exec
/bin/bash -lc "if test -f .understand-anything/knowledge-graph.json; then
  rg -n -m 1 '\"project\"' .understand-anything/knowledge-graph.json
else
  printf '%s\\n' 'NO_KNOWLEDGE_GRAPH'
fi
git diff --stat 67cf6003..HEAD
git show --stat --oneline 44455711
git show --stat --oneline f5224285
wc -l api/functions/analysis-snapshot-release.R api/functions/analysis-snapshot-release-manifest.R api/functions/analysis-snapshot-release-materialize.R api/functions/analysis-snapshot-release-repository.R api/services/analysis-snapshot-release-service.R api/endpoints/analysis_endpoints.R api/endpoints/admin_analysis_snapshot_endpoints.R db/migrations/045_add_analysis_snapshot_release.sql" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
NO_KNOWLEDGE_GRAPH
 .gitignore                                         |   3 +
 ...-analysis-snapshot-releases-573-codex-prompt.md |  33 ++
 ...s-snapshot-releases-573-codex-reconciliation.md |  19 +
 ...-analysis-snapshot-releases-573-codex-review.md |  33 ++
 ...tegory-clustering-universes-574-codex-prompt.md |  33 ++
 ...lustering-universes-574-codex-reconciliation.md |  15 +
 ...tegory-clustering-universes-574-codex-review.md |  23 +
 ...26-07-18-analysis-snapshot-releases-573-plan.md | 415 +++++++++++++++
 ...07-18-category-clustering-universes-574-plan.md | 277 ++++++++++
 ...-07-18-analysis-snapshot-releases-573-design.md | 352 +++++++++++++
 ...-18-category-clustering-universes-574-design.md | 151 ++++++
 AGENTS.md                                          |  13 +
 CHANGELOG.md                                       |  61 +++
 README.md                                          |   1 +
 api/bootstrap/load_modules.R                       |  16 +
 api/endpoints/admin_analysis_snapshot_endpoints.R  | 232 +++++++++
 api/endpoints/analysis_endpoints.R                 | 159 ++++++
 api/functions/analysis-reproducibility.R           |  25 +
 api/functions/analysis-snapshot-release-manifest.R | 279 ++++++++++
 .../analysis-snapshot-release-materialize.R        | 359 +++++++++++++
 .../analysis-snapshot-release-repository.R         | 484 ++++++++++++++++++
 api/functions/analysis-snapshot-release.R          | 539 ++++++++++++++++++++
 api/functions/analysis-snapshot-repository.R       |  13 +-
 api/functions/migration-manifest.R                 |   4 +-
 api/services/analysis-snapshot-release-service.R   | 288 +++++++++++
 api/tests/testthat/helper-db.R                     | 105 ++++
 ...-integration-analysis-release-admin-endpoints.R | 488 ++++++++++++++++++
 .../test-integration-analysis-release-endpoints.R  | 360 +++++++++++++
 ...t-integration-analysis-snapshot-release-build.R | 560 +++++++++++++++++++++
 ...egration-analysis-snapshot-release-repository.R | 313 ++++++++++++
 .../test-mcp-select-principal-projections.R        |   6 +-
 .../test-unit-admin-snapshot-endpoint-guard.R      |  21 +-
 .../testthat/test-unit-analysis-reproducibility.R  |  80 +++
 .../test-unit-analysis-snapshot-migration.R        |   4 +-
 ...st-unit-analysis-snapshot-prune-release-guard.R | 225 +++++++++
 .../test-unit-analysis-snapshot-release-manifest.R | 180 +++++++
 ...test-unit-analysis-snapshot-release-migration.R | 110 ++++
 .../test-unit-analysis-snapshot-release-service.R  | 534 ++++++++++++++++++++
 .../test-unit-analysis-snapshot-repository.R       |  16 +-
 .../testthat/test-unit-cheap-route-isolation.R     |  74 +++
 api/tests/testthat/test-unit-core-views-manifest.R |   8 +-
 api/version_spec.json                              |   2 +-
 app/package-lock.json                              |   4 +-
 app/package.json                                   |   2 +-
 .../045_add_analysis_snapshot_release.sql          |  69 +++
 db/migrations/README.md                            |   7 +-
 documentation/08-development.qmd                   |  46 ++
 documentation/09-deployment.qmd                    |  67 +++
 48 files changed, 7088 insertions(+), 20 deletions(-)
44455711 fix(api): release build hardening — layer selection, path containment, repro-hash verify, TOCTOU idempotency, DB provenance (#573)
 api/functions/analysis-snapshot-release-manifest.R |  75 +++++++++++-
 .../analysis-snapshot-release-materialize.R        |  22 ++++
 api/functions/analysis-snapshot-release.R          | 135 +++++++++++++++++----
 ...t-integration-analysis-snapshot-release-build.R |  91 +++++++++++++-
 .../test-unit-analysis-snapshot-release-manifest.R |  54 +++++++++
 5 files changed, 354 insertions(+), 23 deletions(-)
f5224285 fix(api): release public-surface hardening — head projection, 503 lock path, pagination clamp, prune guard (#573)
 .../analysis-snapshot-release-repository.R         | 43 +++++++++++++
 api/functions/analysis-snapshot-repository.R       |  8 ++-
 api/services/analysis-snapshot-release-service.R   | 54 ++++++++++++++--
 ...egration-analysis-snapshot-release-repository.R | 35 +++++++++++
 .../test-unit-analysis-snapshot-release-service.R  | 71 ++++++++++++++++++++--
 5 files changed, 200 insertions(+), 11 deletions(-)
   539 api/functions/analysis-snapshot-release.R
   279 api/functions/analysis-snapshot-release-manifest.R
   359 api/functions/analysis-snapshot-release-materialize.R
   484 api/functions/analysis-snapshot-release-repository.R
   288 api/services/analysis-snapshot-release-service.R
   535 api/endpoints/analysis_endpoints.R
   293 api/endpoints/admin_analysis_snapshot_endpoints.R
    69 db/migrations/045_add_analysis_snapshot_release.sql
  2846 total

codex
The review scope is substantial but contained to the release subsystem. The diff-analysis knowledge graph is not present, so I’m following the source-level call chains and the accompanying integration/unit coverage directly; I will not generate its optional overlay because this is a read-only review.
exec
/bin/bash -lc 'git show --format=fuller --find-renames 44455711 -- api/functions/analysis-snapshot-release.R api/functions/analysis-snapshot-release-manifest.R api/functions/analysis-snapshot-release-materialize.R
git show --format=fuller --find-renames f5224285 -- api/functions/analysis-snapshot-release-repository.R api/functions/analysis-snapshot-repository.R api/services/analysis-snapshot-release-service.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
commit 44455711501949bad89499da321acdf97007d37c
Author:     Bernt Popp <bernt.popp@gmail.com>
AuthorDate: Sat Jul 18 21:59:15 2026 +0200
Commit:     Bernt Popp <bernt.popp@gmail.com>
CommitDate: Sat Jul 18 21:59:15 2026 +0200

    fix(api): release build hardening — layer selection, path containment, repro-hash verify, TOCTOU idempotency, DB provenance (#573)
    
    Codex DO-NOT-SHIP fixes on the build path (B1/H2/H3-build/M1/WB-A2).
    
    B1 (BLOCKER): a request `layers` is now a SELECTION, not a policy
    redefinition. analysis_snapshot_release_resolve_layers() matches each requested
    selector (bare string OR {analysis_type} object) against the authoritative
    registry and returns the REGISTRY entry — the caller can no longer override
    has_reproducibility (which would skip the hard-coherence/reproducibility gates)
    or files_prefix (path traversal). Unknown/duplicate analysis_type -> 400. Plus
    defense-in-depth: .analysis_release_assert_safe_path() rejects any archive path
    that is absolute, backslash-bearing, or contains a `..` segment — enforced in
    analysis_release_build_tar_gz() AND at the .analysis_release_artifact() choke
    point.
    
    H2 (HIGH): the build now DECODES the reproducibility bytes and asserts
    sha256(bytes) == reproducibility_hash (the LOCKED equality must HOLD, not merely
    be present); a corrupt/restored bundle -> release_reproducibility_missing (400).
    
    H3 (HIGH, build side): a failed per-preset advisory-lock acquisition on a real
    DBIConnection no longer proceeds unlocked -> release_lock_unavailable. The insert
    is wrapped: on a duplicate-key error it re-reads by release_id and returns
    created=FALSE when the stored content_digest matches (idempotent), else re-raises
    (500 anomaly). lock_acquire + inserter are now injectable seams.
    
    M1 (MEDIUM): db_release_version/commit are read from the pinned snapshot
    manifests (consistent-value helper) and persisted on the release head +
    manifest.source.db_release{version,commit}.
    
    WB-A2: content_digest layer sort -> order(method='radix') (locale-invariant).
    
    Claude-Session: https://claude.ai/code/session_01Shab9CYtSFmHhb7yzqBGNn

diff --git a/api/functions/analysis-snapshot-release-manifest.R b/api/functions/analysis-snapshot-release-manifest.R
index bef8ebb2..8e5bb84f 100644
--- a/api/functions/analysis-snapshot-release-manifest.R
+++ b/api/functions/analysis-snapshot-release-manifest.R
@@ -47,6 +47,72 @@ analysis_snapshot_release_layers <- function() {
   )
 }
 
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
 #' UTF-8 raw bytes of the canonical JSON serialization of `obj`.
 #'
 #' Uses the SAME serializer as the public snapshot API
@@ -88,7 +154,9 @@ analysis_release_sha256 <- function(raw_or_chr) {
 #' @return chr, a 64-character lowercase hex sha256 digest.
 analysis_release_content_digest <- function(layer_entries, source_data_version, manifest_schema_version) {
   analysis_types <- vapply(layer_entries, function(entry) entry$analysis_type, character(1))
-  sorted_entries <- layer_entries[order(analysis_types)]
+  # method = "radix" is locale-invariant: the content identity must not depend on
+  # the builder's LC_COLLATE (de-risks cross-host #574 reproducibility).
+  sorted_entries <- layer_entries[order(analysis_types, method = "radix")]
 
   identity_layers <- lapply(sorted_entries, function(entry) {
     entry[c("analysis_type", "input_hash", "payload_hash", "reproducibility_hash", "dependencies")]
@@ -181,6 +249,11 @@ analysis_release_build_tar_gz <- function(named_raw_list) {
   stopifnot(
     "named_raw_list must be a non-empty named list" = length(paths) > 0 && all(nzchar(paths))
   )
+  # Containment: refuse any path that could escape the archive root before it is
+  # written under the scratch dir with file.path(src_dir, path).
+  for (path in paths) {
+    .analysis_release_assert_safe_path(path)
+  }
   paths <- sort(paths)
 
   src_dir <- tempfile("analysis-release-src-")
diff --git a/api/functions/analysis-snapshot-release-materialize.R b/api/functions/analysis-snapshot-release-materialize.R
index 4339fb94..3fc2ef62 100644
--- a/api/functions/analysis-snapshot-release-materialize.R
+++ b/api/functions/analysis-snapshot-release-materialize.R
@@ -54,6 +54,25 @@ if (!exists("%||%", mode = "function")) {
   if (is.null(value)) default else value
 }
 
+#' Take a consistent scalar of `field` across the loaded layer manifests.
+#'
+#' Returns the single distinct non-empty value when the layers agree, else the
+#' FIRST non-NA/non-empty value (a benign provenance disagreement never blocks a
+#' build). NA when no layer carries it. Used for `db_release_version`/`_commit`.
+#' @noRd
+.analysis_release_consistent_manifest_value <- function(loaded, field) {
+  values <- vapply(
+    loaded,
+    function(e) as.character(.analysis_release_manifest_scalar(e$manifest, field, NA_character_)),
+    character(1)
+  )
+  values <- values[!is.na(values) & nzchar(values)]
+  if (length(values) == 0L) {
+    return(NA_character_)
+  }
+  values[[1]]
+}
+
 #' Coerce a possibly-NULL child tibble to a plain data.frame for serialization.
 #' @noRd
 .analysis_release_rows <- function(x) {
@@ -282,6 +301,9 @@ analysis_snapshot_release_assert_coherent <- function(snapshot, kind) {
 #' Assemble one materialized artifact with its own sha256 + byte_size.
 #' @noRd
 .analysis_release_artifact <- function(path, bytes, media_type) {
+  # Every materialized file path flows through here — assert containment at this
+  # single choke point (defense-in-depth alongside analysis_release_build_tar_gz).
+  .analysis_release_assert_safe_path(path)
   list(
     path = path,
     bytes = bytes,
diff --git a/api/functions/analysis-snapshot-release.R b/api/functions/analysis-snapshot-release.R
index 6f504dca..1a52641e 100644
--- a/api/functions/analysis-snapshot-release.R
+++ b/api/functions/analysis-snapshot-release.R
@@ -94,6 +94,29 @@ if (!exists("%||%", mode = "function")) {
   invisible(TRUE)
 }
 
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
 #' Fresh pre-insert re-read: re-load each layer via the loader seam (NOT the
 #' cached step-1 `loaded`) and confirm each layer's {snapshot_id, payload_hash}
 #' and the correlation dependencies still equal the pinned lineage. Throws a
@@ -155,11 +178,16 @@ if (!exists("%||%", mode = "function")) {
 #' @param publish If TRUE the inserted draft is flipped to `published`.
 #' @param created_by Optional user id recorded on the head row.
 #' @param conn A real DBIConnection (required for persistence; A5 checks one out).
-#' @param loader,reproducibility_loader,coherence_assert Injectable seams (see file
-#'   header); call-time defaults are the real functions.
+#' @param layers Optional SELECTION of layers to include (NULL = full registry);
+#'   resolved to authoritative registry entries by
+#'   `analysis_snapshot_release_resolve_layers()` (caller cannot override policy).
+#' @param loader,reproducibility_loader,coherence_assert,lock_acquire,inserter
+#'   Injectable seams (see file header); call-time defaults are the real
+#'   functions. `lock_acquire` returns `list(ok, acquired, skipped)`; `inserter`
+#'   persists the head/members/files.
 #' @return `list(release = <head>, created = TRUE|FALSE)`.
 #' @export
-analysis_snapshot_release_build <- function(layers = analysis_snapshot_release_layers(),
+analysis_snapshot_release_build <- function(layers = NULL,
                                             title = NULL,
                                             scope_statement = NULL,
                                             license = "CC-BY-4.0",
@@ -168,7 +196,14 @@ analysis_snapshot_release_build <- function(layers = analysis_snapshot_release_l
                                             conn = NULL,
                                             loader = analysis_snapshot_get_public,
                                             reproducibility_loader = analysis_snapshot_get_reproducibility,
-                                            coherence_assert = analysis_snapshot_release_assert_coherent) {
+                                            coherence_assert = analysis_snapshot_release_assert_coherent,
+                                            lock_acquire = .analysis_release_acquire_preset_locks,
+                                            inserter = analysis_release_insert) {
+  # B1: a caller `layers` request is a SELECTION, never a policy redefinition —
+  # resolve each selector to the AUTHORITATIVE registry entry (params /
+  # files_prefix / has_reproducibility come from the registry, never the caller).
+  layers <- analysis_snapshot_release_resolve_layers(layers)
+
   # Resolve (analysis_type, parameter_hash) per layer once (pure; validates params).
   layer_specs <- lapply(layers, function(layer) {
     at <- as.character(layer$analysis_type[[1]])
@@ -179,23 +214,29 @@ analysis_snapshot_release_build <- function(layers = analysis_snapshot_release_l
     )
   })
 
-  # --- Step 0: per-preset TOCTOU advisory locks (best-effort) --------------
+  # --- Step 0: per-preset TOCTOU advisory locks ----------------------------
   # Acquire the SAME per-preset lock the axis refresh holds, so a mid-flight
-  # refresh of a source preset serializes against this read. Released on exit.
-  if (inherits(conn, "DBIConnection")) {
-    acquired_locks <- character(0)
-    for (spec in layer_specs) {
-      lock_name <- .analysis_release_preset_lock_name(spec$analysis_type, spec$parameter_hash)
-      if (.analysis_release_get_lock(conn, lock_name, 5L)) {
-        acquired_locks <- c(acquired_locks, lock_name)
-      }
-    }
-    if (length(acquired_locks) > 0L) {
-      on.exit(
-        for (lock_name in acquired_locks) .analysis_release_release_named_lock(conn, lock_name),
-        add = TRUE
-      )
-    }
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
   }
 
   # --- Step 1/1b/1c: load + gate each layer --------------------------------
@@ -272,6 +313,11 @@ analysis_snapshot_release_build <- function(layers = analysis_snapshot_release_l
     loaded, function(e) as.character(e$source_data_version), character(1)
   ))[[1]]
 
+  # M1: DB release provenance — carried on each pinned snapshot manifest. Take a
+  # consistent value across layers (assert equal; else the first non-NA/non-empty).
+  shared_db_release_version <- .analysis_release_consistent_manifest_value(loaded, "db_release_version")
+  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit")
+
   # For the correlation layer, pin the actual dependency lineage into its entry.
   corr <- loaded[["phenotype_functional_correlations"]]
   if (!is.null(corr)) {
@@ -295,6 +341,21 @@ analysis_snapshot_release_build <- function(layers = analysis_snapshot_release_l
 
     if (isTRUE(layer$has_reproducibility)) {
       repro_bytes <- charToRaw(analysis_reproducibility_decode_raw(entry$reproducibility_bundle))
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
       artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
         paste0(prefix, "/reproducibility.json"), repro_bytes, "application/json"
       )
@@ -360,6 +421,10 @@ analysis_snapshot_release_build <- function(layers = analysis_snapshot_release_l
     ),
     source = list(
       source_data_version = shared_source_version,
+      db_release = list(
+        version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
+        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
+      ),
       snapshots = lapply(layer_entries, function(e) {
         list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
       })
@@ -406,6 +471,8 @@ analysis_snapshot_release_build <- function(layers = analysis_snapshot_release_l
     bundle_sha256 = bundle_sha256,
     bundle_gzip = bundle_gzip,
     source_data_version = shared_source_version,
+    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
+    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
     scope_statement = scope_statement,
     license = license %||% "CC-BY-4.0",
     created_by_user_id = created_by
@@ -434,7 +501,33 @@ analysis_snapshot_release_build <- function(layers = analysis_snapshot_release_l
     )
   })
 
-  analysis_release_insert(release_head, members, insert_files, conn)
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
   if (isTRUE(publish)) {
     analysis_release_publish(release_id, conn = conn)
   }
commit f522428564dccbe6ea5439124c6663ff13d955e0
Author:     Bernt Popp <bernt.popp@gmail.com>
AuthorDate: Sat Jul 18 21:59:24 2026 +0200
Commit:     Bernt Popp <bernt.popp@gmail.com>
CommitDate: Sat Jul 18 21:59:24 2026 +0200

    fix(api): release public-surface hardening — head projection, 503 lock path, pagination clamp, prune guard (#573)
    
    Codex DO-NOT-SHIP fixes on the public/service surface (H1/H3-service/L1/WB-M1).
    
    H1 (HIGH): public GET /releases /latest /<id> no longer leak operational
    columns. analysis_release_public_head() projects to an explicit allowlist
    (drops created_by_user_id, last_error_message, updated_at) and groups the DOI
    fields under `zenodo`; public-safe derived members (layers, parsed manifest)
    are preserved. Applied in the PUBLIC getters svc_release_list/get only; the
    admin path keeps the raw head.
    
    H3 (HIGH, service side): svc_release_build special-cases release_lock_unavailable
    -> 503 + Retry-After (a transient 'sources mid-refresh', NOT a 400), mirroring
    the public capacity guard (no 5xx classed-error helper exists).
    
    L1 (LOW): svc_release_list clamps limit to [1,100] and offset to >=0
    (non-numeric -> defaults) — the single source of the public pagination clamp.
    
    WB-M1: analysis_snapshot_prune() exists()-guards the cross-file
    analysis_release_referenced_snapshot_ids() call for mirai-pool parity.
    
    Claude-Session: https://claude.ai/code/session_01Shab9CYtSFmHhb7yzqBGNn

diff --git a/api/functions/analysis-snapshot-release-repository.R b/api/functions/analysis-snapshot-release-repository.R
index e4b0729e..4888fc71 100644
--- a/api/functions/analysis-snapshot-release-repository.R
+++ b/api/functions/analysis-snapshot-release-repository.R
@@ -188,6 +188,49 @@ analysis_release_insert <- function(release_head, members = list(), files = list
   release_id
 }
 
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
 # --------------------------------------------------------------------------- #
 # Read
 # --------------------------------------------------------------------------- #
diff --git a/api/functions/analysis-snapshot-repository.R b/api/functions/analysis-snapshot-repository.R
index b58a1ded..9638d127 100644
--- a/api/functions/analysis-snapshot-repository.R
+++ b/api/functions/analysis-snapshot-repository.R
@@ -581,7 +581,13 @@ analysis_snapshot_prune <- function(analysis_type,
   # Never prune a snapshot a release (#573) still references (its LIVE
   # reproducibility endpoint would 503). analysis_release_referenced_snapshot_ids()
   # is the single source of truth for this -- do not inline a NOT IN subquery.
-  referenced_ids <- as.numeric(analysis_release_referenced_snapshot_ids(conn = conn))
+  # exists()-guarded for mirai-pool parity (the release repository file is not
+  # sourced on the legacy mirai worker), mirroring the lock-name guard.
+  referenced_ids <- if (exists("analysis_release_referenced_snapshot_ids", mode = "function")) {
+    as.numeric(analysis_release_referenced_snapshot_ids(conn = conn))
+  } else {
+    numeric()
+  }
 
   delete_ids <- setdiff(as.numeric(candidates$snapshot_id %||% numeric()), union(keep_ids, referenced_ids))
   if (length(delete_ids) == 0L) {
diff --git a/api/services/analysis-snapshot-release-service.R b/api/services/analysis-snapshot-release-service.R
index d4134c9e..0e6bca72 100644
--- a/api/services/analysis-snapshot-release-service.R
+++ b/api/services/analysis-snapshot-release-service.R
@@ -89,6 +89,17 @@ svc_release_build <- function(res,
 
   result <- tryCatch(
     do.call(analysis_snapshot_release_build, build_args),
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
     release_snapshot_not_available = function(e) stop_for_bad_request(conditionMessage(e)),
     release_source_incoherent = function(e) stop_for_bad_request(conditionMessage(e)),
     release_reproducibility_missing = function(e) stop_for_bad_request(conditionMessage(e)),
@@ -96,6 +107,11 @@ svc_release_build <- function(res,
     release_dependency_lineage_mismatch = function(e) stop_for_bad_request(conditionMessage(e))
   )
 
+  # The 503 handler already set res$status + body; return it verbatim.
+  if (!is.null(res$status) && identical(as.integer(res$status), 503L)) {
+    return(result)
+  }
+
   res$status <- if (isTRUE(result$created)) 201L else 200L
   result$release
 }
@@ -169,13 +185,41 @@ svc_release_delete_draft <- function(release_id, conn = NULL) {
 
 #' List published releases (newest first).
 #'
-#' @param limit,offset Pagination.
+#' `limit` is clamped to `[1, 100]` and `offset` to `>= 0` (L1: public
+#' pagination must never be unbounded or negative — this is the single source of
+#' the clamp). Each returned head is projected to the PUBLIC allowlist
+#' (`analysis_release_public_head`) so operational columns never leak.
+#'
+#' @param limit,offset Pagination (clamped).
 #' @param conn A real DBIConnection.
-#' @return Whatever shape `analysis_release_list()` returns (a list of
-#'   release-head-plus-layers entries); never includes drafts.
+#' @return A list of public-projected release-head-plus-layers entries; never
+#'   includes drafts.
 #' @export
 svc_release_list <- function(limit = 50, offset = 0, conn = NULL) {
-  analysis_release_list(status = "published", limit = limit, offset = offset, conn = conn)
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
 }
 
 #' Fetch one published release's head + parsed manifest.
@@ -193,7 +237,7 @@ svc_release_get <- function(release_id, conn = NULL) {
   if (is.null(head)) {
     stop_for_not_found("Release not found")
   }
-  head
+  analysis_release_public_head(head)
 }
 
 #' Fetch a published release's stored `manifest.json` file.

exec
/bin/bash -lc "rg -n -C 3 'analysis_snapshot_release_resolve_layers|analysis_release_assert_safe_path|analysis_release_content_digest|analysis_release_build_tar_gz' api/functions/analysis-snapshot-release-manifest.R
rg -n -C 5 'consistent_manifest_value|analysis_snapshot_release_build|lock_state|reproducibility bytes|release_head|insert_created|analysis_release_exists|analysis_release_get' api/functions/analysis-snapshot-release.R api/functions/analysis-snapshot-release-materialize.R
rg -n -C 5 'analysis_release_public_head|analysis_release_list|analysis_release_get|analysis_release_file|analysis_release_bundle|analysis_release_referenced_snapshot_ids' api/functions/analysis-snapshot-release-repository.R
rg -n -C 5 'svc_release_build|svc_release_list|svc_release_get|svc_release_manifest|svc_release_file|svc_release_bundle|svc_release_clamp' api/services/analysis-snapshot-release-service.R
rg -n -C 3 'releases|svc_release|require_role|mount' api/endpoints/analysis_endpoints.R api/endpoints/admin_analysis_snapshot_endpoints.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
6-# These functions define release IDENTITY and file contracts consumed by
7-# later tasks (repository persistence, build orchestrator). They must stay
8-# pure: no DB access, no network, no side effects beyond a scratch tempdir
9:# used internally by `analysis_release_build_tar_gz()`.
10-#
11-# Reuses the EXISTING canonical JSON serializer from
12-# `analysis-snapshot-presets.R` (`analysis_snapshot_canonical_json()`, sourced
--
63-#' @param requested NULL, or a list of selectors (strings or `{analysis_type}`).
64-#' @return list of registry layer entries (a subset of the registry, in request
65-#'   order).
66:analysis_snapshot_release_resolve_layers <- function(requested = NULL) {
67-  registry <- analysis_snapshot_release_layers()
68-  if (is.null(requested) || length(requested) == 0L) {
69-    return(registry)
--
96-#' Defense-in-depth against path traversal: rejects any path that is empty,
97-#' absolute (leading `/` or a Windows drive), contains a backslash separator, or
98-#' contains a `..` segment. Called for every materialized file path AND every
99:#' path written into the tar archive (`analysis_release_build_tar_gz`).
100-#'
101-#' @param path chr, an archive-relative file path.
102-#' @return invisibly TRUE; throws on an unsafe path.
103:.analysis_release_assert_safe_path <- function(path) {
104-  p <- as.character(path)[[1]]
105-  segments <- strsplit(p, "/", fixed = TRUE)[[1]]
106-  if (!nzchar(p) ||
--
152-#' @param source_data_version chr.
153-#' @param manifest_schema_version chr.
154-#' @return chr, a 64-character lowercase hex sha256 digest.
155:analysis_release_content_digest <- function(layer_entries, source_data_version, manifest_schema_version) {
156-  analysis_types <- vapply(layer_entries, function(entry) entry$analysis_type, character(1))
157-  # method = "radix" is locale-invariant: the content identity must not depend on
158-  # the builder's LC_COLLATE (de-risks cross-host #574 reproducibility).
--
177-#' `asr_`. This is a human/URL-facing handle only; the full content digest is
178-#' the authoritative identity value and is stored separately by later tasks.
179-#'
180:#' @param content_digest chr, as returned by `analysis_release_content_digest()`.
181-#' @return chr, matching `^asr_[0-9a-f]{16}$` for a well-formed digest.
182-analysis_release_id <- function(content_digest) {
183-  paste0("asr_", substr(content_digest, 1, 16))
--
244-#' @param named_raw_list named list of raw vectors, keyed by archive-relative
245-#'   path.
246-#' @return raw vector, the gzip-compressed tar archive bytes.
247:analysis_release_build_tar_gz <- function(named_raw_list) {
248-  paths <- names(named_raw_list)
249-  stopifnot(
250-    "named_raw_list must be a non-empty named list" = length(paths) > 0 && all(nzchar(paths))
--
252-  # Containment: refuse any path that could escape the archive root before it is
253-  # written under the scratch dir with file.path(src_dir, path).
254-  for (path in paths) {
255:    .analysis_release_assert_safe_path(path)
256-  }
257-  paths <- sort(paths)
258-
api/functions/analysis-snapshot-release-materialize.R-58-#'
api/functions/analysis-snapshot-release-materialize.R-59-#' Returns the single distinct non-empty value when the layers agree, else the
api/functions/analysis-snapshot-release-materialize.R-60-#' FIRST non-NA/non-empty value (a benign provenance disagreement never blocks a
api/functions/analysis-snapshot-release-materialize.R-61-#' build). NA when no layer carries it. Used for `db_release_version`/`_commit`.
api/functions/analysis-snapshot-release-materialize.R-62-#' @noRd
api/functions/analysis-snapshot-release-materialize.R:63:.analysis_release_consistent_manifest_value <- function(loaded, field) {
api/functions/analysis-snapshot-release-materialize.R-64-  values <- vapply(
api/functions/analysis-snapshot-release-materialize.R-65-    loaded,
api/functions/analysis-snapshot-release-materialize.R-66-    function(e) as.character(.analysis_release_manifest_scalar(e$manifest, field, NA_character_)),
api/functions/analysis-snapshot-release-materialize.R-67-    character(1)
api/functions/analysis-snapshot-release-materialize.R-68-  )
--
api/functions/analysis-snapshot-release.R-61-  # defines analysis_snapshot_lock_name() is not sourced.
api/functions/analysis-snapshot-release.R-62-  paste0("asr:", substr(as.character(parameter_hash[[1]]), 1, 56))
api/functions/analysis-snapshot-release.R-63-}
api/functions/analysis-snapshot-release.R-64-
api/functions/analysis-snapshot-release.R-65-#' @noRd
api/functions/analysis-snapshot-release.R:66:.analysis_release_get_lock <- function(conn, name, timeout_seconds = 5L) {
api/functions/analysis-snapshot-release.R-67-  if (!inherits(conn, "DBIConnection")) {
api/functions/analysis-snapshot-release.R-68-    return(FALSE)
api/functions/analysis-snapshot-release.R-69-  }
api/functions/analysis-snapshot-release.R-70-  tryCatch(
api/functions/analysis-snapshot-release.R-71-    {
--
api/functions/analysis-snapshot-release.R-105-  if (!inherits(conn, "DBIConnection")) {
api/functions/analysis-snapshot-release.R-106-    return(list(ok = TRUE, acquired = character(0), skipped = TRUE))
api/functions/analysis-snapshot-release.R-107-  }
api/functions/analysis-snapshot-release.R-108-  acquired <- character(0)
api/functions/analysis-snapshot-release.R-109-  for (lock_name in lock_names) {
api/functions/analysis-snapshot-release.R:110:    if (.analysis_release_get_lock(conn, lock_name, timeout_seconds)) {
api/functions/analysis-snapshot-release.R-111-      acquired <- c(acquired, lock_name)
api/functions/analysis-snapshot-release.R-112-    } else {
api/functions/analysis-snapshot-release.R-113-      for (held in acquired) .analysis_release_release_named_lock(conn, held)
api/functions/analysis-snapshot-release.R-114-      return(list(ok = FALSE, acquired = character(0), skipped = FALSE))
api/functions/analysis-snapshot-release.R-115-    }
--
api/functions/analysis-snapshot-release.R-185-#'   Injectable seams (see file header); call-time defaults are the real
api/functions/analysis-snapshot-release.R-186-#'   functions. `lock_acquire` returns `list(ok, acquired, skipped)`; `inserter`
api/functions/analysis-snapshot-release.R-187-#'   persists the head/members/files.
api/functions/analysis-snapshot-release.R-188-#' @return `list(release = <head>, created = TRUE|FALSE)`.
api/functions/analysis-snapshot-release.R-189-#' @export
api/functions/analysis-snapshot-release.R:190:analysis_snapshot_release_build <- function(layers = NULL,
api/functions/analysis-snapshot-release.R-191-                                            title = NULL,
api/functions/analysis-snapshot-release.R-192-                                            scope_statement = NULL,
api/functions/analysis-snapshot-release.R-193-                                            license = "CC-BY-4.0",
api/functions/analysis-snapshot-release.R-194-                                            publish = TRUE,
api/functions/analysis-snapshot-release.R-195-                                            created_by = NULL,
--
api/functions/analysis-snapshot-release.R-217-  # --- Step 0: per-preset TOCTOU advisory locks ----------------------------
api/functions/analysis-snapshot-release.R-218-  # Acquire the SAME per-preset lock the axis refresh holds, so a mid-flight
api/functions/analysis-snapshot-release.R-219-  # refresh of a source preset serializes against this read. On a REAL
api/functions/analysis-snapshot-release.R-220-  # DBIConnection a failed acquisition MUST NOT proceed unlocked (H3): it raises
api/functions/analysis-snapshot-release.R-221-  # `release_lock_unavailable`, which the service maps to 503 + Retry-After.
api/functions/analysis-snapshot-release.R:222:  # A non-DBI/test conn skips the lock (lock_state$skipped).
api/functions/analysis-snapshot-release.R-223-  lock_names <- vapply(
api/functions/analysis-snapshot-release.R-224-    layer_specs,
api/functions/analysis-snapshot-release.R-225-    function(spec) .analysis_release_preset_lock_name(spec$analysis_type, spec$parameter_hash),
api/functions/analysis-snapshot-release.R-226-    character(1)
api/functions/analysis-snapshot-release.R-227-  )
api/functions/analysis-snapshot-release.R:228:  lock_state <- lock_acquire(conn, lock_names)
api/functions/analysis-snapshot-release.R:229:  if (length(lock_state$acquired %||% character(0)) > 0L) {
api/functions/analysis-snapshot-release.R-230-    on.exit(
api/functions/analysis-snapshot-release.R:231:      for (lock_name in lock_state$acquired) .analysis_release_release_named_lock(conn, lock_name),
api/functions/analysis-snapshot-release.R-232-      add = TRUE
api/functions/analysis-snapshot-release.R-233-    )
api/functions/analysis-snapshot-release.R-234-  }
api/functions/analysis-snapshot-release.R:235:  if (!isTRUE(lock_state$ok)) {
api/functions/analysis-snapshot-release.R-236-    stop(.analysis_release_condition(
api/functions/analysis-snapshot-release.R-237-      "release_lock_unavailable",
api/functions/analysis-snapshot-release.R-238-      "source analysis snapshots are being refreshed; retry the release build shortly"
api/functions/analysis-snapshot-release.R-239-    ))
api/functions/analysis-snapshot-release.R-240-  }
--
api/functions/analysis-snapshot-release.R-313-    loaded, function(e) as.character(e$source_data_version), character(1)
api/functions/analysis-snapshot-release.R-314-  ))[[1]]
api/functions/analysis-snapshot-release.R-315-
api/functions/analysis-snapshot-release.R-316-  # M1: DB release provenance — carried on each pinned snapshot manifest. Take a
api/functions/analysis-snapshot-release.R-317-  # consistent value across layers (assert equal; else the first non-NA/non-empty).
api/functions/analysis-snapshot-release.R:318:  shared_db_release_version <- .analysis_release_consistent_manifest_value(loaded, "db_release_version")
api/functions/analysis-snapshot-release.R:319:  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit")
api/functions/analysis-snapshot-release.R-320-
api/functions/analysis-snapshot-release.R-321-  # For the correlation layer, pin the actual dependency lineage into its entry.
api/functions/analysis-snapshot-release.R-322-  corr <- loaded[["phenotype_functional_correlations"]]
api/functions/analysis-snapshot-release.R-323-  if (!is.null(corr)) {
api/functions/analysis-snapshot-release.R-324-    loaded[["phenotype_functional_correlations"]]$dependencies <-
--
api/functions/analysis-snapshot-release.R-348-      computed_repro_hash <- analysis_release_sha256(repro_bytes)
api/functions/analysis-snapshot-release.R-349-      if (!identical(computed_repro_hash, entry$reproducibility_hash)) {
api/functions/analysis-snapshot-release.R-350-        stop(.analysis_release_condition(
api/functions/analysis-snapshot-release.R-351-          "release_reproducibility_missing",
api/functions/analysis-snapshot-release.R-352-          sprintf(
api/functions/analysis-snapshot-release.R:353:            "layer %s reproducibility bytes do not hash to the stored reproducibility_hash (bundle corrupt)",
api/functions/analysis-snapshot-release.R-354-            at
api/functions/analysis-snapshot-release.R-355-          ),
api/functions/analysis-snapshot-release.R-356-          analysis_type = at
api/functions/analysis-snapshot-release.R-357-        ))
api/functions/analysis-snapshot-release.R-358-      }
--
api/functions/analysis-snapshot-release.R-377-  content_digest <- analysis_release_content_digest(
api/functions/analysis-snapshot-release.R-378-    layer_entries, shared_source_version, ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION
api/functions/analysis-snapshot-release.R-379-  )
api/functions/analysis-snapshot-release.R-380-  release_id <- analysis_release_id(content_digest)
api/functions/analysis-snapshot-release.R-381-
api/functions/analysis-snapshot-release.R:382:  if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
api/functions/analysis-snapshot-release.R:383:    existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/functions/analysis-snapshot-release.R-384-    if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
api/functions/analysis-snapshot-release.R-385-      return(list(release = existing, created = FALSE))
api/functions/analysis-snapshot-release.R-386-    }
api/functions/analysis-snapshot-release.R-387-    stop(sprintf(
api/functions/analysis-snapshot-release.R-388-      "release id %s already exists with a different content_digest (identity anomaly)",
--
api/functions/analysis-snapshot-release.R-459-  # with the per-preset locks above, this closes the TOCTOU window.
api/functions/analysis-snapshot-release.R-460-  .analysis_release_assert_lineage(loaded)
api/functions/analysis-snapshot-release.R-461-  .analysis_release_verify_lineage_unchanged(layer_specs, loaded, loader, conn)
api/functions/analysis-snapshot-release.R-462-
api/functions/analysis-snapshot-release.R-463-  # --- Step 10: persist ----------------------------------------------------
api/functions/analysis-snapshot-release.R:464:  release_head <- list(
api/functions/analysis-snapshot-release.R-465-    release_id = release_id,
api/functions/analysis-snapshot-release.R-466-    release_version = NULL,
api/functions/analysis-snapshot-release.R-467-    title = title,
api/functions/analysis-snapshot-release.R-468-    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
api/functions/analysis-snapshot-release.R-469-    content_digest = content_digest,
--
api/functions/analysis-snapshot-release.R-503-
api/functions/analysis-snapshot-release.R-504-  # H3(b): a concurrent identical build can win the insert race (both passed the
api/functions/analysis-snapshot-release.R-505-  # step-6 idempotency probe). On a DB duplicate-key error, re-read by release_id:
api/functions/analysis-snapshot-release.R-506-  # if the stored content_digest matches, this build is a no-op (idempotent 200);
api/functions/analysis-snapshot-release.R-507-  # otherwise it is a genuine identity anomaly (re-raise -> 500).
api/functions/analysis-snapshot-release.R:508:  insert_created <- tryCatch(
api/functions/analysis-snapshot-release.R-509-    {
api/functions/analysis-snapshot-release.R:510:      inserter(release_head, members, insert_files, conn)
api/functions/analysis-snapshot-release.R-511-      TRUE
api/functions/analysis-snapshot-release.R-512-    },
api/functions/analysis-snapshot-release.R-513-    error = function(e) {
api/functions/analysis-snapshot-release.R:514:      if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
api/functions/analysis-snapshot-release.R:515:        existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/functions/analysis-snapshot-release.R-516-        if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
api/functions/analysis-snapshot-release.R-517-          return(FALSE) # idempotent: the concurrent winner stored the identical release
api/functions/analysis-snapshot-release.R-518-        }
api/functions/analysis-snapshot-release.R-519-      }
api/functions/analysis-snapshot-release.R-520-      stop(e)
api/functions/analysis-snapshot-release.R-521-    }
api/functions/analysis-snapshot-release.R-522-  )
api/functions/analysis-snapshot-release.R-523-
api/functions/analysis-snapshot-release.R:524:  if (!isTRUE(insert_created)) {
api/functions/analysis-snapshot-release.R-525-    return(list(
api/functions/analysis-snapshot-release.R:526:      release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
api/functions/analysis-snapshot-release.R-527-      created = FALSE
api/functions/analysis-snapshot-release.R-528-    ))
api/functions/analysis-snapshot-release.R-529-  }
api/functions/analysis-snapshot-release.R-530-
api/functions/analysis-snapshot-release.R-531-  if (isTRUE(publish)) {
api/functions/analysis-snapshot-release.R-532-    analysis_release_publish(release_id, conn = conn)
api/functions/analysis-snapshot-release.R-533-  }
api/functions/analysis-snapshot-release.R-534-
api/functions/analysis-snapshot-release.R-535-  list(
api/functions/analysis-snapshot-release.R:536:    release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
api/functions/analysis-snapshot-release.R-537-    created = TRUE
api/functions/analysis-snapshot-release.R-538-  )
api/functions/analysis-snapshot-release.R-539-}
55-  as.character(x[[1]])
56-}
57-
58-#' Head-table column list shared by SELECTs (excludes the `bundle_gzip` blob
59-#' so metadata reads never pull the multi-MB bundle unless explicitly asked
60:#' for via `analysis_release_get_bundle()`).
61-#' @noRd
62-.analysis_release_head_columns <- paste(
63-  "release_id, release_version, title, status, manifest_schema_version,",
64-  "content_digest, manifest_sha256, bundle_sha256, bundle_bytes,",
65-  "source_data_version, db_release_version, db_release_commit, scope_statement,",
--
196-#'
197-#' The raw head carries operational columns — `created_by_user_id`,
198-#' `last_error_message`, `updated_at` — that must never reach the public
199-#' list/detail/latest surface. This projects to an explicit allowlist and groups
200-#' the DOI fields under `zenodo`. Public-safe derived members (`layers` from
201:#' `analysis_release_list()`, the parsed `manifest` from `analysis_release_get()`)
202-#' are carried through when present. The ADMIN surface keeps the raw head.
203-#'
204-#' @param head A named list (a raw head from the repository read functions), or NULL.
205-#' @return The projected named list, or NULL when `head` is NULL.
206-#' @export
207:analysis_release_public_head <- function(head) {
208-  if (is.null(head)) {
209-    return(NULL)
210-  }
211-  nullify <- function(x) if (is.null(x) || (length(x) == 1L && is.na(x))) NULL else x
212-
--
243-#'
244-#' @return A named list (head columns + `$manifest`, the parsed manifest.json
245-#'   as a plain R list via `jsonlite::fromJSON(simplifyVector = FALSE)`), or
246-#'   `NULL` if no matching (visible) row exists.
247-#' @export
248:analysis_release_get <- function(release_id, include_draft = FALSE, conn) {
249-  status_clause <- if (isTRUE(include_draft)) "" else " AND status = 'published'"
250-  sql <- paste0(
251-    "SELECT ", .analysis_release_head_columns, "
252-       FROM analysis_snapshot_release
253-      WHERE release_id = ?", status_clause, "
--
258-    return(NULL)
259-  }
260-
261-  head <- .analysis_release_row_to_list(rows)
262-
263:  manifest_file <- analysis_release_get_file(
264-    release_id, "manifest.json",
265-    include_draft = include_draft, conn = conn
266-  )
267-  head$manifest <- if (is.null(manifest_file)) {
268-    NULL
--
283-#'
284-#' @return A list of named lists (head columns + `$layers`, a list of
285-#'   `list(analysis_type, snapshot_id, payload_hash)` for `role = 'layer'`
286-#'   members). Empty list if no rows match.
287-#' @export
288:analysis_release_list <- function(status = "published", limit = 50L, offset = 0L, conn) {
289-  where_clause <- ""
290-  params <- list()
291-  if (!is.null(status)) {
292-    where_clause <- " WHERE status = ?"
293-    params <- list(as.character(status))
--
339-#' `status`, applied before any blob is fetched).
340-#'
341-#' @return `list(bytes = <raw, decompressed>, media_type = chr,
342-#'   content_sha256 = chr)`, or `NULL` if no matching (visible) row exists.
343-#' @export
344:analysis_release_get_file <- function(release_id, file_path, include_draft = FALSE, conn) {
345-  status_clause <- if (isTRUE(include_draft)) "" else " AND r.status = 'published'"
346-  sql <- paste0(
347-    "SELECT f.content_gzip, f.media_type, f.content_sha256
348-       FROM analysis_snapshot_release_file f
349-       JOIN analysis_snapshot_release r ON r.release_id = f.release_id
--
367-}
368-
369-#' Fetch the whole release archive (`bundle_gzip`) verbatim.
370-#'
371-#' `bundle_gzip` is stored already-gzipped and served as-is — this does NOT
372:#' decompress it (unlike `analysis_release_get_file()`, which stores each
373-#' file's gzip as a transport-only encoding of JSON content). Draft releases
374-#' are hidden unless `include_draft = TRUE`, filtered in SQL.
375-#'
376-#' @return `list(bytes = <raw, verbatim gzip tar>, sha256 = chr, filename =
377-#'   "<release_id>.tar.gz")`, or `NULL` if no matching (visible) row exists.
378-#' @export
379:analysis_release_get_bundle <- function(release_id, include_draft = FALSE, conn) {
380-  status_clause <- if (isTRUE(include_draft)) "" else " AND status = 'published'"
381-  sql <- paste0(
382-    "SELECT bundle_gzip, bundle_sha256
383-       FROM analysis_snapshot_release
384-      WHERE release_id = ?", status_clause, "
--
410-
411-#' Distinct snapshot ids referenced by any release member (the later prune
412-#' guard uses this to never delete a snapshot a release still points to).
413-#' @return integer vector (possibly empty).
414-#' @export
415:analysis_release_referenced_snapshot_ids <- function(conn) {
416-  rows <- DBI::dbGetQuery(
417-    conn,
418-    "SELECT DISTINCT snapshot_id FROM analysis_snapshot_release_member"
419-  )
420-  as.integer(rows$snapshot_id)
14-# is a 400, not a conflict. The mounted errorHandler (`core/filters.R`)
15-# serializes `conditionMessage(err)` (the classed condition's `message`) into
16-# the problem+json body, NOT `detail` — so every user-facing reason is passed
17-# as the `message` argument to `stop_for_*()`, never `detail`.
18-#
19:# BUILD MAPPING. `svc_release_build()` calls the A4 orchestrator inside a
20-# `tryCatch()` that maps its five classed `release_*` conditions
21-# (`release_snapshot_not_available`, `release_source_incoherent`,
22-# `release_reproducibility_missing`, `release_source_version_mismatch`,
23-# `release_dependency_lineage_mismatch`) to `stop_for_bad_request()`, passing
24-# the ORIGINAL `conditionMessage()` through verbatim (it already names the
25-# failing layer/analysis_type and the concrete reason). Any OTHER error is
26-# left to propagate unmapped (falls through to the generic 500 path). A
27-# DUPLICATE/idempotent build (`created = FALSE`) is NOT an error: the caller
28-# gets 200 + the existing head instead of 201 + the new head.
29-#
30:# PUBLIC SURFACE. `svc_release_list/get/manifest/file/bundle()` are the
31-# published-only public read surface: every repository call is pinned to
32-# `status = "published"` / `include_draft = FALSE`, so a draft release (or an
33-# unknown release id, or an unknown archive file path) is indistinguishable
34-# from the caller's point of view — both resolve to a plain 404. Drafts are
35-# NEVER returned publicly.
36-#
37:# ADMIN SURFACE. `svc_release_build/publish/set_doi/delete_draft()` are
38-# admin-only from the caller's perspective (the endpoint layer is expected to
39-# gate with `require_role(req, res, "Administrator")` before calling in, the
40-# same pattern as the other `svc_*` admin services in this directory); this
41-# file does not itself check roles.
42-#
--
65-#' @param publish Whether to flip the inserted draft to `published`.
66-#' @param created_by Optional user id recorded on the head row.
67-#' @param conn A real DBIConnection (the orchestrator persists via A3).
68-#' @return The release head (a named list).
69-#' @export
70:svc_release_build <- function(res,
71-                               layers = NULL,
72-                               title = NULL,
73-                               scope_statement = NULL,
74-                               license = "CC-BY-4.0",
75-                               publish = TRUE,
--
193-#' @param limit,offset Pagination (clamped).
194-#' @param conn A real DBIConnection.
195-#' @return A list of public-projected release-head-plus-layers entries; never
196-#'   includes drafts.
197-#' @export
198:svc_release_list <- function(limit = 50, offset = 0, conn = NULL) {
199:  limit <- svc_release_clamp_limit(limit)
200:  offset <- svc_release_clamp_offset(offset)
201-  rows <- analysis_release_list(status = "published", limit = limit, offset = offset, conn = conn)
202-  lapply(rows, analysis_release_public_head)
203-}
204-
205-#' Clamp a public list `limit` into `[1, 100]` (non-numeric -> default 50).
206-#' @noRd
207:svc_release_clamp_limit <- function(limit) {
208-  value <- suppressWarnings(as.integer(limit))
209-  if (length(value) == 0L || is.na(value)) {
210-    value <- 50L
211-  }
212-  min(100L, max(1L, value))
213-}
214-
215-#' Clamp a public list `offset` to `>= 0` (non-numeric -> 0).
216-#' @noRd
217:svc_release_clamp_offset <- function(offset) {
218-  value <- suppressWarnings(as.integer(offset))
219-  if (length(value) == 0L || is.na(value)) {
220-    value <- 0L
221-  }
222-  max(0L, value)
--
230-#'
231-#' @param release_id Release id.
232-#' @param conn A real DBIConnection.
233-#' @return The release head (+ `$manifest`).
234-#' @export
235:svc_release_get <- function(release_id, conn = NULL) {
236-  head <- analysis_release_get(release_id, include_draft = FALSE, conn = conn)
237-  if (is.null(head)) {
238-    stop_for_not_found("Release not found")
239-  }
240-  analysis_release_public_head(head)
--
244-#'
245-#' @param release_id Release id.
246-#' @param conn A real DBIConnection.
247-#' @return `list(bytes, media_type = "application/json", content_sha256)`.
248-#' @export
249:svc_release_manifest <- function(release_id, conn = NULL) {
250-  file <- analysis_release_get_file(release_id, "manifest.json", include_draft = FALSE, conn = conn)
251-  if (is.null(file)) {
252-    stop_for_not_found("Release not found")
253-  }
254-  list(bytes = file$bytes, media_type = "application/json", content_sha256 = file$content_sha256)
--
263-#' @param file_path Exact archive-relative path (e.g. `"README.md"`,
264-#'   `"functional_clusters/payload.json"`).
265-#' @param conn A real DBIConnection.
266-#' @return `list(bytes, media_type, content_sha256)`.
267-#' @export
268:svc_release_file <- function(release_id, file_path, conn = NULL) {
269-  file <- analysis_release_get_file(release_id, file_path, include_draft = FALSE, conn = conn)
270-  if (is.null(file)) {
271-    stop_for_not_found(sprintf("Release file not found: %s", file_path))
272-  }
273-  list(bytes = file$bytes, media_type = file$media_type, content_sha256 = file$content_sha256)
--
277-#'
278-#' @param release_id Release id.
279-#' @param conn A real DBIConnection.
280-#' @return `list(bytes, sha256, filename)`.
281-#' @export
282:svc_release_bundle <- function(release_id, conn = NULL) {
283-  bundle <- analysis_release_get_bundle(release_id, include_draft = FALSE, conn = conn)
284-  if (is.null(bundle)) {
285-    stop_for_not_found("Release not found")
286-  }
287-  list(bytes = bundle$bytes, sha256 = bundle$sha256, filename = bundle$filename)
api/endpoints/admin_analysis_snapshot_endpoints.R-15-# content-addressed public analysis-snapshot RELEASES: build/list/detail/
api/endpoints/admin_analysis_snapshot_endpoints.R-16-# publish/record-DOI/delete-draft. The mutating routes (build, publish, set
api/endpoints/admin_analysis_snapshot_endpoints.R-17-# DOI, delete draft) thinly delegate to the A5 service layer
api/endpoints/admin_analysis_snapshot_endpoints.R:18:# (services/analysis-snapshot-release-service.R, `svc_release_*`); the two
api/endpoints/admin_analysis_snapshot_endpoints.R-19-# admin READS that must see DRAFT rows call the A3 repository
api/endpoints/admin_analysis_snapshot_endpoints.R-20-# (functions/analysis-snapshot-release-repository.R) directly with
api/endpoints/admin_analysis_snapshot_endpoints.R-21-# `include_draft = TRUE` / `status = NULL` -- the sibling
api/endpoints/admin_analysis_snapshot_endpoints.R:22:# svc_release_list()/svc_release_get() in the service layer are
api/endpoints/admin_analysis_snapshot_endpoints.R-23-# PUBLISHED-ONLY by design (the public routes in analysis_endpoints.R use
api/endpoints/admin_analysis_snapshot_endpoints.R-24-# those), so this file bypasses them for the two admin listings. The service
api/endpoints/admin_analysis_snapshot_endpoints.R-25-# file and the four release function files are wired into
--
api/endpoints/admin_analysis_snapshot_endpoints.R-45-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-46-#* @post /snapshots/refresh
api/endpoints/admin_analysis_snapshot_endpoints.R-47-function(req, res, analysis_type = NULL, force = FALSE) {
api/endpoints/admin_analysis_snapshot_endpoints.R:48:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-49-
api/endpoints/admin_analysis_snapshot_endpoints.R-50-  at <- if (is.null(analysis_type) || !nzchar(as.character(analysis_type[[1]]))) {
api/endpoints/admin_analysis_snapshot_endpoints.R-51-    NULL
--
api/endpoints/admin_analysis_snapshot_endpoints.R-74-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-75-#* @get /snapshots/status
api/endpoints/admin_analysis_snapshot_endpoints.R-76-function(req, res) {
api/endpoints/admin_analysis_snapshot_endpoints.R:77:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-78-  service_analysis_snapshot_status()
api/endpoints/admin_analysis_snapshot_endpoints.R-79-}
api/endpoints/admin_analysis_snapshot_endpoints.R-80-
--
api/endpoints/admin_analysis_snapshot_endpoints.R-86-#' = FALSE)`, NOT Plumber's default `req$argsBody` (`plumber:::safeFromJSON`,
api/endpoints/admin_analysis_snapshot_endpoints.R-87-#' which parses with `simplifyVector = TRUE`).
api/endpoints/admin_analysis_snapshot_endpoints.R-88-#'
api/endpoints/admin_analysis_snapshot_endpoints.R:89:#' This matters specifically for `POST /releases`'s optional `layers` array
api/endpoints/admin_analysis_snapshot_endpoints.R-90-#' override. Verified live: `simplifyVector = TRUE` collapses a JSON array of
api/endpoints/admin_analysis_snapshot_endpoints.R-91-#' layer-override objects into a *data.frame* -- and a nested object field
api/endpoints/admin_analysis_snapshot_endpoints.R-92-#' (e.g. `params`) collapses into its OWN nested data.frame column when every
--
api/endpoints/admin_analysis_snapshot_endpoints.R-102-#' `analysis_snapshot_release_layers()` itself returns (each layer's `params`
api/endpoints/admin_analysis_snapshot_endpoints.R-103-#' comes back as a genuine named list too), so a caller-supplied `layers`
api/endpoints/admin_analysis_snapshot_endpoints.R-104-#' override needs no further normalization before being forwarded to
api/endpoints/admin_analysis_snapshot_endpoints.R:105:#' `svc_release_build()`. `req$postBody` is populated by Plumber's default
api/endpoints/admin_analysis_snapshot_endpoints.R-106-#' `bodyFilter` for every request with a body, independent of any `@parser`
api/endpoints/admin_analysis_snapshot_endpoints.R-107-#' annotation on this route.
api/endpoints/admin_analysis_snapshot_endpoints.R-108-#'
--
api/endpoints/admin_analysis_snapshot_endpoints.R-121-#' Defensively parse a query-string integer with a default.
api/endpoints/admin_analysis_snapshot_endpoints.R-122-#'
api/endpoints/admin_analysis_snapshot_endpoints.R-123-#' A file-local duplicate of the identically-named helper in
api/endpoints/admin_analysis_snapshot_endpoints.R:124:#' `endpoints/analysis_endpoints.R`: each endpoints file is mounted as its
api/endpoints/admin_analysis_snapshot_endpoints.R-125-#' OWN Plumber sub-router / environment (`plumber::pr(file)`), so a top-level
api/endpoints/admin_analysis_snapshot_endpoints.R-126-#' helper defined in a sibling endpoints file is not visible here.
api/endpoints/admin_analysis_snapshot_endpoints.R-127-#'
--
api/endpoints/admin_analysis_snapshot_endpoints.R-154-#* @tag admin
api/endpoints/admin_analysis_snapshot_endpoints.R-155-#* @serializer unboxedJSON
api/endpoints/admin_analysis_snapshot_endpoints.R-156-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:157:#* @post /releases
api/endpoints/admin_analysis_snapshot_endpoints.R-158-function(req, res) {
api/endpoints/admin_analysis_snapshot_endpoints.R:159:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-160-
api/endpoints/admin_analysis_snapshot_endpoints.R-161-  body <- .admin_release_parse_json_body(req)
api/endpoints/admin_analysis_snapshot_endpoints.R-162-  publish_flag <- if (is.null(body$publish)) TRUE else isTRUE(body$publish)
--
api/endpoints/admin_analysis_snapshot_endpoints.R-171-  conn <- pool::poolCheckout(pool)
api/endpoints/admin_analysis_snapshot_endpoints.R-172-  on.exit(pool::poolReturn(conn), add = TRUE)
api/endpoints/admin_analysis_snapshot_endpoints.R-173-
api/endpoints/admin_analysis_snapshot_endpoints.R:174:  svc_release_build(
api/endpoints/admin_analysis_snapshot_endpoints.R-175-    res,
api/endpoints/admin_analysis_snapshot_endpoints.R-176-    layers = body$layers,
api/endpoints/admin_analysis_snapshot_endpoints.R-177-    title = body$title,
--
api/endpoints/admin_analysis_snapshot_endpoints.R-183-  )
api/endpoints/admin_analysis_snapshot_endpoints.R-184-}
api/endpoints/admin_analysis_snapshot_endpoints.R-185-
api/endpoints/admin_analysis_snapshot_endpoints.R:186:#* List ALL analysis-snapshot releases, including drafts (Administrator only)
api/endpoints/admin_analysis_snapshot_endpoints.R-187-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:188:#* Unlike the public `GET /api/analysis/releases` (published-only, see
api/endpoints/admin_analysis_snapshot_endpoints.R:189:#* `svc_release_list()`), this admin listing includes draft rows so an
api/endpoints/admin_analysis_snapshot_endpoints.R-190-#* operator can see an in-progress/failed build before it is published or
api/endpoints/admin_analysis_snapshot_endpoints.R-191-#* deleted.
api/endpoints/admin_analysis_snapshot_endpoints.R-192-#*
--
api/endpoints/admin_analysis_snapshot_endpoints.R-196-#* @param limit:int Optional page size. Default 50.
api/endpoints/admin_analysis_snapshot_endpoints.R-197-#* @param offset:int Optional page offset. Default 0.
api/endpoints/admin_analysis_snapshot_endpoints.R-198-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:199:#* @get /releases
api/endpoints/admin_analysis_snapshot_endpoints.R-200-function(req, res, limit = NULL, offset = NULL) {
api/endpoints/admin_analysis_snapshot_endpoints.R:201:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-202-
api/endpoints/admin_analysis_snapshot_endpoints.R-203-  limit_int <- .admin_release_query_int(limit, 50L)
api/endpoints/admin_analysis_snapshot_endpoints.R-204-  offset_int <- .admin_release_query_int(offset, 0L)
api/endpoints/admin_analysis_snapshot_endpoints.R:205:  releases <- analysis_release_list(status = NULL, limit = limit_int, offset = offset_int, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R-206-
api/endpoints/admin_analysis_snapshot_endpoints.R-207-  list(
api/endpoints/admin_analysis_snapshot_endpoints.R:208:    releases = releases,
api/endpoints/admin_analysis_snapshot_endpoints.R:209:    pagination = list(limit = limit_int, offset = offset_int, count = length(releases))
api/endpoints/admin_analysis_snapshot_endpoints.R-210-  )
api/endpoints/admin_analysis_snapshot_endpoints.R-211-}
api/endpoints/admin_analysis_snapshot_endpoints.R-212-
api/endpoints/admin_analysis_snapshot_endpoints.R-213-#* Fetch one analysis-snapshot release, including a draft (Administrator only)
api/endpoints/admin_analysis_snapshot_endpoints.R-214-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:215:#* Unlike the public `GET /api/analysis/releases/<id>` (published-only, see
api/endpoints/admin_analysis_snapshot_endpoints.R:216:#* `svc_release_get()`), this admin detail resolves a draft release too.
api/endpoints/admin_analysis_snapshot_endpoints.R-217-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-218-#* @tag admin
api/endpoints/admin_analysis_snapshot_endpoints.R-219-#* @serializer unboxedJSON
api/endpoints/admin_analysis_snapshot_endpoints.R-220-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:221:#* @get /releases/<release_id>
api/endpoints/admin_analysis_snapshot_endpoints.R-222-function(req, res, release_id) {
api/endpoints/admin_analysis_snapshot_endpoints.R:223:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-224-
api/endpoints/admin_analysis_snapshot_endpoints.R-225-  head <- analysis_release_get(release_id, include_draft = TRUE, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R-226-  if (is.null(head)) {
--
api/endpoints/admin_analysis_snapshot_endpoints.R-237-#* @tag admin
api/endpoints/admin_analysis_snapshot_endpoints.R-238-#* @serializer unboxedJSON
api/endpoints/admin_analysis_snapshot_endpoints.R-239-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:240:#* @post /releases/<release_id>/publish
api/endpoints/admin_analysis_snapshot_endpoints.R-241-function(req, res, release_id) {
api/endpoints/admin_analysis_snapshot_endpoints.R:242:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R:243:  svc_release_publish(release_id, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R-244-}
api/endpoints/admin_analysis_snapshot_endpoints.R-245-
api/endpoints/admin_analysis_snapshot_endpoints.R-246-#* Record external Zenodo/DOI provenance on a release (Administrator only)
--
api/endpoints/admin_analysis_snapshot_endpoints.R-258-#* @param version_doi:str Optional.
api/endpoints/admin_analysis_snapshot_endpoints.R-259-#* @param concept_doi:str Optional.
api/endpoints/admin_analysis_snapshot_endpoints.R-260-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:261:#* @patch /releases/<release_id>/doi
api/endpoints/admin_analysis_snapshot_endpoints.R-262-function(req, res, release_id, zenodo_record_id = NULL, zenodo_record_url = NULL,
api/endpoints/admin_analysis_snapshot_endpoints.R-263-         version_doi = NULL, concept_doi = NULL) {
api/endpoints/admin_analysis_snapshot_endpoints.R:264:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-265-
api/endpoints/admin_analysis_snapshot_endpoints.R-266-  doi_fields <- list(
api/endpoints/admin_analysis_snapshot_endpoints.R-267-    zenodo_record_id = zenodo_record_id,
--
api/endpoints/admin_analysis_snapshot_endpoints.R-274-  # omitted field to NULL instead of leaving it unchanged.
api/endpoints/admin_analysis_snapshot_endpoints.R-275-  doi_fields <- doi_fields[!vapply(doi_fields, is.null, logical(1))]
api/endpoints/admin_analysis_snapshot_endpoints.R-276-
api/endpoints/admin_analysis_snapshot_endpoints.R:277:  svc_release_set_doi(release_id, doi_fields = doi_fields, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R-278-}
api/endpoints/admin_analysis_snapshot_endpoints.R-279-
api/endpoints/admin_analysis_snapshot_endpoints.R-280-#* Delete a draft analysis-snapshot release (Administrator only)
api/endpoints/admin_analysis_snapshot_endpoints.R-281-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-282-#* Unknown release id -> 404. Refuses (400) once the release is published --
api/endpoints/admin_analysis_snapshot_endpoints.R:283:#* releases are retained indefinitely once published; only a draft (e.g. a
api/endpoints/admin_analysis_snapshot_endpoints.R-284-#* failed/aborted build) can be discarded.
api/endpoints/admin_analysis_snapshot_endpoints.R-285-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-286-#* @tag admin
api/endpoints/admin_analysis_snapshot_endpoints.R-287-#* @serializer unboxedJSON
api/endpoints/admin_analysis_snapshot_endpoints.R-288-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:289:#* @delete /releases/<release_id>
api/endpoints/admin_analysis_snapshot_endpoints.R-290-function(req, res, release_id) {
api/endpoints/admin_analysis_snapshot_endpoints.R:291:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R:292:  svc_release_delete_draft(release_id, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R-293-}
--
api/endpoints/analysis_endpoints.R-329-#* - Approved-public data only (the snapshot is built from approved public data).
api/endpoints/analysis_endpoints.R-330-#* - The `bundle` is the decompressed, parsed JSON of the stored gzip blob.
api/endpoints/analysis_endpoints.R-331-#*
api/endpoints/analysis_endpoints.R:332:#* NOTE: These reproducibility routes live in this file (not a separate mounted
api/endpoints/analysis_endpoints.R:333:#* sub-router) on purpose. Plumber cannot mount a second router at `/api/analysis`
api/endpoints/analysis_endpoints.R:334:#* (a duplicate mount replaces the first) and a sub-router 404 does not fall
api/endpoints/analysis_endpoints.R:335:#* through to other mounts, so the only way to serve the documented sibling path
api/endpoints/analysis_endpoints.R-336-#* `/api/analysis/functional_clustering/reproducibility` is as a route inside the
api/endpoints/analysis_endpoints.R-337-#* same analysis sub-router. The endpoint logic is kept thin (delegated to
api/endpoints/analysis_endpoints.R-338-#* `analysis_reproducibility_endpoint()` in functions/analysis-reproducibility.R).
--
api/endpoints/analysis_endpoints.R-377-## Analysis-snapshot RELEASES: public read routes (#573 Slice A / Task A6)
api/endpoints/analysis_endpoints.R-378-## -------------------------------------------------------------------##
api/endpoints/analysis_endpoints.R-379-#
api/endpoints/analysis_endpoints.R:380:# Immutable, content-addressed public releases of the analysis snapshots
api/endpoints/analysis_endpoints.R-381-# above (see services/analysis-snapshot-release-service.R for the full
api/endpoints/analysis_endpoints.R:382:# contract). DB-only, published-only: every svc_release_* read is pinned to
api/endpoints/analysis_endpoints.R-383-# status = "published", so an unknown release id and a draft release id are
api/endpoints/analysis_endpoints.R-384-# indistinguishable to the caller -- both resolve to a plain 404. `conn =
api/endpoints/analysis_endpoints.R-385-# pool` mirrors the established global-pool endpoint pattern (see
--
api/endpoints/analysis_endpoints.R-387-# explicit connection on every call (no NULL/global-pool fallback), unlike
api/endpoints/analysis_endpoints.R-388-# the sibling analysis-snapshot-repository.R.
api/endpoints/analysis_endpoints.R-389-#
api/endpoints/analysis_endpoints.R:390:# DECLARATION ORDER IS LOAD-BEARING: `releases/latest` MUST stay declared
api/endpoints/analysis_endpoints.R:391:# before `releases/<release_id>` below -- Plumber matches routes in
api/endpoints/analysis_endpoints.R-392-# declaration order, so the dynamic `<release_id>` segment would otherwise
api/endpoints/analysis_endpoints.R-393-# shadow the literal "latest" segment (the same class of bug documented in
api/endpoints/analysis_endpoints.R-394-# AGENTS.md's `/status/_list` vs `/status/<status_id_requested>` lesson). A
--
api/endpoints/analysis_endpoints.R-400-  if (is.na(parsed)) default else parsed
api/endpoints/analysis_endpoints.R-401-}
api/endpoints/analysis_endpoints.R-402-
api/endpoints/analysis_endpoints.R:403:#* List published analysis-snapshot releases
api/endpoints/analysis_endpoints.R-404-#*
api/endpoints/analysis_endpoints.R:405:#* Immutable, content-addressed public releases (newest first). Draft
api/endpoints/analysis_endpoints.R:406:#* releases are never returned.
api/endpoints/analysis_endpoints.R-407-#*
api/endpoints/analysis_endpoints.R-408-#* @tag analysis
api/endpoints/analysis_endpoints.R-409-#* @serializer json list(na="string", auto_unbox=TRUE)
api/endpoints/analysis_endpoints.R:410:#* @param limit:str Max releases to return (default "50")
api/endpoints/analysis_endpoints.R-411-#* @param offset:str Offset into the published list (default "0")
api/endpoints/analysis_endpoints.R-412-#*
api/endpoints/analysis_endpoints.R:413:#* @response 200 OK. Returns { releases, pagination }.
api/endpoints/analysis_endpoints.R-414-#*
api/endpoints/analysis_endpoints.R:415:#* @get releases
api/endpoints/analysis_endpoints.R-416-function(limit = "50", offset = "0", res) {
api/endpoints/analysis_endpoints.R-417-  limit_int <- analysis_release_query_int(limit, 50L)
api/endpoints/analysis_endpoints.R-418-  offset_int <- analysis_release_query_int(offset, 0L)
api/endpoints/analysis_endpoints.R:419:  releases <- svc_release_list(limit = limit_int, offset = offset_int, conn = pool)
api/endpoints/analysis_endpoints.R-420-  list(
api/endpoints/analysis_endpoints.R:421:    releases = releases,
api/endpoints/analysis_endpoints.R-422-    pagination = list(
api/endpoints/analysis_endpoints.R-423-      limit = limit_int,
api/endpoints/analysis_endpoints.R-424-      offset = offset_int,
api/endpoints/analysis_endpoints.R:425:      count = length(releases)
api/endpoints/analysis_endpoints.R-426-    )
api/endpoints/analysis_endpoints.R-427-  )
api/endpoints/analysis_endpoints.R-428-}
--
api/endpoints/analysis_endpoints.R-430-
api/endpoints/analysis_endpoints.R-431-#* Get the newest published analysis-snapshot release
api/endpoints/analysis_endpoints.R-432-#*
api/endpoints/analysis_endpoints.R:433:#* MUST stay declared before `releases/<release_id>` (see the ordering note
api/endpoints/analysis_endpoints.R-434-#* above this section).
api/endpoints/analysis_endpoints.R-435-#*
api/endpoints/analysis_endpoints.R-436-#* @tag analysis
--
api/endpoints/analysis_endpoints.R-439-#* @response 200 OK. Returns the release head + `manifest` (same shape as the detail route).
api/endpoints/analysis_endpoints.R-440-#* @response 404 Not Found. No published release exists yet.
api/endpoints/analysis_endpoints.R-441-#*
api/endpoints/analysis_endpoints.R:442:#* @get releases/latest
api/endpoints/analysis_endpoints.R-443-function(res) {
api/endpoints/analysis_endpoints.R:444:  newest <- svc_release_list(limit = 1, offset = 0, conn = pool)
api/endpoints/analysis_endpoints.R-445-  if (length(newest) == 0L) {
api/endpoints/analysis_endpoints.R-446-    stop_for_not_found("No published analysis-snapshot release exists yet")
api/endpoints/analysis_endpoints.R-447-  }
api/endpoints/analysis_endpoints.R:448:  svc_release_get(as.character(newest[[1]]$release_id), conn = pool)
api/endpoints/analysis_endpoints.R-449-}
api/endpoints/analysis_endpoints.R-450-
api/endpoints/analysis_endpoints.R-451-
--
api/endpoints/analysis_endpoints.R-458-#* @response 200 OK. Returns the release head + `manifest`.
api/endpoints/analysis_endpoints.R-459-#* @response 404 Not Found. Unknown release id, or the release is still a draft.
api/endpoints/analysis_endpoints.R-460-#*
api/endpoints/analysis_endpoints.R:461:#* @get releases/<release_id>
api/endpoints/analysis_endpoints.R-462-function(release_id, res) {
api/endpoints/analysis_endpoints.R:463:  svc_release_get(release_id, conn = pool)
api/endpoints/analysis_endpoints.R-464-}
api/endpoints/analysis_endpoints.R-465-
api/endpoints/analysis_endpoints.R-466-
--
api/endpoints/analysis_endpoints.R-476-#* @response 200 OK. Raw manifest.json bytes, Content-Type application/json.
api/endpoints/analysis_endpoints.R-477-#* @response 404 Not Found. Unknown release id, or the release is still a draft.
api/endpoints/analysis_endpoints.R-478-#*
api/endpoints/analysis_endpoints.R:479:#* @get releases/<release_id>/manifest.json
api/endpoints/analysis_endpoints.R-480-function(release_id, res) {
api/endpoints/analysis_endpoints.R:481:  content <- svc_release_manifest(release_id, conn = pool)
api/endpoints/analysis_endpoints.R-482-  # Content-Type is set by the octet serializer (application/json) -- do NOT also
api/endpoints/analysis_endpoints.R-483-  # res$setHeader() it, which would emit a duplicate Content-Type header.
api/endpoints/analysis_endpoints.R-484-  content$bytes
--
api/endpoints/analysis_endpoints.R-500-#* @response 200 OK. Raw file bytes, Content-Type from the stored file's media type.
api/endpoints/analysis_endpoints.R-501-#* @response 404 Not Found. Unknown release id, draft release, or unknown file path.
api/endpoints/analysis_endpoints.R-502-#*
api/endpoints/analysis_endpoints.R:503:#* @get releases/<release_id>/file
api/endpoints/analysis_endpoints.R-504-function(release_id, path = "", res) {
api/endpoints/analysis_endpoints.R-505-  file_path <- analysis_endpoint_scalar(path, "")
api/endpoints/analysis_endpoints.R:506:  content <- svc_release_file(release_id, file_path, conn = pool)
api/endpoints/analysis_endpoints.R-507-  # The stored media type is per-file (usually application/json), so set the
api/endpoints/analysis_endpoints.R-508-  # serializer's type dynamically rather than res$setHeader()-ing a second
api/endpoints/analysis_endpoints.R-509-  # Content-Type alongside the octet serializer's default.
--
api/endpoints/analysis_endpoints.R-521-#* @response 200 OK. Raw gzip tar bytes, served as an attachment download.
api/endpoints/analysis_endpoints.R-522-#* @response 404 Not Found. Unknown release id, or the release is still a draft.
api/endpoints/analysis_endpoints.R-523-#*
api/endpoints/analysis_endpoints.R:524:#* @get releases/<release_id>/bundle
api/endpoints/analysis_endpoints.R-525-function(release_id, res) {
api/endpoints/analysis_endpoints.R:526:  bundle <- svc_release_bundle(release_id, conn = pool)
api/endpoints/analysis_endpoints.R-527-  # Content-Type (application/gzip) is set by the octet serializer -- do NOT also
api/endpoints/analysis_endpoints.R-528-  # res$setHeader() it (duplicate header). Content-Disposition/Length are distinct.
api/endpoints/analysis_endpoints.R-529-  res$setHeader("Content-Disposition", sprintf('attachment; filename="%s"', bundle$filename))

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release.R | sed -n '1,539p'
nl -ba api/functions/analysis-snapshot-release-manifest.R | sed -n '1,279p'
nl -ba api/functions/analysis-snapshot-release-materialize.R | sed -n '1,359p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
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
   316	  # M1: DB release provenance — carried on each pinned snapshot manifest. Take a
   317	  # consistent value across layers (assert equal; else the first non-NA/non-empty).
   318	  shared_db_release_version <- .analysis_release_consistent_manifest_value(loaded, "db_release_version")
   319	  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit")
   320	
   321	  # For the correlation layer, pin the actual dependency lineage into its entry.
   322	  corr <- loaded[["phenotype_functional_correlations"]]
   323	  if (!is.null(corr)) {
   324	    loaded[["phenotype_functional_correlations"]]$dependencies <-
   325	      analysis_snapshot_manifest_dependencies(corr$manifest)
   326	  }
   327	
   328	  # --- Step 3/4/5: materialize per-layer files + README, build layer_entries
   329	  artifacts <- list()
   330	  layer_entries <- list()
   331	
   332	  for (layer in layers) {
   333	    at <- as.character(layer$analysis_type[[1]])
   334	    entry <- loaded[[at]]
   335	    prefix <- layer$files_prefix %||% at
   336	
   337	    payload_bytes <- analysis_release_canonical_bytes(.analysis_release_layer_payload(entry$snapshot, layer))
   338	    artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   339	      paste0(prefix, "/payload.json"), payload_bytes, "application/json"
   340	    )
   341	
   342	    if (isTRUE(layer$has_reproducibility)) {
   343	      repro_bytes <- charToRaw(analysis_reproducibility_decode_raw(entry$reproducibility_bundle))
   344	      # H2: the LOCKED equality `sha256(reproducibility.json) == reproducibility_hash`
   345	      # must HOLD, not merely be present — verify the decoded bytes hash to the
   346	      # stored hash (a corrupt/restored bundle whose bytes drifted from its hash
   347	      # is rejected, not published).
   348	      computed_repro_hash <- analysis_release_sha256(repro_bytes)
   349	      if (!identical(computed_repro_hash, entry$reproducibility_hash)) {
   350	        stop(.analysis_release_condition(
   351	          "release_reproducibility_missing",
   352	          sprintf(
   353	            "layer %s reproducibility bytes do not hash to the stored reproducibility_hash (bundle corrupt)",
   354	            at
   355	          ),
   356	          analysis_type = at
   357	        ))
   358	      }
   359	      artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   360	        paste0(prefix, "/reproducibility.json"), repro_bytes, "application/json"
   361	      )
   362	    }
   363	
   364	    layer_entries[[length(layer_entries) + 1L]] <- list(
   365	      analysis_type = at,
   366	      parameter_hash = entry$parameter_hash,
   367	      snapshot_id = entry$snapshot_id,
   368	      input_hash = entry$input_hash,
   369	      payload_hash = entry$payload_hash,
   370	      schema_version = entry$schema_version,
   371	      reproducibility_hash = entry$reproducibility_hash,
   372	      dependencies = entry$dependencies
   373	    )
   374	  }
   375	
   376	  # --- Step 6: content_digest -> release_id + idempotency ------------------
   377	  content_digest <- analysis_release_content_digest(
   378	    layer_entries, shared_source_version, ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION
   379	  )
   380	  release_id <- analysis_release_id(content_digest)
   381	
   382	  if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
   383	    existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   384	    if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
   385	      return(list(release = existing, created = FALSE))
   386	    }
   387	    stop(sprintf(
   388	      "release id %s already exists with a different content_digest (identity anomaly)",
   389	      release_id
   390	    ), call. = FALSE)
   391	  }
   392	
   393	  # README carries the resolved release_id now that it is known.
   394	  readme_bytes <- .analysis_release_readme_bytes(
   395	    release_id, title, scope_statement, license, shared_source_version, layer_entries
   396	  )
   397	  artifacts <- c(
   398	    list(.analysis_release_artifact("README.md", readme_bytes, "text/markdown")),
   399	    artifacts
   400	  )
   401	
   402	  created_at <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
   403	
   404	  # --- Step 7: manifest.json (files[] excludes manifest + checksums) -------
   405	  content_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256, bytes = a$byte_size))
   406	  manifest_obj <- analysis_release_build_manifest(list(
   407	    release_id = release_id,
   408	    release_version = NULL,
   409	    title = title,
   410	    created_at = created_at,
   411	    license = license %||% "CC-BY-4.0",
   412	    scope_statement = scope_statement,
   413	    generator = list(
   414	      name = "sysndd-analysis-snapshot-release-build",
   415	      manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
   416	      reproducibility_schema_version = if (exists("ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION")) {
   417	        ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION
   418	      } else {
   419	        NULL
   420	      }
   421	    ),
   422	    source = list(
   423	      source_data_version = shared_source_version,
   424	      db_release = list(
   425	        version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
   426	        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
   427	      ),
   428	      snapshots = lapply(layer_entries, function(e) {
   429	        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
   430	      })
   431	    ),
   432	    layers = layer_entries,
   433	    files = content_files,
   434	    content_digest = content_digest
   435	  ))
   436	  manifest_bytes <- analysis_release_canonical_bytes(manifest_obj)
   437	  manifest_artifact <- .analysis_release_artifact("manifest.json", manifest_bytes, "application/json")
   438	  manifest_sha256 <- manifest_artifact$sha256
   439	  artifacts[[length(artifacts) + 1L]] <- manifest_artifact
   440	
   441	  # --- Step 8: checksums.sha256 (all files incl. manifest, excl. checksums)-
   442	  checksum_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256))
   443	  checksums_bytes <- charToRaw(enc2utf8(analysis_release_checksums_text(checksum_files)))
   444	  artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   445	    "checksums.sha256", checksums_bytes, "text/plain"
   446	  )
   447	
   448	  # --- Step 9: bundle.tar.gz (all files) -----------------------------------
   449	  named_raw <- stats::setNames(
   450	    lapply(artifacts, function(a) a$bytes),
   451	    vapply(artifacts, function(a) a$path, character(1))
   452	  )
   453	  bundle_gzip <- analysis_release_build_tar_gz(named_raw)
   454	  bundle_sha256 <- analysis_release_sha256(bundle_gzip)
   455	
   456	  # --- Step 2 (re-assert immediately before insert) ------------------------
   457	  # A FRESH DB re-read via the loader seam (not the cached `loaded`) so a source
   458	  # snapshot that was refreshed between the first read and now is caught. Combined
   459	  # with the per-preset locks above, this closes the TOCTOU window.
   460	  .analysis_release_assert_lineage(loaded)
   461	  .analysis_release_verify_lineage_unchanged(layer_specs, loaded, loader, conn)
   462	
   463	  # --- Step 10: persist ----------------------------------------------------
   464	  release_head <- list(
   465	    release_id = release_id,
   466	    release_version = NULL,
   467	    title = title,
   468	    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
   469	    content_digest = content_digest,
   470	    manifest_sha256 = manifest_sha256,
   471	    bundle_sha256 = bundle_sha256,
   472	    bundle_gzip = bundle_gzip,
   473	    source_data_version = shared_source_version,
   474	    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
   475	    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
   476	    scope_statement = scope_statement,
   477	    license = license %||% "CC-BY-4.0",
   478	    created_by_user_id = created_by
   479	  )
   480	
   481	  members <- lapply(layer_entries, function(e) {
   482	    list(
   483	      analysis_type = e$analysis_type,
   484	      parameter_hash = e$parameter_hash,
   485	      snapshot_id = e$snapshot_id,
   486	      input_hash = e$input_hash,
   487	      payload_hash = e$payload_hash,
   488	      schema_version = e$schema_version,
   489	      reproducibility_hash = e$reproducibility_hash,
   490	      role = "layer"
   491	    )
   492	  })
   493	
   494	  insert_files <- lapply(artifacts, function(a) {
   495	    list(
   496	      file_path = a$path,
   497	      content_sha256 = a$sha256,
   498	      byte_size = a$byte_size,
   499	      media_type = a$media_type,
   500	      content_gzip = memCompress(a$bytes, type = "gzip")
   501	    )
   502	  })
   503	
   504	  # H3(b): a concurrent identical build can win the insert race (both passed the
   505	  # step-6 idempotency probe). On a DB duplicate-key error, re-read by release_id:
   506	  # if the stored content_digest matches, this build is a no-op (idempotent 200);
   507	  # otherwise it is a genuine identity anomaly (re-raise -> 500).
   508	  insert_created <- tryCatch(
   509	    {
   510	      inserter(release_head, members, insert_files, conn)
   511	      TRUE
   512	    },
   513	    error = function(e) {
   514	      if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
   515	        existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   516	        if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
   517	          return(FALSE) # idempotent: the concurrent winner stored the identical release
   518	        }
   519	      }
   520	      stop(e)
   521	    }
   522	  )
   523	
   524	  if (!isTRUE(insert_created)) {
   525	    return(list(
   526	      release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
   527	      created = FALSE
   528	    ))
   529	  }
   530	
   531	  if (isTRUE(publish)) {
   532	    analysis_release_publish(release_id, conn = conn)
   533	  }
   534	
   535	  list(
   536	    release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
   537	    created = TRUE
   538	  )
   539	}
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
     1	# functions/analysis-snapshot-release-materialize.R
     2	#
     3	# Pure, DB-light helpers for the immutable analysis-snapshot RELEASE build
     4	# orchestrator (#573 Slice A / Task A4). Split out of
     5	# `analysis-snapshot-release.R` to keep both files under the 600-line ceiling.
     6	#
     7	# Contains: the classed-condition constructor, the manifest/loader extraction
     8	# helpers, the best-effort HARD coherence-re-check default (`coherence_assert`
     9	# seam default), the cross-layer lineage gates, and the per-layer file
    10	# materialization (payload / reproducibility / README). No DB access, no network.
    11	#
    12	# Sourced together with `analysis-snapshot-release.R` (both registered in
    13	# `bootstrap/load_modules.R` -- Task A8 -- and both sourced by the direct-source
    14	# integration test).
    15	
    16	if (!exists("%||%", mode = "function")) {
    17	  `%||%` <- function(x, y) if (is.null(x)) y else x
    18	}
    19	
    20	# --------------------------------------------------------------------------- #
    21	# Classed conditions
    22	# --------------------------------------------------------------------------- #
    23	
    24	#' Construct a classed release-gate condition (`c(<class>,"error","condition")`).
    25	#'
    26	#' The five `release_*` gate classes are surfaced to the A5 service, which maps
    27	#' them to HTTP 400 (`stop_for_bad_request`; the contract has no 409 class).
    28	#' @noRd
    29	.analysis_release_condition <- function(class, message, ...) {
    30	  structure(
    31	    list(message = message, call = NULL, ...),
    32	    class = c(class, "error", "condition")
    33	  )
    34	}
    35	
    36	# --------------------------------------------------------------------------- #
    37	# Extraction helpers
    38	# --------------------------------------------------------------------------- #
    39	
    40	#' Scalar read of a manifest field (manifest is a 1-row data.frame / tibble).
    41	#' @noRd
    42	.analysis_release_manifest_scalar <- function(manifest, field, default = NA) {
    43	  if (is.null(manifest)) {
    44	    return(default)
    45	  }
    46	  if (!(field %in% names(manifest))) {
    47	    return(default)
    48	  }
    49	  column <- manifest[[field]]
    50	  if (length(column) == 0L) {
    51	    return(default)
    52	  }
    53	  value <- column[[1]]
    54	  if (is.null(value)) default else value
    55	}
    56	
    57	#' Take a consistent scalar of `field` across the loaded layer manifests.
    58	#'
    59	#' Returns the single distinct non-empty value when the layers agree, else the
    60	#' FIRST non-NA/non-empty value (a benign provenance disagreement never blocks a
    61	#' build). NA when no layer carries it. Used for `db_release_version`/`_commit`.
    62	#' @noRd
    63	.analysis_release_consistent_manifest_value <- function(loaded, field) {
    64	  values <- vapply(
    65	    loaded,
    66	    function(e) as.character(.analysis_release_manifest_scalar(e$manifest, field, NA_character_)),
    67	    character(1)
    68	  )
    69	  values <- values[!is.na(values) & nzchar(values)]
    70	  if (length(values) == 0L) {
    71	    return(NA_character_)
    72	  }
    73	  values[[1]]
    74	}
    75	
    76	#' Coerce a possibly-NULL child tibble to a plain data.frame for serialization.
    77	#' @noRd
    78	.analysis_release_rows <- function(x) {
    79	  if (is.null(x)) {
    80	    return(data.frame())
    81	  }
    82	  as.data.frame(x, stringsAsFactors = FALSE)
    83	}
    84	
    85	#' Map a cluster analysis_type to its cluster_kind label.
    86	#' @noRd
    87	.analysis_release_layer_kind <- function(analysis_type) {
    88	  switch(as.character(analysis_type[[1]]),
    89	    functional_clusters = "functional",
    90	    phenotype_clusters = "phenotype",
    91	    NA_character_
    92	  )
    93	}
    94	
    95	#' Extract the reproducibility_hash from a loader row (df or list), or NA.
    96	#' @noRd
    97	.analysis_release_repro_hash <- function(repro) {
    98	  if (is.null(repro)) {
    99	    return(NA_character_)
   100	  }
   101	  if (is.data.frame(repro) && nrow(repro) == 0L) {
   102	    return(NA_character_)
   103	  }
   104	  hash <- repro$reproducibility_hash
   105	  if (is.null(hash) || length(hash) == 0L) {
   106	    return(NA_character_)
   107	  }
   108	  as.character(hash[[1]])
   109	}
   110	
   111	# --------------------------------------------------------------------------- #
   112	# Default coherence seam (best-effort HARD re-check over the STORED snapshot).
   113	#
   114	# Two of the three #514 coherence components ARE reconstructable from the stored
   115	# public snapshot and are re-checked here (HARD, require_coherence = TRUE,
   116	# ignoring the ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE downgrade):
   117	#   1. Cluster-set integrity: every visible cluster (by cluster_kind) must appear
   118	#      in the membership AND carry a non-NA stability score (jaccard_mean) in its
   119	#      metadata_json — directly catching the #514 symptom ("real clusters with n/a
   120	#      stability") in stored form.
   121	#   2. Channel match (functional axis): the served membership channel
   122	#      (`membership_weight_channel`) and the validation channel (`weight_channel`)
   123	#      are both persisted in the manifest `validation_json`; when both are present
   124	#      they must agree, else the served membership was clustered on a different
   125	#      STRING channel than the validation scored (the #514 text-mining-vs-exp+db
   126	#      case that slips through when cluster-id labels coincide).
   127	# The THIRD component — full member-set equality — is genuinely NOT
   128	# reconstructable: the validator's `reference_members` is a sibling of `partition`
   129	# and is never persisted. That check is left to the build-time gate; the dev-stack
   130	# e2e exercises the true membership-vs-validation recompute path.
   131	# --------------------------------------------------------------------------- #
   132	
   133	#' Parse the manifest `validation_json` column to a plain list (or empty list).
   134	#' @noRd
   135	.analysis_release_parse_validation_json <- function(manifest) {
   136	  raw <- suppressWarnings(as.character(.analysis_release_manifest_scalar(manifest, "validation_json", NA_character_)))
   137	  if (length(raw) == 0L || is.na(raw[[1]]) || !nzchar(raw[[1]])) {
   138	    return(list())
   139	  }
   140	  parsed <- tryCatch(jsonlite::fromJSON(raw[[1]], simplifyVector = TRUE), error = function(e) NULL)
   141	  if (is.null(parsed) || !is.list(parsed)) {
   142	    return(list())
   143	  }
   144	  parsed
   145	}
   146	
   147	#' @noRd
   148	.analysis_release_cluster_has_stability <- function(metadata_json) {
   149	  txt <- suppressWarnings(as.character(metadata_json))
   150	  if (length(txt) == 0L || is.na(txt[[1]]) || !nzchar(txt[[1]])) {
   151	    return(FALSE)
   152	  }
   153	  parsed <- tryCatch(jsonlite::fromJSON(txt[[1]], simplifyVector = TRUE), error = function(e) NULL)
   154	  if (is.null(parsed)) {
   155	    return(FALSE)
   156	  }
   157	  score <- parsed$jaccard_mean %||% parsed$stability %||% parsed$stability_score
   158	  !is.null(score) && length(score) >= 1L && !is.na(suppressWarnings(as.numeric(score[[1]])))
   159	}
   160	
   161	#' Hard coherence re-check over a loaded cluster snapshot. Default `coherence_assert`.
   162	#' @export
   163	analysis_snapshot_release_assert_coherent <- function(snapshot, kind) {
   164	  clusters <- .analysis_release_rows(snapshot$clusters)
   165	  members <- .analysis_release_rows(snapshot$cluster_members)
   166	  if ("cluster_kind" %in% names(clusters)) {
   167	    clusters <- clusters[as.character(clusters$cluster_kind) == kind, , drop = FALSE]
   168	  }
   169	  if ("cluster_kind" %in% names(members)) {
   170	    members <- members[as.character(members$cluster_kind) == kind, , drop = FALSE]
   171	  }
   172	
   173	  membership_ids <- if ("cluster_id" %in% names(members)) unique(as.character(members$cluster_id)) else character(0)
   174	  membership <- tibble::tibble(cluster = membership_ids)
   175	
   176	  valid_ids <- character(0)
   177	  if (nrow(clusters) > 0L && "cluster_id" %in% names(clusters)) {
   178	    metadata <- if ("metadata_json" %in% names(clusters)) clusters$metadata_json else rep(NA_character_, nrow(clusters))
   179	    has_stability <- vapply(
   180	      seq_len(nrow(clusters)),
   181	      function(i) .analysis_release_cluster_has_stability(metadata[[i]]),
   182	      logical(1)
   183	    )
   184	    valid_ids <- as.character(clusters$cluster_id[has_stability])
   185	  }
   186	  per_cluster <- tibble::tibble(cluster_id = valid_ids)
   187	
   188	  # Channel match (functional axis only): both channels live in validation_json;
   189	  # when both are present they must agree. Absent/older snapshots skip this
   190	  # comparison (assert_partition_coherent only fires channel_mismatch when BOTH
   191	  # membership_channel and validation_channel are non-NULL).
   192	  membership_channel <- NULL
   193	  validation_channel <- NULL
   194	  if (identical(kind, "functional")) {
   195	    validation <- .analysis_release_parse_validation_json(snapshot$manifest)
   196	    membership_channel <- validation$membership_weight_channel
   197	    validation_channel <- validation$weight_channel
   198	  }
   199	
   200	  tryCatch(
   201	    analysis_snapshot_assert_partition_coherent(
   202	      membership, per_cluster, kind,
   203	      membership_channel = membership_channel,
   204	      validation_channel = validation_channel,
   205	      require_coherence = TRUE
   206	    ),
   207	    error = function(e) {
   208	      stop(.analysis_release_condition(
   209	        "release_source_incoherent",
   210	        sprintf("%s snapshot failed hard coherence re-check: %s", kind, conditionMessage(e)),
   211	        kind = kind
   212	      ))
   213	    }
   214	  )
   215	  invisible(TRUE)
   216	}
   217	
   218	# --------------------------------------------------------------------------- #
   219	# Cross-layer lineage gates (step 2). Re-asserted immediately before insert.
   220	# --------------------------------------------------------------------------- #
   221	
   222	#' @noRd
   223	.analysis_release_dep_matches <- function(dependencies, key, entry) {
   224	  if (!is.list(dependencies)) {
   225	    return(FALSE)
   226	  }
   227	  dep <- dependencies[[key]]
   228	  if (!is.list(dep)) {
   229	    return(FALSE)
   230	  }
   231	  dep_id <- suppressWarnings(as.integer(dep$snapshot_id %||% NA))
   232	  dep_hash <- as.character(dep$payload_hash %||% "")
   233	  entry_id <- suppressWarnings(as.integer(entry$snapshot_id))
   234	  entry_hash <- as.character(entry$payload_hash %||% "")
   235	  !is.na(dep_id) && !is.na(entry_id) && identical(dep_id, entry_id) &&
   236	    nzchar(dep_hash) && nzchar(entry_hash) && identical(dep_hash, entry_hash)
   237	}
   238	
   239	#' Assert one shared source_data_version + correlation dependency lineage.
   240	#' @noRd
   241	.analysis_release_assert_lineage <- function(loaded) {
   242	  versions <- vapply(
   243	    loaded,
   244	    function(e) as.character(e$source_data_version %||% NA_character_),
   245	    character(1)
   246	  )
   247	  uniq <- unique(versions)
   248	  if (length(uniq) != 1L || is.na(uniq[[1]]) || !nzchar(uniq[[1]])) {
   249	    stop(.analysis_release_condition(
   250	      "release_source_version_mismatch",
   251	      sprintf(
   252	        "release layers do not share one source_data_version (found: %s)",
   253	        paste(ifelse(is.na(versions), "<NA>", versions), collapse = ", ")
   254	      )
   255	    ))
   256	  }
   257	
   258	  corr <- loaded[["phenotype_functional_correlations"]]
   259	  func <- loaded[["functional_clusters"]]
   260	  phen <- loaded[["phenotype_clusters"]]
   261	  if (!is.null(corr) && !is.null(func) && !is.null(phen)) {
   262	    dependencies <- analysis_snapshot_manifest_dependencies(corr$manifest)
   263	    ok <- .analysis_release_dep_matches(dependencies, "functional_clusters", func) &&
   264	      .analysis_release_dep_matches(dependencies, "phenotype_clusters", phen)
   265	    if (!ok) {
   266	      stop(.analysis_release_condition(
   267	        "release_dependency_lineage_mismatch",
   268	        paste(
   269	          "correlation snapshot dependency lineage does not match the pinned",
   270	          "functional/phenotype cluster snapshots (a cluster axis was refreshed",
   271	          "after the correlation was computed)"
   272	        )
   273	      ))
   274	    }
   275	  }
   276	  invisible(TRUE)
   277	}
   278	
   279	# --------------------------------------------------------------------------- #
   280	# File materialization
   281	# --------------------------------------------------------------------------- #
   282	
   283	#' Layer-appropriate payload object (its own bytes; NOT the snapshot payload_hash).
   284	#' @noRd
   285	.analysis_release_layer_payload <- function(snapshot, layer) {
   286	  if (isTRUE(layer$has_reproducibility)) {
   287	    list(
   288	      clusters = .analysis_release_rows(snapshot$clusters),
   289	      cluster_members = .analysis_release_rows(snapshot$cluster_members)
   290	    )
   291	  } else if (grepl("correlation", layer$analysis_type, fixed = TRUE)) {
   292	    list(correlations = .analysis_release_rows(snapshot$correlations))
   293	  } else {
   294	    list(
   295	      network_nodes = .analysis_release_rows(snapshot$network_nodes),
   296	      network_edges = .analysis_release_rows(snapshot$network_edges)
   297	    )
   298	  }
   299	}
   300	
   301	#' Assemble one materialized artifact with its own sha256 + byte_size.
   302	#' @noRd
   303	.analysis_release_artifact <- function(path, bytes, media_type) {
   304	  # Every materialized file path flows through here — assert containment at this
   305	  # single choke point (defense-in-depth alongside analysis_release_build_tar_gz).
   306	  .analysis_release_assert_safe_path(path)
   307	  list(
   308	    path = path,
   309	    bytes = bytes,
   310	    media_type = media_type,
   311	    sha256 = analysis_release_sha256(bytes),
   312	    byte_size = length(bytes)
   313	  )
   314	}
   315	
   316	#' README.md content bytes (scope + independent-verification recipe).
   317	#' @noRd
   318	.analysis_release_readme_bytes <- function(release_id, title, scope_statement, license,
   319	                                           source_data_version, layer_entries) {
   320	  layer_lines <- vapply(
   321	    layer_entries,
   322	    function(e) {
   323	      sprintf(
   324	        "- %s (snapshot_id %s, payload_hash %s)",
   325	        e$analysis_type, as.character(e$snapshot_id), substr(e$payload_hash, 1, 12)
   326	      )
   327	    },
   328	    character(1)
   329	  )
   330	  lines <- c(
   331	    sprintf("# %s", title %||% "SysNDD analysis-snapshot release"),
   332	    "",
   333	    sprintf("Release: `%s`", release_id),
   334	    sprintf("License: %s", license %||% "CC-BY-4.0"),
   335	    sprintf("Source data version: %s", source_data_version %||% "unknown"),
   336	    "",
   337	    "## Scope",
   338	    "",
   339	    scope_statement %||% paste(
   340	      "Immutable, content-addressed public export of the curated derived",
   341	      "cluster-analysis snapshots served by the SysNDD analysis API."
   342	    ),
   343	    "",
   344	    "## Layers",
   345	    "",
   346	    layer_lines,
   347	    "",
   348	    "## Verify",
   349	    "",
   350	    "1. `sha256sum -c checksums.sha256` verifies every file against its recorded digest.",
   351	    "2. `manifest.json` records each layer's source snapshot lineage",
   352	    "   (`snapshot_id`, `payload_hash`, `input_hash`) plus the reproducibility hash.",
   353	    "3. Each cluster layer's `reproducibility.json` hashes exactly to its",
   354	    "   `reproducibility_hash` and carries the inputs to independently recompute",
   355	    "   the served separation metric (modularity / silhouette).",
   356	    ""
   357	  )
   358	  charToRaw(enc2utf8(paste(lines, collapse = "\n")))
   359	}

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release.R | sed -n '365,539p'
nl -ba api/functions/analysis-snapshot-release-repository.R | sed -n '1,484p'
nl -ba api/services/analysis-snapshot-release-service.R | sed -n '1,288p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
   365	      analysis_type = at,
   366	      parameter_hash = entry$parameter_hash,
   367	      snapshot_id = entry$snapshot_id,
   368	      input_hash = entry$input_hash,
   369	      payload_hash = entry$payload_hash,
   370	      schema_version = entry$schema_version,
   371	      reproducibility_hash = entry$reproducibility_hash,
   372	      dependencies = entry$dependencies
   373	    )
   374	  }
   375	
   376	  # --- Step 6: content_digest -> release_id + idempotency ------------------
   377	  content_digest <- analysis_release_content_digest(
   378	    layer_entries, shared_source_version, ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION
   379	  )
   380	  release_id <- analysis_release_id(content_digest)
   381	
   382	  if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
   383	    existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   384	    if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
   385	      return(list(release = existing, created = FALSE))
   386	    }
   387	    stop(sprintf(
   388	      "release id %s already exists with a different content_digest (identity anomaly)",
   389	      release_id
   390	    ), call. = FALSE)
   391	  }
   392	
   393	  # README carries the resolved release_id now that it is known.
   394	  readme_bytes <- .analysis_release_readme_bytes(
   395	    release_id, title, scope_statement, license, shared_source_version, layer_entries
   396	  )
   397	  artifacts <- c(
   398	    list(.analysis_release_artifact("README.md", readme_bytes, "text/markdown")),
   399	    artifacts
   400	  )
   401	
   402	  created_at <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
   403	
   404	  # --- Step 7: manifest.json (files[] excludes manifest + checksums) -------
   405	  content_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256, bytes = a$byte_size))
   406	  manifest_obj <- analysis_release_build_manifest(list(
   407	    release_id = release_id,
   408	    release_version = NULL,
   409	    title = title,
   410	    created_at = created_at,
   411	    license = license %||% "CC-BY-4.0",
   412	    scope_statement = scope_statement,
   413	    generator = list(
   414	      name = "sysndd-analysis-snapshot-release-build",
   415	      manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
   416	      reproducibility_schema_version = if (exists("ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION")) {
   417	        ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION
   418	      } else {
   419	        NULL
   420	      }
   421	    ),
   422	    source = list(
   423	      source_data_version = shared_source_version,
   424	      db_release = list(
   425	        version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
   426	        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
   427	      ),
   428	      snapshots = lapply(layer_entries, function(e) {
   429	        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
   430	      })
   431	    ),
   432	    layers = layer_entries,
   433	    files = content_files,
   434	    content_digest = content_digest
   435	  ))
   436	  manifest_bytes <- analysis_release_canonical_bytes(manifest_obj)
   437	  manifest_artifact <- .analysis_release_artifact("manifest.json", manifest_bytes, "application/json")
   438	  manifest_sha256 <- manifest_artifact$sha256
   439	  artifacts[[length(artifacts) + 1L]] <- manifest_artifact
   440	
   441	  # --- Step 8: checksums.sha256 (all files incl. manifest, excl. checksums)-
   442	  checksum_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256))
   443	  checksums_bytes <- charToRaw(enc2utf8(analysis_release_checksums_text(checksum_files)))
   444	  artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   445	    "checksums.sha256", checksums_bytes, "text/plain"
   446	  )
   447	
   448	  # --- Step 9: bundle.tar.gz (all files) -----------------------------------
   449	  named_raw <- stats::setNames(
   450	    lapply(artifacts, function(a) a$bytes),
   451	    vapply(artifacts, function(a) a$path, character(1))
   452	  )
   453	  bundle_gzip <- analysis_release_build_tar_gz(named_raw)
   454	  bundle_sha256 <- analysis_release_sha256(bundle_gzip)
   455	
   456	  # --- Step 2 (re-assert immediately before insert) ------------------------
   457	  # A FRESH DB re-read via the loader seam (not the cached `loaded`) so a source
   458	  # snapshot that was refreshed between the first read and now is caught. Combined
   459	  # with the per-preset locks above, this closes the TOCTOU window.
   460	  .analysis_release_assert_lineage(loaded)
   461	  .analysis_release_verify_lineage_unchanged(layer_specs, loaded, loader, conn)
   462	
   463	  # --- Step 10: persist ----------------------------------------------------
   464	  release_head <- list(
   465	    release_id = release_id,
   466	    release_version = NULL,
   467	    title = title,
   468	    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
   469	    content_digest = content_digest,
   470	    manifest_sha256 = manifest_sha256,
   471	    bundle_sha256 = bundle_sha256,
   472	    bundle_gzip = bundle_gzip,
   473	    source_data_version = shared_source_version,
   474	    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
   475	    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
   476	    scope_statement = scope_statement,
   477	    license = license %||% "CC-BY-4.0",
   478	    created_by_user_id = created_by
   479	  )
   480	
   481	  members <- lapply(layer_entries, function(e) {
   482	    list(
   483	      analysis_type = e$analysis_type,
   484	      parameter_hash = e$parameter_hash,
   485	      snapshot_id = e$snapshot_id,
   486	      input_hash = e$input_hash,
   487	      payload_hash = e$payload_hash,
   488	      schema_version = e$schema_version,
   489	      reproducibility_hash = e$reproducibility_hash,
   490	      role = "layer"
   491	    )
   492	  })
   493	
   494	  insert_files <- lapply(artifacts, function(a) {
   495	    list(
   496	      file_path = a$path,
   497	      content_sha256 = a$sha256,
   498	      byte_size = a$byte_size,
   499	      media_type = a$media_type,
   500	      content_gzip = memCompress(a$bytes, type = "gzip")
   501	    )
   502	  })
   503	
   504	  # H3(b): a concurrent identical build can win the insert race (both passed the
   505	  # step-6 idempotency probe). On a DB duplicate-key error, re-read by release_id:
   506	  # if the stored content_digest matches, this build is a no-op (idempotent 200);
   507	  # otherwise it is a genuine identity anomaly (re-raise -> 500).
   508	  insert_created <- tryCatch(
   509	    {
   510	      inserter(release_head, members, insert_files, conn)
   511	      TRUE
   512	    },
   513	    error = function(e) {
   514	      if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
   515	        existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   516	        if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
   517	          return(FALSE) # idempotent: the concurrent winner stored the identical release
   518	        }
   519	      }
   520	      stop(e)
   521	    }
   522	  )
   523	
   524	  if (!isTRUE(insert_created)) {
   525	    return(list(
   526	      release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
   527	      created = FALSE
   528	    ))
   529	  }
   530	
   531	  if (isTRUE(publish)) {
   532	    analysis_release_publish(release_id, conn = conn)
   533	  }
   534	
   535	  list(
   536	    release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
   537	    created = TRUE
   538	  )
   539	}
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

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-repository.R | sed -n '238,368p'
nl -ba api/endpoints/analysis_endpoints.R | sed -n '377,535p'
nl -ba api/endpoints/admin_analysis_snapshot_endpoints.R | sed -n '80,293p'
rg -n -C 3 'resolve_layers|safe_path|reproducibility bytes|reproducibility_hash|lock_unavailable|duplicate|db_release|clamp|public_head|created_by_user_id|last_error_message' api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R api/tests/testthat/test-unit-analysis-snapshot-release-service.R api/tests/testthat/test-integration-analysis-snapshot-release-build.R api/tests/testthat/test-integration-analysis-release-endpoints.R api/tests/testthat/test-integration-analysis-release-admin-endpoints.R api/tests/testthat/test-integration-analysis-snapshot-release-repository.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
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
   420	  list(
   421	    releases = releases,
   422	    pagination = list(
   423	      limit = limit_int,
   424	      offset = offset_int,
   425	      count = length(releases)
   426	    )
   427	  )
   428	}
   429	
   430	
   431	#* Get the newest published analysis-snapshot release
   432	#*
   433	#* MUST stay declared before `releases/<release_id>` (see the ordering note
   434	#* above this section).
   435	#*
   436	#* @tag analysis
   437	#* @serializer json list(na="string", auto_unbox=TRUE)
   438	#*
   439	#* @response 200 OK. Returns the release head + `manifest` (same shape as the detail route).
   440	#* @response 404 Not Found. No published release exists yet.
   441	#*
   442	#* @get releases/latest
   443	function(res) {
   444	  newest <- svc_release_list(limit = 1, offset = 0, conn = pool)
   445	  if (length(newest) == 0L) {
   446	    stop_for_not_found("No published analysis-snapshot release exists yet")
   447	  }
   448	  svc_release_get(as.character(newest[[1]]$release_id), conn = pool)
   449	}
   450	
   451	
   452	#* Get one published analysis-snapshot release
   453	#*
   454	#* @tag analysis
   455	#* @serializer json list(na="string", auto_unbox=TRUE)
   456	#* @param release_id Release id (`asr_<16 hex>`).
   457	#*
   458	#* @response 200 OK. Returns the release head + `manifest`.
   459	#* @response 404 Not Found. Unknown release id, or the release is still a draft.
   460	#*
   461	#* @get releases/<release_id>
   462	function(release_id, res) {
   463	  svc_release_get(release_id, conn = pool)
   464	}
   465	
   466	
   467	#* Get a published release's stored `manifest.json` bytes verbatim
   468	#*
   469	#* Serves the EXACT stored bytes (never re-serialized), so
   470	#* `sha256(bytes) == manifest_sha256` on the release head.
   471	#*
   472	#* @tag analysis
   473	#* @serializer octet list(type = "application/json")
   474	#* @param release_id Release id.
   475	#*
   476	#* @response 200 OK. Raw manifest.json bytes, Content-Type application/json.
   477	#* @response 404 Not Found. Unknown release id, or the release is still a draft.
   478	#*
   479	#* @get releases/<release_id>/manifest.json
   480	function(release_id, res) {
   481	  content <- svc_release_manifest(release_id, conn = pool)
   482	  # Content-Type is set by the octet serializer (application/json) -- do NOT also
   483	  # res$setHeader() it, which would emit a duplicate Content-Type header.
   484	  content$bytes
   485	}
   486	
   487	
   488	#* Get one content file from a published release by its exact archive path
   489	#*
   490	#* `path` is a QUERY parameter, not a path segment -- Plumber 1.3.2 has no
   491	#* `<path:.*>` multi-segment param type, so a nested path segment would 404.
   492	#* Resolved by an exact `(release_id, file_path)` primary-key lookup, so
   493	#* there is no path-traversal surface.
   494	#*
   495	#* @tag analysis
   496	#* @serializer octet
   497	#* @param release_id Release id.
   498	#* @param path:str Exact archive-relative file path, e.g. "functional_clusters/payload.json".
   499	#*
   500	#* @response 200 OK. Raw file bytes, Content-Type from the stored file's media type.
   501	#* @response 404 Not Found. Unknown release id, draft release, or unknown file path.
   502	#*
   503	#* @get releases/<release_id>/file
   504	function(release_id, path = "", res) {
   505	  file_path <- analysis_endpoint_scalar(path, "")
   506	  content <- svc_release_file(release_id, file_path, conn = pool)
   507	  # The stored media type is per-file (usually application/json), so set the
   508	  # serializer's type dynamically rather than res$setHeader()-ing a second
   509	  # Content-Type alongside the octet serializer's default.
   510	  res$serializer <- plumber::serializer_octet(type = content$media_type)
   511	  content$bytes
   512	}
   513	
   514	
   515	#* Download a published release's whole archive (`bundle.tar.gz`) verbatim
   516	#*
   517	#* @tag analysis
   518	#* @serializer octet list(type = "application/gzip")
   519	#* @param release_id Release id.
   520	#*
   521	#* @response 200 OK. Raw gzip tar bytes, served as an attachment download.
   522	#* @response 404 Not Found. Unknown release id, or the release is still a draft.
   523	#*
   524	#* @get releases/<release_id>/bundle
   525	function(release_id, res) {
   526	  bundle <- svc_release_bundle(release_id, conn = pool)
   527	  # Content-Type (application/gzip) is set by the octet serializer -- do NOT also
   528	  # res$setHeader() it (duplicate header). Content-Disposition/Length are distinct.
   529	  res$setHeader("Content-Disposition", sprintf('attachment; filename="%s"', bundle$filename))
   530	  res$setHeader("Content-Length", as.character(length(bundle$bytes)))
   531	  bundle$bytes
   532	}
   533	
   534	## Analyses endpoints
   535	## -------------------------------------------------------------------##
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
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-75-      input_hash = analysis_release_sha256("functional_clusters-input"),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-76-      payload_hash = analysis_release_sha256("functional_clusters-payload"),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-77-      schema_version = "1.2",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:78:      reproducibility_hash = analysis_release_sha256("functional_clusters-repro"),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-79-      role = "layer"
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-80-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-81-    list(
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-85-      input_hash = analysis_release_sha256("phenotype_clusters-input"),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-86-      payload_hash = analysis_release_sha256("phenotype_clusters-payload"),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-87-      schema_version = "2.0",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:88:      reproducibility_hash = analysis_release_sha256("phenotype_clusters-repro"),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-89-      role = "layer"
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-90-    )
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-91-  )
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-234-  expect_true(all(c(101L, 202L) %in% snap_ids))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-235-})
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-236-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:237:test_that("analysis_release_public_head drops operational columns and groups zenodo (H1)", {
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-238-  raw_head <- list(
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-239-    release_id = "asr_pub", release_version = "v1", title = "T", status = "published",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-240-    content_digest = "digest", created_at = "2026-07-18", published_at = "2026-07-18",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:241:    source_data_version = "srcv", db_release_version = "1.0.0", db_release_commit = "abc",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-242-    manifest_sha256 = "m", bundle_sha256 = "b", license = "CC-BY-4.0",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-243-    file_count = 5L, total_bytes = 100,
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-244-    zenodo_record_url = "https://zenodo.org/records/1", version_doi = "10.5281/zenodo.1",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-245-    concept_doi = NA_character_,
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-246-    # operational columns that MUST NOT leak publicly:
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:247:    created_by_user_id = 42L, last_error_message = "secret internal error", updated_at = "2026-07-18",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-248-    layers = list(list(analysis_type = "functional_clusters")),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-249-    manifest = list(release_id = "asr_pub")
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-250-  )
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-251-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:252:  projected <- analysis_release_public_head(raw_head)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-253-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:254:  expect_false("created_by_user_id" %in% names(projected))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:255:  expect_false("last_error_message" %in% names(projected))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-256-  expect_false("updated_at" %in% names(projected))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-257-  # allowlisted fields survive:
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-258-  expect_equal(projected$release_id, "asr_pub")
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:259:  expect_equal(projected$db_release_version, "1.0.0")
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-260-  expect_equal(projected$file_count, 5L)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-261-  # zenodo grouped; NA concept_doi -> NULL (dropped from the group):
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-262-  expect_equal(projected$zenodo$record_url, "https://zenodo.org/records/1")
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-266-  expect_false(is.null(projected$layers))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-267-  expect_false(is.null(projected$manifest))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-268-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:269:  expect_null(analysis_release_public_head(NULL))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-270-})
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-271-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-272-test_that("analysis_release_delete_draft removes a draft release and its file/member children", {
--
api/tests/testthat/test-integration-analysis-release-endpoints.R-125-    input_hash = analysis_release_sha256("functional_clusters-input"),
api/tests/testthat/test-integration-analysis-release-endpoints.R-126-    payload_hash = analysis_release_sha256("functional_clusters-payload"),
api/tests/testthat/test-integration-analysis-release-endpoints.R-127-    schema_version = "1.2",
api/tests/testthat/test-integration-analysis-release-endpoints.R:128:    reproducibility_hash = analysis_release_sha256("functional_clusters-repro"),
api/tests/testthat/test-integration-analysis-release-endpoints.R-129-    role = "layer"
api/tests/testthat/test-integration-analysis-release-endpoints.R-130-  )
api/tests/testthat/test-integration-analysis-release-endpoints.R-131-}
--
api/tests/testthat/test-integration-analysis-release-endpoints.R-249-  manifest_bytes <- manifest_handler(release_id = TEST_RELEASE_ID, res = manifest_res)
api/tests/testthat/test-integration-analysis-release-endpoints.R-250-  expect_equal(analysis_release_sha256(manifest_bytes), head$manifest_sha256)
api/tests/testthat/test-integration-analysis-release-endpoints.R-251-  # Content-Type (application/json) is set by the octet serializer annotation,
api/tests/testthat/test-integration-analysis-release-endpoints.R:252:  # not a manual header (see the duplicate-header regression guard below); the
api/tests/testthat/test-integration-analysis-release-endpoints.R-253-  # handler-extraction harness does not run the serializer, so the live
api/tests/testthat/test-integration-analysis-release-endpoints.R-254-  # dev-stack check + the static guard verify the header.
api/tests/testthat/test-integration-analysis-release-endpoints.R-255-
--
api/tests/testthat/test-integration-analysis-release-endpoints.R-273-  # NOT the layer's snapshot payload_hash.
api/tests/testthat/test-integration-analysis-release-endpoints.R-274-  expect_equal(analysis_release_sha256(file_bytes), payload_file$content_sha256)
api/tests/testthat/test-integration-analysis-release-endpoints.R-275-  # The per-file route sets its (per-file) media type by assigning a dynamic
api/tests/testthat/test-integration-analysis-release-endpoints.R:276:  # octet serializer to res$serializer (avoiding a duplicate Content-Type); the
api/tests/testthat/test-integration-analysis-release-endpoints.R-277-  # handler-extraction harness can at least confirm the handler installed it.
api/tests/testthat/test-integration-analysis-release-endpoints.R-278-  expect_true(is.function(file_res$serializer))
api/tests/testthat/test-integration-analysis-release-endpoints.R-279-
--
api/tests/testthat/test-integration-analysis-release-endpoints.R-336-  expect_lt(latest_idx[[1L]], detail_idx[[1L]])
api/tests/testthat/test-integration-analysis-release-endpoints.R-337-})
api/tests/testthat/test-integration-analysis-release-endpoints.R-338-
api/tests/testthat/test-integration-analysis-release-endpoints.R:339:test_that("byte-serving release routes set Content-Type via the serializer, never a duplicate manual header", {
api/tests/testthat/test-integration-analysis-release-endpoints.R-340-  # Regression guard (found in live dev-stack verification): combining
api/tests/testthat/test-integration-analysis-release-endpoints.R-341-  # `@serializer octet` with a manual res$setHeader("Content-Type", ...) emits
api/tests/testthat/test-integration-analysis-release-endpoints.R-342-  # TWO Content-Type headers (the serializer's application/octet-stream + the
--
api/tests/testthat/test-integration-analysis-release-endpoints.R-347-  src <- readLines(file.path("endpoints", "analysis_endpoints.R"), warn = FALSE)
api/tests/testthat/test-integration-analysis-release-endpoints.R-348-  joined <- paste(src, collapse = "\n")
api/tests/testthat/test-integration-analysis-release-endpoints.R-349-
api/tests/testthat/test-integration-analysis-release-endpoints.R:350:  # No release route may manually set Content-Type (it duplicates the serializer's).
api/tests/testthat/test-integration-analysis-release-endpoints.R-351-  expect_false(
api/tests/testthat/test-integration-analysis-release-endpoints.R-352-    any(grepl("setHeader\\(\\s*[\"']Content-Type[\"']", src)),
api/tests/testthat/test-integration-analysis-release-endpoints.R:353:    info = "a release byte-route sets Content-Type manually -> duplicate header"
api/tests/testthat/test-integration-analysis-release-endpoints.R-354-  )
api/tests/testthat/test-integration-analysis-release-endpoints.R-355-  # manifest.json + bundle carry the type on the serializer annotation.
api/tests/testthat/test-integration-analysis-release-endpoints.R-356-  expect_true(grepl('@serializer octet list(type = "application/json")', joined, fixed = TRUE))
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-56-                          input_hash = analysis_release_sha256(paste0(analysis_type, "-input")),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-57-                          schema_version = "1.2",
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-58-                          source_versions_json = NA_character_,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:59:                          db_release_version = DB_RELEASE_VERSION,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:60:                          db_release_commit = DB_RELEASE_COMMIT) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-61-  data.frame(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-62-    analysis_type = analysis_type,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-63-    snapshot_id = as.integer(snapshot_id),
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-66-    source_data_version = source_data_version,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-67-    schema_version = schema_version,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-68-    source_versions_json = source_versions_json,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:69:    db_release_version = db_release_version,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:70:    db_release_commit = db_release_commit,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-71-    stringsAsFactors = FALSE
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-72-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-73-}
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-170-    return(NULL)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-171-  }
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-172-  row <- data.frame(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:173:    kind = b$kind, reproducibility_hash = b$reproducibility_hash,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-174-    byte_size = b$byte_size, stringsAsFactors = FALSE
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-175-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-176-  row$bundle_gzip_json <- list(b$bundle_gzip_json) # DBI blob column shape: list-of-raw
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-312-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-313-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-314-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:315:test_that("build rejects a reproducibility bundle whose bytes do not hash to reproducibility_hash (H2)", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:316:  # The stored reproducibility_hash is present but LIES about the bytes (corrupt/restored bundle).
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-317-  corrupt_repro_loader <- function(snapshot_id, conn = NULL) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-318-    row <- present_repro_loader(snapshot_id, conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-319-    if (is.null(row)) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-320-      return(NULL)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-321-    }
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:322:    row$reproducibility_hash <- analysis_release_sha256("this-hash-does-not-match-the-bytes")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-323-    row
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-324-  }
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-325-  expect_error(
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-341-      loader = make_loader(), reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-342-      coherence_assert = pass_coherence, lock_acquire = failing_lock
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-343-    ),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:344:    class = "release_lock_unavailable"
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-345-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-346-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-347-
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-430-    expect_match(release_id, "^asr_[0-9a-f]{16}$")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-431-    expect_equal(result$release$status, "published")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-432-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:433:    # reproducibility.json hashes EXACTLY to the stored reproducibility_hash
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-434-    # (materialized from the raw pre-gzip bytes, not a parse round-trip).
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-435-    rf <- analysis_release_get_file(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-436-      release_id, "functional_clusters/reproducibility.json",
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-437-      include_draft = TRUE, conn = conn
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-438-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-439-    expect_false(is.null(rf))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:440:    expect_identical(rf$content_sha256, FUNC_BUNDLE$reproducibility_hash)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-441-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-442-    # manifest per-layer payload_hash is the cross-checkable LINEAGE ANCHOR
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-443-    # (== the source snapshot's payload_hash), NOT the payload.json file hash.
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-445-    manifest <- jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-446-    fc <- Filter(function(l) identical(l$analysis_type, "functional_clusters"), manifest$layers)[[1]]
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-447-    expect_identical(fc$payload_hash, FUNC_HASH)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:448:    expect_identical(fc$reproducibility_hash, FUNC_BUNDLE$reproducibility_hash)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-449-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-450-    payload_file <- analysis_release_get_file(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-451-      release_id, "functional_clusters/payload.json",
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-470-  })
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-471-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-472-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:473:test_that("build is idempotent by content: same sources -> same release_id, no duplicate row", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-474-  with_release_build_db(function(conn) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-475-    args <- list(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-476-      conn = conn, publish = TRUE,
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-516-      loader = make_loader(), reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-517-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-518-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:519:    expect_equal(result$release$db_release_version, DB_RELEASE_VERSION)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:520:    expect_equal(result$release$db_release_commit, DB_RELEASE_COMMIT)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-521-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-522-    manifest_file <- analysis_release_get_file(result$release$release_id, "manifest.json", include_draft = TRUE, conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-523-    manifest <- jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:524:    expect_equal(manifest$source$db_release$version, DB_RELEASE_VERSION)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:525:    expect_equal(manifest$source$db_release$commit, DB_RELEASE_COMMIT)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-526-  })
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-527-})
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-528-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:529:test_that("insert duplicate-key race resolves to idempotent created=FALSE, no double insert (H3b)", {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-530-  with_release_build_db(function(conn) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-531-    # The inserter simulates the concurrent WINNER: it stores the identical
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-532-    # release, then this build's own insert loses the PK race (dup-key error).
--
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-28-# POST /releases (build) is tested against a STUBBED
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-29-# analysis_snapshot_release_build() (real snapshot-backed building is
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-30-# integration-tested in A4's own test file and end-to-end in the dev-stack;
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:31:# seeding the full analysis_snapshot_* source tables here would duplicate
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-32-# that coverage for no benefit). The stub is bound into .GlobalEnv the same
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-33-# way `pool` is -- assign + withr::defer(rm(...)).
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-34-#
--
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-130-    input_hash = analysis_release_sha256("functional_clusters-input"),
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-131-    payload_hash = analysis_release_sha256("functional_clusters-payload"),
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-132-    schema_version = "1.2",
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:133:    reproducibility_hash = analysis_release_sha256("functional_clusters-repro"),
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-134-    role = "layer"
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-135-  )
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-136-}
--
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-253-# POST /releases (stubbed orchestrator)
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-254-# =============================================================================
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-255-
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:256:test_that("POST /releases: 201 on a new build, 200 on an idempotent duplicate, 400 naming the failing layer on a gate error", {
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-257-  skip_if_no_test_db()
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-258-
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-259-  admin_pool <- make_test_pool()
--
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-274-  expect_equal(res_new$status, 201L)
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-275-  expect_identical(out_new, head_new)
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-276-
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:277:  # --- 200: idempotent duplicate ---------------------------------------------
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-278-  head_dup <- list(release_id = "asr_admin_dup", status = "published")
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-279-  assign("analysis_snapshot_release_build", function(...) list(release = head_dup, created = FALSE), envir = .GlobalEnv)
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-280-  res_dup <- release_endpoint_fake_res()
--
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-35-# Identity stand-in for the PUBLIC projection: the REAL allowlist behaviour is
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-36-# covered against the real function in the repository integration test; here the
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-37-# service tests only verify svc_release_list/get ROUTE through it.
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:38:analysis_release_public_head <- function(head) head
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-39-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-40-source_api_file("services/analysis-snapshot-release-service.R", local = FALSE)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-41-
--
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-218-  )
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-219-})
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-220-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:221:test_that("build maps release_lock_unavailable to a 503 + Retry-After (NOT a 400)", {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-222-  res <- release_fake_res()
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-223-  with_release_mocks(
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-224-    list(analysis_snapshot_release_build = function(...) {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:225:      stop(release_condition("release_lock_unavailable", "sources are being refreshed; retry shortly"))
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-226-    }),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-227-    {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-228-      out <- svc_release_build(res)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-229-      expect_equal(res$status, 503L)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-230-      expect_equal(res$headers[["Retry-After"]], "5")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:231:      expect_equal(out$error, "release_lock_unavailable")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-232-      expect_match(out$message, "refreshed", fixed = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-233-    }
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-234-  )
--
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-385-  )
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-386-})
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-387-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:388:test_that("list: clamps limit to [1,100] and offset to >=0 (L1)", {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-389-  captured <- NULL
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-390-  capture_loader <- function(status, limit, offset, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-391-    captured <<- list(limit = limit, offset = offset)
--
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-405-  })
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-406-})
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-407-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:408:test_that("list + get route heads through analysis_release_public_head (H1)", {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-409-  marker <- list(release_id = "asr_projected", projected = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-410-  with_release_mocks(
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-411-    list(
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:412:      analysis_release_list = function(...) list(list(release_id = "asr_raw", created_by_user_id = 9L)),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:413:      analysis_release_get = function(...) list(release_id = "asr_raw", created_by_user_id = 9L),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:414:      analysis_release_public_head = function(head) marker
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-415-    ),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-416-    {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-417-      expect_identical(svc_release_list()[[1]], marker)
--
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-18-# B1: `layers` is a SELECTION, never a policy redefinition.
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-19-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-20-
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:21:test_that("resolve_layers returns the full registry when nothing is requested", {
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:22:  expect_identical(analysis_snapshot_release_resolve_layers(NULL), analysis_snapshot_release_layers())
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:23:  expect_identical(analysis_snapshot_release_resolve_layers(list()), analysis_snapshot_release_layers())
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-24-})
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-25-
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:26:test_that("resolve_layers ignores caller policy fields and returns REGISTRY entries", {
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-27-  registry <- analysis_snapshot_release_layers()
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-28-  reg_functional <- Filter(function(l) identical(l$analysis_type, "functional_clusters"), registry)[[1]]
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-29-
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-30-  # A hostile selector: tries to disable the reproducibility gate + path-traverse.
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:31:  resolved <- analysis_snapshot_release_resolve_layers(list(
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-32-    list(analysis_type = "functional_clusters", has_reproducibility = FALSE, files_prefix = "../evil", params = list(x = 1))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-33-  ))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-34-  expect_length(resolved, 1L)
--
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-37-  expect_identical(resolved[[1]]$params, reg_functional$params)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-38-})
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-39-
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:40:test_that("resolve_layers accepts a bare-string selector and preserves request order", {
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:41:  resolved <- analysis_snapshot_release_resolve_layers(list("phenotype_clusters", "functional_clusters"))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-42-  expect_equal(
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-43-    vapply(resolved, function(l) l$analysis_type, character(1)),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-44-    c("phenotype_clusters", "functional_clusters")
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-45-  )
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-46-})
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-47-
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:48:test_that("resolve_layers rejects an unknown or duplicate analysis_type with 400", {
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-49-  expect_error(
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:50:    analysis_snapshot_release_resolve_layers(list(list(analysis_type = "not_a_layer"))),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-51-    class = "error_400"
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-52-  )
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-53-  expect_error(
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:54:    analysis_snapshot_release_resolve_layers(list("functional_clusters", "functional_clusters")),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-55-    class = "error_400"
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-56-  )
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-57-})
--
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-118-
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-119-test_that("content_digest and release_id are pure functions of scientific content", {
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-120-  entries <- list(
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:121:    list(analysis_type = "functional_clusters", input_hash = "a", payload_hash = "b", reproducibility_hash = "c", dependencies = NULL),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:122:    list(analysis_type = "phenotype_clusters", input_hash = "d", payload_hash = "e", reproducibility_hash = "f", dependencies = NULL)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-123-  )
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-124-  d1 <- analysis_release_content_digest(entries, "srcv1", "1.0")
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-125-  d2 <- analysis_release_content_digest(rev(entries), "srcv1", "1.0") # order-independent (sorted internally)

exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R | sed -n '1,180p'
nl -ba api/tests/testthat/test-integration-analysis-snapshot-release-build.R | sed -n '260,360p'
nl -ba api/tests/testthat/test-integration-analysis-snapshot-release-build.R | sed -n '500,560p'
nl -ba api/tests/testthat/test-integration-analysis-release-repository.R | sed -n '220,313p'
nl -ba api/tests/testthat/test-unit-analysis-snapshot-release-service.R | sed -n '200,240p;380,435p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
     1	# Unit tests for the pure, DB-free analysis-snapshot RELEASE manifest +
     2	# content-address + canonical-archive helpers (#573 Slice A / Task A2).
     3	#
     4	# These functions define release IDENTITY (content_digest / release_id) and
     5	# produce the release manifest.json, checksums.sha256 text, and tar.gz
     6	# archive consumed by later tasks (repository persistence, build
     7	# orchestrator). Pure unit test: no database, runs anywhere.
     8	
     9	analysis_release_manifest_test_wd <- getwd()
    10	setwd(get_api_dir())
    11	withr::defer(setwd(analysis_release_manifest_test_wd), testthat::teardown_env())
    12	
    13	source(file.path("core", "errors.R"), local = TRUE)
    14	source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
    15	source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = TRUE)
    16	
    17	# --------------------------------------------------------------------------- #
    18	# B1: `layers` is a SELECTION, never a policy redefinition.
    19	# --------------------------------------------------------------------------- #
    20	
    21	test_that("resolve_layers returns the full registry when nothing is requested", {
    22	  expect_identical(analysis_snapshot_release_resolve_layers(NULL), analysis_snapshot_release_layers())
    23	  expect_identical(analysis_snapshot_release_resolve_layers(list()), analysis_snapshot_release_layers())
    24	})
    25	
    26	test_that("resolve_layers ignores caller policy fields and returns REGISTRY entries", {
    27	  registry <- analysis_snapshot_release_layers()
    28	  reg_functional <- Filter(function(l) identical(l$analysis_type, "functional_clusters"), registry)[[1]]
    29	
    30	  # A hostile selector: tries to disable the reproducibility gate + path-traverse.
    31	  resolved <- analysis_snapshot_release_resolve_layers(list(
    32	    list(analysis_type = "functional_clusters", has_reproducibility = FALSE, files_prefix = "../evil", params = list(x = 1))
    33	  ))
    34	  expect_length(resolved, 1L)
    35	  expect_identical(resolved[[1]]$files_prefix, reg_functional$files_prefix)
    36	  expect_true(resolved[[1]]$has_reproducibility) # registry value, NOT the caller's FALSE
    37	  expect_identical(resolved[[1]]$params, reg_functional$params)
    38	})
    39	
    40	test_that("resolve_layers accepts a bare-string selector and preserves request order", {
    41	  resolved <- analysis_snapshot_release_resolve_layers(list("phenotype_clusters", "functional_clusters"))
    42	  expect_equal(
    43	    vapply(resolved, function(l) l$analysis_type, character(1)),
    44	    c("phenotype_clusters", "functional_clusters")
    45	  )
    46	})
    47	
    48	test_that("resolve_layers rejects an unknown or duplicate analysis_type with 400", {
    49	  expect_error(
    50	    analysis_snapshot_release_resolve_layers(list(list(analysis_type = "not_a_layer"))),
    51	    class = "error_400"
    52	  )
    53	  expect_error(
    54	    analysis_snapshot_release_resolve_layers(list("functional_clusters", "functional_clusters")),
    55	    class = "error_400"
    56	  )
    57	})
    58	
    59	test_that("build_tar_gz rejects a path-traversal archive path", {
    60	  expect_error(
    61	    analysis_release_build_tar_gz(list("../x.json" = charToRaw("{}"))),
    62	    "unsafe release file path"
    63	  )
    64	  expect_error(
    65	    analysis_release_build_tar_gz(list("/etc/passwd" = charToRaw("x"))),
    66	    "unsafe release file path"
    67	  )
    68	})
    69	
    70	test_that("release manifest module exposes the expected public API", {
    71	  expect_true(is.character(ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION))
    72	  expect_equal(ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION, "1.0")
    73	  expect_true(exists("analysis_snapshot_release_layers", mode = "function"))
    74	  expect_true(exists("analysis_release_canonical_bytes", mode = "function"))
    75	  expect_true(exists("analysis_release_sha256", mode = "function"))
    76	  expect_true(exists("analysis_release_content_digest", mode = "function"))
    77	  expect_true(exists("analysis_release_id", mode = "function"))
    78	  expect_true(exists("analysis_release_build_manifest", mode = "function"))
    79	  expect_true(exists("analysis_release_checksums_text", mode = "function"))
    80	  expect_true(exists("analysis_release_build_tar_gz", mode = "function"))
    81	})
    82	
    83	test_that("analysis_snapshot_release_layers() registers the 3 default analysis layers", {
    84	  layers <- analysis_snapshot_release_layers()
    85	  expect_equal(length(layers), 3)
    86	
    87	  types <- vapply(layers, `[[`, character(1), "analysis_type")
    88	  expect_equal(types, c("functional_clusters", "phenotype_clusters", "phenotype_functional_correlations"))
    89	
    90	  functional <- layers[[1]]
    91	  expect_equal(functional$params, list(algorithm = "leiden"))
    92	  expect_equal(functional$files_prefix, "functional_clusters")
    93	  expect_true(functional$has_reproducibility)
    94	
    95	  phenotype <- layers[[2]]
    96	  expect_equal(phenotype$params, list())
    97	  expect_true(phenotype$has_reproducibility)
    98	
    99	  correlations <- layers[[3]]
   100	  expect_equal(correlations$params, list(algorithm = "leiden"))
   101	  expect_false(correlations$has_reproducibility)
   102	})
   103	
   104	test_that("analysis_release_sha256 accepts raw and character and agrees on the same bytes", {
   105	  from_chr <- analysis_release_sha256("hello")
   106	  from_raw <- analysis_release_sha256(charToRaw("hello"))
   107	  expect_identical(from_chr, from_raw)
   108	  expect_match(from_chr, "^[0-9a-f]{64}$")
   109	})
   110	
   111	test_that("analysis_release_canonical_bytes reuses the shared canonical serializer", {
   112	  obj <- list(b = 2, a = 1)
   113	  expect_identical(
   114	    analysis_release_canonical_bytes(obj),
   115	    charToRaw(enc2utf8(analysis_snapshot_canonical_json(obj)))
   116	  )
   117	})
   118	
   119	test_that("content_digest and release_id are pure functions of scientific content", {
   120	  entries <- list(
   121	    list(analysis_type = "functional_clusters", input_hash = "a", payload_hash = "b", reproducibility_hash = "c", dependencies = NULL),
   122	    list(analysis_type = "phenotype_clusters", input_hash = "d", payload_hash = "e", reproducibility_hash = "f", dependencies = NULL)
   123	  )
   124	  d1 <- analysis_release_content_digest(entries, "srcv1", "1.0")
   125	  d2 <- analysis_release_content_digest(rev(entries), "srcv1", "1.0") # order-independent (sorted internally)
   126	  expect_identical(d1, d2)
   127	  expect_match(analysis_release_id(d1), "^asr_[0-9a-f]{16}$")
   128	  # created_at / title do NOT affect identity:
   129	  expect_false(identical(d1, analysis_release_content_digest(entries, "srcv2", "1.0")))
   130	})
   131	
   132	test_that("analysis_release_build_manifest excludes manifest.json and checksums.sha256 from files[]", {
   133	  files <- list(
   134	    list(path = "manifest.json", sha256 = "111", bytes = 3L),
   135	    list(path = "a/payload.json", sha256 = "222", bytes = 5L),
   136	    list(path = "checksums.sha256", sha256 = "333", bytes = 9L)
   137	  )
   138	  manifest <- analysis_release_build_manifest(list(
   139	    release_id = "asr_deadbeefcafebabe",
   140	    release_version = "2026-07-18",
   141	    title = "SysNDD Analysis Release",
   142	    created_at = "2026-07-18T00:00:00Z",
   143	    license = "CC-BY-4.0",
   144	    scope_statement = "default analysis layers",
   145	    generator = "sysndd-api",
   146	    source = list(source_data_version = "srcv1"),
   147	    layers = list(),
   148	    files = files,
   149	    content_digest = "deadbeef"
   150	  ))
   151	
   152	  paths <- vapply(manifest$files, `[[`, character(1), "path")
   153	  expect_equal(paths, "a/payload.json")
   154	  expect_equal(manifest$release_id, "asr_deadbeefcafebabe")
   155	  expect_equal(manifest$content_digest, "deadbeef")
   156	})
   157	
   158	test_that("checksums text lists every file except checksums.sha256", {
   159	  files <- list(
   160	    list(path = "manifest.json", sha256 = "111", bytes = 3L),
   161	    list(path = "a/payload.json", sha256 = "222", bytes = 5L),
   162	    list(path = "checksums.sha256", sha256 = "333", bytes = 9L)
   163	  )
   164	  txt <- analysis_release_checksums_text(files)
   165	  expect_match(txt, "111  manifest.json")
   166	  expect_match(txt, "222  a/payload.json")
   167	  expect_false(grepl("checksums.sha256", txt, fixed = TRUE))
   168	})
   169	
   170	test_that("tar.gz round-trips: untar yields exactly the input files/bytes", {
   171	  payload <- list("a/x.json" = charToRaw("{\"k\":1}"), "manifest.json" = charToRaw("{}"))
   172	  gz <- analysis_release_build_tar_gz(payload)
   173	  d <- tempfile()
   174	  dir.create(d)
   175	  tarfile <- file.path(d, "b.tar")
   176	  writeBin(memDecompress(gz, type = "gzip"), tarfile)
   177	  utils::untar(tarfile, exdir = d)
   178	  expect_identical(readBin(file.path(d, "a/x.json"), "raw", 64L), payload[["a/x.json"]])
   179	  expect_identical(readBin(file.path(d, "manifest.json"), "raw", 64L), payload[["manifest.json"]])
   180	})
   260	    present_repro_loader(snapshot_id, conn)
   261	  }
   262	  expect_error(
   263	    analysis_snapshot_release_build(
   264	      conn = NULL, publish = TRUE,
   265	      loader = make_loader(), reproducibility_loader = missing_repro_loader,
   266	      coherence_assert = pass_coherence
   267	    ),
   268	    class = "release_reproducibility_missing"
   269	  )
   270	})
   271	
   272	test_that("build refuses layers that do not share one source_data_version", {
   273	  loader <- make_loader(list(
   274	    phenotype_clusters = make_cluster_snap(
   275	      "phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH,
   276	      source_data_version = "srcv-DIFFERENT"
   277	    )
   278	  ))
   279	  expect_error(
   280	    analysis_snapshot_release_build(
   281	      conn = NULL, publish = TRUE,
   282	      loader = loader, reproducibility_loader = present_repro_loader,
   283	      coherence_assert = pass_coherence
   284	    ),
   285	    class = "release_source_version_mismatch"
   286	  )
   287	})
   288	
   289	test_that("build refuses a correlation snapshot whose dependency lineage is stale", {
   290	  # Correlation manifest pins a functional snapshot_id that no longer matches.
   291	  loader <- make_loader(list(
   292	    phenotype_functional_correlations = make_corr_snap(func_id = 999L)
   293	  ))
   294	  expect_error(
   295	    analysis_snapshot_release_build(
   296	      conn = NULL, publish = TRUE,
   297	      loader = loader, reproducibility_loader = present_repro_loader,
   298	      coherence_assert = pass_coherence
   299	    ),
   300	    class = "release_dependency_lineage_mismatch"
   301	  )
   302	})
   303	
   304	test_that("build rejects an unknown requested layer (selection, not redefinition) with 400", {
   305	  expect_error(
   306	    analysis_snapshot_release_build(
   307	      conn = NULL, publish = TRUE, layers = list(list(analysis_type = "not_a_layer")),
   308	      loader = make_loader(), reproducibility_loader = present_repro_loader,
   309	      coherence_assert = pass_coherence
   310	    ),
   311	    class = "error_400"
   312	  )
   313	})
   314	
   315	test_that("build rejects a reproducibility bundle whose bytes do not hash to reproducibility_hash (H2)", {
   316	  # The stored reproducibility_hash is present but LIES about the bytes (corrupt/restored bundle).
   317	  corrupt_repro_loader <- function(snapshot_id, conn = NULL) {
   318	    row <- present_repro_loader(snapshot_id, conn)
   319	    if (is.null(row)) {
   320	      return(NULL)
   321	    }
   322	    row$reproducibility_hash <- analysis_release_sha256("this-hash-does-not-match-the-bytes")
   323	    row
   324	  }
   325	  expect_error(
   326	    analysis_snapshot_release_build(
   327	      conn = NULL, publish = TRUE,
   328	      loader = make_loader(), reproducibility_loader = corrupt_repro_loader,
   329	      coherence_assert = pass_coherence
   330	    ),
   331	    class = "release_reproducibility_missing"
   332	  )
   333	})
   334	
   335	test_that("build refuses to proceed unlocked when the advisory lock cannot be acquired (H3a)", {
   336	  # Inject a lock seam that reports acquisition FAILED (a source preset is mid-refresh).
   337	  failing_lock <- function(conn, lock_names) list(ok = FALSE, acquired = character(0), skipped = FALSE)
   338	  expect_error(
   339	    analysis_snapshot_release_build(
   340	      conn = NULL, publish = TRUE,
   341	      loader = make_loader(), reproducibility_loader = present_repro_loader,
   342	      coherence_assert = pass_coherence, lock_acquire = failing_lock
   343	    ),
   344	    class = "release_lock_unavailable"
   345	  )
   346	})
   347	
   348	test_that("build refuses a functional snapshot whose served channel != validation channel", {
   349	  # Real coherence default reads validation_json; membership (combined_score) was
   350	  # clustered on a different STRING channel than the validation scored (exp+db).
   351	  loader <- make_loader(list(
   352	    functional_clusters = make_functional_snap_with_channels(
   353	      membership_channel = "combined_score", validation_channel = "experimental_database"
   354	    )
   355	  ))
   356	  expect_error(
   357	    analysis_snapshot_release_build(
   358	      conn = NULL, publish = TRUE,
   359	      loader = loader, reproducibility_loader = present_repro_loader,
   360	      coherence_assert = analysis_snapshot_release_assert_coherent # the REAL default
   500	        conn = conn, publish = TRUE,
   501	        loader = make_stateful_loader("functional_clusters"),
   502	        reproducibility_loader = present_repro_loader,
   503	        coherence_assert = pass_coherence
   504	      ),
   505	      class = "release_dependency_lineage_mismatch"
   506	    )
   507	    # nothing was persisted (the mismatch fired before insert):
   508	    expect_identical(0L, length(analysis_release_list(status = "published", conn = conn)))
   509	  })
   510	})
   511	
   512	test_that("build head + manifest carry the DB release provenance from the source snapshots (M1)", {
   513	  with_release_build_db(function(conn) {
   514	    result <- analysis_snapshot_release_build(
   515	      conn = conn, publish = TRUE,
   516	      loader = make_loader(), reproducibility_loader = present_repro_loader,
   517	      coherence_assert = pass_coherence
   518	    )
   519	    expect_equal(result$release$db_release_version, DB_RELEASE_VERSION)
   520	    expect_equal(result$release$db_release_commit, DB_RELEASE_COMMIT)
   521	
   522	    manifest_file <- analysis_release_get_file(result$release$release_id, "manifest.json", include_draft = TRUE, conn = conn)
   523	    manifest <- jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE)
   524	    expect_equal(manifest$source$db_release$version, DB_RELEASE_VERSION)
   525	    expect_equal(manifest$source$db_release$commit, DB_RELEASE_COMMIT)
   526	  })
   527	})
   528	
   529	test_that("insert duplicate-key race resolves to idempotent created=FALSE, no double insert (H3b)", {
   530	  with_release_build_db(function(conn) {
   531	    # The inserter simulates the concurrent WINNER: it stores the identical
   532	    # release, then this build's own insert loses the PK race (dup-key error).
   533	    dup_inserter <- function(head, members, files, conn) {
   534	      analysis_release_insert(head, members, files, conn)
   535	      stop("Duplicate entry 'asr_xxxx' for key 'PRIMARY'")
   536	    }
   537	    result <- analysis_snapshot_release_build(
   538	      conn = conn, publish = TRUE,
   539	      loader = make_loader(), reproducibility_loader = present_repro_loader,
   540	      coherence_assert = pass_coherence, inserter = dup_inserter
   541	    )
   542	    expect_false(result$created)
   543	    expect_match(result$release$release_id, "^asr_[0-9a-f]{16}$")
   544	    # exactly one row total -- the release was NOT double-inserted:
   545	    expect_identical(1L, length(analysis_release_list(status = NULL, conn = conn)))
   546	  })
   547	})
   548	
   549	test_that("build with publish = FALSE leaves a draft (not visible as published)", {
   550	  with_release_build_db(function(conn) {
   551	    result <- analysis_snapshot_release_build(
   552	      conn = conn, publish = FALSE,
   553	      loader = make_loader(), reproducibility_loader = present_repro_loader,
   554	      coherence_assert = pass_coherence
   555	    )
   556	    expect_true(result$created)
   557	    expect_equal(result$release$status, "draft")
   558	    expect_identical(0L, length(analysis_release_list(status = "published", conn = conn)))
   559	  })
   560	})
nl: api/tests/testthat/test-integration-analysis-release-repository.R: No such file or directory
   200	      err <- tryCatch(svc_release_build(res), error = function(e) e)
   201	      expect_s3_class(err, "error_400")
   202	      expect_match(conditionMessage(err), "v1 vs v2", fixed = TRUE)
   203	    }
   204	  )
   205	})
   206	
   207	test_that("build maps release_dependency_lineage_mismatch to a 400 carrying the reason", {
   208	  res <- release_fake_res()
   209	  msg <- release_build_condition_cases$release_dependency_lineage_mismatch
   210	  with_release_mocks(
   211	    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_dependency_lineage_mismatch", msg))),
   212	    {
   213	      err <- tryCatch(svc_release_build(res), error = function(e) e)
   214	      expect_s3_class(err, "error_400")
   215	      expect_match(conditionMessage(err), "phenotype_functional_correlations", fixed = TRUE)
   216	      expect_match(conditionMessage(err), "changed between read and insert", fixed = TRUE)
   217	    }
   218	  )
   219	})
   220	
   221	test_that("build maps release_lock_unavailable to a 503 + Retry-After (NOT a 400)", {
   222	  res <- release_fake_res()
   223	  with_release_mocks(
   224	    list(analysis_snapshot_release_build = function(...) {
   225	      stop(release_condition("release_lock_unavailable", "sources are being refreshed; retry shortly"))
   226	    }),
   227	    {
   228	      out <- svc_release_build(res)
   229	      expect_equal(res$status, 503L)
   230	      expect_equal(res$headers[["Retry-After"]], "5")
   231	      expect_equal(out$error, "release_lock_unavailable")
   232	      expect_match(out$message, "refreshed", fixed = TRUE)
   233	    }
   234	  )
   235	})
   236	
   237	test_that("build lets a non-release_* error propagate unmapped (500 path)", {
   238	  res <- release_fake_res()
   239	  with_release_mocks(
   240	    list(analysis_snapshot_release_build = function(...) stop("boom: unexpected DB error")),
   380	      expect_identical(out, rows) # identity projection stub -> verbatim
   381	      expect_equal(captured$status, "published")
   382	      expect_equal(captured$limit, 10L)
   383	      expect_equal(captured$offset, 5L)
   384	    }
   385	  )
   386	})
   387	
   388	test_that("list: clamps limit to [1,100] and offset to >=0 (L1)", {
   389	  captured <- NULL
   390	  capture_loader <- function(status, limit, offset, conn = NULL) {
   391	    captured <<- list(limit = limit, offset = offset)
   392	    list()
   393	  }
   394	  cases <- list(
   395	    list(in_limit = -1, in_offset = -5, out_limit = 1L, out_offset = 0L),
   396	    list(in_limit = 1e6, in_offset = 10, out_limit = 100L, out_offset = 10L),
   397	    list(in_limit = "abc", in_offset = "xyz", out_limit = 50L, out_offset = 0L)
   398	  )
   399	  with_release_mocks(list(analysis_release_list = capture_loader), {
   400	    for (case in cases) {
   401	      svc_release_list(limit = case$in_limit, offset = case$in_offset)
   402	      expect_equal(captured$limit, case$out_limit)
   403	      expect_equal(captured$offset, case$out_offset)
   404	    }
   405	  })
   406	})
   407	
   408	test_that("list + get route heads through analysis_release_public_head (H1)", {
   409	  marker <- list(release_id = "asr_projected", projected = TRUE)
   410	  with_release_mocks(
   411	    list(
   412	      analysis_release_list = function(...) list(list(release_id = "asr_raw", created_by_user_id = 9L)),
   413	      analysis_release_get = function(...) list(release_id = "asr_raw", created_by_user_id = 9L),
   414	      analysis_release_public_head = function(head) marker
   415	    ),
   416	    {
   417	      expect_identical(svc_release_list()[[1]], marker)
   418	      expect_identical(svc_release_get("asr_raw"), marker)
   419	    }
   420	  )
   421	})
   422	
   423	# =============================================================================
   424	# svc_release_get (public)
   425	# =============================================================================
   426	
   427	test_that("get: draft or unknown (stub returns NULL) -> 404, and include_draft is FALSE", {
   428	  captured_include_draft <- NULL
   429	  with_release_mocks(
   430	    list(analysis_release_get = function(release_id, include_draft, conn = NULL) {
   431	      captured_include_draft <<- include_draft
   432	      NULL
   433	    }),
   434	    {
   435	      expect_error(svc_release_get("asr_draft_or_missing"), class = "error_404")

exec
/bin/bash -lc "nl -ba api/functions/analysis-reproducibility.R | sed -n '1,180p'
rg -n -C 3 'db_release_version|db_release_commit' api/functions/analysis-snapshot* api/functions/analysis-reproducibility.R api/tests/testthat/test-integration-analysis-snapshot-release-build.R
rg -n -C 3 'analysis_release_public_head|created_by_user_id|last_error_message|manifest\\"'$|layers'"' api/tests/testthat/test-integration-analysis-snapshot-release-repository.R api/tests/testthat/test-integration-analysis-release-endpoints.R api/tests/testthat/test-integration-analysis-release-admin-endpoints.R 2>/dev/null || true
find api/tests/testthat -maxdepth 1 -iname '*release*repository*' -printf '%f\\n'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
     1	# functions/analysis-reproducibility.R
     2	#
     3	# Self-reproducing cluster-snapshot bundles (#512). Worker/heavy-path only —
     4	# never invoked on a public request (the read endpoints below only decode a row
     5	# that a worker already persisted).
     6	#
     7	# Per clustering snapshot, this exports the inputs needed to INDEPENDENTLY
     8	# recompute the served separation metric:
     9	#   - functional: the full largest-connected-component (LCC) edge list
    10	#     (source, target, combined_score, exp_db_score?) + the COMPLETE membership
    11	#     (every community, incl. clusters below min_size) + params + served_modularity
    12	#   - phenotype:  the MCA coordinate matrix (entity_id, Dim.1..Dim.k) + membership
    13	#     (entity_id, cluster) + params (ncp, kk, consol, seed, prevalence band) +
    14	#     served_silhouette
    15	# plus a SHA-256 `reproducibility_hash` over the CANONICAL pre-gzip JSON so the
    16	# served validation numbers are verifiably tied to their inputs.
    17	#
    18	# The bundle serializer (`analysis_reproducibility_bundle`) is representation-
    19	# agnostic: it serializes whatever payload it is given, gzips it, and hashes the
    20	# pre-gzip JSON. The heavy payload builders (which call build_string_subgraph /
    21	# FactoMineR::MCA) are separated out so the snapshot builder stays thin.
    22	#
    23	# Deps: jsonlite, digest (serializer); igraph, FactoMineR (payload builders).
    24	
    25	if (!exists("%||%", mode = "function")) {
    26	  `%||%` <- function(x, y) if (is.null(x)) y else x
    27	}
    28	
    29	# Schema version of the bundle envelope itself (independent of the snapshot
    30	# schema version). Bump only if the bundle field layout changes.
    31	ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION <- "1.0"
    32	
    33	#' Canonical JSON for the reproducibility bundle.
    34	#'
    35	#' `digits = NA` keeps full numeric precision so a recomputation from the bundle
    36	#' matches the served metric bit-for-bit; `dataframe = "rows"` emits row objects.
    37	#' @noRd
    38	analysis_reproducibility_canonical_json <- function(value) {
    39	  as.character(jsonlite::toJSON(
    40	    value,
    41	    dataframe = "rows",
    42	    auto_unbox = TRUE,
    43	    digits = NA,
    44	    null = "null",
    45	    na = "null"
    46	  ))
    47	}
    48	
    49	analysis_reproducibility_rows <- function(df) {
    50	  if (is.null(df)) {
    51	    return(data.frame())
    52	  }
    53	  as.data.frame(df, stringsAsFactors = FALSE)
    54	}
    55	
    56	analysis_reproducibility_scalar_num <- function(x) {
    57	  if (is.null(x) || length(x) == 0L) {
    58	    return(NA_real_)
    59	  }
    60	  suppressWarnings(as.numeric(x[[1]]))
    61	}
    62	
    63	#' Assemble, gzip and hash a reproducibility bundle.
    64	#'
    65	#' Representation-agnostic: the payload carries the already-built inputs.
    66	#' - `kind = "functional"`: `payload$edges` (source/target/combined_score/
    67	#'   exp_db_score?), `payload$membership` (node/cluster), `payload$params`,
    68	#'   `payload$served_modularity`.
    69	#' - `kind = "phenotype"`: `payload$coords` (entity_id/Dim.*),
    70	#'   `payload$membership` (entity_id/cluster), `payload$params`,
    71	#'   `payload$served_silhouette`.
    72	#'
    73	#' @return list(kind, bundle_gzip_json = <raw gzip>, reproducibility_hash =
    74	#'   <64-char sha256 over the pre-gzip canonical JSON>, byte_size = <length of
    75	#'   the gzip blob>).
    76	#' @export
    77	analysis_reproducibility_bundle <- function(kind, payload) {
    78	  kind <- as.character(kind)[[1]]
    79	  payload <- payload %||% list()
    80	
    81	  if (identical(kind, "functional")) {
    82	    bundle_obj <- list(
    83	      schema_version = ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION,
    84	      kind = kind,
    85	      params = payload$params %||% list(),
    86	      edges = analysis_reproducibility_rows(payload$edges),
    87	      membership = analysis_reproducibility_rows(payload$membership),
    88	      served_modularity = analysis_reproducibility_scalar_num(payload$served_modularity)
    89	    )
    90	  } else if (identical(kind, "phenotype")) {
    91	    bundle_obj <- list(
    92	      schema_version = ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION,
    93	      kind = kind,
    94	      params = payload$params %||% list(),
    95	      coords = analysis_reproducibility_rows(payload$coords),
    96	      membership = analysis_reproducibility_rows(payload$membership),
    97	      served_silhouette = analysis_reproducibility_scalar_num(payload$served_silhouette)
    98	    )
    99	  } else {
   100	    stop(sprintf("Unsupported reproducibility bundle kind: %s", kind), call. = FALSE)
   101	  }
   102	
   103	  json <- analysis_reproducibility_canonical_json(bundle_obj)
   104	  gz <- memCompress(charToRaw(json), type = "gzip")
   105	  list(
   106	    kind = kind,
   107	    bundle_gzip_json = gz,
   108	    reproducibility_hash = digest::digest(json, algo = "sha256", serialize = FALSE),
   109	    byte_size = length(gz)
   110	  )
   111	}
   112	
   113	#' Decode a stored bundle blob back to the parsed JSON object.
   114	#'
   115	#' Accepts either a raw gzip vector or a DBI blob column value (list-of-raw).
   116	#' @export
   117	analysis_reproducibility_decode <- function(bundle_gzip_json) {
   118	  raw_blob <- bundle_gzip_json
   119	  if (is.list(raw_blob) && length(raw_blob) >= 1L) {
   120	    raw_blob <- raw_blob[[1]]
   121	  }
   122	  if (!is.raw(raw_blob)) {
   123	    stop("reproducibility bundle is not a raw gzip blob", call. = FALSE)
   124	  }
   125	  json <- memDecompress(raw_blob, type = "gzip", asChar = TRUE)
   126	  jsonlite::fromJSON(json, simplifyVector = TRUE)
   127	}
   128	
   129	#' Decode a stored bundle blob back to its RAW pre-gzip canonical-JSON string.
   130	#'
   131	#' Identical blob-unwrap to `analysis_reproducibility_decode()`, but returns the
   132	#' verbatim `memDecompress(..., asChar = TRUE)` string WITHOUT parsing. This is
   133	#' the exact byte content the `reproducibility_hash` was computed over
   134	#' (`digest::digest(json, algo = "sha256", serialize = FALSE)`), so
   135	#' `sha256(charToRaw(<this>)) == reproducibility_hash` bit-for-bit. The immutable
   136	#' release (#573) materializes `reproducibility.json` from THIS string, never from
   137	#' `analysis_reproducibility_decode()` — a parse + re-serialize round-trip drops
   138	#' the `digits = NA` precision and would break the content-address hash.
   139	#'
   140	#' Accepts either a raw gzip vector or a DBI blob column value (list-of-raw).
   141	#' @return chr(1), the pre-gzip canonical JSON.
   142	#' @export
   143	analysis_reproducibility_decode_raw <- function(bundle_gzip_json) {
   144	  raw_blob <- bundle_gzip_json
   145	  if (is.list(raw_blob) && length(raw_blob) >= 1L) {
   146	    raw_blob <- raw_blob[[1]]
   147	  }
   148	  if (!is.raw(raw_blob)) {
   149	    stop("reproducibility bundle is not a raw gzip blob", call. = FALSE)
   150	  }
   151	  memDecompress(raw_blob, type = "gzip", asChar = TRUE)
   152	}
   153	
   154	# --------------------------------------------------------------------------- #
   155	# Heavy payload builders (worker/heavy-path only).
   156	# --------------------------------------------------------------------------- #
   157	
   158	#' Build the functional reproducibility payload from the clustered graph.
   159	#'
   160	#' Reconstructs the byte-identical STRING subgraph via `build_string_subgraph`,
   161	#' restricts to the largest connected component (the connected substrate the
   162	#' modularity null is calibrated against), reclusters with the same seeded Leiden
   163	#' (`.leiden_membership`), and records the LCC modularity as `served_modularity`
   164	#' so a recomputation from the bundle reproduces it exactly.
   165	#' @noRd
   166	analysis_reproducibility_functional_payload <- function(hgnc_list, val = NULL, params = list(),
   167	                                                        score_threshold = 400, resolution = 1.0,
   168	                                                        seed = 42L) {
   169	  subgraph <- build_string_subgraph(hgnc_list, score_threshold)
   170	  lcc <- igraph::largest_component(subgraph)
   171	  membership_int <- .leiden_membership(lcc, resolution, seed)
   172	  served_modularity <- igraph::modularity(
   173	    lcc, membership_int,
   174	    weights = igraph::E(lcc)$combined_score
   175	  )
   176	
   177	  el <- igraph::as_data_frame(lcc, what = "edges")
   178	  edges <- data.frame(
   179	    source = as.character(el$from),
   180	    target = as.character(el$to),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-56-                          input_hash = analysis_release_sha256(paste0(analysis_type, "-input")),
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-57-                          schema_version = "1.2",
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-58-                          source_versions_json = NA_character_,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:59:                          db_release_version = DB_RELEASE_VERSION,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:60:                          db_release_commit = DB_RELEASE_COMMIT) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-61-  data.frame(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-62-    analysis_type = analysis_type,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-63-    snapshot_id = as.integer(snapshot_id),
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-66-    source_data_version = source_data_version,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-67-    schema_version = schema_version,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-68-    source_versions_json = source_versions_json,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:69:    db_release_version = db_release_version,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:70:    db_release_commit = db_release_commit,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-71-    stringsAsFactors = FALSE
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-72-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-73-}
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-516-      loader = make_loader(), reproducibility_loader = present_repro_loader,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-517-      coherence_assert = pass_coherence
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-518-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:519:    expect_equal(result$release$db_release_version, DB_RELEASE_VERSION)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:520:    expect_equal(result$release$db_release_commit, DB_RELEASE_COMMIT)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-521-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-522-    manifest_file <- analysis_release_get_file(result$release$release_id, "manifest.json", include_draft = TRUE, conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-523-    manifest <- jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE)
--
api/functions/analysis-snapshot-repository.R-115-         source_versions_json, source_data_version, parameters_json,
api/functions/analysis-snapshot-repository.R-116-         input_hash, payload_hash, algorithm_name, algorithm_version,
api/functions/analysis-snapshot-repository.R-117-         package_versions_json, row_counts_json, warnings_json, last_error_message,
api/functions/analysis-snapshot-repository.R:118:         validation_json, db_release_version, db_release_commit
api/functions/analysis-snapshot-repository.R-119-       ) VALUES (
api/functions/analysis-snapshot-repository.R-120-         ?, ?, ?, ?, ?, 0, ?, COALESCE(?, NOW(6)), ?,
api/functions/analysis-snapshot-repository.R-121-         ?, ?, ?, ?, ?, ?, ?,
--
api/functions/analysis-snapshot-repository.R-143-        analysis_snapshot_json(manifest$warnings),
api/functions/analysis-snapshot-repository.R-144-        analysis_snapshot_scalar(manifest$last_error_message, NA_character_),
api/functions/analysis-snapshot-repository.R-145-        analysis_snapshot_json(manifest$validation),                       # JSON column
api/functions/analysis-snapshot-repository.R:146:        analysis_snapshot_scalar(manifest$db_release_version, NA_character_),
api/functions/analysis-snapshot-repository.R:147:        analysis_snapshot_scalar(manifest$db_release_commit,  NA_character_)
api/functions/analysis-snapshot-repository.R-148-      )),
api/functions/analysis-snapshot-repository.R-149-      conn = manifest_conn
api/functions/analysis-snapshot-repository.R-150-    )
--
api/functions/analysis-snapshot-release.R-315-
api/functions/analysis-snapshot-release.R-316-  # M1: DB release provenance — carried on each pinned snapshot manifest. Take a
api/functions/analysis-snapshot-release.R-317-  # consistent value across layers (assert equal; else the first non-NA/non-empty).
api/functions/analysis-snapshot-release.R:318:  shared_db_release_version <- .analysis_release_consistent_manifest_value(loaded, "db_release_version")
api/functions/analysis-snapshot-release.R:319:  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit")
api/functions/analysis-snapshot-release.R-320-
api/functions/analysis-snapshot-release.R-321-  # For the correlation layer, pin the actual dependency lineage into its entry.
api/functions/analysis-snapshot-release.R-322-  corr <- loaded[["phenotype_functional_correlations"]]
--
api/functions/analysis-snapshot-release.R-422-    source = list(
api/functions/analysis-snapshot-release.R-423-      source_data_version = shared_source_version,
api/functions/analysis-snapshot-release.R-424-      db_release = list(
api/functions/analysis-snapshot-release.R:425:        version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
api/functions/analysis-snapshot-release.R:426:        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
api/functions/analysis-snapshot-release.R-427-      ),
api/functions/analysis-snapshot-release.R-428-      snapshots = lapply(layer_entries, function(e) {
api/functions/analysis-snapshot-release.R-429-        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
--
api/functions/analysis-snapshot-release.R-471-    bundle_sha256 = bundle_sha256,
api/functions/analysis-snapshot-release.R-472-    bundle_gzip = bundle_gzip,
api/functions/analysis-snapshot-release.R-473-    source_data_version = shared_source_version,
api/functions/analysis-snapshot-release.R:474:    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
api/functions/analysis-snapshot-release.R:475:    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
api/functions/analysis-snapshot-release.R-476-    scope_statement = scope_statement,
api/functions/analysis-snapshot-release.R-477-    license = license %||% "CC-BY-4.0",
api/functions/analysis-snapshot-release.R-478-    created_by_user_id = created_by
--
api/functions/analysis-snapshot-builder.R-516-    # surface is unavailable, store the literal "unknown" (never omit).
api/functions/analysis-snapshot-builder.R-517-    dbv <- tryCatch(db_version_get(conn = refresh_conn),
api/functions/analysis-snapshot-builder.R-518-                    error = function(e) list(version = "unknown", commit = "unknown", available = FALSE))
api/functions/analysis-snapshot-builder.R:519:    db_release_version <- if (isTRUE(dbv$available)) dbv$version %||% "unknown" else "unknown"
api/functions/analysis-snapshot-builder.R:520:    db_release_commit  <- if (isTRUE(dbv$available)) dbv$commit  %||% "unknown" else "unknown"
api/functions/analysis-snapshot-builder.R-521-    source_versions <- list(
api/functions/analysis-snapshot-builder.R-522-      sysndd_public_data = source_data_version,
api/functions/analysis-snapshot-builder.R:523:      db_release_version = db_release_version,
api/functions/analysis-snapshot-builder.R:524:      db_release_commit = db_release_commit
api/functions/analysis-snapshot-builder.R-525-    )
api/functions/analysis-snapshot-builder.R-526-    if (!is.null(payload$dependencies)) {
api/functions/analysis-snapshot-builder.R-527-      source_versions$dependencies <- payload$dependencies
--
api/functions/analysis-snapshot-builder.R-545-          algorithm_name = normalized$params$algorithm %||% normalized$params$cluster_type %||% NA_character_,
api/functions/analysis-snapshot-builder.R-546-          row_counts = row_counts,
api/functions/analysis-snapshot-builder.R-547-          validation = payload$partition_validation,   # NULL for non-clustering presets
api/functions/analysis-snapshot-builder.R:548:          db_release_version = db_release_version,
api/functions/analysis-snapshot-builder.R:549:          db_release_commit  = db_release_commit
api/functions/analysis-snapshot-builder.R-550-        ),
api/functions/analysis-snapshot-builder.R-551-        conn = txn_conn
api/functions/analysis-snapshot-builder.R-552-      )
--
api/functions/analysis-snapshot-release-materialize.R-58-#'
api/functions/analysis-snapshot-release-materialize.R-59-#' Returns the single distinct non-empty value when the layers agree, else the
api/functions/analysis-snapshot-release-materialize.R-60-#' FIRST non-NA/non-empty value (a benign provenance disagreement never blocks a
api/functions/analysis-snapshot-release-materialize.R:61:#' build). NA when no layer carries it. Used for `db_release_version`/`_commit`.
api/functions/analysis-snapshot-release-materialize.R-62-#' @noRd
api/functions/analysis-snapshot-release-materialize.R-63-.analysis_release_consistent_manifest_value <- function(loaded, field) {
api/functions/analysis-snapshot-release-materialize.R-64-  values <- vapply(
--
api/functions/analysis-snapshot-release-repository.R-62-.analysis_release_head_columns <- paste(
api/functions/analysis-snapshot-release-repository.R-63-  "release_id, release_version, title, status, manifest_schema_version,",
api/functions/analysis-snapshot-release-repository.R-64-  "content_digest, manifest_sha256, bundle_sha256, bundle_bytes,",
api/functions/analysis-snapshot-release-repository.R:65:  "source_data_version, db_release_version, db_release_commit, scope_statement,",
api/functions/analysis-snapshot-release-repository.R-66-  "license, file_count, total_bytes, created_by_user_id, created_at,",
api/functions/analysis-snapshot-release-repository.R-67-  "published_at, updated_at, zenodo_record_id, zenodo_record_url,",
api/functions/analysis-snapshot-release-repository.R-68-  "version_doi, concept_doi, last_error_message"
--
api/functions/analysis-snapshot-release-repository.R-84-#' `release_head` is a named list with (at least) `release_id`,
api/functions/analysis-snapshot-release-repository.R-85-#' `manifest_schema_version`, `content_digest`, `manifest_sha256`,
api/functions/analysis-snapshot-release-repository.R-86-#' `bundle_sha256`, `bundle_gzip` (raw), plus optional `release_version`,
api/functions/analysis-snapshot-release-repository.R:87:#' `title`, `source_data_version`, `db_release_version`, `db_release_commit`,
api/functions/analysis-snapshot-release-repository.R-88-#' `scope_statement`, `license` (defaults `"CC-BY-4.0"`),
api/functions/analysis-snapshot-release-repository.R-89-#' `created_by_user_id`. Always inserted with `status = 'draft'` —
api/functions/analysis-snapshot-release-repository.R-90-#' `analysis_release_publish()` is the only way to flip it.
--
api/functions/analysis-snapshot-release-repository.R-122-      "INSERT INTO analysis_snapshot_release (
api/functions/analysis-snapshot-release-repository.R-123-         release_id, release_version, title, status, manifest_schema_version,
api/functions/analysis-snapshot-release-repository.R-124-         content_digest, manifest_sha256, bundle_sha256, bundle_gzip, bundle_bytes,
api/functions/analysis-snapshot-release-repository.R:125:         source_data_version, db_release_version, db_release_commit, scope_statement,
api/functions/analysis-snapshot-release-repository.R-126-         license, file_count, total_bytes, created_by_user_id
api/functions/analysis-snapshot-release-repository.R-127-       ) VALUES (?, ?, ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
api/functions/analysis-snapshot-release-repository.R-128-      params = unname(list(
--
api/functions/analysis-snapshot-release-repository.R-136-        list(bundle_gzip),
api/functions/analysis-snapshot-release-repository.R-137-        length(bundle_gzip),
api/functions/analysis-snapshot-release-repository.R-138-        .analysis_release_chr(release_head$source_data_version),
api/functions/analysis-snapshot-release-repository.R:139:        .analysis_release_chr(release_head$db_release_version),
api/functions/analysis-snapshot-release-repository.R:140:        .analysis_release_chr(release_head$db_release_commit),
api/functions/analysis-snapshot-release-repository.R-141-        .analysis_release_chr(release_head$scope_statement),
api/functions/analysis-snapshot-release-repository.R-142-        release_head$license %||% "CC-BY-4.0",
api/functions/analysis-snapshot-release-repository.R-143-        as.integer(file_count),
--
api/functions/analysis-snapshot-release-repository.R-213-  allowlist <- c(
api/functions/analysis-snapshot-release-repository.R-214-    "release_id", "release_version", "title", "status", "content_digest",
api/functions/analysis-snapshot-release-repository.R-215-    "created_at", "published_at", "source_data_version",
api/functions/analysis-snapshot-release-repository.R:216:    "db_release_version", "db_release_commit", "manifest_sha256",
api/functions/analysis-snapshot-release-repository.R-217-    "bundle_sha256", "license", "file_count", "total_bytes"
api/functions/analysis-snapshot-release-repository.R-218-  )
api/functions/analysis-snapshot-release-repository.R-219-  projected <- head[intersect(allowlist, names(head))]
api/tests/testthat/test-integration-analysis-release-endpoints.R-227-  detail_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>\\s*$")
api/tests/testthat/test-integration-analysis-release-endpoints.R-228-  detail_result <- detail_handler(release_id = TEST_RELEASE_ID, res = release_endpoint_fake_res())
api/tests/testthat/test-integration-analysis-release-endpoints.R-229-  expect_equal(as.character(detail_result$release_id), TEST_RELEASE_ID)
api/tests/testthat/test-integration-analysis-release-endpoints.R:230:  expect_equal(detail_result$manifest$release_id, TEST_RELEASE_ID)
api/tests/testthat/test-integration-analysis-release-endpoints.R-231-
api/tests/testthat/test-integration-analysis-release-endpoints.R-232-  unknown_err <- tryCatch(
api/tests/testthat/test-integration-analysis-release-endpoints.R-233-    detail_handler(release_id = "asr_does_not_exist", res = release_endpoint_fake_res()),
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-140-  expect_equal(draft$status, "draft")
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-141-  expect_equal(draft$file_count, 2L)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-142-  expect_false(is.null(draft$manifest))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:143:  expect_equal(draft$manifest$release_id, TEST_RELEASE_ID)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-144-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-145-  published_ids_before <- vapply(analysis_release_list("published", conn = conn), function(r) r$release_id, character(1))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-146-  expect_false(TEST_RELEASE_ID %in% published_ids_before)
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-189-  published_ids_after <- vapply(analysis_release_list("published", conn = conn), function(r) r$release_id, character(1))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-190-  expect_true(TEST_RELEASE_ID %in% published_ids_after)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-191-  entry <- analysis_release_list("published", conn = conn)[[which(published_ids_after == TEST_RELEASE_ID)]]
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:192:  expect_equal(length(entry$layers), 2L)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-193-  expect_setequal(
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:194:    vapply(entry$layers, function(l) l$analysis_type, character(1)),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-195-    c("functional_clusters", "phenotype_clusters")
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-196-  )
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-197-  expect_setequal(
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:198:    vapply(entry$layers, function(l) as.integer(l$snapshot_id), integer(1)),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-199-    c(101L, 202L)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-200-  )
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-201-
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-234-  expect_true(all(c(101L, 202L) %in% snap_ids))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-235-})
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-236-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:237:test_that("analysis_release_public_head drops operational columns and groups zenodo (H1)", {
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-238-  raw_head <- list(
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-239-    release_id = "asr_pub", release_version = "v1", title = "T", status = "published",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-240-    content_digest = "digest", created_at = "2026-07-18", published_at = "2026-07-18",
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-244-    zenodo_record_url = "https://zenodo.org/records/1", version_doi = "10.5281/zenodo.1",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-245-    concept_doi = NA_character_,
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-246-    # operational columns that MUST NOT leak publicly:
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:247:    created_by_user_id = 42L, last_error_message = "secret internal error", updated_at = "2026-07-18",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:248:    layers = list(list(analysis_type = "functional_clusters")),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-249-    manifest = list(release_id = "asr_pub")
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-250-  )
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-251-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:252:  projected <- analysis_release_public_head(raw_head)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-253-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:254:  expect_false("created_by_user_id" %in% names(projected))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:255:  expect_false("last_error_message" %in% names(projected))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-256-  expect_false("updated_at" %in% names(projected))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-257-  # allowlisted fields survive:
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-258-  expect_equal(projected$release_id, "asr_pub")
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-263-  expect_equal(projected$zenodo$version_doi, "10.5281/zenodo.1")
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-264-  expect_null(projected$zenodo$concept_doi)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-265-  # public-safe derived members carried through:
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:266:  expect_false(is.null(projected$layers))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-267-  expect_false(is.null(projected$manifest))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-268-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:269:  expect_null(analysis_release_public_head(NULL))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-270-})
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-271-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-272-test_that("analysis_release_delete_draft removes a draft release and its file/member children", {
--
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-302-  expect_match(conditionMessage(gate_err), "snapshot_stale", fixed = TRUE)
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-303-})
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-304-
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:305:test_that("POST /releases: a caller-supplied `layers` JSON body array parses as list-of-lists, never a data.frame", {
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-306-  skip_if_no_test_db()
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-307-
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-308-  admin_pool <- make_test_pool()
--
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-320-    "analysis_snapshot_release_build",
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-321-    function(...) {
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-322-      captured <<- list(...)
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:323:      list(release = list(release_id = "asr_admin_layers"), created = TRUE)
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-324-    },
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-325-    envir = .GlobalEnv
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-326-  )
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-327-
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-328-  post_body <- paste0(
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:329:    '{"title":"Manual build","publish":false,"layers":[',
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-330-    '{"analysis_type":"functional_clusters","params":{"algorithm":"leiden"},',
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-331-    '"files_prefix":"functional_clusters","has_reproducibility":true},',
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-332-    '{"analysis_type":"phenotype_clusters","params":{},',
--
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-335-  )
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-336-  build_handler(req = release_admin_fake_req(post_body = post_body), res = release_endpoint_fake_res())
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-337-
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:338:  expect_false(is.null(captured$layers))
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:339:  expect_false(is.data.frame(captured$layers))
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:340:  expect_type(captured$layers, "list")
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:341:  expect_length(captured$layers, 2L)
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:342:  expect_equal(captured$layers[[1]]$analysis_type, "functional_clusters")
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:343:  expect_equal(captured$layers[[1]]$params$algorithm, "leiden")
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:344:  expect_true(isTRUE(captured$layers[[1]]$has_reproducibility))
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:345:  expect_equal(captured$layers[[2]]$analysis_type, "phenotype_clusters")
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:346:  expect_length(captured$layers[[2]]$params, 0L) # jsonlite parses {} as a named empty list
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-347-  expect_equal(captured$title, "Manual build")
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-348-  expect_false(isTRUE(captured$publish))
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-349-})
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-350-
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:351:test_that("POST /releases: an empty body omits `layers` (lets the orchestrator default apply) and defaults publish=TRUE/license", {
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-352-  skip_if_no_test_db()
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-353-
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-354-  admin_pool <- make_test_pool()
--
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-373-
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-374-  build_handler(req = release_admin_fake_req(post_body = NULL), res = release_endpoint_fake_res())
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-375-
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:376:  expect_null(captured$layers)
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-377-  expect_true(isTRUE(captured$publish))
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-378-  expect_equal(captured$license, "CC-BY-4.0")
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-379-  expect_equal(captured$created_by, 42L)
test-integration-analysis-snapshot-release-repository.R

exec
/bin/bash -lc "rg -n 'res\\"'$status <- 503|Retry-After|setHeader'"\\(\"Retry-After\"' api | head -80
rg -n 'analysis_release_(list|get|public_head)|svc_release_(list|get|manifest|file|bundle)' api --glob '*.R' | sed -n '1,240p'
rg -n 'analysis_snapshot_release_build\\(' api --glob '*.R' | sed -n '1,160p'
rg -n 'analysis_snapshot_release_resolve_layers|analysis_release_build_tar_gz|\\.analysis_release_artifact' api --glob '*.R'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
api/services/job-phenotype-submission-service.R:30:#' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
api/services/job-phenotype-submission-service.R:178:    res$setHeader("Retry-After", "0")
api/services/job-phenotype-submission-service.R:200:    res$status <- 503
api/services/job-phenotype-submission-service.R:201:    res$setHeader("Retry-After", "60")
api/services/job-phenotype-submission-service.R:224:    res$status <- 503
api/services/job-phenotype-submission-service.R:225:    res$setHeader("Retry-After", as.character(result$retry_after))
api/services/job-phenotype-submission-service.R:231:  res$setHeader("Retry-After", "5")
api/services/job-maintenance-submission-service.R:75:    res$status <- 503
api/services/job-maintenance-submission-service.R:76:    res$setHeader("Retry-After", as.character(result$retry_after))
api/services/job-maintenance-submission-service.R:83:  res$setHeader("Retry-After", "30") # Longer polling interval for ontology update
api/services/job-maintenance-submission-service.R:124:    res$status <- 503
api/services/job-maintenance-submission-service.R:125:    res$setHeader("Retry-After", as.character(result$retry_after))
api/services/job-maintenance-submission-service.R:132:  res$setHeader("Retry-After", "60") # Long-running job: poll every minute
api/services/job-maintenance-submission-service.R:173:    res$status <- 503
api/services/job-maintenance-submission-service.R:174:    res$setHeader("Retry-After", as.character(result$retry_after))
api/services/job-maintenance-submission-service.R:181:  res$setHeader("Retry-After", "30") # Long-running job: poll every 30 seconds
api/services/analysis-snapshot-release-service.R:93:    # with Retry-After, NOT a 400. Handled here (like the public capacity guard)
api/services/analysis-snapshot-release-service.R:96:      res$status <- 503L
api/services/analysis-snapshot-release-service.R:97:      res$setHeader("Retry-After", "5")
api/endpoints/external_endpoints.R:56:    res$status <- 503L
api/endpoints/external_endpoints.R:122:    res$status <- 503L
api/endpoints/external_endpoints.R:191:    res$status <- 503L
api/endpoints/external_endpoints.R:248:    res$status <- 503L
api/endpoints/external_endpoints.R:305:    res$status <- 503L
api/endpoints/external_endpoints.R:362:    res$status <- 503L
api/endpoints/external_endpoints.R:454:    res$status <- 503L
api/endpoints/external_endpoints.R:515:    res$status <- 503L
api/services/admin-nddscore-endpoint-service.R:129:  res$setHeader("Retry-After", "5")
api/functions/per-caller-throttle.R:284:  res$status <- 503L
api/functions/per-caller-throttle.R:285:  res$setHeader("Retry-After", as.character(retry_after))
api/functions/per-caller-throttle.R:336:    res$setHeader("Retry-After", as.character(retry_after))
api/endpoints/analysis_endpoints.R:23:      res$setHeader("Retry-After", as.character(snapshot_result$retry_after))
api/endpoints/jobs_endpoints.R:134:#* Returns Retry-After header for running jobs.
api/services/backup-endpoint-service.R:25:    res$status <- 503
api/services/backup-endpoint-service.R:26:    res$setHeader("Retry-After", as.character(result$retry_after))
api/services/backup-endpoint-service.R:32:  res$setHeader("Retry-After", "5")
api/services/publication-admin-endpoint-service.R:316:    res$status <- 503
api/services/publication-admin-endpoint-service.R:317:    res$setHeader("Retry-After", as.character(result$retry_after))
api/services/publication-admin-endpoint-service.R:323:  res$setHeader("Retry-After", "5")
api/services/job-query-endpoint-service.R:87:      res$status <- 503
api/services/job-query-endpoint-service.R:115:  # Set Retry-After for running jobs
api/services/job-query-endpoint-service.R:117:    res$setHeader("Retry-After", as.character(status$retry_after %||% 5))
api/services/job-functional-submission-service.R:24:#' (`async_job_capacity_exceeded()`, 503 + `Retry-After`) before submitting a
api/services/job-functional-submission-service.R:180:    res$setHeader("Retry-After", "0")
api/services/job-functional-submission-service.R:202:    res$status <- 503
api/services/job-functional-submission-service.R:203:    res$setHeader("Retry-After", "60")
api/services/job-functional-submission-service.R:224:    res$status <- 503
api/services/job-functional-submission-service.R:225:    res$setHeader("Retry-After", as.character(result$retry_after))
api/services/job-functional-submission-service.R:232:  res$setHeader("Retry-After", "5")
api/services/admin-publication-refresh-endpoint-service.R:165:    res$status <- 503
api/functions/analysis-snapshot-release.R:221:  # `release_lock_unavailable`, which the service maps to 503 + Retry-After.
api/endpoints/genereviews_endpoints.R:41:    res$status <- 503
api/functions/publication-endpoint-helpers.R:190:  res$setHeader("Retry-After", "5")
api/endpoints/health_endpoints.R:172:    res$status <- 503L
api/functions/llm-endpoint-helpers.R:101:    res$status <- 503L
api/endpoints/jobs_network_layout_endpoints.R:51:  res$setHeader("Retry-After", "10")
api/functions/analysis-reproducibility.R:366:    if (!is.null(res)) res$status <- 503L
api/tests/testthat/test-unit-auth-endpoint-throttle.R:35:test_that("auth guard emits only a generic 429 and Retry-After", {
api/tests/testthat/test-unit-auth-endpoint-throttle.R:47:  expect_true(nzchar(res$headers[["Retry-After"]]))
api/tests/testthat/test-unit-auth-endpoint-throttle.R:48:  expect_match(res$headers[["Retry-After"]], "^[1-9][0-9]*$")
api/tests/testthat/test-unit-auth-endpoint-throttle.R:137:  expect_equal(res$headers[["Retry-After"]], "5")
api/tests/testthat/test-unit-job-endpoint-services.R:120:  expect_equal(res$headers[["Retry-After"]], "0")
api/tests/testthat/test-unit-job-endpoint-services.R:137:  expect_equal(res$headers[["Retry-After"]], "60")
api/tests/testthat/test-unit-job-endpoint-services.R:151:  expect_equal(res$headers[["Retry-After"]], "5")
api/tests/testthat/test-unit-job-endpoint-services.R:179:    res$setHeader("Retry-After", "42")
api/tests/testthat/test-unit-job-endpoint-services.R:310:  expect_equal(res$headers[["Retry-After"]], "60")
api/tests/testthat/test-unit-job-endpoint-services.R:322:  expect_equal(res$headers[["Retry-After"]], "5")
api/tests/testthat/test-unit-job-endpoint-services.R:371:    res$setHeader("Retry-After", "42")
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R:54:# differing only in operation name and Retry-After (30 / 60 / 30 seconds).
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R:86:  test_that(paste(job_endpoint_spec$op, ": new submit returns 202 with the expected Retry-After"), {
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R:104:    expect_equal(res$headers[["Retry-After"]], job_endpoint_spec$retry_after)
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R:113:test_that("ontology update: create_job error surfaces as 503 with Retry-After", {
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R:122:  expect_equal(res$headers[["Retry-After"]], "60")
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R:222:test_that("job status: invalid result_mode (400), summary bypasses the gate (200), 404, and running Retry-After", {
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R:243:  expect_null(res$headers[["Retry-After"]])
api/tests/testthat/test-unit-job-endpoint-services-maintenance.R:255:  expect_equal(res$headers[["Retry-After"]], "7")
api/tests/testthat/test-endpoint-auth-rate-limit.R:38:    res$setHeader("Retry-After", "60")
api/tests/testthat/test-endpoint-auth-rate-limit.R:91:  expect_equal(res$headers[["Retry-After"]], "60")
api/tests/testthat/test-endpoint-auth-rate-limit.R:109:  expect_equal(res$headers[["Retry-After"]], "60")
api/tests/testthat/test-endpoint-auth-rate-limit.R:126:  expect_equal(res$headers[["Retry-After"]], "60")
api/services/analysis-snapshot-release-service.R:30:# PUBLIC SURFACE. `svc_release_list/get/manifest/file/bundle()` are the
api/services/analysis-snapshot-release-service.R:132:  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/services/analysis-snapshot-release-service.R:153:  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/services/analysis-snapshot-release-service.R:171:  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/services/analysis-snapshot-release-service.R:191:#' (`analysis_release_public_head`) so operational columns never leak.
api/services/analysis-snapshot-release-service.R:198:svc_release_list <- function(limit = 50, offset = 0, conn = NULL) {
api/services/analysis-snapshot-release-service.R:201:  rows <- analysis_release_list(status = "published", limit = limit, offset = offset, conn = conn)
api/services/analysis-snapshot-release-service.R:202:  lapply(rows, analysis_release_public_head)
api/services/analysis-snapshot-release-service.R:235:svc_release_get <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R:236:  head <- analysis_release_get(release_id, include_draft = FALSE, conn = conn)
api/services/analysis-snapshot-release-service.R:240:  analysis_release_public_head(head)
api/services/analysis-snapshot-release-service.R:249:svc_release_manifest <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R:250:  file <- analysis_release_get_file(release_id, "manifest.json", include_draft = FALSE, conn = conn)
api/services/analysis-snapshot-release-service.R:268:svc_release_file <- function(release_id, file_path, conn = NULL) {
api/services/analysis-snapshot-release-service.R:269:  file <- analysis_release_get_file(release_id, file_path, include_draft = FALSE, conn = conn)
api/services/analysis-snapshot-release-service.R:282:svc_release_bundle <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R:283:  bundle <- analysis_release_get_bundle(release_id, include_draft = FALSE, conn = conn)
api/functions/analysis-snapshot-release.R:66:.analysis_release_get_lock <- function(conn, name, timeout_seconds = 5L) {
api/functions/analysis-snapshot-release.R:110:    if (.analysis_release_get_lock(conn, lock_name, timeout_seconds)) {
api/functions/analysis-snapshot-release.R:383:    existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/functions/analysis-snapshot-release.R:515:        existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/functions/analysis-snapshot-release.R:526:      release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
api/functions/analysis-snapshot-release.R:536:    release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
api/functions/analysis-snapshot-release-repository.R:60:#' for via `analysis_release_get_bundle()`).
api/functions/analysis-snapshot-release-repository.R:201:#' `analysis_release_list()`, the parsed `manifest` from `analysis_release_get()`)
api/functions/analysis-snapshot-release-repository.R:207:analysis_release_public_head <- function(head) {
api/functions/analysis-snapshot-release-repository.R:248:analysis_release_get <- function(release_id, include_draft = FALSE, conn) {
api/functions/analysis-snapshot-release-repository.R:263:  manifest_file <- analysis_release_get_file(
api/functions/analysis-snapshot-release-repository.R:288:analysis_release_list <- function(status = "published", limit = 50L, offset = 0L, conn) {
api/functions/analysis-snapshot-release-repository.R:344:analysis_release_get_file <- function(release_id, file_path, include_draft = FALSE, conn) {
api/functions/analysis-snapshot-release-repository.R:372:#' decompress it (unlike `analysis_release_get_file()`, which stores each
api/functions/analysis-snapshot-release-repository.R:379:analysis_release_get_bundle <- function(release_id, include_draft = FALSE, conn) {
api/endpoints/analysis_endpoints.R:419:  releases <- svc_release_list(limit = limit_int, offset = offset_int, conn = pool)
api/endpoints/analysis_endpoints.R:444:  newest <- svc_release_list(limit = 1, offset = 0, conn = pool)
api/endpoints/analysis_endpoints.R:448:  svc_release_get(as.character(newest[[1]]$release_id), conn = pool)
api/endpoints/analysis_endpoints.R:463:  svc_release_get(release_id, conn = pool)
api/endpoints/analysis_endpoints.R:481:  content <- svc_release_manifest(release_id, conn = pool)
api/endpoints/analysis_endpoints.R:506:  content <- svc_release_file(release_id, file_path, conn = pool)
api/endpoints/analysis_endpoints.R:526:  bundle <- svc_release_bundle(release_id, conn = pool)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:136:  expect_null(analysis_release_get(TEST_RELEASE_ID, include_draft = FALSE, conn = conn))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:138:  draft <- analysis_release_get(TEST_RELEASE_ID, include_draft = TRUE, conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:145:  published_ids_before <- vapply(analysis_release_list("published", conn = conn), function(r) r$release_id, character(1))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:148:  all_ids_before <- vapply(analysis_release_list(NULL, conn = conn), function(r) r$release_id, character(1))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:152:  payload_file <- analysis_release_get_file(
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:161:  expect_null(analysis_release_get_file(
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:165:  expect_null(analysis_release_get_file(
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:171:  bundle <- analysis_release_get_bundle(TEST_RELEASE_ID, include_draft = TRUE, conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:176:  expect_null(analysis_release_get_bundle(TEST_RELEASE_ID, include_draft = FALSE, conn = conn))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:183:  published <- analysis_release_get(TEST_RELEASE_ID, include_draft = FALSE, conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:189:  published_ids_after <- vapply(analysis_release_list("published", conn = conn), function(r) r$release_id, character(1))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:191:  entry <- analysis_release_list("published", conn = conn)[[which(published_ids_after == TEST_RELEASE_ID)]]
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:212:  with_doi <- analysis_release_get(TEST_RELEASE_ID, include_draft = FALSE, conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:237:test_that("analysis_release_public_head drops operational columns and groups zenodo (H1)", {
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:252:  projected <- analysis_release_public_head(raw_head)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:269:  expect_null(analysis_release_public_head(NULL))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:295:  expect_null(analysis_release_get(TEST_RELEASE_ID_2, include_draft = TRUE, conn = conn))
api/endpoints/admin_analysis_snapshot_endpoints.R:22:# svc_release_list()/svc_release_get() in the service layer are
api/endpoints/admin_analysis_snapshot_endpoints.R:189:#* `svc_release_list()`), this admin listing includes draft rows so an
api/endpoints/admin_analysis_snapshot_endpoints.R:205:  releases <- analysis_release_list(status = NULL, limit = limit_int, offset = offset_int, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R:216:#* `svc_release_get()`), this admin detail resolves a draft release too.
api/endpoints/admin_analysis_snapshot_endpoints.R:225:  head <- analysis_release_get(release_id, include_draft = TRUE, conn = pool)
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:445:  reread_after_publish <- analysis_release_get(TEST_DRAFT_PUBLISH_RELEASE_ID, include_draft = TRUE, conn = conn)
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:452:  before_doi <- analysis_release_get(TEST_PUBLISHED_RELEASE_ID, include_draft = TRUE, conn = conn)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:8:# (`analysis_release_list/get/get_file/get_bundle/publish/set_doi/
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:28:analysis_release_list <- function(...) stop("stub: analysis_release_list not mocked")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:29:analysis_release_get <- function(...) stop("stub: analysis_release_get not mocked")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:30:analysis_release_get_file <- function(...) stop("stub: analysis_release_get_file not mocked")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:31:analysis_release_get_bundle <- function(...) stop("stub: analysis_release_get_bundle not mocked")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:37:# service tests only verify svc_release_list/get ROUTE through it.
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:38:analysis_release_public_head <- function(head) head
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:258:      analysis_release_get = function(...) NULL
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:271:      analysis_release_get = function(release_id, include_draft, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:291:      analysis_release_get = function(...) NULL
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:311:      analysis_release_get = function(...) head
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:327:    list(analysis_release_get = function(...) NULL),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:336:    list(analysis_release_get = function(...) list(release_id = "asr_pub", status = "published")),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:352:      analysis_release_get = function(...) list(release_id = "asr_draft1", status = "draft"),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:367:# svc_release_list (public)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:374:    list(analysis_release_list = function(status, limit, offset, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:379:      out <- svc_release_list(limit = 10, offset = 5)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:399:  with_release_mocks(list(analysis_release_list = capture_loader), {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:401:      svc_release_list(limit = case$in_limit, offset = case$in_offset)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:408:test_that("list + get route heads through analysis_release_public_head (H1)", {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:412:      analysis_release_list = function(...) list(list(release_id = "asr_raw", created_by_user_id = 9L)),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:413:      analysis_release_get = function(...) list(release_id = "asr_raw", created_by_user_id = 9L),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:414:      analysis_release_public_head = function(head) marker
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:417:      expect_identical(svc_release_list()[[1]], marker)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:418:      expect_identical(svc_release_get("asr_raw"), marker)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:424:# svc_release_get (public)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:430:    list(analysis_release_get = function(release_id, include_draft, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:435:      expect_error(svc_release_get("asr_draft_or_missing"), class = "error_404")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:444:    list(analysis_release_get = function(...) head),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:446:      out <- svc_release_get("asr_pub2")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:453:# svc_release_manifest (public)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:458:    list(analysis_release_get_file = function(...) NULL),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:460:      expect_error(svc_release_manifest("asr_missing"), class = "error_404")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:469:    list(analysis_release_get_file = function(release_id, file_path, include_draft, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:475:      out <- svc_release_manifest("asr_1")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:483:# svc_release_file (public)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:488:    list(analysis_release_get_file = function(...) NULL),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:490:      expect_error(svc_release_file("asr_1", "does/not/exist.json"), class = "error_404")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:498:    list(analysis_release_get_file = function(release_id, file_path, include_draft, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:503:      out <- svc_release_file("asr_1", "README.md")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:510:# svc_release_bundle (public)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:515:    list(analysis_release_get_bundle = function(...) NULL),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:517:      expect_error(svc_release_bundle("asr_missing"), class = "error_404")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:525:    list(analysis_release_get_bundle = function(release_id, include_draft, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:530:      out <- svc_release_bundle("asr_1")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:435:    rf <- analysis_release_get_file(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:444:    manifest_file <- analysis_release_get_file(release_id, "manifest.json", include_draft = TRUE, conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:450:    payload_file <- analysis_release_get_file(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:461:    expect_null(analysis_release_get_file(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:467:    bundle <- analysis_release_get_bundle(release_id, include_draft = TRUE, conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:488:    published <- analysis_release_list(status = "published", conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:508:    expect_identical(0L, length(analysis_release_list(status = "published", conn = conn)))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:522:    manifest_file <- analysis_release_get_file(result$release$release_id, "manifest.json", include_draft = TRUE, conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:545:    expect_identical(1L, length(analysis_release_list(status = NULL, conn = conn)))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:558:    expect_identical(0L, length(analysis_release_list(status = "published", conn = conn)))
api/services/analysis-snapshot-release-service.R:53:#' Thin problem+json shim over `analysis_snapshot_release_build()`. On
api/endpoints/admin_analysis_snapshot_endpoints.R:93:#' layer shares the same param keys. `analysis_snapshot_release_build()`
api/endpoints/admin_analysis_snapshot_endpoints.R:164:  # analysis_snapshot_release_build() ultimately calls
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:4:# Task A4): analysis_snapshot_release_build().
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:234:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:246:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:263:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:280:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:295:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:306:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:326:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:339:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:357:    analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:422:    result <- analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:499:      analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:514:    result <- analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:537:    result <- analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:551:    result <- analysis_snapshot_release_build(
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:29:# analysis_snapshot_release_build() (real snapshot-backed building is
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:35:# analysis_snapshot_release_build()'s ultimate persistence call,
api/functions/analysis-snapshot-release.R:183:#'   `analysis_snapshot_release_resolve_layers()` (caller cannot override policy).
api/functions/analysis-snapshot-release.R:205:  layers <- analysis_snapshot_release_resolve_layers(layers)
api/functions/analysis-snapshot-release.R:338:    artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
api/functions/analysis-snapshot-release.R:359:      artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
api/functions/analysis-snapshot-release.R:398:    list(.analysis_release_artifact("README.md", readme_bytes, "text/markdown")),
api/functions/analysis-snapshot-release.R:437:  manifest_artifact <- .analysis_release_artifact("manifest.json", manifest_bytes, "application/json")
api/functions/analysis-snapshot-release.R:444:  artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
api/functions/analysis-snapshot-release.R:453:  bundle_gzip <- analysis_release_build_tar_gz(named_raw)
api/functions/analysis-snapshot-release-manifest.R:9:# used internally by `analysis_release_build_tar_gz()`.
api/functions/analysis-snapshot-release-manifest.R:66:analysis_snapshot_release_resolve_layers <- function(requested = NULL) {
api/functions/analysis-snapshot-release-manifest.R:99:#' path written into the tar archive (`analysis_release_build_tar_gz`).
api/functions/analysis-snapshot-release-manifest.R:247:analysis_release_build_tar_gz <- function(named_raw_list) {
api/functions/analysis-snapshot-release-materialize.R:303:.analysis_release_artifact <- function(path, bytes, media_type) {
api/functions/analysis-snapshot-release-materialize.R:305:  # single choke point (defense-in-depth alongside analysis_release_build_tar_gz).
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:22:  expect_identical(analysis_snapshot_release_resolve_layers(NULL), analysis_snapshot_release_layers())
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:23:  expect_identical(analysis_snapshot_release_resolve_layers(list()), analysis_snapshot_release_layers())
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:31:  resolved <- analysis_snapshot_release_resolve_layers(list(
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:41:  resolved <- analysis_snapshot_release_resolve_layers(list("phenotype_clusters", "functional_clusters"))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:50:    analysis_snapshot_release_resolve_layers(list(list(analysis_type = "not_a_layer"))),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:54:    analysis_snapshot_release_resolve_layers(list("functional_clusters", "functional_clusters")),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:61:    analysis_release_build_tar_gz(list("../x.json" = charToRaw("{}"))),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:65:    analysis_release_build_tar_gz(list("/etc/passwd" = charToRaw("x"))),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:80:  expect_true(exists("analysis_release_build_tar_gz", mode = "function"))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:172:  gz <- analysis_release_build_tar_gz(payload)

codex
I’ve confirmed the hardening is wired through the real public and admin call paths, not only helper-level tests. I found one remaining provenance-consistency concern and am now validating it against the build inputs and targeted test suite, alongside checking that no fix-path regression changes the HTTP or archive contracts.
exec
/bin/bash -lc "git diff --check 67cf6003..HEAD
sed -n '1,240p' .planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md
sed -n '1,220p' .planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-reconciliation.md
nl -ba db/migrations/045_add_analysis_snapshot_release.sql
nl -ba api/bootstrap/load_modules.R | sed -n '1,180p'
nl -ba api/functions/migration-manifest.R | sed -n '1,200p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:7: trailing whitespace.
+- [Plan A4](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:262) requires `sha256(payload.json) == payload_hash`. That is not achievable from the persisted snapshot. `payload_hash` is computed on the pre-persistence in-memory object, while release construction reads normalized child rows; correlations/edges round-trip through `DECIMAL(8,5)` / `DECIMAL(8,7)` ([builder](/home/bernt-popp/development/sysndd/api/functions/analysis-snapshot-builder.R:502), [migration](/home/bernt-popp/development/sysndd/db/migrations/024_add_public_analysis_snapshots.sql:67)). A value rounded on insert makes the A4 assertion fail and blocks release creation. The current design correctly contradicts the plan on this point ([spec](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:126)).  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:10: trailing whitespace.
+- [Spec §6](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:127) incorrectly says `analysis_reproducibility_decode()` returns the original JSON string. It returns a parsed R object ([implementation](/home/bernt-popp/development/sysndd/api/functions/analysis-reproducibility.R:112)); reserializing it with the snapshot serializer loses the `digits = NA` contract used for `reproducibility_hash` ([serializer](/home/bernt-popp/development/sysndd/api/functions/analysis-reproducibility.R:31)). A bundle with a full-precision modularity value will fail the planned hash assertion.  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:13: trailing whitespace.
+- [Plan A6](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:310) proposes Plumber `<path:.*>`. SysNDD pins Plumber 1.3.2 ([renv.lock](/home/bernt-popp/development/sysndd/api/renv.lock:7382)); its path grammar only supports named, typed single-segment parameters (`<id>`, `<id:int>`). `.*` is not a supported type and the replacement grammar does not accept `*`; it will not capture `functional_clusters/payload.json`. Consequently every nested release-file URL 404s.  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:16: trailing whitespace.
+- [Plan A1](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:141) updates only `EXPECTED_LATEST_MIGRATION`. The live manifest also enforces `EXPECTED_MIGRATION_COUNT = 42L` ([migration manifest](/home/bernt-popp/development/sysndd/api/functions/migration-manifest.R:5)). Adding `045` without changing it to `43L` makes API startup fail before serving anything.  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:21: trailing whitespace.
+- [Spec §7](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:175) claims `analysis_snapshot_get_public()` reuses the coherence gate. It does not: it only checks freshness/schema, and runs dependency validation only for the correlation layer ([repository](/home/bernt-popp/development/sysndd/api/functions/analysis-snapshot-repository.R:337)). The actual coherence gate can be downgraded to a warning with `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false` ([coherence gate](/home/bernt-popp/development/sysndd/api/functions/analysis-snapshot-coherence.R:21)). An incoherent but `public_ready` functional snapshot can therefore pass `status_code == "available"` and be frozen as a release.  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:24: trailing whitespace.
+- The design and plan are mutually incompatible on material API behavior: the current spec requires 400 for unavailable inputs, idempotent 200, a 64-bit short handle, collision checking, and a TOCTOU guard ([spec](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:169)), while the plan implements 409, 48-bit IDs, `release_already_exists`, and no lock/consistent transaction ([plan](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:240)). A concurrent axis refresh after the plan reads the correlation but before insert yields a “current” release pinned to superseded axes. Also, following A5 literally would add only `core/errors.R`; `errorHandler` has no 409 branch ([filters](/home/bernt-popp/development/sysndd/api/core/filters.R:272)), so any new conflict condition becomes an opaque 500.  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:27: trailing whitespace.
+- Reproducibility is best-effort in the current snapshot builder: a failed bundle build returns `NULL`, yet the snapshot still activates ([repro persistence](/home/bernt-popp/development/sysndd/api/functions/analysis-reproducibility.R:391)). The release schema permits a null `reproducibility_hash`, but the release file set makes both reproducibility files mandatory. A current functional snapshot without a bundle passes `available`, then produces either an opaque crash or a release that cannot reproduce its stated metrics.  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:32: trailing whitespace.
+- [Plan D2](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:374) says to extend dedupe only with the resolved HGNC hash. Existing dedupe keys only `{genes, algorithm}` ([submission service](/home/bernt-popp/development/sysndd/api/services/job-functional-submission-service.R:86)). `["Definitive"]` and `["Definitive","Moderate"]` can resolve to the same current genes; the second request then receives a duplicate of the first while claiming a different selector/provenance.  
# Codex adversarial review — findings (gpt-5.6-terra, high reasoning)

Raw streamed log: `2026-07-18-analysis-snapshot-releases-573-codex-review-rawlog.md`. Reconciliation: `…-codex-reconciliation.md`.

## BLOCKER

- [Plan A4](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:262) requires `sha256(payload.json) == payload_hash`. That is not achievable from the persisted snapshot. `payload_hash` is computed on the pre-persistence in-memory object, while release construction reads normalized child rows; correlations/edges round-trip through `DECIMAL(8,5)` / `DECIMAL(8,7)` ([builder](/home/bernt-popp/development/sysndd/api/functions/analysis-snapshot-builder.R:502), [migration](/home/bernt-popp/development/sysndd/db/migrations/024_add_public_analysis_snapshots.sql:67)). A value rounded on insert makes the A4 assertion fail and blocks release creation. The current design correctly contradicts the plan on this point ([spec](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:126)).  
  Minimal fix: remove the equality assertion entirely; hash the exported file independently and record `{snapshot_id,input_hash,payload_hash}` as lineage anchors.

- [Spec §6](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:127) incorrectly says `analysis_reproducibility_decode()` returns the original JSON string. It returns a parsed R object ([implementation](/home/bernt-popp/development/sysndd/api/functions/analysis-reproducibility.R:112)); reserializing it with the snapshot serializer loses the `digits = NA` contract used for `reproducibility_hash` ([serializer](/home/bernt-popp/development/sysndd/api/functions/analysis-reproducibility.R:31)). A bundle with a full-precision modularity value will fail the planned hash assertion.  
  Minimal fix: add a raw/character decompression helper that returns the exact pre-gzip JSON bytes; hash and store those verbatim. Do not route this through `fromJSON()`.

- [Plan A6](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:310) proposes Plumber `<path:.*>`. SysNDD pins Plumber 1.3.2 ([renv.lock](/home/bernt-popp/development/sysndd/api/renv.lock:7382)); its path grammar only supports named, typed single-segment parameters (`<id>`, `<id:int>`). `.*` is not a supported type and the replacement grammar does not accept `*`; it will not capture `functional_clusters/payload.json`. Consequently every nested release-file URL 404s.  
  Minimal fix: use a query parameter for the exact DB `file_path`, or explicit fixed-depth routes such as `<directory>/<filename>` and validate the resulting combined path against the DB PK.

- [Plan A1](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:141) updates only `EXPECTED_LATEST_MIGRATION`. The live manifest also enforces `EXPECTED_MIGRATION_COUNT = 42L` ([migration manifest](/home/bernt-popp/development/sysndd/api/functions/migration-manifest.R:5)). Adding `045` without changing it to `43L` makes API startup fail before serving anything.  
  Minimal fix: update both constants and add a manifest test covering 045/count 43.

## HIGH

- [Spec §7](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:175) claims `analysis_snapshot_get_public()` reuses the coherence gate. It does not: it only checks freshness/schema, and runs dependency validation only for the correlation layer ([repository](/home/bernt-popp/development/sysndd/api/functions/analysis-snapshot-repository.R:337)). The actual coherence gate can be downgraded to a warning with `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false` ([coherence gate](/home/bernt-popp/development/sysndd/api/functions/analysis-snapshot-coherence.R:21)). An incoherent but `public_ready` functional snapshot can therefore pass `status_code == "available"` and be frozen as a release.  
  Minimal fix: persist an immutable hard coherence attestation at snapshot activation, and require it during release construction; do not infer coherence from `available`.

- The design and plan are mutually incompatible on material API behavior: the current spec requires 400 for unavailable inputs, idempotent 200, a 64-bit short handle, collision checking, and a TOCTOU guard ([spec](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:169)), while the plan implements 409, 48-bit IDs, `release_already_exists`, and no lock/consistent transaction ([plan](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:240)). A concurrent axis refresh after the plan reads the correlation but before insert yields a “current” release pinned to superseded axes. Also, following A5 literally would add only `core/errors.R`; `errorHandler` has no 409 branch ([filters](/home/bernt-popp/development/sysndd/api/core/filters.R:272)), so any new conflict condition becomes an opaque 500.  
  Minimal fix: reconcile documents before implementation; use one checked-out connection, transaction/ordered advisory locks, recheck lineage before insert, and adopt the spec’s 400/200 behavior.

- Reproducibility is best-effort in the current snapshot builder: a failed bundle build returns `NULL`, yet the snapshot still activates ([repro persistence](/home/bernt-popp/development/sysndd/api/functions/analysis-reproducibility.R:391)). The release schema permits a null `reproducibility_hash`, but the release file set makes both reproducibility files mandatory. A current functional snapshot without a bundle passes `available`, then produces either an opaque crash or a release that cannot reproduce its stated metrics.  
  Minimal fix: fail release creation with a typed source-not-ready error when either clustering layer lacks a verified bundle; test this explicitly.

## MEDIUM

- [Plan D2](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:374) says to extend dedupe only with the resolved HGNC hash. Existing dedupe keys only `{genes, algorithm}` ([submission service](/home/bernt-popp/development/sysndd/api/services/job-functional-submission-service.R:86)). `["Definitive"]` and `["Definitive","Moderate"]` can resolve to the same current genes; the second request then receives a duplicate of the first while claiming a different selector/provenance.  
  Minimal fix: normalize and include the selector, sorted resolved IDs, algorithm, `CLUSTER_LOGIC_VERSION`, source-data version, STRING channel, and threshold in both preflight dedupe and durable request payload.
# Codex adversarial review — reconciliation

Reviewer: `gpt-5.6-terra`, high reasoning, read-only, non-interactive (one command-line pass).
Raw output: `2026-07-18-analysis-snapshot-releases-573-codex-review.md` (findings printed twice — streaming artifact; the two blocks are identical).

Codex read the **committed** spec/plan. Two findings had already been fixed by an independent verification pass before Codex returned (noted below); the rest are newly applied. All BLOCKER/HIGH findings are resolved in the spec + plan.

| # | Sev | Finding | Resolution |
|---|-----|---------|------------|
| 1 | BLOCKER | `sha256(payload.json) == payload_hash` unachievable (`payload_hash` is over the pre-persistence in-memory object; child rows round-trip `DECIMAL(8,5)`/`(8,7)`). | **Already fixed** (independently confirmed vs `analysis-snapshot-builder.R:502`). `payload.json` now carries its **own** `content_sha256`; the snapshot `payload_hash`/`input_hash`/`snapshot_id` are recorded as **lineage anchors** cross-checkable against live `meta.snapshot`. Spec §6, Plan A4 test. |
| 2 | BLOCKER | `analysis_reproducibility_decode()` returns a **parsed** object; re-serializing drops the `digits=NA` contract → hash mismatch. | Fixed: use `memDecompress(bundle_gzip_json, type="gzip", asChar=TRUE)` (new `analysis_reproducibility_decode_raw()`), hash/store the **raw pre-gzip bytes** verbatim; `sha256(reproducibility.json)==reproducibility_hash` then holds. Spec §6, Plan A4 step 3 + Consumes. |
| 3 | BLOCKER | Plumber 1.3.2 has no `<path:.*>` multi-segment param → nested `/files/<path>` 404s. | Fixed: file retrieval is `GET /releases/<id>/file?path=<file_path>` (query param, exact `(release_id,file_path)` PK lookup, no traversal). Spec §8/§14, Plan A6. |
| 4 | BLOCKER | Startup also enforces `EXPECTED_MIGRATION_COUNT = 42L` (`migration-manifest.R:5`); bumping only `EXPECTED_LATEST_MIGRATION` crashes boot. | Fixed: Plan A1 bumps **both** (`…COUNT 42L→43L`, `…LATEST → 045`) + manifest test. |
| 5 | HIGH | `status_code=="available"` does **not** prove coherence (the #514 gate can be `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false`); an incoherent `public_ready` snapshot could be frozen. | Fixed: build **re-asserts hard coherence** per cluster layer (`analysis_snapshot_assert_partition_coherent(..., require_coherence=TRUE)`, ignoring the env) → 400 `release_source_incoherent`. Spec §7 step 2, Plan A4 step 1b + test. |
| 6 | HIGH | Spec/plan were mutually incompatible (409 vs 400, 48- vs 64-bit id, TOCTOU, no 409 branch in `errorHandler`). | **Already fixed** in the independent pass: spec+plan both use 400 + idempotent-200, 64-bit `release_id`, advisory-lock/consistent-read TOCTOU guard with pre-insert lineage re-assert, and **no new 409 class** (Codex confirms `filters.R:272` has no 409 branch). Spec §7/§10, Plan A4/A5. |
| 7 | HIGH | Reproducibility bundles are **best-effort** (a NULL bundle still activates the snapshot; `reproducibility_hash` nullable), but the release makes `reproducibility.json` mandatory → crash / non-reproducible release. | Fixed: build requires a stored bundle per cluster layer → 400 `release_reproducibility_missing`. Spec §7 step 3, Plan A4 step 1c + test. |
| 8 | MEDIUM | #574 dedupe keyed only on resolved genes; two selectors resolving to the same current genes collapse with mismatched provenance. | Fixed: dedupe key (preflight + durable payload) includes the **normalized selector** + sorted resolved IDs + algorithm + `CLUSTER_LOGIC_VERSION` + source-data version + STRING channel + threshold. Plan D2. |

No finding required Zenodo in-app integration, RO-Crate, object storage, or a topology redesign — scope held to the issues.
     1	-- Migration: 045_add_analysis_snapshot_release
     2	-- Description: Immutable, content-addressed public analysis-snapshot releases (#573).
     3	--   A release freezes canonical-JSON copies of the active coherent public snapshots
     4	--   (functional/phenotype clusters + phenotype-functional correlation) with per-file
     5	--   SHA-256 checksums and dependency lineage. Retained indefinitely; a later refresh
     6	--   mints a NEW release. DOI columns are additive external provenance.
     7	
     8	CREATE TABLE IF NOT EXISTS `analysis_snapshot_release` (
     9	  `release_id` VARCHAR(64) NOT NULL,
    10	  `release_version` VARCHAR(32) DEFAULT NULL,
    11	  `title` VARCHAR(255) DEFAULT NULL,
    12	  `status` ENUM('draft','published') NOT NULL DEFAULT 'draft',
    13	  `manifest_schema_version` VARCHAR(16) NOT NULL,
    14	  `content_digest` CHAR(64) NOT NULL,
    15	  `manifest_sha256` CHAR(64) NOT NULL,
    16	  `bundle_sha256` CHAR(64) NOT NULL,
    17	  `bundle_gzip` LONGBLOB NOT NULL,
    18	  `bundle_bytes` BIGINT NOT NULL,
    19	  `source_data_version` VARCHAR(128) DEFAULT NULL,
    20	  `db_release_version` VARCHAR(64) DEFAULT NULL,
    21	  `db_release_commit` VARCHAR(64) DEFAULT NULL,
    22	  `scope_statement` TEXT DEFAULT NULL,
    23	  `license` VARCHAR(64) NOT NULL DEFAULT 'CC-BY-4.0',
    24	  `file_count` INT NOT NULL DEFAULT 0,
    25	  `total_bytes` BIGINT NOT NULL DEFAULT 0,
    26	  `created_by_user_id` INT DEFAULT NULL,
    27	  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    28	  `published_at` DATETIME(6) DEFAULT NULL,
    29	  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    30	  `zenodo_record_id` VARCHAR(32) DEFAULT NULL,
    31	  `zenodo_record_url` VARCHAR(255) DEFAULT NULL,
    32	  `version_doi` VARCHAR(128) DEFAULT NULL,
    33	  `concept_doi` VARCHAR(128) DEFAULT NULL,
    34	  `last_error_message` TEXT DEFAULT NULL,
    35	  PRIMARY KEY (`release_id`),
    36	  KEY `idx_asr_status_created` (`status`, `created_at`),
    37	  KEY `idx_asr_content_digest` (`content_digest`),
    38	  CONSTRAINT `fk_asr_created_by`
    39	    FOREIGN KEY (`created_by_user_id`) REFERENCES `user` (`user_id`) ON DELETE SET NULL
    40	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    41	
    42	CREATE TABLE IF NOT EXISTS `analysis_snapshot_release_member` (
    43	  `release_id` VARCHAR(64) NOT NULL,
    44	  `analysis_type` VARCHAR(64) NOT NULL,
    45	  `parameter_hash` CHAR(64) NOT NULL,
    46	  `snapshot_id` BIGINT NOT NULL,
    47	  `input_hash` CHAR(64) NOT NULL,
    48	  `payload_hash` CHAR(64) NOT NULL,
    49	  `schema_version` VARCHAR(16) NOT NULL,
    50	  `reproducibility_hash` CHAR(64) DEFAULT NULL,
    51	  `role` ENUM('layer','dependency') NOT NULL DEFAULT 'layer',
    52	  PRIMARY KEY (`release_id`, `analysis_type`, `parameter_hash`),
    53	  KEY `idx_asrm_snapshot` (`snapshot_id`),
    54	  CONSTRAINT `fk_asrm_release`
    55	    FOREIGN KEY (`release_id`) REFERENCES `analysis_snapshot_release` (`release_id`) ON DELETE CASCADE
    56	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    57	
    58	CREATE TABLE IF NOT EXISTS `analysis_snapshot_release_file` (
    59	  `release_id` VARCHAR(64) NOT NULL,
    60	  `file_path` VARCHAR(255) NOT NULL,
    61	  `content_sha256` CHAR(64) NOT NULL,
    62	  `byte_size` INT NOT NULL,
    63	  `media_type` VARCHAR(64) NOT NULL DEFAULT 'application/json',
    64	  `content_gzip` LONGBLOB NOT NULL,
    65	  PRIMARY KEY (`release_id`, `file_path`),
    66	  KEY `idx_asrf_sha256` (`content_sha256`),
    67	  CONSTRAINT `fk_asrf_release`
    68	    FOREIGN KEY (`release_id`) REFERENCES `analysis_snapshot_release` (`release_id`) ON DELETE CASCADE
    69	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
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
    73	    "functions/analysis-snapshot-coherence.R",
    74	    "functions/analysis-snapshot-dependencies.R",
    75	    "functions/analysis-snapshot-builder.R",
    76	    "functions/analysis-reproducibility.R",
    77	    # Immutable, content-addressed public analysis-snapshot releases (#573
    78	    # Slice A). Synchronous admin/API-only build path (svc_release_build(),
    79	    # called directly from the admin endpoint) -- NOT a durable async-job
    80	    # handler and NOT a mirai daemon job, so (unlike the sibling
    81	    # analysis-snapshot-*.R files above) these are intentionally absent from
    82	    # bootstrap/setup_workers.R's mirai everywhere() block. Registered here
    83	    # only, which still covers the durable worker (start_async_worker.R) and
    84	    # the MCP sidecar (start_sysndd_mcp.R) via this shared loader. Order:
    85	    # manifest (content digest / canonical JSON / tar.gz) -> repository (DB
    86	    # CRUD) -> materialize (coherence assertions + file/README building) ->
    87	    # release (orchestrator, depends on all three).
    88	    "functions/analysis-snapshot-release-manifest.R",
    89	    "functions/analysis-snapshot-release-repository.R",
    90	    "functions/analysis-snapshot-release-materialize.R",
    91	    "functions/analysis-snapshot-release.R",
    92	    "functions/async-job-analysis-snapshot-handlers.R",
    93	    "functions/async-job-network-layout-handlers.R",
    94	    "functions/nddscore-import.R",
    95	    "functions/nddscore-repository.R",
    96	    "functions/nddscore-admin-endpoint-helpers.R",
    97	    "functions/entity-repository.R",
    98	    "functions/review-repository.R",
    99	    "functions/status-repository.R",
   100	    "functions/re-review-sync.R",
   101	    "functions/publication-repository.R",
   102	    "functions/phenotype-repository.R",
   103	    "functions/ontology-repository.R",
   104	    "functions/mcp-search-repository.R",
   105	    "functions/mcp-repository.R",
   106	    "functions/mcp-analysis-cache-repository.R",
   107	    "functions/mcp-analysis-repository.R",
   108	    "functions/user-repository.R",
   109	    "functions/user-endpoint-helpers.R",
   110	    "functions/hash-repository.R",
   111	    "functions/metadata-vocabulary-repository.R",
   112	    "functions/category-normalization.R",
   113	    "functions/phenotype-endpoint-functions.R",
   114	    "functions/panels-endpoint-functions.R",
   115	    "functions/endpoint-functions.R",
   116	    "functions/comparisons-list.R",
   117	    # Comparisons refresh write-path (durable `comparisons_update` job). These
   118	    # were historically only loaded into the mirai daemon pool via
   119	    # setup_workers.R, but create_job() now submits comparisons_update as a
   120	    # durable System B job, so the async worker (which loads via this list) must
   121	    # define comparisons_update_async() and its helpers too. Order: sources +
   122	    # parsers + omim before comparisons-functions.R (which uses them).
   123	    "functions/omim-functions.R",
   124	    "functions/comparisons-sources.R",
   125	    "functions/comparisons-parsers.R",
   126	    "functions/comparisons-omim.R",
   127	    "functions/comparisons-functions.R",
   128	    "functions/publication-endpoint-helpers.R",
   129	    "functions/pubmed-xml-parser.R",
   130	    "functions/publication-functions.R",
   131	    "functions/publication-date-backfill.R",
   132	    "functions/genereviews-functions.R",
   133	    "functions/analysis-string-channels.R",
   134	    "functions/analysis-cache-fingerprint.R",
   135	    "functions/analyses-functions.R",
   136	    "functions/analysis-phenotype-mca-prep.R",
   137	    "functions/analysis-phenotype-functions.R",
   138	    "functions/analysis-null-models.R",
   139	    "functions/analysis-cluster-validation.R",
   140	    "functions/analysis-network-layout-functions.R",
   141	    "functions/analysis-network-functions.R",
   142	    "functions/account-helpers.R",
   143	    "functions/data-helpers.R",
   144	    "functions/entity-helpers.R",
   145	    "functions/response-helpers.R",
   146	    "functions/response-fields-helpers.R",
   147	    "functions/email-templates.R",
   148	    "functions/pagination-helpers.R",
   149	    "functions/external-proxy-functions.R",
   150	    "functions/external-proxy-gnomad.R",
   151	    "functions/external-proxy-gnomad-batch.R",
   152	    "functions/external-proxy-uniprot.R",
   153	    "functions/external-proxy-ensembl.R",
   154	    "functions/external-proxy-alphafold.R",
   155	    "functions/external-proxy-mgi.R",
   156	    "functions/external-proxy-rgd.R",
   157	    "functions/genereviews-lookup.R",
   158	    "functions/file-functions.R",
   159	    "functions/hpo-functions.R",
   160	    "functions/hgnc-functions.R",
   161	    "functions/hgnc-enrichment-gnomad.R",
   162	    "functions/llm-summary-config.R",
   163	    "functions/llm-cache-repository.R",
   164	    "functions/llm-cache-admin-repository.R",
   165	    "functions/llm-validation.R",
   166	    "functions/llm-model-config.R",
   167	    "functions/llm-client.R",
   168	    "functions/llm-rate-limiter.R",
   169	    "functions/llm-types.R",
   170	    "functions/llm-prompt-template-repository.R",
   171	    "functions/llm-service.R",
   172	    "functions/llm-judge-prompts.R",
   173	    "functions/llm-judge.R",
   174	    "functions/llm-batch-cluster-data.R",
   175	    "functions/llm-batch-generator.R",
   176	    "functions/llm-regenerate-helpers.R",
   177	    "functions/mondo-index-builder.R",
   178	    "functions/disease-ontology-mapping-builder.R",
   179	    "functions/disease-ontology-mapping-repository.R",
   180	    "functions/disease-ontology-mapping-refresh.R",
     1	# functions/migration-manifest.R
     2	#
     3	# Strict migration manifest validation for startup/readiness.
     4	
     5	EXPECTED_LATEST_MIGRATION <- "045_add_analysis_snapshot_release.sql"
     6	EXPECTED_MIGRATION_COUNT <- 43L
     7	
     8	#' Validate the migration manifest for strict startup/readiness checks
     9	#'
    10	#' Low-level migration helpers remain tolerant of missing or empty directories
    11	#' for tests and fixtures. API startup/readiness uses this validator so bad
    12	#' migration mounts fail explicitly instead of looking up to date.
    13	#'
    14	#' @param migrations_dir Path to migrations directory. Default: "db/migrations"
    15	#' @param expected_latest Expected latest migration filename for this repo state.
    16	#' @param expected_min_count Minimum SQL migration count for this repo state.
    17	#' @param allow_empty Logical. If TRUE, missing/empty dirs return an allowed
    18	#'   non-ok result for fixture callers instead of throwing.
    19	#'
    20	#' @return List describing manifest health.
    21	#' @export
    22	validate_migration_manifest <- function(migrations_dir = "db/migrations",
    23	                                        expected_latest = EXPECTED_LATEST_MIGRATION,
    24	                                        expected_min_count = EXPECTED_MIGRATION_COUNT,
    25	                                        allow_empty = FALSE) {
    26	  if (!fs::dir_exists(migrations_dir)) {
    27	    if (isTRUE(allow_empty)) {
    28	      return(list(ok = FALSE, allowed_empty = TRUE, reason = "missing_directory", count = 0L))
    29	    }
    30	    stop(sprintf("Migrations directory does not exist: %s", migrations_dir))
    31	  }
    32	
    33	  files <- list_migration_files(migrations_dir)
    34	  count <- length(files)
    35	
    36	  if (count == 0L) {
    37	    if (isTRUE(allow_empty)) {
    38	      return(list(ok = FALSE, allowed_empty = TRUE, reason = "empty_directory", count = 0L))
    39	    }
    40	    stop(sprintf("No migration files found in: %s", migrations_dir))
    41	  }
    42	
    43	  latest <- utils::tail(files, 1L)[[1L]]
    44	
    45	  if (!identical(latest, expected_latest)) {
    46	    stop(sprintf(
    47	      "Expected latest migration mismatch: expected %s, found %s",
    48	      expected_latest,
    49	      latest
    50	    ))
    51	  }
    52	
    53	  if (count < expected_min_count) {
    54	    stop(sprintf("Migration file count too low: found %d, expected at least %d", count, expected_min_count))
    55	  }
    56	
    57	  list(
    58	    ok = TRUE,
    59	    allowed_empty = FALSE,
    60	    count = count,
    61	    expected_latest = expected_latest,
    62	    latest = latest
    63	  )
    64	}

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-coherence.R | sed -n '1,260p'
nl -ba api/functions/analysis-snapshot-repository.R | sed -n '300,430p'
nl -ba api/functions/analysis-snapshot-builder.R | sed -n '440,570p'
nl -ba api/tests/testthat/test-integration-analysis-snapshot-release-build.R | sed -n '1,260p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
     1	# functions/analysis-snapshot-coherence.R
     2	#
     3	# Snapshot partition-coherence gate (#514).
     4	#
     5	# The clustering snapshot builder derives the SERVED membership from the memoised
     6	# clustering function and the VALIDATION (per-cluster stability + partition metrics)
     7	# from a separate, un-memoised validator. They are coherent-by-construction only when
     8	# both ran the identical seeded clustering on the identical graph. A stale memoise
     9	# disk-cache hit (fixed by the #514 fingerprint) broke that assumption in production:
    10	# the served membership was the pre-#510 text-mining partition while the validation was
    11	# the fresh exp+db partition, and the integer-keyed join then left real clusters with
    12	# `n/a` stability.
    13	#
    14	# This module is the defense-in-depth: BEFORE the builder joins validation onto
    15	# membership, assert that the two describe the SAME partition — the visible membership
    16	# cluster set must equal the validation cluster set, and (functional axis) the channel
    17	# the membership was clustered on must match the channel the validator used. On a
    18	# mismatch the refresh throws, so the prior public-ready snapshot is retained and the
    19	# new one is recorded as failed (observable) rather than published incoherent.
    20	#
    21	# `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE` (default "true") gates the hard failure; set it
    22	# to "false" to downgrade to a warning as an operability escape hatch.
    23	
    24	if (!exists("%||%", mode = "function")) {
    25	  `%||%` <- function(x, y) if (is.null(x)) y else x
    26	}
    27	
    28	.analysis_snapshot_require_coherence <- function() {
    29	  val <- tolower(trimws(Sys.getenv("ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE", "true")))
    30	  val %in% c("true", "1", "yes", "on")
    31	}
    32	
    33	#' Assert that a served membership and its validation describe the same partition.
    34	#'
    35	#' @param membership tibble with an integer `cluster` column (the served visible
    36	#'   clusters, already filtered to >= min_size by the clustering function).
    37	#' @param per_cluster the validator's per-cluster tibble with a `cluster_id` column.
    38	#' @param kind "functional" or "phenotype" (for messages only).
    39	#' @param membership_channel,validation_channel optional channel labels; when both are
    40	#'   supplied they must be identical (functional axis coherence).
    41	#' @param membership_members,validation_members optional named lists (cluster_id ->
    42	#'   member-id character vector) for the served membership and the validated reference
    43	#'   partition. When both are supplied, each shared cluster_id must have the SAME member
    44	#'   set — this proves the two describe the same partition, not merely the same labels
    45	#'   (guards against a stale membership whose cluster-id set happens to coincide).
    46	#' @param require_coherence logical; NULL resolves from
    47	#'   `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE`.
    48	#' @return invisibly, a list(coherent, problems, missing_scores, orphan_scores).
    49	#'   Throws (or warns, per the escape hatch) when incoherent.
    50	#' @export
    51	analysis_snapshot_assert_partition_coherent <- function(membership, per_cluster, kind,
    52	                                                        membership_channel = NULL,
    53	                                                        validation_channel = NULL,
    54	                                                        membership_members = NULL,
    55	                                                        validation_members = NULL,
    56	                                                        require_coherence = NULL) {
    57	  if (is.null(require_coherence)) require_coherence <- .analysis_snapshot_require_coherence()
    58	
    59	  membership_ids <- if (is.null(membership) || !("cluster" %in% names(membership))) {
    60	    character(0)
    61	  } else {
    62	    as.character(membership$cluster)
    63	  }
    64	  validation_ids <- if (is.null(per_cluster) || !("cluster_id" %in% names(per_cluster))) {
    65	    character(0)
    66	  } else {
    67	    as.character(per_cluster$cluster_id)
    68	  }
    69	
    70	  missing_scores <- setdiff(membership_ids, validation_ids) # served clusters with no stability row
    71	  orphan_scores <- setdiff(validation_ids, membership_ids) # validation clusters not served
    72	  channel_mismatch <- !is.null(membership_channel) && !is.null(validation_channel) &&
    73	    !identical(as.character(membership_channel), as.character(validation_channel))
    74	
    75	  problems <- character(0)
    76	  if (length(missing_scores)) {
    77	    problems <- c(problems, sprintf(
    78	      "%d visible %s cluster(s) have no validation/stability score (ids: %s)",
    79	      length(missing_scores), kind, paste(missing_scores, collapse = ", ")
    80	    ))
    81	  }
    82	  if (length(orphan_scores)) {
    83	    problems <- c(problems, sprintf(
    84	      "%d validation %s cluster(s) are not in the served membership (ids: %s)",
    85	      length(orphan_scores), kind, paste(orphan_scores, collapse = ", ")
    86	    ))
    87	  }
    88	  if (channel_mismatch) {
    89	    problems <- c(problems, sprintf(
    90	      "%s membership channel (%s) disagrees with the validation channel (%s)",
    91	      kind, membership_channel, validation_channel
    92	    ))
    93	  }
    94	
    95	  # Same-partition proof (not just same labels): for every shared cluster_id the
    96	  # served membership and the validated reference partition must contain the SAME
    97	  # member set. Catches a stale membership whose cluster-id labels coincide with the
    98	  # fresh validation but whose contents differ.
    99	  if (!is.null(membership_members) && !is.null(validation_members)) {
   100	    shared <- intersect(names(membership_members), names(validation_members))
   101	    content_mismatch <- character(0)
   102	    for (cid in shared) {
   103	      a <- unique(as.character(membership_members[[cid]]))
   104	      b <- unique(as.character(validation_members[[cid]]))
   105	      if (!setequal(a, b)) content_mismatch <- c(content_mismatch, cid)
   106	    }
   107	    if (length(content_mismatch)) {
   108	      problems <- c(problems, sprintf(
   109	        "%d %s cluster(s) have membership content that differs from the validated partition (ids: %s)",
   110	        length(content_mismatch), kind, paste(content_mismatch, collapse = ", ")
   111	      ))
   112	    }
   113	  }
   114	
   115	  coherent <- length(problems) == 0L
   116	  if (!coherent) {
   117	    msg <- sprintf(
   118	      paste0(
   119	        "Incoherent %s partition snapshot: membership and validation describe ",
   120	        "different partitions: %s. Refusing to publish (#514)."
   121	      ),
   122	      kind, paste(problems, collapse = "; ")
   123	    )
   124	    if (require_coherence) {
   125	      stop(msg, call. = FALSE)
   126	    } else {
   127	      warning(msg, call. = FALSE)
   128	    }
   129	  }
   130	
   131	  invisible(list(
   132	    coherent = coherent,
   133	    problems = problems,
   134	    missing_scores = missing_scores,
   135	    orphan_scores = orphan_scores
   136	  ))
   137	}
   138	
   139	#' Gate then join the validator's per-cluster scores onto the served membership.
   140	#'
   141	#' Single choke-point for the builder's two clustering presets: it asserts partition
   142	#' coherence FIRST (so an incoherent snapshot can never be published), then performs the
   143	#' `cluster` <-> `cluster_id` left-join, and carries the served membership channel as a
   144	#' `membership_weight_channel` attribute for additive provenance.
   145	#'
   146	#' @param membership tibble from the memoised clustering function (integer `cluster`,
   147	#'   optional `weight_channel` attribute).
   148	#' @param val the validator return list (`per_cluster` tibble + `partition` list).
   149	#' @param kind "functional" or "phenotype".
   150	#' @return the joined clusters tibble (validation columns merged; `cluster_id` dropped).
   151	#' @export
   152	analysis_snapshot_join_validated_clusters <- function(membership, val, kind) {
   153	  membership_channel <- attr(membership, "weight_channel")
   154	  validation_channel <- val$partition$weight_channel
   155	
   156	  # Member id space differs per axis: functional clusters over STRING node ids, phenotype
   157	  # clusters over entity ids. Extract the served per-cluster member set (keyed by the same
   158	  # integer cluster label as val$reference_members) for the same-partition proof.
   159	  member_col <- if (identical(kind, "functional")) "STRING_id" else "entity_id"
   160	  membership_members <- NULL
   161	  if (all(c("identifiers", "cluster") %in% names(membership))) {
   162	    membership_members <- stats::setNames(
   163	      lapply(membership$identifiers, function(df) {
   164	        if (is.data.frame(df) && member_col %in% names(df)) {
   165	          as.character(df[[member_col]])
   166	        } else {
   167	          character(0)
   168	        }
   169	      }),
   170	      as.character(membership$cluster)
   171	    )
   172	  }
   173	
   174	  analysis_snapshot_assert_partition_coherent(
   175	    membership, val$per_cluster, kind,
   176	    membership_channel = membership_channel,
   177	    validation_channel = validation_channel,
   178	    membership_members = membership_members,
   179	    validation_members = val$reference_members
   180	  )
   181	
   182	  joined <- dplyr::left_join(
   183	    dplyr::mutate(membership, cluster_id = as.character(cluster)),
   184	    val$per_cluster,
   185	    by = "cluster_id"
   186	  )
   187	  joined <- dplyr::select(joined, -cluster_id)
   188	  attr(joined, "membership_weight_channel") <- membership_channel %||% NA_character_
   189	  joined
   190	}
   300	  }
   301	
   302	  DBI::dbWithTransaction(conn, tx(conn))
   303	}
   304	
   305	analysis_snapshot_get_public <- function(analysis_type,
   306	                                         parameter_hash,
   307	                                         conn = NULL,
   308	                                         current_source_data_version = NULL) {
   309	  manifest <- db_execute_query(
   310	    "SELECT *
   311	       FROM analysis_snapshot_manifest
   312	      WHERE analysis_type = ?
   313	        AND parameter_hash = ?
   314	        AND public_ready = 1
   315	        AND status = 'public_ready'
   316	      ORDER BY activated_at DESC, snapshot_id DESC
   317	      LIMIT 1",
   318	    unname(list(analysis_type, parameter_hash)),
   319	    conn = conn
   320	  )
   321	
   322	  if (nrow(manifest) == 0L) {
   323	    return(NULL)
   324	  }
   325	
   326	  if (is.null(current_source_data_version) &&
   327	    exists("analysis_snapshot_source_data_version", mode = "function")) {
   328	    current_source_data_version <- tryCatch(
   329	      analysis_snapshot_source_data_version(conn = conn),
   330	      error = function(e) NULL
   331	    )
   332	  }
   333	  if (!is.null(current_source_data_version)) {
   334	    manifest$current_source_data_version <- as.character(current_source_data_version)[1]
   335	  }
   336	
   337	  manifest <- manifest[1, , drop = FALSE]
   338	  status_code <- analysis_snapshot_status_code(manifest)
   339	  if (identical(status_code, "available") &&
   340	      identical(as.character(analysis_type[[1]]), "phenotype_functional_correlations")) {
   341	    if (!exists("analysis_snapshot_dependency_status_code", mode = "function")) {
   342	      status_code <- "dependency_snapshot_mismatch"
   343	    } else {
   344	      status_code <- analysis_snapshot_dependency_status_code(manifest, conn = conn)
   345	    }
   346	  }
   347	  if (!identical(status_code, "available")) {
   348	    return(list(
   349	      manifest = manifest,
   350	      status_code = status_code
   351	    ))
   352	  }
   353	
   354	  snapshot_id <- manifest$snapshot_id[[1]]
   355	  list(
   356	    manifest = manifest,
   357	    status_code = status_code,
   358	    network_nodes = db_execute_query(
   359	      "SELECT * FROM analysis_snapshot_network_node WHERE snapshot_id = ? ORDER BY display_order, hgnc_id",
   360	      unname(list(snapshot_id)),
   361	      conn = conn
   362	    ),
   363	    network_edges = db_execute_query(
   364	      "SELECT * FROM analysis_snapshot_network_edge WHERE snapshot_id = ? ORDER BY edge_rank",
   365	      unname(list(snapshot_id)),
   366	      conn = conn
   367	    ),
   368	    clusters = db_execute_query(
   369	      "SELECT * FROM analysis_snapshot_cluster WHERE snapshot_id = ? ORDER BY cluster_kind, cluster_id",
   370	      unname(list(snapshot_id)),
   371	      conn = conn
   372	    ),
   373	    cluster_members = db_execute_query(
   374	      paste(
   375	        "SELECT * FROM analysis_snapshot_cluster_member",
   376	        "WHERE snapshot_id = ?",
   377	        "ORDER BY cluster_kind, cluster_id, member_rank"
   378	      ),
   379	      unname(list(snapshot_id)),
   380	      conn = conn
   381	    ),
   382	    correlations = db_execute_query(
   383	      "SELECT * FROM analysis_snapshot_correlation WHERE snapshot_id = ? ORDER BY row_rank",
   384	      unname(list(snapshot_id)),
   385	      conn = conn
   386	    )
   387	  )
   388	}
   389	
   390	analysis_snapshot_status_code <- function(row) {
   391	  if (is.null(row) || length(row) == 0L || (is.data.frame(row) && nrow(row) == 0L)) {
   392	    return("snapshot_missing")
   393	  }
   394	
   395	  # Source-data version is the primary freshness signal (more informative when
   396	  # both differ), so it is checked before the schema-version bump below.
   397	  source_version <- analysis_snapshot_scalar(row$source_data_version, NA_character_)
   398	  current_version <- if ("current_source_data_version" %in% names(row)) {
   399	    analysis_snapshot_scalar(row$current_source_data_version, NA_character_)
   400	  } else {
   401	    NA_character_
   402	  }
   403	  if (is.na(current_version)) {
   404	    current_version <- attr(row, "current_source_data_version", exact = TRUE)
   405	  }
   406	  if (!is.null(current_version) &&
   407	    !is.na(current_version) &&
   408	    !is.na(source_version) &&
   409	    !identical(as.character(source_version), as.character(current_version))) {
   410	    return("source_version_mismatch")
   411	  }
   412	
   413	  # Rebuild on a snapshot-schema bump even when source data is unchanged (#483):
   414	  # a stored schema_version != the code's ANALYSIS_SNAPSHOT_SCHEMA_VERSION is
   415	  # treated as not-current (like source_version_mismatch) so it self-heals.
   416	  expected_schema <- tryCatch(as.character(ANALYSIS_SNAPSHOT_SCHEMA_VERSION)[1], error = function(e) NA_character_)
   417	  stored_schema <- analysis_snapshot_scalar(row$schema_version, NA_character_)
   418	  if (!is.na(expected_schema) && !is.na(stored_schema) && nzchar(stored_schema) &&
   419	    !identical(stored_schema, expected_schema)) {
   420	    return("schema_version_mismatch")
   421	  }
   422	
   423	  stale_after <- analysis_snapshot_scalar(row$stale_after, NA)
   424	  if (!is.null(stale_after) && length(stale_after) > 0L && !is.na(stale_after)) {
   425	    stale_at <- as.POSIXct(stale_after, tz = "UTC")
   426	    if (!is.na(stale_at) && stale_at < Sys.time()) {
   427	      return("snapshot_stale")
   428	    }
   429	  }
   430	
   440	    },
   441	    phenotype_functional_correlations = {
   442	      result <- analysis_snapshot_build_dependency_bound_pc_fc_correlation(conn = conn)
   443	      rows <- result$rows
   444	      built <- analysis_snapshot_build_correlation_rows(rows, correlation_kind = "phenotype_functional")
   445	      list(
   446	        kind = "correlations",
   447	        raw = rows,
   448	        correlations = built$correlations,
   449	        row_counts = built$row_counts,
   450	        dependencies = result$dependencies
   451	      )
   452	    },
   453	    gene_network_edges = {
   454	      network <- generate_network_edges_response(
   455	        cluster_type = params$cluster_type,
   456	        min_confidence = params$min_confidence,
   457	        max_edges = params$max_edges
   458	      )
   459	      built <- analysis_snapshot_build_network_rows(network)
   460	      list(
   461	        kind = "network",
   462	        raw = network,
   463	        nodes = built$nodes,
   464	        edges = built$edges,
   465	        metadata = network$metadata %||% list(),
   466	        row_counts = built$row_counts
   467	      )
   468	    },
   469	    stop(sprintf("Unsupported analysis snapshot type: %s", normalized$analysis_type), call. = FALSE)
   470	  )
   471	}
   472	
   473	analysis_snapshot_refresh <- function(analysis_type, params, job_id = NULL, conn = NULL) {
   474	  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
   475	  analysis_snapshot_with_refresh_connection(conn, function(refresh_conn) {
   476	    lock_acquired <- analysis_snapshot_acquire_lock(
   477	      normalized$analysis_type,
   478	      normalized$parameter_hash,
   479	      conn = refresh_conn
   480	    )
   481	    if (!isTRUE(lock_acquired)) {
   482	      stop("Analysis snapshot refresh is already running for this parameter set", call. = FALSE)
   483	    }
   484	    on.exit(
   485	      tryCatch(
   486	        analysis_snapshot_release_lock(normalized$analysis_type, normalized$parameter_hash, conn = refresh_conn),
   487	        error = function(e) NULL
   488	      ),
   489	      add = TRUE
   490	    )
   491	
   492	    source_data_version <- analysis_snapshot_source_data_version(conn = refresh_conn)
   493	    stale_after <- analysis_snapshot_stale_after()
   494	    payload <- analysis_snapshot_build_payload(normalized$analysis_type, normalized$params, conn = refresh_conn)
   495	    row_counts <- payload$row_counts %||% list()
   496	    if (identical(payload$kind, "network")) {
   497	      row_counts$network_metadata <- payload$metadata %||% list()
   498	    }
   499	    # `reproducibility` is an ADDITIVE artifact (raw gzip blob) and must stay out
   500	    # of the payload hash so it never perturbs the cluster/payload hash (#512 is a
   501	    # Wave-1 additive change: no cluster_hash churn, no LLM-cache invalidation).
   502	    payload_hash <- analysis_snapshot_payload_hash(
   503	      payload[setdiff(names(payload), c("raw", "partition_validation", "reproducibility"))]
   504	    )
   505	    input_provenance <- list(
   506	      analysis_type = normalized$analysis_type,
   507	      params = normalized$params,
   508	      source_data_version = source_data_version
   509	    )
   510	    if (!is.null(payload$dependencies)) {
   511	      input_provenance$dependencies <- payload$dependencies
   512	    }
   513	    input_hash <- analysis_snapshot_input_hash(input_provenance)
   514	
   515	    # Human-facing DB release label (#22 / #459). Policy: when the db_version
   516	    # surface is unavailable, store the literal "unknown" (never omit).
   517	    dbv <- tryCatch(db_version_get(conn = refresh_conn),
   518	                    error = function(e) list(version = "unknown", commit = "unknown", available = FALSE))
   519	    db_release_version <- if (isTRUE(dbv$available)) dbv$version %||% "unknown" else "unknown"
   520	    db_release_commit  <- if (isTRUE(dbv$available)) dbv$commit  %||% "unknown" else "unknown"
   521	    source_versions <- list(
   522	      sysndd_public_data = source_data_version,
   523	      db_release_version = db_release_version,
   524	      db_release_commit = db_release_commit
   525	    )
   526	    if (!is.null(payload$dependencies)) {
   527	      source_versions$dependencies <- payload$dependencies
   528	    }
   529	
   530	    write_result <- analysis_snapshot_with_write_transaction(refresh_conn, function(txn_conn) {
   531	      snapshot_id <- analysis_snapshot_create_manifest(
   532	        list(
   533	          analysis_type = normalized$analysis_type,
   534	          parameter_hash = normalized$parameter_hash,
   535	          schema_version = ANALYSIS_SNAPSHOT_SCHEMA_VERSION,
   536	          data_class = normalized$data_class,
   537	          status = "pending",
   538	          generated_by_job_id = job_id,
   539	          stale_after = stale_after,
   540	          source_versions = source_versions,
   541	          source_data_version = source_data_version,
   542	          parameters_json = normalized$parameters_json,
   543	          input_hash = input_hash,
   544	          payload_hash = payload_hash,
   545	          algorithm_name = normalized$params$algorithm %||% normalized$params$cluster_type %||% NA_character_,
   546	          row_counts = row_counts,
   547	          validation = payload$partition_validation,   # NULL for non-clustering presets
   548	          db_release_version = db_release_version,
   549	          db_release_commit  = db_release_commit
   550	        ),
   551	        conn = txn_conn
   552	      )
   553	
   554	      if (identical(payload$kind, "network")) {
   555	        analysis_snapshot_insert_network_rows(snapshot_id, payload, conn = txn_conn)
   556	      } else if (identical(payload$kind, "clusters")) {
   557	        analysis_snapshot_insert_cluster_rows(snapshot_id, payload$clusters, payload$members, conn = txn_conn)
   558	        if (!is.null(payload$reproducibility)) {
   559	          analysis_snapshot_insert_reproducibility(snapshot_id, payload$reproducibility, conn = txn_conn)
   560	        }
   561	      } else if (identical(payload$kind, "correlations")) {
   562	        analysis_snapshot_insert_correlation_rows(snapshot_id, payload$correlations, conn = txn_conn)
   563	      } else {
   564	        stop(sprintf("Unsupported analysis snapshot payload kind: %s", payload$kind), call. = FALSE)
   565	      }
   566	
   567	      analysis_snapshot_activate(
   568	        snapshot_id,
   569	        normalized$analysis_type,
   570	        normalized$parameter_hash,
     1	# tests/testthat/test-integration-analysis-snapshot-release-build.R
     2	#
     3	# Tests for the analysis-snapshot RELEASE build orchestrator (#573 Slice A /
     4	# Task A4): analysis_snapshot_release_build().
     5	#
     6	# ARCHITECTURE: the orchestrator has three dependency-injection seams so the
     7	# correctness-critical GATES are deterministically unit-testable WITHOUT seeding
     8	# the (very complex) analysis_snapshot_* source tables:
     9	#   - loader(analysis_type, parameter_hash, conn)  (default analysis_snapshot_get_public)
    10	#   - reproducibility_loader(snapshot_id, conn)    (default analysis_snapshot_get_reproducibility)
    11	#   - coherence_assert(snapshot, kind)             (default analysis_snapshot_release_assert_coherent)
    12	# Every gate branch is driven by injecting fakes. PERSISTENCE (analysis_release_*)
    13	# runs against the REAL release tables (ensure_test_release_schema), so
    14	# idempotency/persistence is genuinely exercised even while the snapshot SOURCE is
    15	# faked. The real seam DEFAULTS are exercised by the post-slice dev-stack e2e.
    16	#
    17	# DDL / transaction traps (verified live against RMariaDB, mirrored from the A3
    18	# repository test): analysis_release_insert() opens ONE DBI::dbWithTransaction()
    19	# on its conn, which cannot be nested inside with_test_db_transaction(); and
    20	# ensure_test_release_schema() applies DDL (auto-commits) on its OWN short-lived
    21	# connection first. So the build tests use a single plain connection and clean up
    22	# via DELETE (children cascade), never with_test_db_transaction().
    23	
    24	release_build_test_wd <- getwd()
    25	setwd(get_api_dir())
    26	withr::defer(setwd(release_build_test_wd), testthat::teardown_env())
    27	
    28	source(file.path("core", "errors.R"), local = TRUE)
    29	source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
    30	source(file.path("functions", "analysis-snapshot-dependencies.R"), local = TRUE)
    31	source(file.path("functions", "analysis-snapshot-coherence.R"), local = TRUE)
    32	source(file.path("functions", "analysis-reproducibility.R"), local = TRUE)
    33	source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = TRUE)
    34	source(file.path("functions", "analysis-snapshot-release-repository.R"), local = TRUE)
    35	source(file.path("functions", "analysis-snapshot-release-materialize.R"), local = TRUE)
    36	source(file.path("functions", "analysis-snapshot-release.R"), local = TRUE)
    37	
    38	# --------------------------------------------------------------------------- #
    39	# Fixtures: fake loaded snapshots mirroring analysis_snapshot_get_public()'s
    40	# return shape (status_code + manifest [1-row df] + payload tibbles).
    41	# --------------------------------------------------------------------------- #
    42	
    43	SRC_V <- "srcv-2026-07-18"
    44	FUNC_ID <- 101L
    45	PHEN_ID <- 202L
    46	CORR_ID <- 303L
    47	FUNC_HASH <- analysis_release_sha256("functional-payload")
    48	PHEN_HASH <- analysis_release_sha256("phenotype-payload")
    49	CORR_HASH <- analysis_release_sha256("correlation-payload")
    50	
    51	DB_RELEASE_VERSION <- "1.0.0"
    52	DB_RELEASE_COMMIT <- "abc1234"
    53	
    54	make_manifest <- function(analysis_type, snapshot_id, payload_hash,
    55	                          source_data_version = SRC_V,
    56	                          input_hash = analysis_release_sha256(paste0(analysis_type, "-input")),
    57	                          schema_version = "1.2",
    58	                          source_versions_json = NA_character_,
    59	                          db_release_version = DB_RELEASE_VERSION,
    60	                          db_release_commit = DB_RELEASE_COMMIT) {
    61	  data.frame(
    62	    analysis_type = analysis_type,
    63	    snapshot_id = as.integer(snapshot_id),
    64	    payload_hash = payload_hash,
    65	    input_hash = input_hash,
    66	    source_data_version = source_data_version,
    67	    schema_version = schema_version,
    68	    source_versions_json = source_versions_json,
    69	    db_release_version = db_release_version,
    70	    db_release_commit = db_release_commit,
    71	    stringsAsFactors = FALSE
    72	  )
    73	}
    74	
    75	make_cluster_snap <- function(analysis_type, kind, snapshot_id, payload_hash,
    76	                              source_data_version = SRC_V, status_code = "available",
    77	                              stability_ok = TRUE) {
    78	  meta <- if (stability_ok) {
    79	    c('{"jaccard_mean":0.82,"jaccard_n_resamples":50}', '{"jaccard_mean":0.61,"jaccard_n_resamples":50}')
    80	  } else {
    81	    c('{"jaccard_mean":0.82,"jaccard_n_resamples":50}', '{"jaccard_n_resamples":0}')
    82	  }
    83	  clusters <- data.frame(
    84	    cluster_kind = c(kind, kind),
    85	    cluster_id = c("1", "2"),
    86	    cluster_hash = c(analysis_release_sha256(paste0(kind, "-c1")), analysis_release_sha256(paste0(kind, "-c2"))),
    87	    cluster_size = c(3L, 2L),
    88	    label = c("Cluster A", "Cluster B"),
    89	    metadata_json = meta,
    90	    stringsAsFactors = FALSE
    91	  )
    92	  members <- data.frame(
    93	    cluster_kind = kind,
    94	    cluster_id = c("1", "1", "1", "2", "2"),
    95	    member_rank = c(1L, 2L, 3L, 1L, 2L),
    96	    entity_id = c(10L, 11L, 12L, 13L, 14L),
    97	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3", "HGNC:4", "HGNC:5"),
    98	    symbol = c("G1", "G2", "G3", "G4", "G5"),
    99	    stringsAsFactors = FALSE
   100	  )
   101	  list(
   102	    status_code = status_code,
   103	    manifest = make_manifest(analysis_type, snapshot_id, payload_hash, source_data_version),
   104	    clusters = clusters,
   105	    cluster_members = members
   106	  )
   107	}
   108	
   109	make_corr_snap <- function(func_id = FUNC_ID, func_hash = FUNC_HASH,
   110	                           phen_id = PHEN_ID, phen_hash = PHEN_HASH,
   111	                           source_data_version = SRC_V, status_code = "available") {
   112	  deps_json <- analysis_snapshot_canonical_json(list(dependencies = list(
   113	    functional_clusters = list(snapshot_id = func_id, payload_hash = func_hash),
   114	    phenotype_clusters = list(snapshot_id = phen_id, payload_hash = phen_hash)
   115	  )))
   116	  correlations <- data.frame(
   117	    row_rank = 1:3,
   118	    correlation_kind = c("pc_fc", "pc_fc", "pc_fc"),
   119	    x_key = c("fc_1", "fc_1", "pc_1"),
   120	    y_key = c("fc_1", "pc_1", "pc_1"),
   121	    value = c(1.0, 0.21, 1.0),
   122	    abs_value = c(1.0, 0.21, 1.0),
   123	    metadata_json = NA_character_,
   124	    stringsAsFactors = FALSE
   125	  )
   126	  list(
   127	    status_code = status_code,
   128	    manifest = make_manifest("phenotype_functional_correlations", CORR_ID, CORR_HASH,
   129	      source_data_version,
   130	      source_versions_json = deps_json
   131	    ),
   132	    correlations = correlations
   133	  )
   134	}
   135	
   136	make_repro_bundle <- function(kind) {
   137	  payload <- if (identical(kind, "functional")) {
   138	    list(
   139	      edges = data.frame(
   140	        source = c("1", "2"), target = c("2", "3"),
   141	        combined_score = c(0.987654321098765, 0.6543210987654321),
   142	        stringsAsFactors = FALSE
   143	      ),
   144	      membership = data.frame(node = c("1", "2", "3"), cluster = c(1L, 1L, 2L), stringsAsFactors = FALSE),
   145	      served_modularity = 0.123456789012345,
   146	      params = list(seed = 42L, weight_channel = "experimental_database")
   147	    )
   148	  } else {
   149	    list(
   150	      coords = data.frame(
   151	        entity_id = c("10", "11"), Dim.1 = c(0.111111111, 0.222222222),
   152	        Dim.2 = c(0.333333333, 0.444444444), stringsAsFactors = FALSE
   153	      ),
   154	      membership = data.frame(entity_id = c("10", "11"), cluster = c(1L, 2L), stringsAsFactors = FALSE),
   155	      served_silhouette = 0.234567890123,
   156	      params = list(seed = 42L)
   157	    )
   158	  }
   159	  analysis_reproducibility_bundle(kind, payload)
   160	}
   161	
   162	FUNC_BUNDLE <- make_repro_bundle("functional")
   163	PHEN_BUNDLE <- make_repro_bundle("phenotype")
   164	
   165	# reproducibility_loader fake returning the real bundle row-shape for cluster ids.
   166	present_repro_loader <- function(snapshot_id, conn = NULL) {
   167	  sid <- as.integer(snapshot_id)
   168	  b <- if (identical(sid, FUNC_ID)) FUNC_BUNDLE else if (identical(sid, PHEN_ID)) PHEN_BUNDLE else NULL
   169	  if (is.null(b)) {
   170	    return(NULL)
   171	  }
   172	  row <- data.frame(
   173	    kind = b$kind, reproducibility_hash = b$reproducibility_hash,
   174	    byte_size = b$byte_size, stringsAsFactors = FALSE
   175	  )
   176	  row$bundle_gzip_json <- list(b$bundle_gzip_json) # DBI blob column shape: list-of-raw
   177	  row
   178	}
   179	
   180	pass_coherence <- function(snapshot, kind) invisible(TRUE)
   181	
   182	# Base loader returning a coherent, available snapshot for every default layer.
   183	make_loader <- function(overrides = list()) {
   184	  base <- list(
   185	    functional_clusters = make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH),
   186	    phenotype_clusters = make_cluster_snap("phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH),
   187	    phenotype_functional_correlations = make_corr_snap()
   188	  )
   189	  snaps <- utils::modifyList(base, overrides)
   190	  function(analysis_type, parameter_hash, conn = NULL) snaps[[analysis_type]]
   191	}
   192	
   193	# A functional cluster snapshot whose manifest validation_json carries the served
   194	# membership channel + the validation channel (the exp+db-vs-text-mining #514 case).
   195	make_functional_snap_with_channels <- function(membership_channel, validation_channel) {
   196	  snap <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
   197	  snap$manifest$validation_json <- analysis_snapshot_canonical_json(list(
   198	    weight_channel = validation_channel,
   199	    membership_weight_channel = membership_channel
   200	  ))
   201	  snap
   202	}
   203	
   204	# A STATEFUL loader: returns the original snapshot on the first read of each
   205	# preset, then a DIFFERENT {snapshot_id, payload_hash} for `changed_type` on the
   206	# pre-insert re-read — simulating a concurrent axis refresh mid-build. Proves the
   207	# pre-insert re-read is a FRESH DB read, not a tautological re-check of `loaded`.
   208	make_stateful_loader <- function(changed_type = "functional_clusters") {
   209	  counts <- new.env(parent = emptyenv())
   210	  base <- make_loader()
   211	  function(analysis_type, parameter_hash, conn = NULL) {
   212	    n <- (counts[[analysis_type]] %||% 0L) + 1L
   213	    counts[[analysis_type]] <- n
   214	    snap <- base(analysis_type, parameter_hash, conn)
   215	    if (identical(analysis_type, changed_type) && n >= 2L) {
   216	      snap$manifest <- make_manifest(analysis_type, 999L, analysis_release_sha256("refreshed-payload"))
   217	    }
   218	    snap
   219	  }
   220	}
   221	
   222	# --------------------------------------------------------------------------- #
   223	# Gate tests (no DB: they fail before any persistence; conn = NULL).
   224	# --------------------------------------------------------------------------- #
   225	
   226	test_that("build refuses when any layer snapshot is not available", {
   227	  loader <- make_loader(list(
   228	    phenotype_clusters = make_cluster_snap(
   229	      "phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH,
   230	      status_code = "snapshot_stale"
   231	    )
   232	  ))
   233	  expect_error(
   234	    analysis_snapshot_release_build(
   235	      conn = NULL, publish = TRUE,
   236	      loader = loader, reproducibility_loader = present_repro_loader,
   237	      coherence_assert = pass_coherence
   238	    ),
   239	    class = "release_snapshot_not_available"
   240	  )
   241	})
   242	
   243	test_that("build refuses an available-but-incoherent snapshot (hard coherence re-check)", {
   244	  throwing_coherence <- function(snapshot, kind) stop("planted incoherence")
   245	  expect_error(
   246	    analysis_snapshot_release_build(
   247	      conn = NULL, publish = TRUE,
   248	      loader = make_loader(), reproducibility_loader = present_repro_loader,
   249	      coherence_assert = throwing_coherence
   250	    ),
   251	    class = "release_source_incoherent"
   252	  )
   253	})
   254	
   255	test_that("build refuses when a cluster layer's reproducibility bundle is missing", {
   256	  missing_repro_loader <- function(snapshot_id, conn = NULL) {
   257	    if (identical(as.integer(snapshot_id), FUNC_ID)) {
   258	      return(NULL)
   259	    }
   260	    present_repro_loader(snapshot_id, conn)

codex
The targeted test command could not start because this environment forbids creating R’s temporary files; no repository state was changed. Static diff validation is clean. I’ve completed the source-level check and am preparing the re-review, including the unresolved provenance conflict and a separate release-coherence gap discovered in the full Slice A gate path.
exec
/bin/bash -lc "git status --short
git diff --check 67cf6003..HEAD
git diff --numstat 67cf6003..HEAD | tail -20
git log --format='%H %s' 49eb025b..HEAD" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-prompt.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-reconciliation.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-rereview-prompt.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-rereview.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-review.md
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:7: trailing whitespace.
+- [Plan A4](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:262) requires `sha256(payload.json) == payload_hash`. That is not achievable from the persisted snapshot. `payload_hash` is computed on the pre-persistence in-memory object, while release construction reads normalized child rows; correlations/edges round-trip through `DECIMAL(8,5)` / `DECIMAL(8,7)` ([builder](/home/bernt-popp/development/sysndd/api/functions/analysis-snapshot-builder.R:502), [migration](/home/bernt-popp/development/sysndd/db/migrations/024_add_public_analysis_snapshots.sql:67)). A value rounded on insert makes the A4 assertion fail and blocks release creation. The current design correctly contradicts the plan on this point ([spec](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:126)).  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:10: trailing whitespace.
+- [Spec §6](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:127) incorrectly says `analysis_reproducibility_decode()` returns the original JSON string. It returns a parsed R object ([implementation](/home/bernt-popp/development/sysndd/api/functions/analysis-reproducibility.R:112)); reserializing it with the snapshot serializer loses the `digits = NA` contract used for `reproducibility_hash` ([serializer](/home/bernt-popp/development/sysndd/api/functions/analysis-reproducibility.R:31)). A bundle with a full-precision modularity value will fail the planned hash assertion.  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:13: trailing whitespace.
+- [Plan A6](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:310) proposes Plumber `<path:.*>`. SysNDD pins Plumber 1.3.2 ([renv.lock](/home/bernt-popp/development/sysndd/api/renv.lock:7382)); its path grammar only supports named, typed single-segment parameters (`<id>`, `<id:int>`). `.*` is not a supported type and the replacement grammar does not accept `*`; it will not capture `functional_clusters/payload.json`. Consequently every nested release-file URL 404s.  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:16: trailing whitespace.
+- [Plan A1](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:141) updates only `EXPECTED_LATEST_MIGRATION`. The live manifest also enforces `EXPECTED_MIGRATION_COUNT = 42L` ([migration manifest](/home/bernt-popp/development/sysndd/api/functions/migration-manifest.R:5)). Adding `045` without changing it to `43L` makes API startup fail before serving anything.  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:21: trailing whitespace.
+- [Spec §7](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:175) claims `analysis_snapshot_get_public()` reuses the coherence gate. It does not: it only checks freshness/schema, and runs dependency validation only for the correlation layer ([repository](/home/bernt-popp/development/sysndd/api/functions/analysis-snapshot-repository.R:337)). The actual coherence gate can be downgraded to a warning with `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false` ([coherence gate](/home/bernt-popp/development/sysndd/api/functions/analysis-snapshot-coherence.R:21)). An incoherent but `public_ready` functional snapshot can therefore pass `status_code == "available"` and be frozen as a release.  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:24: trailing whitespace.
+- The design and plan are mutually incompatible on material API behavior: the current spec requires 400 for unavailable inputs, idempotent 200, a 64-bit short handle, collision checking, and a TOCTOU guard ([spec](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:169)), while the plan implements 409, 48-bit IDs, `release_already_exists`, and no lock/consistent transaction ([plan](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:240)). A concurrent axis refresh after the plan reads the correlation but before insert yields a “current” release pinned to superseded axes. Also, following A5 literally would add only `core/errors.R`; `errorHandler` has no 409 branch ([filters](/home/bernt-popp/development/sysndd/api/core/filters.R:272)), so any new conflict condition becomes an opaque 500.  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:27: trailing whitespace.
+- Reproducibility is best-effort in the current snapshot builder: a failed bundle build returns `NULL`, yet the snapshot still activates ([repro persistence](/home/bernt-popp/development/sysndd/api/functions/analysis-reproducibility.R:391)). The release schema permits a null `reproducibility_hash`, but the release file set makes both reproducibility files mandatory. A current functional snapshot without a bundle passes `available`, then produces either an opaque crash or a release that cannot reproduce its stated metrics.  
.planning/reviews/2026-07-18-analysis-snapshot-releases-573-codex-review.md:32: trailing whitespace.
+- [Plan D2](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:374) says to extend dedupe only with the resolved HGNC hash. Existing dedupe keys only `{genes, algorithm}` ([submission service](/home/bernt-popp/development/sysndd/api/services/job-functional-submission-service.R:86)). `["Definitive"]` and `["Definitive","Moderate"]` can resolve to the same current genes; the second request then receives a duplicate of the first while claiming a different selector/provenance.  
560	0	api/tests/testthat/test-integration-analysis-snapshot-release-build.R
313	0	api/tests/testthat/test-integration-analysis-snapshot-release-repository.R
3	3	api/tests/testthat/test-mcp-select-principal-projections.R
19	2	api/tests/testthat/test-unit-admin-snapshot-endpoint-guard.R
80	0	api/tests/testthat/test-unit-analysis-reproducibility.R
2	2	api/tests/testthat/test-unit-analysis-snapshot-migration.R
225	0	api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R
180	0	api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R
110	0	api/tests/testthat/test-unit-analysis-snapshot-release-migration.R
534	0	api/tests/testthat/test-unit-analysis-snapshot-release-service.R
15	1	api/tests/testthat/test-unit-analysis-snapshot-repository.R
74	0	api/tests/testthat/test-unit-cheap-route-isolation.R
4	4	api/tests/testthat/test-unit-core-views-manifest.R
1	1	api/version_spec.json
2	2	app/package-lock.json
1	1	app/package.json
69	0	db/migrations/045_add_analysis_snapshot_release.sql
6	1	db/migrations/README.md
46	0	documentation/08-development.qmd
67	0	documentation/09-deployment.qmd
f522428564dccbe6ea5439124c6663ff13d955e0 fix(api): release public-surface hardening — head projection, 503 lock path, pagination clamp, prune guard (#573)
44455711501949bad89499da321acdf97007d37c fix(api): release build hardening — layer selection, path containment, repro-hash verify, TOCTOU idempotency, DB provenance (#573)

codex
## HIGH

- [analysis-snapshot-release-materialize.R:173](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release-materialize.R:173) — release “hard coherence” does not verify member-set coherence. It calls the coherence helper without `membership_members` or `validation_members`; that helper only checks membership content when both are supplied ([analysis-snapshot-coherence.R:99](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-coherence.R:99)). A snapshot admitted while `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false`, whose stale and validated partitions share cluster IDs/channels but differ in members, passes the release gate and can be frozen publicly. Persist a hard coherence attestation/reference-member sets at activation and require it at release build.  
  This is a remaining whole-slice gate issue, not introduced by the two fix commits.

## MEDIUM

- [analysis-snapshot-release-materialize.R:63](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release-materialize.R:63) — DB-release provenance is populated, but conflicting layer values are silently represented as the first value ([line 73](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release-materialize.R:73)). A functional snapshot from DB release `v1` and phenotype snapshot from `v2` can yield a release whose head and manifest claim only `v1`. Reject inconsistent non-empty values, or retain provenance per layer; do not select arbitrarily.

## LOW

- [analysis_endpoints.R:417](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/endpoints/analysis_endpoints.R:417) — the DB query is correctly clamped by `svc_release_list()`, but response pagination reports the unclamped request values. For `?limit=1000000&offset=-1`, it returns at most 100 rows from offset 0 yet reports `limit: 1000000, offset: -1`. Clamp before constructing the response, or return effective pagination values from the service.

Prior-finding verification:

- BLOCKER layer-policy/path bypass: resolved. Authoritative registry resolution ignores caller policy fields; unknown/duplicate selectors are 400; empty selection becomes the full registry; archive paths are checked at both materialization and tar-write points.
- HIGH public operational-field leak: resolved. Public list/detail/latest project through an explicit allowlist; admin routes retain raw heads. Public `layers` are explicitly selected safe fields, and release manifests contain no head operational fields.
- HIGH reproducibility hash: resolved. The build hashes raw pre-gzip decoded bytes, not a parsed/re-serialized object, and rejects mismatches.
- HIGH lock/idempotency race: resolved. Real checked-out DB connections require all locks; lock contention maps to 503 + `Retry-After`; duplicate-key recovery returns an existing release only when its full digest matches.
- MEDIUM provenance: only partially resolved; see finding above.
- LOW pagination resource bound: enforced at the service/SQL boundary; response metadata remains incorrect.

`git diff --check` only reports trailing whitespace in an existing planning review document. Targeted R tests could not be started because this read-only sandbox blocks R temporary-file creation.  

**DO NOT SHIP** until the HIGH coherence issue is addressed.
tokens used
149,807
## HIGH

- [analysis-snapshot-release-materialize.R:173](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release-materialize.R:173) — release “hard coherence” does not verify member-set coherence. It calls the coherence helper without `membership_members` or `validation_members`; that helper only checks membership content when both are supplied ([analysis-snapshot-coherence.R:99](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-coherence.R:99)). A snapshot admitted while `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false`, whose stale and validated partitions share cluster IDs/channels but differ in members, passes the release gate and can be frozen publicly. Persist a hard coherence attestation/reference-member sets at activation and require it at release build.  
  This is a remaining whole-slice gate issue, not introduced by the two fix commits.

## MEDIUM

- [analysis-snapshot-release-materialize.R:63](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release-materialize.R:63) — DB-release provenance is populated, but conflicting layer values are silently represented as the first value ([line 73](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release-materialize.R:73)). A functional snapshot from DB release `v1` and phenotype snapshot from `v2` can yield a release whose head and manifest claim only `v1`. Reject inconsistent non-empty values, or retain provenance per layer; do not select arbitrarily.

## LOW

- [analysis_endpoints.R:417](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/endpoints/analysis_endpoints.R:417) — the DB query is correctly clamped by `svc_release_list()`, but response pagination reports the unclamped request values. For `?limit=1000000&offset=-1`, it returns at most 100 rows from offset 0 yet reports `limit: 1000000, offset: -1`. Clamp before constructing the response, or return effective pagination values from the service.

Prior-finding verification:

- BLOCKER layer-policy/path bypass: resolved. Authoritative registry resolution ignores caller policy fields; unknown/duplicate selectors are 400; empty selection becomes the full registry; archive paths are checked at both materialization and tar-write points.
- HIGH public operational-field leak: resolved. Public list/detail/latest project through an explicit allowlist; admin routes retain raw heads. Public `layers` are explicitly selected safe fields, and release manifests contain no head operational fields.
- HIGH reproducibility hash: resolved. The build hashes raw pre-gzip decoded bytes, not a parsed/re-serialized object, and rejects mismatches.
- HIGH lock/idempotency race: resolved. Real checked-out DB connections require all locks; lock contention maps to 503 + `Retry-After`; duplicate-key recovery returns an existing release only when its full digest matches.
- MEDIUM provenance: only partially resolved; see finding above.
- LOW pagination resource bound: enforced at the service/SQL boundary; response metadata remains incorrect.

`git diff --check` only reports trailing whitespace in an existing planning review document. Targeted R tests could not be started because this read-only sandbox blocks R temporary-file creation.  

**DO NOT SHIP** until the HIGH coherence issue is addressed.
