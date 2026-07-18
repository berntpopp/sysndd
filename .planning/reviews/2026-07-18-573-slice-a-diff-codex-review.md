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
session id: 019f76b9-ef3d-75e1-8261-c5c7e679abf6
--------
user
# Codex adversarial DIFF review — #573 Slice A (immutable public analysis-snapshot releases, backend)

You are an adversarial staff-level reviewer. Review the implemented backend for issue #573 on the current branch against `master`. Be skeptical and thorough: find correctness bugs, security holes, and any regression of the LOCKED design decisions below. Prefer concrete, reproducible findings with `file:line` and a failure scenario.

## What to review
The Slice A commits are `git log --oneline 67cf6003..HEAD` (branch tip). Inspect the full diff: `git diff 67cf6003..HEAD`. Key new/changed files:
- `db/migrations/045_add_analysis_snapshot_release.sql` (+ `api/functions/migration-manifest.R` constant bump)
- `api/functions/analysis-snapshot-release-manifest.R` (pure content-address/manifest/tar helpers)
- `api/functions/analysis-snapshot-release-repository.R` (DB reads/writes, blobs)
- `api/functions/analysis-snapshot-release.R` + `api/functions/analysis-snapshot-release-materialize.R` (build orchestrator + gates + materialization)
- `api/functions/analysis-reproducibility.R` (new `analysis_reproducibility_decode_raw`)
- `api/services/analysis-snapshot-release-service.R` (problem+json shaping)
- `api/endpoints/analysis_endpoints.R` (public read routes) + `api/endpoints/admin_analysis_snapshot_endpoints.R` (admin routes)
- `api/functions/analysis-snapshot-repository.R` (`analysis_snapshot_prune` release guard)
- `api/bootstrap/load_modules.R` (registration); tests under `api/tests/testthat/`
Spec (source of truth, already reconciled with a prior Codex review — do NOT re-litigate settled design): `.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md` and plan `…-573-plan.md`.

## LOCKED decisions (intentional — flag a REGRESSION of these, not the decision itself)
- Release identity = `content_digest` = sha256 over invariant scientific content, EXCLUDING `created_at`/`title`/DOI. `release_id = "asr_" + content_digest[:16]`; full 64-char digest stored; collision-checked on insert.
- Each release file has its OWN `content_sha256`. `sha256(payload.json) != payload_hash` by design (DECIMAL round-trip) — `payload_hash`/`input_hash`/`snapshot_id` are cross-checkable LINEAGE ANCHORS vs the live `meta.snapshot`, not the file hash.
- `reproducibility.json` = the RAW `memDecompress(bundle_gzip_json, type="gzip", asChar=TRUE)` bytes (NOT the parsing `analysis_reproducibility_decode()`), so `sha256(reproducibility.json) == reproducibility_hash` EXACTLY.
- File retrieval route = `GET /releases/<id>/file?path=<file_path>` (query param; Plumber 1.3.2 has NO `<path:.*>`); exact `(release_id,file_path)` PK lookup, no traversal surface.
- Build fails 400 (there is NO 409 class): not-available / hard-coherence-recheck (require_coherence=TRUE, ignoring the env downgrade; incl. the reconstructable channel-match check; member-set equality is genuinely NOT reconstructable because `reference_members` is not persisted — the non-NA-stability check is the accepted substitute) / missing-reproducibility / source-version-mismatch / dependency-lineage-mismatch. Duplicate build = idempotent 200. TOCTOU: per-preset advisory locks + a FRESH pre-insert loader re-read re-asserting {snapshot_id,payload_hash}+deps. DOI additive, outside the hash. Bundle built once + stored + served verbatim (rebuild determinism NOT required).
- Migration 045 bumps BOTH `EXPECTED_LATEST_MIGRATION` and `EXPECTED_MIGRATION_COUNT` (42→43).
- Public release routes are DB-only (no external fetcher). Admin routes require Administrator. Drafts never public.

## Focus your adversarial attention on
1. **Authorization / data exposure:** can any public route reach a draft release or non-approved-public data? Is every admin route Administrator-gated (first line)? Any way to bypass?
2. **SQL / injection:** every `release_id`/`file_path`/param goes through bound `?` params with `unname()`; no string interpolation; the prune `NOT IN`/helper is NULL-safe. Any interpolation site?
3. **Build gate soundness:** can an incoherent / stale / mismatched / reproducibility-less / superseded snapshot be frozen into a published release? Is the TOCTOU re-read genuinely fresh (not the cached in-memory object)? Do the per-preset locks actually collide with the axis-refresh locks?
4. **Hashing invariants:** verify the reproducibility.json exact-equality and the content_digest exclusions hold in code; look for any place `created_at`/`title`/DOI could leak into the digest, or where the served bytes could differ from the hashed bytes.
5. **Byte-serving correctness:** the manifest/file/bundle routes — single Content-Type, correct bytes, no traversal, blobs not stringified/logged.
6. **Resource safety:** the build route's `pool::poolCheckout` returns the connection on ALL paths (incl. every 400 error path); advisory locks released on all exits; no connection/lock leak.
7. **Adjacent same-class issues:** if you find one instance of a class of bug (a missing bound param, a leak path, an authz gap, a hash-input inconsistency), GREP FOR AND REPORT ALL SIBLINGS in the release code — do not stop at the first.
8. **Migration/bootstrap:** 045 DDL correctness for MySQL 8.4; the manifest count/latest bump; module source order in load_modules.R.

## Output format
Group findings by severity: BLOCKER / HIGH / MEDIUM / LOW. For each: `file:line`, the defect, a concrete failure scenario (inputs → wrong outcome), and a minimal fix. If a concern turns out to be handled correctly, say so briefly (a short "checked X — OK"). End with a one-line SHIP / DO-NOT-SHIP recommendation. Do not modify any files (read-only review).
codex
I’ll inspect the locked design spec and the complete `67cf6003..HEAD` backend diff, then trace the public/admin routes, build gates, DB layer, and tests for bypasses and sibling defects.
exec
/bin/bash -lc "sed -n '1,240p' /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md && git status --short && git log --oneline 67cf6003..HEAD && git diff --stat 67cf6003..HEAD" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
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
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-prompt.md
?? .planning/reviews/2026-07-18-573-slice-a-diff-codex-review.md
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
87b41f5f docs(review): Codex (gpt-5.6-terra) adversarial review + reconciled #574 design/plan
5558850e docs(spec+plan): dedicated rigorous #574 design + TDD plan (category-selected clustering)
e925c54e docs(review): Codex (gpt-5.6-terra) adversarial review + reconciled spec/plan (#573)
ec20f31d docs(plan): implementation plan for analysis-snapshot releases (#573/#574/#572)
758da251 docs(spec): immutable public analysis-snapshot releases (#573) + companions (#574/#572)
 .gitignore                                         |   3 +
 ...-analysis-snapshot-releases-573-codex-prompt.md |  33 ++
 ...s-snapshot-releases-573-codex-reconciliation.md |  19 +
 ...-analysis-snapshot-releases-573-codex-review.md |  33 ++
 ...tegory-clustering-universes-574-codex-prompt.md |  33 ++
 ...lustering-universes-574-codex-reconciliation.md |  15 +
 ...tegory-clustering-universes-574-codex-review.md |  23 +
 ...26-07-18-analysis-snapshot-releases-573-plan.md | 415 ++++++++++++++++++
 ...07-18-category-clustering-universes-574-plan.md | 277 ++++++++++++
 ...-07-18-analysis-snapshot-releases-573-design.md | 352 +++++++++++++++
 ...-18-category-clustering-universes-574-design.md | 151 +++++++
 AGENTS.md                                          |  13 +
 CHANGELOG.md                                       |  61 +++
 README.md                                          |   1 +
 api/bootstrap/load_modules.R                       |  16 +
 api/endpoints/admin_analysis_snapshot_endpoints.R  | 232 ++++++++++
 api/endpoints/analysis_endpoints.R                 | 159 +++++++
 api/functions/analysis-reproducibility.R           |  25 ++
 api/functions/analysis-snapshot-release-manifest.R | 206 +++++++++
 .../analysis-snapshot-release-materialize.R        | 337 ++++++++++++++
 .../analysis-snapshot-release-repository.R         | 441 +++++++++++++++++++
 api/functions/analysis-snapshot-release.R          | 446 +++++++++++++++++++
 api/functions/analysis-snapshot-repository.R       |   7 +-
 api/functions/migration-manifest.R                 |   4 +-
 api/services/analysis-snapshot-release-service.R   | 244 +++++++++++
 api/tests/testthat/helper-db.R                     | 105 +++++
 ...-integration-analysis-release-admin-endpoints.R | 488 +++++++++++++++++++++
 .../test-integration-analysis-release-endpoints.R  | 360 +++++++++++++++
 ...t-integration-analysis-snapshot-release-build.R | 471 ++++++++++++++++++++
 ...egration-analysis-snapshot-release-repository.R | 278 ++++++++++++
 .../test-mcp-select-principal-projections.R        |   6 +-
 .../test-unit-admin-snapshot-endpoint-guard.R      |  21 +-
 .../testthat/test-unit-analysis-reproducibility.R  |  80 ++++
 .../test-unit-analysis-snapshot-migration.R        |   4 +-
 ...st-unit-analysis-snapshot-prune-release-guard.R | 225 ++++++++++
 .../test-unit-analysis-snapshot-release-manifest.R | 126 ++++++
 ...test-unit-analysis-snapshot-release-migration.R | 110 +++++
 .../test-unit-analysis-snapshot-release-service.R  | 473 ++++++++++++++++++++
 .../test-unit-analysis-snapshot-repository.R       |  16 +-
 .../testthat/test-unit-cheap-route-isolation.R     |  74 ++++
 api/tests/testthat/test-unit-core-views-manifest.R |   8 +-
 api/version_spec.json                              |   2 +-
 app/package-lock.json                              |   4 +-
 app/package.json                                   |   2 +-
 .../045_add_analysis_snapshot_release.sql          |  69 +++
 db/migrations/README.md                            |   7 +-
 documentation/08-development.qmd                   |  46 ++
 documentation/09-deployment.qmd                    |  67 +++
 48 files changed, 6568 insertions(+), 20 deletions(-)

codex
I’m using the repository’s security review guidance because this is an authorization, SQL, data-exposure, and resource-lifetime audit; I’ll keep it read-only.
exec
/bin/bash -lc "sed -n '1,260p' .agents/skills/sysndd-security-bug-scan/SKILL.md && sed -n '1,240p' .planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md && sed -n '1,220p' .planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
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
# Immutable Public Analysis-Snapshot Releases + Category-Selected Clustering — Design

Date: 2026-07-18
Issues: **#573** (feat: publish immutable public analysis-snapshot releases with verifiable lineage — PRIMARY), **#574** (feat: category-selected gene universes for functional clustering jobs — companion), **#572** (bug: production serves a phenotype-functional snapshot without dependency lineage — deployment prerequisite).
Reference: `../nddscore` Zenodo dataset-release flow (`scripts/package_sysndd_zenodo_dataset.py`, `scripts/upload_sysndd_zenodo_dataset.py`, `src/models/sysndd_export.py`, `.planning/specs/2026-05-17-sysndd-zenodo-dataset-release-design.md`).

---

## 1. Summary

Add a **read-only, immutable, content-addressed public "analysis-snapshot release"** layer on top of the existing durable analysis snapshots, so a manuscript can cite and any reader can independently verify the *exact* linked functional-clustering, phenotype-clustering, and phenotype-functional-correlation results (with their cross-snapshot dependency lineage) without access to server disks, mutable caches, curator records, or admin endpoints. A later snapshot refresh mints a *new* release and never mutates an existing one.

The primary deliverable is entirely in-app (DB-materialized frozen release + public retrieval API + verification UI). A separate **operator archival slice** mirrors the `../nddscore` flow to package a published release for Zenodo (draft-only, guarded publish, DOI recorded back as additive external provenance).

Two companions ride along because the user grouped all three issues and each is manuscript-reproducibility work:
- **#574**: a server-side `category_filter` selector for the async functional-clustering submit endpoint (a Definitive-only sensitivity run), sharing the release program's provenance philosophy (sorted-HGNC SHA-256, resolved gene count, code/data versions, STRING channel/threshold).
- **#572**: a production deployment + force-refresh runbook that must land *before* the first real release, because a release built from a pre-#571 correlation snapshot would lack the dependency lineage the release must pin.

---

## 2. Context & current state (grounded)

### 2.1 The snapshot infrastructure already provides the provenance primitives

- `analysis_snapshot_manifest` (`db/migrations/024`) is already a manifest/head table with content-address hashes (`input_hash`, `payload_hash`), a status lifecycle (`pending → validated → public_ready → superseded → failed`), a single-active invariant (`public_ready_slot` UNIQUE per `(analysis_type, parameter_hash)`), and provenance columns (`source_versions_json`, `source_data_version`, `db_release_version/commit`, `validation_json`).
- Per-snapshot **reproducibility bundle** `analysis_snapshot_reproducibility` (`db/migrations/041`, `api/functions/analysis-reproducibility.R`): gzipped canonical JSON of the inputs to independently recompute the served separation metric (functional LCC edge list + membership + served modularity; phenotype MCA coords + membership + served silhouette), plus a SHA-256 `reproducibility_hash`. Served today via public `GET /api/analysis/{functional,phenotype}_clustering/reproducibility` as `{reproducibility_hash, kind, byte_size, snapshot_id, bundle}`.
- **#571 dependency lineage** (`api/functions/analysis-snapshot-dependencies.R`): the `phenotype_functional_correlations` snapshot binds to the active `functional_clusters` (`{algorithm:"leiden"}`) and `phenotype_clusters` (`{}`) snapshots by `{snapshot_id, payload_hash}`, stored in `source_versions_json.dependencies`. On public read, `analysis_snapshot_dependency_status_code()` re-checks those against the currently active cluster manifests and returns `dependency_snapshot_mismatch` (fail-closed → 503) on drift. The lineage is exposed as `meta.snapshot.dependencies`.
- `meta.snapshot` (`api/services/analysis-snapshot-service.R`, "W3C-PROV / FAIR provenance, #347") already emits `snapshot_id, analysis_type, parameter_hash, schema_version, data_class, generated_at, stale_after, source_data_version, dependencies, input_hash, payload_hash, validation_hash, record_counts, db_release{version,commit}`.
- Canonical hashing: `analysis_snapshot_canonical_json()` = `jsonlite::toJSON(auto_unbox=TRUE, null="null", dataframe="rows")`; `payload_hash = sha256(canonical(payload_without[raw, partition_validation, reproducibility]))`. Reuse this serializer verbatim so release file bytes match the public API bytes and hash identically.

### 2.2 There is already a complete immutable-release precedent in this repo

`nddscore_release` (`db/migrations/023`) is a full content-addressed public-release table: `release_id` PK, `is_active` + generated `active_release_slot` UNIQUE, `import_status` ENUM, `artifact_hashes_json`, `source_archive_checksum/bytes`, `zenodo_record_url/version_doi/concept_doi/source_record_id`, `imported_by` FK, `*_current` views. The analysis-snapshot release table mirrors this shape (minus the single-active constraint — analysis releases coexist and are all retained). The frontend `NddScoreModelCard.vue` (Version / Version DOI / Concept DOI / Zenodo links, fed by `fetchCurrentRelease()`) is the exact per-release manifest UI precedent to generalize into a list + detail.

### 2.3 Reusable building blocks

- **Byte-streaming download**: `backup_endpoints.R` + `services/backup-endpoint-service.R` (`@serializer octet`, `Content-Type`, `Content-Disposition: attachment`, `Content-Length`, path-traversal guard, `readBin` stream). Template for `/bundle` and `/file?path=`.
- **Checksum helpers**: `digest::digest(..., algo="sha256", serialize=FALSE)` (repo-wide), `digest::digest(file=path, algo="sha256")` (`nddscore-release-source.R:224`).
- **Zenodo download/verify precedent (consumer side)**: `nddscore-release-source.R` (`nddscore_fetch_zenodo_metadata`, `nddscore_verify_archive_checksum`, `nddscore_extract_and_verify` per-file SHA-256). The producer script mirrors the `../nddscore` upload flow.
- **`mount_endpoint()`** (RFC 9457 problem+json), `require_role()`, `with_test_db_transaction()`, cheap-route / external-budget static guards.

### 2.4 Live production evidence for #572

`GET https://sysndd.dbmr.unibe.ch/api/analysis/phenotype_functional_cluster_correlation` (2026-07-18) returns HTTP 200, snapshot 40, schema 1.2, **no `meta.snapshot.dependencies`**. The active `functional_clusters` snapshot is 41 (generated 10:46) while the correlation (40, generated 10:39) predates it — exactly the drift #571 guards. Production is running pre-#571 code; on `master` this read now fails closed as `dependency_snapshot_mismatch`. **A release must not be built from a lineage-less correlation snapshot**, so #572 is a hard prerequisite (Part 3).

---

## 3. Goals / Non-goals

### Goals
- G1. A stable, immutable, content-addressed public release that pins the functional, phenotype, and phenotype-functional-correlation layers together with their dependency lineage and per-file SHA-256 checksums.
- G2. Public read-only catalog, per-release manifest, per-file retrieval, and a single downloadable bundle via documented stable API URLs — retrieval-only (no compute, refresh, LLM, external calls, or writes).
- G3. Admin can build a release only from coherent, public-ready, non-stale, lineage-verified snapshots; a build from incoherent/stale/mismatched sources is rejected with a specific reason.
- G4. A later snapshot refresh leaves every prior release **byte-identical** and publicly retrievable; releases are retained indefinitely.
- G5. Verification UI + "how to verify" docs; OpenAPI + operator/developer docs describe creation, retention, and the reproducibility boundary.
- G6. Operator Zenodo archival path mirroring `../nddscore` (draft-only, guarded publish, DOI recorded back additively).
- G7 (#574). Server-side `category_filter` for `POST /api/jobs/clustering/submit`, with an auditable provenance record; public GET snapshot endpoint stays a fixed snapshot.
- G8 (#572). Production serves lineage-carrying correlation snapshots and fails closed on drift.

### Non-goals
- Do not rerun or change any biological analysis, cluster membership, validation metrics, cache keys, or LLM-summary validity to publish an archive (release construction is a pure additive provenance layer).
- Do not add an in-app auto-upload-to-Zenodo path or publish a Zenodo record without an explicit operator confirmation.
- Do not make `GET /api/analysis/functional_clustering?category_filter=...` compute on demand (#574).
- Do not expose draft curation, admin/user/job/log data, credentials, internal paths, prompts, cache-only material, or write operations through any public release route.
- No DOI minting logic inside the API (Zenodo/DataCite own DOIs); the API only records a DOI supplied by the operator.

---

## 4. Best-practices grounding

- **Content-addressing / immutability**: release identity is a SHA-256 `content_digest` over the invariant scientific content (per-layer `payload_hash`/`input_hash`/`reproducibility_hash` + `source_data_version` + schema versions). Rebuilding from identical snapshots yields the identical `release_id` (idempotent); any content change yields a new id. Mirrors Software/Data Heritage and the existing snapshot `payload_hash` discipline.
- **FAIR + verifiable manifest**: a custom `manifest.json` (precise snapshot lineage + dependency graph + per-file checksums) is the verifiability core; the Zenodo staging additionally ships a Frictionless **`datapackage.json`** (consistent with `../nddscore`), a **`CITATION.cff`**, and a `checksums.sha256`. RO-Crate / JSON-LD is noted as an optional future enrichment, not v1 (Frictionless is simpler, already in the sibling repo, and sufficient).
- **Zenodo REST flow** (confirmed current): create draft → optionally reserve DOI (registered with DataCite only on publish; 100 files / 50 GB cap) → PUT file to bucket → set metadata → **stop at draft** unless explicit `--publish --confirm-publish`. Exactly the `../nddscore` `upload_sysndd_zenodo_dataset.py` shape.
- **Fail-closed provenance**: reuse the coherence gate (#514) and the #571 dependency gate at build time so an incoherent/stale/mismatched snapshot can never enter a release.
- **Least privilege / retrieval-only public surface**: public routes are DB-only reads over frozen release blobs; no external fetchers (cheap-route isolation guard extended to cover them).

---

# PART 1 — #573 Immutable public analysis-snapshot releases (primary)

## 5. Data model — migration `045_add_analysis_snapshot_release.sql`

Three tables (mirroring `nddscore_release` conventions: `utf8mb4_unicode_ci`, generated-slot pattern where a single-active is wanted). Releases are **self-contained frozen copies** so they survive snapshot pruning/refresh byte-identically.

### `analysis_snapshot_release` (head)
| column | type | notes |
|---|---|---|
| `release_id` | VARCHAR(64) PK | content-addressed, `asr_<content_digest[:16]>` (full 64-char `content_digest` also stored) |
| `release_version` | VARCHAR(32) | human date-version, e.g. `2026.07.18` (metadata, not in hash) |
| `title` | VARCHAR(255) | |
| `status` | ENUM('draft','published') NOT NULL DEFAULT 'draft' | drafts are admin-only; publishing exposes publicly and freezes |
| `manifest_schema_version` | VARCHAR(16) | release-manifest schema, start `1.0` |
| `content_digest` | CHAR(64) | SHA-256 over the invariant scientific content; determines `release_id` |
| `manifest_sha256` | CHAR(64) | SHA-256 over the exact stored `manifest.json` bytes |
| `bundle_sha256` | CHAR(64) | SHA-256 over the stored `bundle.tar.gz` bytes |
| `bundle_gzip` | LONGBLOB | the frozen `bundle.tar.gz` bytes, served verbatim |
| `bundle_bytes` | BIGINT | |
| `source_data_version` | VARCHAR(128) | shared source-data version pinned across all layers |
| `db_release_version` | VARCHAR(64) / `db_release_commit` VARCHAR(64) | human DB release label at build time |
| `scope_statement` | TEXT | what is reproducible vs served-only |
| `license` | VARCHAR(64) DEFAULT 'CC-BY-4.0' | |
| `file_count` | INT / `total_bytes` BIGINT | over per-file blobs (excludes bundle) |
| `created_by_user_id` | INT FK user ON DELETE SET NULL | |
| `created_at`/`published_at`/`updated_at` | DATETIME(6) | |
| `zenodo_record_id` VARCHAR(32) / `zenodo_record_url` VARCHAR(255) / `version_doi` VARCHAR(128) / `concept_doi` VARCHAR(128) | | nullable; **additive external provenance, excluded from `content_digest`/`manifest_sha256`** so recording a DOI never changes release identity |
| `last_error_message` | TEXT | |

Keys: PK `release_id`; `KEY (status, created_at)`; `KEY (content_digest)`. No single-active slot — releases coexist; "latest" = newest `published`.

### `analysis_snapshot_release_member` (pinned snapshots)
`release_id` VARCHAR(64) FK→release ON DELETE CASCADE, `analysis_type` VARCHAR(64), `snapshot_id` BIGINT, `parameter_hash` CHAR(64), `input_hash` CHAR(64), `payload_hash` CHAR(64), `schema_version` VARCHAR(16), `reproducibility_hash` CHAR(64) NULL, `role` ENUM('layer','dependency') DEFAULT 'layer'. PK `(release_id, analysis_type, parameter_hash)`; `KEY (snapshot_id)` (used by the prune guard, §9).

### `analysis_snapshot_release_file` (immutable content)
`release_id` VARCHAR(64) FK→release ON DELETE CASCADE, `file_path` VARCHAR(255), `content_sha256` CHAR(64), `byte_size` INT, `media_type` VARCHAR(64) DEFAULT 'application/json', `content_gzip` LONGBLOB (gzipped canonical bytes; decompress on read, mirroring reproducibility storage). PK `(release_id, file_path)`; `KEY (content_sha256)`.

> Storing gzipped copies (not references to snapshot rows) is the immutability guarantee: a release is decoupled from the mutable snapshot lifecycle and from `analysis_snapshot_prune`. Total per release ≈ a few MB gzipped; retaining dozens is negligible.

## 6. Release identity, files, and manifest

**Layer registry** `analysis_snapshot_release_layers()` (new; single source of truth), default 3 manuscript layers, registry-driven so more can be added:
- `functional_clusters` (`{algorithm:"leiden"}`) → files `functional_clusters/payload.json`, `functional_clusters/reproducibility.json`
- `phenotype_clusters` (`{}`) → files `phenotype_clusters/payload.json`, `phenotype_clusters/reproducibility.json`
- `phenotype_functional_correlations` (`{algorithm:"leiden"}`) → file `phenotype_functional_correlations/payload.json` (+ its dependency lineage on the two cluster layers)

**File set per release** (canonical JSON; each file carries its own SHA-256):
- per-layer `payload.json` = the **complete** stored snapshot payload rows returned by `analysis_snapshot_get_public()` (all clusters + members, or correlation rows, or network nodes + edges — **not** a paginated GET page), serialized with `analysis_snapshot_canonical_json`. Its `content_sha256` is the **file's own hash** (verifies the download). It is **not** equal to the snapshot's `payload_hash`: `payload_hash` is computed over the in-memory build object *before* DB storage, and the child tables round-trip through `DECIMAL(8,7)`/`DECIMAL(8,5)` columns, so a reconstructed byte-for-byte match is neither guaranteed nor attempted. **Instead, `payload_hash` (and `input_hash`, `snapshot_id`) are recorded in the manifest as the cross-checkable lineage anchor** — a client verifies the release pins the exact snapshot the public API served by comparing them to the live `/api/analysis/*` `meta.snapshot.{payload_hash,input_hash,snapshot_id}`.
- per-cluster-layer `reproducibility.json` = the **exact pre-gzip canonical bytes** of the stored bundle. **Critical:** do **not** use `analysis_reproducibility_decode()` — it runs `jsonlite::fromJSON()` and returns a *parsed R object*; re-serializing it drops the bundle's `digits = NA` full-precision contract (`analysis-reproducibility.R:31`) and the SHA-256 no longer matches. Instead take the raw string with `memDecompress(bundle_gzip_json, type = "gzip", asChar = TRUE)` (add a small `analysis_reproducibility_decode_raw()` helper) and store/hash **those bytes verbatim**. Then the equality holds exactly: `content_sha256(reproducibility.json) == reproducibility_hash`. This is the scientific-reproduction anchor (recompute modularity/silhouette from it).
- `README.md` = generated human scope + verification instructions
- `manifest.json` = the release manifest (below)
- `checksums.sha256` = `"<sha256>  <path>"` for every file **except `checksums.sha256` itself** (includes `manifest.json`)
- `bundle.tar.gz` = a tar of all the above, gzipped; **built once at release time, stored on the release row, and served verbatim**, so `bundle_sha256` is the hash of the stored bytes and is trivially fixed/citeable. Byte-level *rebuild* determinism (tar mtime/order, gzip header timestamp via `memCompress`) is **not required and not relied upon**: the verification anchors are the per-file `checksums.sha256` + `manifest.json`, which a client recomputes per file. (Build with sorted entries + fixed mtime as a courtesy, but correctness does not depend on it.)

**`manifest.json` (the verifiability core):**
```jsonc
{
  "manifest_schema_version": "1.0",
  "release_id": "asr_<12hex>",
  "release_version": "2026.07.18",
  "title": "...",
  "created_at": "2026-07-18T10:00:00Z",
  "content_digest": "<sha256>",              // == basis of release_id
  "license": "CC-BY-4.0",
  "scope_statement": "...",
  "generator": {
    "api_version": "0.30.0",
    "analysis_snapshot_schema_version": "1.2",
    "reproducibility_schema_version": "1.0",
    "cluster_logic_version": "2026-07-06.510-expdb"
  },
  "source": { "source_data_version": "c41b5d8...", "db_release": { "version": "1.0.0", "commit": "..." } },
  "layers": [
    { "analysis_type": "functional_clusters", "parameter_hash": "ef3a...", "snapshot_id": 41,
      "schema_version": "1.2", "input_hash": "390e...", "payload_hash": "a142...",
      "reproducibility_hash": "...", "record_counts": {"members":2605,"clusters":18},
      "files": ["functional_clusters/payload.json","functional_clusters/reproducibility.json"] },
    { "analysis_type": "phenotype_clusters", "...": "..." },
    { "analysis_type": "phenotype_functional_correlations", "snapshot_id": 42, "payload_hash": "...",
      "dependencies": {
        "functional_clusters": { "snapshot_id": 41, "payload_hash": "a142..." },
        "phenotype_clusters":  { "snapshot_id": 39, "payload_hash": "bbce..." } },
      "files": ["phenotype_functional_correlations/payload.json"] }
  ],
  "files": [ { "path": "functional_clusters/payload.json", "sha256": "...", "bytes": 12345, "media_type": "application/json" }, "..." ],
  "reproducibility_boundary": "Reproduces the served separation metrics (functional modularity, phenotype silhouette) and the cross-cluster correlation from the bundled reproducibility inputs. LLM summaries and fCoSE layout coordinates are served-only and excluded."
}
```
- `files[]` excludes `manifest.json` and `checksums.sha256` (Frictionless-style, mirrors `../nddscore` `datapackage.json`).
- `manifest_sha256` (row) = SHA-256 of the exact `manifest.json` bytes — served in LIST/HEAD so a client can verify the manifest itself.
- `content_digest` = `sha256(canonical({ manifest_schema_version, source_data_version, layers:[sorted {analysis_type, input_hash, payload_hash, reproducibility_hash, dependencies}] }))`. **Excludes `created_at`, `title`, and DOI** so identity is a pure function of scientific content. The full 64-char `content_digest` is the true identity and is stored + in the manifest; `release_id = "asr_" + content_digest[:16]` (64-bit readable handle). Insert is guarded: if a row with that `release_id` exists but its stored `content_digest` differs (astronomically unlikely at 64 bits), the build fails loudly rather than colliding.

## 7. Build path — `analysis_snapshot_release_build()` (admin, synchronous, DB-only)

New `api/functions/analysis-snapshot-release.R` (registered in `bootstrap/load_modules.R`) + service `api/services/analysis-snapshot-release-service.R`.

1. **Load + gate each layer** under one read connection: for each registry layer, `analysis_snapshot_get_public(analysis_type, parameter_hash, conn)` and require `status_code == "available"`. Note `status_code` only checks **freshness/schema/source-version** (+ the #571 dependency gate for the correlation) — it does **not** re-run the #514 coherence gate, and that gate can be downgraded to a warning via `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false` at snapshot build. So `available` is necessary but **not** proof of coherence. Any `snapshot_missing | snapshot_stale | source_version_mismatch | schema_version_mismatch | dependency_snapshot_mismatch` → **reject build** with **HTTP 400** (`stop_for_bad_request`) whose `detail` names the failing `analysis_type` + `status_code`. (The existing error contract has only `error_400/401/403/404/500`; a "sources not ready" rejection is a 400, not a new 409 class — no error-handler change.)
2. **Hard coherence re-check (per cluster layer)**: independently re-assert partition coherence on the loaded snapshot with `analysis_snapshot_assert_partition_coherent(..., require_coherence = TRUE)` (membership cluster-set == validation cluster-set, channel match, per-cluster member-set equality), **ignoring** the env downgrade, so an incoherent-but-`public_ready` snapshot can never be frozen into a release. Failure → 400 `release_source_incoherent`.
3. **Reproducibility presence (per cluster layer)**: require a stored reproducibility bundle (`analysis_snapshot_get_reproducibility(snapshot_id)` non-empty with a `reproducibility_hash`). The snapshot builder makes the bundle **best-effort** (a failed build returns `NULL` yet the snapshot still activates; `reproducibility_hash` is nullable), but the release makes `reproducibility.json` mandatory — so a missing bundle → 400 `release_reproducibility_missing`, never a crash or a non-reproducible release.
4. **Cross-layer coherence** (belt-and-suspenders): assert all layers share one `source_data_version`; assert the correlation's stored `dependencies` point at exactly the pinned functional + phenotype `snapshot_id`+`payload_hash`. Mismatch → 400 with detail.
5. **TOCTOU guard**: take the standard analysis-snapshot advisory lock (or read all layers within a single consistent transaction/`REPEATABLE READ` snapshot) so a concurrent axis refresh cannot swap an active snapshot between the per-layer reads and the dependency check. Re-assert the correlation's active dependencies immediately before insert.
6. **Materialize files**: canonical-JSON of each layer's stored payload rows (own `content_sha256`) + the verbatim raw reproducibility bytes (`memDecompress(..., asChar = TRUE)`, **not** the parsing `decode()`); generate `README.md`; compute per-file `content_sha256` + `byte_size`.
7. **Assemble manifest** (§6), compute `content_digest` → `release_id`. If a release with that `release_id` already exists → **idempotent HTTP 200** returning the existing head (content-addressed create is idempotent; identical sources never duplicate). A same-id row with a *different* stored `content_digest` (impossible short of a 64-bit collision) → 500 to surface the anomaly.
8. **Build `checksums.sha256`** (over all files incl. `manifest.json`, excl. `checksums.sha256` itself) and the **`bundle.tar.gz`** (built once, stored); compute `manifest_sha256`, `bundle_sha256`.
9. **Persist in one transaction**: insert release (status per `publish` flag), members, files. `DBI::dbBind` with `unname()`; blobs bound as `list(raw)`. Blob size is a few MB gzipped — well within `max_allowed_packet` (verify the dev value ≥ 16 MB; the migration/docs note the requirement).
10. Return the release head. **No external calls, no clustering recompute, no LLM, no cache writes.**

`POST /api/admin/analysis/releases` body: `{ layers?: [...], title?, scope_statement?, license?, publish?: true }` (default `publish:true`; `false` stages a draft for review before a Zenodo run). Administrator-gated.

## 8. Public read routes (retrieval-only) — `analysis_endpoints.R` (`/api/analysis`, unauthenticated)

Mounted in the same sub-router as the reproducibility routes (Plumber cannot mount a second router on `/api/analysis`). All DB-only; problem+json via `mount_endpoint`. `latest` declared **before** the dynamic `/<release_id>` route (the `/status/_list` shadowing lesson).

| Route | Returns |
|---|---|
| `GET /releases?limit=&offset=` | list of **published** releases: `{release_id, release_version, title, created_at, published_at, source_data_version, manifest_sha256, bundle_sha256, license, file_count, total_bytes, layers:[{analysis_type, snapshot_id, payload_hash}], zenodo:{record_url,version_doi,concept_doi}|null}` + pagination |
| `GET /releases/latest` | newest published release head (same shape as detail) |
| `GET /releases/<release_id>` | release head + full manifest object |
| `GET /releases/<release_id>/manifest.json` | the **exact stored** `manifest.json` bytes (Content-Type `application/json`), so `sha256(bytes)==manifest_sha256` |
| `GET /releases/<release_id>/file?path=<file_path>` | one content-addressed file; decompress `content_gzip`; `media_type`; resolved by **exact `(release_id, file_path)` DB lookup** — **anything not in the table → 404** (no filesystem, no traversal surface). A **query param** is used, not a nested `<path>` segment: Plumber 1.3.2 only supports named, typed, single-segment path params (`<id>`, `<id:int>`) — `<path:.*>` does not exist and would 404 every nested file URL. The manifest's `files[].path` values are the caller's index into this route. |
| `GET /releases/<release_id>/bundle` | `@serializer octet`, `Content-Disposition: attachment; filename="<release_id>.tar.gz"`, stream `bundle_gzip` verbatim (backup-endpoint template) |

- Unknown or `draft` release → 404 (drafts never public).
- A release being minted is a synchronous admin op, so there is no public "preparing" state; still, reuse the friendly-error frontend classifier for any transient 5xx.

## 9. Immutability, retention, pruning

- Published releases are **never** auto-pruned; `manifest.json`/files/bundle are frozen at build.
- A snapshot refresh mints a new snapshot → a fresh admin build mints a **new** release (new `content_digest`/`release_id`); prior releases stay byte-identical (they hold their own frozen copies — no dependency on the source snapshot surviving).
- Defensive guard: extend `analysis_snapshot_prune` to **skip any `snapshot_id` referenced by a `analysis_snapshot_release_member`** so the *live* reproducibility endpoint for a pinned snapshot also keeps working (not required for release integrity, which is self-contained, but avoids a confusing 503 on the live endpoint for a still-cited snapshot).
- Draft delete allowed (`DELETE /api/admin/analysis/releases/<id>` only when `status='draft'`); published delete forbidden.

## 10. Admin routes — `admin_analysis_snapshot_endpoints.R` (`/api/admin/analysis`, Administrator)

| Route | Purpose |
|---|---|
| `POST /releases` | build (+optionally publish) from current coherent snapshots → 201 head (new) / 200 head (idempotent, identical content) / 400 with the failing-layer reason |
| `GET /releases` | list all incl. drafts + status |
| `GET /releases/<id>` | admin detail (incl. draft) |
| `POST /releases/<id>/publish` | publish a draft |
| `PATCH /releases/<id>/doi` | record `{zenodo_record_id, zenodo_record_url, version_doi, concept_doi}` (additive; the only post-publish mutation; outside the content hash) |
| `DELETE /releases/<id>` | delete a **draft** only |

## 11. UI/UX

### Public "Data releases" page (`/DataReleases`)
- New view `app/src/views/analyses/DataReleases.vue` (copy `GeneNetworks.vue`: `AnalysisShell` + `useHead`).
- Releases list (`GenericTable`/`BTable`, **flat field keys** — alias any dotted key; bind reactive tooltips via directive value) → row select opens a `SectionCard`-wrapped manifest panel styled like `NddScoreModelCard.vue`'s `<dl>` grid: `release_id`, `release_version`, `created_at`, `source_data_version`, `manifest_sha256`/`bundle_sha256` (mono, truncated + copy button), per-layer `snapshot_id` + `payload_hash`, the dependency lineage (functional↔phenotype↔correlation), license, and DOI links (`doiUrl()`, `target=_blank rel=noopener`) when present.
- Download buttons: `manifest.json`, `bundle.tar.gz` (via `apiClient.raw.get<Blob>(..., {responseType:'blob'})`, `browseComparisonsXlsx` precedent), and per-layer files.
- A **"How to verify"** disclosure: the exact `sha256`/`tar` commands and what is reproducible vs served-only.
- New typed client `app/src/api/releases.ts` (+ `releases.spec.ts`, MSW) mirroring `about.ts`/`nddscore.ts`: `listReleases()`, `getLatestRelease()`, `getReleaseManifest(id)`, `getReleaseFileUrl(id, path)`, `downloadReleaseBundle(id)`. Errors via `extractApiErrorMessage`; Plumber-scalar unwrap via `unwrapScalar`.
- Routing: public route in `routes.ts` with `meta.sitemap: { priority: 0.7, changefreq: 'monthly' }`; nav item under `analyses_dropdown` in `main_nav_constants.ts` ("Data releases"); route-registration assertion in `routes.spec.ts`.
- SEO: add `/DataReleases` to backend `/api/seo/routes` `static`; optionally a `buildReleaseSeo()` prerender branch + `sitemap-releases.xml` + fixture (recommended for a citable dataset landing surface); `make verify-seo-app` must pass.

### Admin surface
- Thin admin panel (extend the analysis-snapshots admin view or add `ManageAnalysisReleases.vue`): "Build release from current snapshots" (shows the current coherence/lineage status first, disables build when any layer is not `available`), a releases table with status + Build/Publish/Record-DOI actions, and a copy-paste operator block for the Zenodo packaging command. Reuse `AuthenticatedPageShell`, typed admin client.

### Public correlation page affordance
- A small "Cite this data" / data-availability note on the phenotype-functional correlation page linking to `latest` release (nice-to-have, low risk).

## 12. Zenodo operator archival (Slice C — mirror `../nddscore`)

# Immutable Public Analysis-Snapshot Releases — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a read-only, immutable, content-addressed public "analysis-snapshot release" that pins the functional, phenotype, and phenotype-functional-correlation layers together with verifiable lineage and per-file SHA-256 checksums, plus a Zenodo operator archival path, a category-selected clustering submit (#574), and the #572 production lineage runbook.

**Architecture:** A release freezes canonical-JSON copies of the currently-active, coherent, lineage-verified public snapshots into three new DB tables (`analysis_snapshot_release`, `_member`, `_file`), identified by a content-addressed `release_id`. Admin builds synchronously (DB-only, fail-closed on incoherent/stale/mismatched sources); the public reads catalog/manifest/files/bundle retrieval-only. Mirrors the in-repo `nddscore_release` pattern and the `../nddscore` Zenodo flow.

**Tech Stack:** R/Plumber API (`renv`), MySQL migrations, `digest`/`jsonlite` for canonical hashing, Vue 3 + TypeScript SPA, `httr2` for the operator Zenodo script.

**Spec:** `.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md`

## Global Constraints

- Release construction is a **pure additive provenance layer**: never alter cluster membership, validation metrics, cache keys, LLM-summary validity, or recompute any analysis to publish an archive.
- Public release routes are **retrieval-only**: no compute, snapshot refresh, LLM generation, external provider calls, or DB writes. Add them to the cheap-route / external-budget isolation guards.
- Build fails **closed**: only `public_ready`, non-stale, source/schema-matching, **hard-coherence-re-checked**, reproducibility-bearing, dependency-lineage-verified snapshots may enter a release; otherwise **HTTP 400** with the exact reason (no 409 class exists). A duplicate build is idempotent (200, existing head).
- A published release is **immutable** and retained indefinitely; a later snapshot refresh mints a **new** release. DOI columns are additive external provenance, **excluded** from `content_digest`/`manifest_sha256`.
- Canonical serializer = `analysis_snapshot_canonical_json()` (`jsonlite::toJSON(auto_unbox=TRUE, null="null", dataframe="rows")`); SHA-256 via `digest::digest(x, algo="sha256", serialize=FALSE)`. `release_id = "asr_" + content_digest[:16]` (64-bit handle; full digest stored).
- Every endpoint file is mounted via `mount_endpoint()` (RFC 9457 problem+json). `require_role(req, res, "Administrator")` on admin routes. `DBI::dbBind` params `unname()`-ed; blobs bound as `list(raw)`. Namespace `dplyr::select` etc. explicitly. Use `base::get` (not `config`-masked `get`).
- Keep every touched file **< 600 lines**; split builder/manifest/files/service helpers. Approved-public data only — release payloads contain only snapshot payload data already public via `/api/analysis/*`.
- Frontend: typed clients in `app/src/api/*` only (no raw axios); errors via `extractApiErrorMessage`; Plumber scalar-array unwrap via `unwrapScalar`; `BTable` flat field keys; reactive tooltips via directive value.
- Version bump four surfaces (`app/package.json` root+lockfile, `api/version_spec.json`, `CHANGELOG.md`) per repo convention. Docs contract: `AGENTS.md`, `documentation/08-development.qmd`, `documentation/09-deployment.qmd`, `README.md`.
- Gates before handoff: `make code-quality-audit`, `make lint-api`, `make test-api-fast` (then `make ci-local`), `cd app && npm run type-check && npm run test:unit`, `make verify-seo-app`.

---

# SLICE 0 — #572 production lineage runbook (prerequisite, no code)

### Task 0: Deploy master + force-refresh + verify lineage

**Files:** none (operator runbook; captured in `documentation/09-deployment.qmd` under Task A9).

- [ ] Deploy current `master` to the production Compose stack; restart `api`, `worker`, `worker-maintenance`.
- [ ] As Administrator: `POST /api/admin/analysis/snapshots/refresh` body `{"analysis_type":"phenotype_functional_correlations","force":true}`; watch `GET /api/admin/analysis/snapshots/status` until it reports `available`.
- [ ] Verify: `curl -s https://<host>/api/analysis/phenotype_functional_cluster_correlation | jq '.meta.snapshot.dependencies'` shows both `functional_clusters` and `phenotype_clusters` with `snapshot_id` + `payload_hash`.
- [ ] Verify fail-closed: force-refresh one cluster axis, confirm the correlation read returns 503 `dependency_snapshot_mismatch` until the correlation is rebuilt.
- [ ] Notify manuscript maintainers. **Gate:** do not build the first release until this passes.

---

# SLICE A — #573 core backend (fully detailed; its own PR)

## File structure (Slice A)

- Create `db/migrations/045_add_analysis_snapshot_release.sql` — the three release tables.
- Create `api/functions/analysis-snapshot-release-manifest.R` — pure manifest/hash/canonical-file helpers (no DB).
- Create `api/functions/analysis-snapshot-release-repository.R` — DB reads/writes (insert release+members+files in one txn; list/get/get-file; prune guard).
- Create `api/functions/analysis-snapshot-release.R` — `analysis_snapshot_release_build()` orchestrator (load+gate+materialize+persist).
- Create `api/services/analysis-snapshot-release-service.R` — admin build/publish/doi/delete + public list/get/manifest/file/bundle service wrappers (problem+json shaping).
- Modify `api/endpoints/analysis_endpoints.R` — public read routes (same sub-router as reproducibility).
- Modify `api/endpoints/admin_analysis_snapshot_endpoints.R` — admin release routes.
- Modify `api/bootstrap/load_modules.R` — register the three new function files (API + worker + MCP loaders).
- Modify `api/functions/analysis-snapshot-repository.R` — `analysis_snapshot_prune()` skip release-referenced snapshots.
- Modify the cheap-route / external-budget guard test allow/deny lists.
- Tests under `api/tests/testthat/`.

### Task A1: Migration 045 (release tables)

**Files:**
- Create: `db/migrations/045_add_analysis_snapshot_release.sql`
- Modify: `db/migrations/README.md` (bump `EXPECTED_LATEST_MIGRATION` note) and the manifest constant if one exists (`grep -rn EXPECTED_LATEST_MIGRATION api/`).
- Test: `api/tests/testthat/test-unit-analysis-snapshot-release-repository.R` (schema smoke uses the running dev DB).

**Interfaces:**
- Produces tables `analysis_snapshot_release`, `analysis_snapshot_release_member`, `analysis_snapshot_release_file` (columns per spec §5).

- [ ] **Step 1: Write the migration** (DDL exactly per spec §5; `utf8mb4_unicode_ci`; FK `created_by_user_id`→`user`; child FKs cascade).

```sql
-- Migration: 045_add_analysis_snapshot_release
-- Description: Immutable, content-addressed public analysis-snapshot releases (#573).
--   A release freezes canonical-JSON copies of the active coherent public snapshots
--   (functional/phenotype clusters + phenotype-functional correlation) with per-file
--   SHA-256 checksums and dependency lineage. Retained indefinitely; a later refresh
--   mints a NEW release. DOI columns are additive external provenance.

CREATE TABLE IF NOT EXISTS `analysis_snapshot_release` (
  `release_id` VARCHAR(64) NOT NULL,
  `release_version` VARCHAR(32) DEFAULT NULL,
  `title` VARCHAR(255) DEFAULT NULL,
  `status` ENUM('draft','published') NOT NULL DEFAULT 'draft',
  `manifest_schema_version` VARCHAR(16) NOT NULL,
  `content_digest` CHAR(64) NOT NULL,
  `manifest_sha256` CHAR(64) NOT NULL,
  `bundle_sha256` CHAR(64) NOT NULL,
  `bundle_gzip` LONGBLOB NOT NULL,
  `bundle_bytes` BIGINT NOT NULL,
  `source_data_version` VARCHAR(128) DEFAULT NULL,
  `db_release_version` VARCHAR(64) DEFAULT NULL,
  `db_release_commit` VARCHAR(64) DEFAULT NULL,
  `scope_statement` TEXT DEFAULT NULL,
  `license` VARCHAR(64) NOT NULL DEFAULT 'CC-BY-4.0',
  `file_count` INT NOT NULL DEFAULT 0,
  `total_bytes` BIGINT NOT NULL DEFAULT 0,
  `created_by_user_id` INT DEFAULT NULL,
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `published_at` DATETIME(6) DEFAULT NULL,
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `zenodo_record_id` VARCHAR(32) DEFAULT NULL,
  `zenodo_record_url` VARCHAR(255) DEFAULT NULL,
  `version_doi` VARCHAR(128) DEFAULT NULL,
  `concept_doi` VARCHAR(128) DEFAULT NULL,
  `last_error_message` TEXT DEFAULT NULL,
  PRIMARY KEY (`release_id`),
  KEY `idx_asr_status_created` (`status`, `created_at`),
  KEY `idx_asr_content_digest` (`content_digest`),
  CONSTRAINT `fk_asr_created_by`
    FOREIGN KEY (`created_by_user_id`) REFERENCES `user` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_release_member` (
  `release_id` VARCHAR(64) NOT NULL,
  `analysis_type` VARCHAR(64) NOT NULL,
  `parameter_hash` CHAR(64) NOT NULL,
  `snapshot_id` BIGINT NOT NULL,
  `input_hash` CHAR(64) NOT NULL,
  `payload_hash` CHAR(64) NOT NULL,
  `schema_version` VARCHAR(16) NOT NULL,
  `reproducibility_hash` CHAR(64) DEFAULT NULL,
  `role` ENUM('layer','dependency') NOT NULL DEFAULT 'layer',
  PRIMARY KEY (`release_id`, `analysis_type`, `parameter_hash`),
  KEY `idx_asrm_snapshot` (`snapshot_id`),
  CONSTRAINT `fk_asrm_release`
    FOREIGN KEY (`release_id`) REFERENCES `analysis_snapshot_release` (`release_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `analysis_snapshot_release_file` (
  `release_id` VARCHAR(64) NOT NULL,
  `file_path` VARCHAR(255) NOT NULL,
  `content_sha256` CHAR(64) NOT NULL,
  `byte_size` INT NOT NULL,
  `media_type` VARCHAR(64) NOT NULL DEFAULT 'application/json',
  `content_gzip` LONGBLOB NOT NULL,
  PRIMARY KEY (`release_id`, `file_path`),
  KEY `idx_asrf_sha256` (`content_sha256`),
  CONSTRAINT `fk_asrf_release`
    FOREIGN KEY (`release_id`) REFERENCES `analysis_snapshot_release` (`release_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 2: Update BOTH migration-manifest constants** in `api/functions/migration-manifest.R`: `EXPECTED_LATEST_MIGRATION` → `045_add_analysis_snapshot_release` **and** `EXPECTED_MIGRATION_COUNT` `42L → 43L` (startup validates both; bumping only the latter/former makes the API crash before serving). Update any manifest test that pins these (`grep -rn "EXPECTED_LATEST_MIGRATION\|EXPECTED_MIGRATION_COUNT" api/`).
- [ ] **Step 3: Apply on the dev DB** — `make docker-dev-db` running, restart `api` so the startup migration runner applies 045; confirm via `docker exec sysndd-api-1 Rscript -e 'DBI::dbGetQuery(...SHOW TABLES LIKE "analysis_snapshot_release%")'` (or the dev DB directly). Expected: three tables.
- [ ] **Step 4: Commit** — `git add db/migrations/045_* && git commit -m "feat(db): analysis-snapshot release tables (#573)"`.

### Task A2: Manifest + canonical-file helpers (pure, no DB)

**Files:**
- Create: `api/functions/analysis-snapshot-release-manifest.R`
- Test: `api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R`

**Interfaces:**
- Produces:
  - `ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION` (chr `"1.0"`)
  - `analysis_snapshot_release_layers()` → list of `list(analysis_type, params, files_prefix, has_reproducibility)` (default 3 manuscript layers).
  - `analysis_release_canonical_bytes(obj)` → raw (UTF-8 of `analysis_snapshot_canonical_json(obj)`).
  - `analysis_release_sha256(raw_or_chr)` → chr sha256 hex.
  - `analysis_release_content_digest(layer_entries, source_data_version, manifest_schema_version)` → chr (identity basis; layers sorted internally by `analysis_type`).
  - `analysis_release_id(content_digest)` → `paste0("asr_", substr(content_digest, 1, 16))` (64-bit readable handle; full digest stored separately).
  - `analysis_release_build_manifest(list(release_id, release_version, title, created_at, license, scope_statement, generator, source, layers, files, content_digest))` → the manifest R list (files[] excludes manifest.json + checksums.sha256).
  - `analysis_release_checksums_text(files)` → chr (`"<sha256>  <path>\n"` per file, excludes `checksums.sha256`).
  - `analysis_release_build_tar_gz(named_raw_list)` → raw. Built **once** and stored; byte-level rebuild-determinism is not required (per-file checksums + manifest are the verification anchors). Use `utils::tar` on a temp dir with sorted paths + `memCompress(type="gzip")`, or a small ustar writer; keep it simple.

- [ ] **Step 1: Write failing tests** for determinism + identity:

```r
test_that("content_digest and release_id are pure functions of scientific content", {
  entries <- list(
    list(analysis_type = "functional_clusters", input_hash = "a", payload_hash = "b", reproducibility_hash = "c", dependencies = NULL),
    list(analysis_type = "phenotype_clusters",  input_hash = "d", payload_hash = "e", reproducibility_hash = "f", dependencies = NULL)
  )
  d1 <- analysis_release_content_digest(entries, "srcv1", "1.0")
  d2 <- analysis_release_content_digest(rev(entries), "srcv1", "1.0")  # order-independent (sorted internally)
  expect_identical(d1, d2)
  expect_match(analysis_release_id(d1), "^asr_[0-9a-f]{16}$")
  # created_at / title do NOT affect identity:
  expect_false(identical(d1, analysis_release_content_digest(entries, "srcv2", "1.0")))
})

test_that("checksums text lists every file except checksums.sha256", {
  files <- list(
    list(path = "manifest.json", sha256 = "111", bytes = 3L),
    list(path = "a/payload.json", sha256 = "222", bytes = 5L),
    list(path = "checksums.sha256", sha256 = "333", bytes = 9L)
  )
  txt <- analysis_release_checksums_text(files)
  expect_match(txt, "111  manifest.json")
  expect_match(txt, "222  a/payload.json")
  expect_false(grepl("checksums.sha256", txt, fixed = TRUE))
})

test_that("tar.gz round-trips: untar yields exactly the input files/bytes", {
  payload <- list("a/x.json" = charToRaw("{\"k\":1}"), "manifest.json" = charToRaw("{}"))
  gz <- analysis_release_build_tar_gz(payload)
  d <- tempfile(); dir.create(d)
  tarfile <- file.path(d, "b.tar")
  writeBin(memDecompress(gz, type = "gzip"), tarfile)
  utils::untar(tarfile, exdir = d)
  expect_identical(readBin(file.path(d, "a/x.json"), "raw", 64L), payload[["a/x.json"]])
})
```

- [ ] **Step 2: Run tests, expect FAIL** (`docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-analysis-snapshot-release-manifest.R')"` after `docker cp`, or host `Rscript` if the shim resolves).
- [ ] **Step 3: Implement** `analysis-snapshot-release-manifest.R`. Key logic:
  - `analysis_release_content_digest`: sort `layer_entries` by `analysis_type`; build `list(manifest_schema_version, source_data_version, layers = lapply(sorted, \(e) e[c("analysis_type","input_hash","payload_hash","reproducibility_hash","dependencies")]))`; `analysis_release_sha256(analysis_release_canonical_bytes(that))`.
  - `analysis_release_build_tar_gz`: write each named raw to a temp dir (sorted paths), `utils::tar(tarfile, files, compression="none")`, then `memCompress(readBin(tarfile,"raw",...), type="gzip")`. Byte-stable rebuilds are NOT required (bundle is stored once and served verbatim); the round-trip test above is the only contract.
- [ ] **Step 4: Run tests, expect PASS.**
- [ ] **Step 5: Commit** — `feat(api): release manifest + deterministic archive helpers (#573)`.

### Task A3: Release repository (DB reads/writes)

**Files:**
- Create: `api/functions/analysis-snapshot-release-repository.R`
- Test: `api/tests/testthat/test-integration-analysis-snapshot-release-repository.R` (uses `with_test_db_transaction()`).

**Interfaces:**
- Consumes: manifest helpers (A2).
- Produces:
  - `analysis_release_insert(release_head, members, files, conn)` — one transaction; blobs `list(raw)`; returns `release_id`.
  - `analysis_release_get(release_id, include_draft = FALSE, conn)` — head row (+ parsed manifest via the stored `manifest.json` file) or NULL.

exec
/bin/bash -lc "git diff --name-only 67cf6003..HEAD -- api db | sort && nl -ba db/migrations/045_add_analysis_snapshot_release.sql && nl -ba api/functions/migration-manifest.R | sed -n '1,100p' && nl -ba api/bootstrap/load_modules.R | sed -n '1,240p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
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
db/migrations/045_add_analysis_snapshot_release.sql
db/migrations/README.md
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
   181	    "functions/ontology-functions.R",
   182	    "functions/ontology-object.R",
   183	    "functions/pubtator-client.R",
   184	    "functions/pubtator-parser.R",
   185	    "functions/pubtator-functions.R",
   186	    "functions/pubtator-enrichment-metrics.R",
   187	    "functions/pubtator-enrichment-collector.R",
   188	    "functions/pubtator-gene-summary.R",
   189	    "functions/pubtatornidd-nightly.R",
   190	    "functions/ensembl-functions.R",
   191	    "functions/job-manager.R",
   192	    "functions/job-progress.R",
   193	    "functions/backup-functions.R",
   194	    "functions/ols-functions.R",
   195	    "functions/openapi-helpers.R",
   196	    "functions/migration-manifest.R",
   197	    "functions/migration-runner.R"
   198	  )
   199	  # --- end source list ---
   200	
   201	  core_files <- c(
   202	    "core/security.R",
   203	    "core/errors.R",
   204	    "core/responses.R",
   205	    "core/logging_sanitizer.R",
   206	    "core/middleware.R",
   207	    "core/filters.R"
   208	  )
   209	
   210	  service_files <- c(
   211	    "services/auth-service.R",
   212	    "services/user-service.R",
   213	    "services/status-service.R",
   214	    "services/metadata-vocabulary-service.R",
   215	    "services/search-service.R",
   216	    "services/entity-service.R",
   217	    "services/entity-creation-service.R",
   218	    "services/entity-rename-service.R",
   219	    "services/review-service.R",
   220	    "services/genereviews-service.R",
   221	    "services/approval-service.R",
   222	    "services/re-review-selection-service.R",
   223	    "services/re-review-service.R",
   224	    "services/re-review-refusal-service.R",
   225	    "services/seo-service.R",
   226	    "services/analysis-snapshot-service.R",
   227	    "services/analysis-snapshot-refresh-service.R",
   228	    "services/analysis-snapshot-release-service.R",
   229	    "services/disease-ontology-mapping-service.R",
   230	    "services/mcp-service.R",
   231	    "services/mcp-analysis-shaping.R",
   232	    "services/mcp-query-service.R",
   233	    "services/mcp-record-service.R",
   234	    "services/mcp-analysis-service.R",
   235	    "services/mcp-analysis-llm-cache-service.R",
   236	    "services/mcp-research-context-service.R",
   237	    "services/mcp-capabilities-service.R",
   238	    "services/mcp-tool-core.R",
   239	    "services/mcp-tool-resources.R",
   240	    "services/mcp-tools.R",

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-manifest.R && nl -ba api/functions/analysis-snapshot-release-repository.R | sed -n '1,480p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
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
    50	#' UTF-8 raw bytes of the canonical JSON serialization of `obj`.
    51	#'
    52	#' Uses the SAME serializer as the public snapshot API
    53	#' (`analysis_snapshot_canonical_json()`), so release file bytes hash
    54	#' identically to the corresponding public API response bytes.
    55	#'
    56	#' @param obj Any value accepted by `analysis_snapshot_canonical_json()`.
    57	#' @return raw vector.
    58	analysis_release_canonical_bytes <- function(obj) {
    59	  charToRaw(enc2utf8(analysis_snapshot_canonical_json(obj)))
    60	}
    61	
    62	#' SHA-256 hex digest of raw bytes or a character string.
    63	#'
    64	#' Repo-wide convention: `digest::digest(x, algo = "sha256", serialize =
    65	#' FALSE)`. With `serialize = FALSE`, a raw vector is hashed as its bytes
    66	#' directly and a character string is hashed as its string content, so this
    67	#' accepts either without branching.
    68	#'
    69	#' @param raw_or_chr raw vector or a length-1 character string.
    70	#' @return chr, a 64-character lowercase hex sha256 digest.
    71	analysis_release_sha256 <- function(raw_or_chr) {
    72	  digest::digest(raw_or_chr, algo = "sha256", serialize = FALSE)
    73	}
    74	
    75	#' Order-independent content digest: the identity basis for a release.
    76	#'
    77	#' Deliberately excludes `created_at`, `title`, and any DOI — release
    78	#' identity is pure scientific content (each layer's input/payload/
    79	#' reproducibility hashes and dependencies, plus the source data version and
    80	#' manifest schema version), never presentation metadata. `layer_entries` is
    81	#' sorted by `analysis_type` before hashing so caller-supplied ordering never
    82	#' changes the digest.
    83	#'
    84	#' @param layer_entries list of list(analysis_type, input_hash, payload_hash,
    85	#'   reproducibility_hash, dependencies).
    86	#' @param source_data_version chr.
    87	#' @param manifest_schema_version chr.
    88	#' @return chr, a 64-character lowercase hex sha256 digest.
    89	analysis_release_content_digest <- function(layer_entries, source_data_version, manifest_schema_version) {
    90	  analysis_types <- vapply(layer_entries, function(entry) entry$analysis_type, character(1))
    91	  sorted_entries <- layer_entries[order(analysis_types)]
    92	
    93	  identity_layers <- lapply(sorted_entries, function(entry) {
    94	    entry[c("analysis_type", "input_hash", "payload_hash", "reproducibility_hash", "dependencies")]
    95	  })
    96	
    97	  identity_obj <- list(
    98	    manifest_schema_version = manifest_schema_version,
    99	    source_data_version = source_data_version,
   100	    layers = identity_layers
   101	  )
   102	
   103	  analysis_release_sha256(analysis_release_canonical_bytes(identity_obj))
   104	}
   105	
   106	#' Short, readable release handle derived from the content digest.
   107	#'
   108	#' The first 16 hex characters (64 bits) of the content digest, prefixed
   109	#' `asr_`. This is a human/URL-facing handle only; the full content digest is
   110	#' the authoritative identity value and is stored separately by later tasks.
   111	#'
   112	#' @param content_digest chr, as returned by `analysis_release_content_digest()`.
   113	#' @return chr, matching `^asr_[0-9a-f]{16}$` for a well-formed digest.
   114	analysis_release_id <- function(content_digest) {
   115	  paste0("asr_", substr(content_digest, 1, 16))
   116	}
   117	
   118	#' Build the release `manifest.json` R list.
   119	#'
   120	#' `fields$files` is the caller-computed flat file list (one
   121	#' `list(path, sha256, bytes)` entry per archive member). Neither
   122	#' `manifest.json` nor `checksums.sha256` can describe their own checksum, so
   123	#' both are excluded from the `files[]` array in the built manifest.
   124	#'
   125	#' @param fields list with elements `release_id`, `release_version`, `title`,
   126	#'   `created_at`, `license`, `scope_statement`, `generator`, `source`,
   127	#'   `layers`, `files`, `content_digest`.
   128	#' @return list, the manifest ready for `analysis_snapshot_canonical_json()`.
   129	analysis_release_build_manifest <- function(fields) {
   130	  self_describing_paths <- c("manifest.json", "checksums.sha256")
   131	  files <- Filter(function(f) !(f$path %in% self_describing_paths), fields$files)
   132	
   133	  list(
   134	    release_id = fields$release_id,
   135	    release_version = fields$release_version,
   136	    title = fields$title,
   137	    created_at = fields$created_at,
   138	    license = fields$license,
   139	    scope_statement = fields$scope_statement,
   140	    generator = fields$generator,
   141	    source = fields$source,
   142	    layers = fields$layers,
   143	    files = files,
   144	    content_digest = fields$content_digest
   145	  )
   146	}
   147	
   148	#' Build the `checksums.sha256` file content.
   149	#'
   150	#' One `"<sha256>  <path>\n"` line per file (the classic `sha256sum` format),
   151	#' excluding `checksums.sha256` itself since a file cannot list its own
   152	#' checksum.
   153	#'
   154	#' @param files list of `list(path, sha256, bytes)`.
   155	#' @return chr, the full checksums file text (empty string if `files` yields
   156	#'   no lines after exclusion).
   157	analysis_release_checksums_text <- function(files) {
   158	  files <- Filter(function(f) f$path != "checksums.sha256", files)
   159	  if (length(files) == 0) {
   160	    return("")
   161	  }
   162	  lines <- vapply(files, function(f) paste0(f$sha256, "  ", f$path), character(1))
   163	  paste0(paste(lines, collapse = "\n"), "\n")
   164	}
   165	
   166	#' Build a gzip-compressed tar archive from named raw vectors.
   167	#'
   168	#' `named_raw_list` is a named list of `path = raw_bytes`; each name becomes
   169	#' a (possibly nested, e.g. `"functional_clusters/reproducibility.json.gz"`)
   170	#' relative file path inside the archive. Built ONCE at release-build time
   171	#' and stored/served verbatim thereafter, so byte-level rebuild determinism
   172	#' is NOT required here — per-file `checksums.sha256` entries plus the
   173	#' manifest are the verification anchors for individual file contents. Paths
   174	#' are sorted purely for a stable, readable archive listing order.
   175	#'
   176	#' @param named_raw_list named list of raw vectors, keyed by archive-relative
   177	#'   path.
   178	#' @return raw vector, the gzip-compressed tar archive bytes.
   179	analysis_release_build_tar_gz <- function(named_raw_list) {
   180	  paths <- names(named_raw_list)
   181	  stopifnot(
   182	    "named_raw_list must be a non-empty named list" = length(paths) > 0 && all(nzchar(paths))
   183	  )
   184	  paths <- sort(paths)
   185	
   186	  src_dir <- tempfile("analysis-release-src-")
   187	  dir.create(src_dir, recursive = TRUE)
   188	  on.exit(unlink(src_dir, recursive = TRUE, force = TRUE), add = TRUE)
   189	
   190	  for (path in paths) {
   191	    full_path <- file.path(src_dir, path)
   192	    dir.create(dirname(full_path), recursive = TRUE, showWarnings = FALSE)
   193	    writeBin(named_raw_list[[path]], full_path)
   194	  }
   195	
   196	  tar_file <- tempfile("analysis-release-", fileext = ".tar")
   197	  on.exit(unlink(tar_file, force = TRUE), add = TRUE)
   198	
   199	  previous_wd <- setwd(src_dir)
   200	  on.exit(setwd(previous_wd), add = TRUE)
   201	  # tar = "internal" forces R's built-in (pure-R) tar writer so the archive
   202	  # never depends on a system `tar` binary being present/compatible.
   203	  utils::tar(tarfile = tar_file, files = paths, compression = "none", tar = "internal")
   204	
   205	  memCompress(readBin(tar_file, "raw", n = file.info(tar_file)$size), type = "gzip")
   206	}
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
   192	# Read
   193	# --------------------------------------------------------------------------- #
   194	
   195	#' Fetch a release head (+ parsed manifest.json, if stored) by id.
   196	#'
   197	#' Draft rows are hidden unless `include_draft = TRUE` — the visibility
   198	#' filter is applied in SQL (`AND status = 'published'`), not by fetching and
   199	#' discarding in R.
   200	#'
   201	#' @return A named list (head columns + `$manifest`, the parsed manifest.json
   202	#'   as a plain R list via `jsonlite::fromJSON(simplifyVector = FALSE)`), or
   203	#'   `NULL` if no matching (visible) row exists.
   204	#' @export
   205	analysis_release_get <- function(release_id, include_draft = FALSE, conn) {
   206	  status_clause <- if (isTRUE(include_draft)) "" else " AND status = 'published'"
   207	  sql <- paste0(
   208	    "SELECT ", .analysis_release_head_columns, "
   209	       FROM analysis_snapshot_release
   210	      WHERE release_id = ?", status_clause, "
   211	      LIMIT 1"
   212	  )
   213	  rows <- DBI::dbGetQuery(conn, sql, params = unname(list(as.character(release_id))))
   214	  if (nrow(rows) == 0L) {
   215	    return(NULL)
   216	  }
   217	
   218	  head <- .analysis_release_row_to_list(rows)
   219	
   220	  manifest_file <- analysis_release_get_file(
   221	    release_id, "manifest.json",
   222	    include_draft = include_draft, conn = conn
   223	  )
   224	  head$manifest <- if (is.null(manifest_file)) {
   225	    NULL
   226	  } else {
   227	    tryCatch(
   228	      jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE),
   229	      error = function(e) NULL
   230	    )
   231	  }
   232	
   233	  head
   234	}
   235	
   236	#' List release heads (newest first), each with a `layers` member summary.
   237	#'
   238	#' `status = NULL` returns releases of every status; otherwise filters to the
   239	#' given status (e.g. `"published"`, `"draft"`) in SQL.
   240	#'
   241	#' @return A list of named lists (head columns + `$layers`, a list of
   242	#'   `list(analysis_type, snapshot_id, payload_hash)` for `role = 'layer'`
   243	#'   members). Empty list if no rows match.
   244	#' @export
   245	analysis_release_list <- function(status = "published", limit = 50L, offset = 0L, conn) {
   246	  where_clause <- ""
   247	  params <- list()
   248	  if (!is.null(status)) {
   249	    where_clause <- " WHERE status = ?"
   250	    params <- list(as.character(status))
   251	  }
   252	  sql <- paste0(
   253	    "SELECT ", .analysis_release_head_columns, "
   254	       FROM analysis_snapshot_release",
   255	    where_clause,
   256	    " ORDER BY created_at DESC LIMIT ? OFFSET ?"
   257	  )
   258	  params <- c(params, list(as.integer(limit), as.integer(offset)))
   259	  rows <- DBI::dbGetQuery(conn, sql, params = unname(params))
   260	  if (nrow(rows) == 0L) {
   261	    return(list())
   262	  }
   263	
   264	  release_ids <- as.character(rows$release_id)
   265	  placeholders <- paste(rep("?", length(release_ids)), collapse = ",")
   266	  members <- DBI::dbGetQuery(
   267	    conn,
   268	    paste0(
   269	      "SELECT release_id, analysis_type, snapshot_id, payload_hash
   270	         FROM analysis_snapshot_release_member
   271	        WHERE role = 'layer' AND release_id IN (", placeholders, ")
   272	        ORDER BY release_id, analysis_type"
   273	    ),
   274	    params = unname(as.list(release_ids))
   275	  )
   276	
   277	  lapply(seq_len(nrow(rows)), function(i) {
   278	    head <- .analysis_release_row_to_list(rows, i)
   279	    rid <- as.character(head$release_id)
   280	    layer_rows <- members[members$release_id == rid, , drop = FALSE]
   281	    head$layers <- lapply(seq_len(nrow(layer_rows)), function(j) {
   282	      list(
   283	        analysis_type = as.character(layer_rows$analysis_type[[j]]),
   284	        snapshot_id = layer_rows$snapshot_id[[j]],
   285	        payload_hash = as.character(layer_rows$payload_hash[[j]])
   286	      )
   287	    })
   288	    head
   289	  })
   290	}
   291	
   292	#' Fetch one archive file's bytes by its exact (release_id, file_path) key.
   293	#'
   294	#' PK lookup only — no path building/concatenation. Draft-release files are
   295	#' hidden unless `include_draft = TRUE` (a SQL join against the head table's
   296	#' `status`, applied before any blob is fetched).
   297	#'
   298	#' @return `list(bytes = <raw, decompressed>, media_type = chr,
   299	#'   content_sha256 = chr)`, or `NULL` if no matching (visible) row exists.
   300	#' @export
   301	analysis_release_get_file <- function(release_id, file_path, include_draft = FALSE, conn) {
   302	  status_clause <- if (isTRUE(include_draft)) "" else " AND r.status = 'published'"
   303	  sql <- paste0(
   304	    "SELECT f.content_gzip, f.media_type, f.content_sha256
   305	       FROM analysis_snapshot_release_file f
   306	       JOIN analysis_snapshot_release r ON r.release_id = f.release_id
   307	      WHERE f.release_id = ? AND f.file_path = ?", status_clause, "
   308	      LIMIT 1"
   309	  )
   310	  rows <- DBI::dbGetQuery(
   311	    conn, sql,
   312	    params = unname(list(as.character(release_id), as.character(file_path)))
   313	  )
   314	  if (nrow(rows) == 0L) {
   315	    return(NULL)
   316	  }
   317	
   318	  gz <- .analysis_release_blob(rows$content_gzip[[1]])
   319	  list(
   320	    bytes = memDecompress(gz, type = "gzip"),
   321	    media_type = as.character(rows$media_type[[1]]),
   322	    content_sha256 = as.character(rows$content_sha256[[1]])
   323	  )
   324	}
   325	
   326	#' Fetch the whole release archive (`bundle_gzip`) verbatim.
   327	#'
   328	#' `bundle_gzip` is stored already-gzipped and served as-is — this does NOT
   329	#' decompress it (unlike `analysis_release_get_file()`, which stores each
   330	#' file's gzip as a transport-only encoding of JSON content). Draft releases
   331	#' are hidden unless `include_draft = TRUE`, filtered in SQL.
   332	#'
   333	#' @return `list(bytes = <raw, verbatim gzip tar>, sha256 = chr, filename =
   334	#'   "<release_id>.tar.gz")`, or `NULL` if no matching (visible) row exists.
   335	#' @export
   336	analysis_release_get_bundle <- function(release_id, include_draft = FALSE, conn) {
   337	  status_clause <- if (isTRUE(include_draft)) "" else " AND status = 'published'"
   338	  sql <- paste0(
   339	    "SELECT bundle_gzip, bundle_sha256
   340	       FROM analysis_snapshot_release
   341	      WHERE release_id = ?", status_clause, "
   342	      LIMIT 1"
   343	  )
   344	  rows <- DBI::dbGetQuery(conn, sql, params = unname(list(as.character(release_id))))
   345	  if (nrow(rows) == 0L) {
   346	    return(NULL)
   347	  }
   348	
   349	  list(
   350	    bytes = .analysis_release_blob(rows$bundle_gzip[[1]]),
   351	    sha256 = as.character(rows$bundle_sha256[[1]]),
   352	    filename = paste0(as.character(release_id), ".tar.gz")
   353	  )
   354	}
   355	
   356	#' Check whether a release id exists (any status) — for idempotent creation.
   357	#' @return logical(1).
   358	#' @export
   359	analysis_release_exists <- function(release_id, conn) {
   360	  rows <- DBI::dbGetQuery(
   361	    conn,
   362	    "SELECT 1 AS found FROM analysis_snapshot_release WHERE release_id = ? LIMIT 1",
   363	    params = unname(list(as.character(release_id)))
   364	  )
   365	  nrow(rows) > 0L
   366	}
   367	
   368	#' Distinct snapshot ids referenced by any release member (the later prune
   369	#' guard uses this to never delete a snapshot a release still points to).
   370	#' @return integer vector (possibly empty).
   371	#' @export
   372	analysis_release_referenced_snapshot_ids <- function(conn) {
   373	  rows <- DBI::dbGetQuery(
   374	    conn,
   375	    "SELECT DISTINCT snapshot_id FROM analysis_snapshot_release_member"
   376	  )
   377	  as.integer(rows$snapshot_id)
   378	}
   379	
   380	# --------------------------------------------------------------------------- #
   381	# Update / delete
   382	# --------------------------------------------------------------------------- #
   383	
   384	#' Publish a draft release (no-op if it is not currently a draft).
   385	#' @return logical(1), TRUE iff the row flipped to published.
   386	#' @export
   387	analysis_release_publish <- function(release_id, conn) {
   388	  affected <- DBI::dbExecute(
   389	    conn,
   390	    "UPDATE analysis_snapshot_release
   391	        SET status = 'published', published_at = NOW(6)
   392	      WHERE release_id = ? AND status = 'draft'",
   393	    params = unname(list(as.character(release_id)))
   394	  )
   395	  affected > 0L
   396	}
   397	
   398	#' Record external Zenodo/DOI provenance on an existing release.
   399	#'
   400	#' Additive metadata only — updates whichever of `zenodo_record_id`,
   401	#' `zenodo_record_url`, `version_doi`, `concept_doi` are present in
   402	#' `doi_fields`; never touches `content_digest`/`manifest_sha256` (release
   403	#' scientific identity is immutable once minted).
   404	#'
   405	#' @param doi_fields Named list, any subset of `zenodo_record_id`,
   406	#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
   407	#' @return logical(1), TRUE iff a row was updated.
   408	#' @export
   409	analysis_release_set_doi <- function(release_id, doi_fields = list(), conn) {
   410	  allowed <- c("zenodo_record_id", "zenodo_record_url", "version_doi", "concept_doi")
   411	  present <- intersect(names(doi_fields), allowed)
   412	  if (length(present) == 0L) {
   413	    return(FALSE)
   414	  }
   415	
   416	  set_clause <- paste(paste0(present, " = ?"), collapse = ", ")
   417	  value_params <- lapply(present, function(k) .analysis_release_chr(doi_fields[[k]]))
   418	  affected <- DBI::dbExecute(
   419	    conn,
   420	    paste0("UPDATE analysis_snapshot_release SET ", set_clause, " WHERE release_id = ?"),
   421	    params = unname(c(value_params, list(as.character(release_id))))
   422	  )
   423	  affected > 0L
   424	}
   425	
   426	#' Delete a release ONLY while it is still a draft (children cascade via FK).
   427	#'
   428	#' Refuses (returns FALSE, no-op) once a release is published — releases are
   429	#' immutable/retained-indefinitely once published; only an unpublished draft
   430	#' can be discarded (e.g. a failed/aborted build).
   431	#'
   432	#' @return logical(1), TRUE iff a draft row was deleted.
   433	#' @export
   434	analysis_release_delete_draft <- function(release_id, conn) {
   435	  affected <- DBI::dbExecute(
   436	    conn,
   437	    "DELETE FROM analysis_snapshot_release WHERE release_id = ? AND status = 'draft'",
   438	    params = unname(list(as.character(release_id)))
   439	  )
   440	  affected > 0L
   441	}

exec
/bin/bash -lc 'nl -ba api/functions/analysis-snapshot-release-materialize.R && nl -ba api/functions/analysis-snapshot-release.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
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
    57	#' Coerce a possibly-NULL child tibble to a plain data.frame for serialization.
    58	#' @noRd
    59	.analysis_release_rows <- function(x) {
    60	  if (is.null(x)) {
    61	    return(data.frame())
    62	  }
    63	  as.data.frame(x, stringsAsFactors = FALSE)
    64	}
    65	
    66	#' Map a cluster analysis_type to its cluster_kind label.
    67	#' @noRd
    68	.analysis_release_layer_kind <- function(analysis_type) {
    69	  switch(as.character(analysis_type[[1]]),
    70	    functional_clusters = "functional",
    71	    phenotype_clusters = "phenotype",
    72	    NA_character_
    73	  )
    74	}
    75	
    76	#' Extract the reproducibility_hash from a loader row (df or list), or NA.
    77	#' @noRd
    78	.analysis_release_repro_hash <- function(repro) {
    79	  if (is.null(repro)) {
    80	    return(NA_character_)
    81	  }
    82	  if (is.data.frame(repro) && nrow(repro) == 0L) {
    83	    return(NA_character_)
    84	  }
    85	  hash <- repro$reproducibility_hash
    86	  if (is.null(hash) || length(hash) == 0L) {
    87	    return(NA_character_)
    88	  }
    89	  as.character(hash[[1]])
    90	}
    91	
    92	# --------------------------------------------------------------------------- #
    93	# Default coherence seam (best-effort HARD re-check over the STORED snapshot).
    94	#
    95	# Two of the three #514 coherence components ARE reconstructable from the stored
    96	# public snapshot and are re-checked here (HARD, require_coherence = TRUE,
    97	# ignoring the ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE downgrade):
    98	#   1. Cluster-set integrity: every visible cluster (by cluster_kind) must appear
    99	#      in the membership AND carry a non-NA stability score (jaccard_mean) in its
   100	#      metadata_json — directly catching the #514 symptom ("real clusters with n/a
   101	#      stability") in stored form.
   102	#   2. Channel match (functional axis): the served membership channel
   103	#      (`membership_weight_channel`) and the validation channel (`weight_channel`)
   104	#      are both persisted in the manifest `validation_json`; when both are present
   105	#      they must agree, else the served membership was clustered on a different
   106	#      STRING channel than the validation scored (the #514 text-mining-vs-exp+db
   107	#      case that slips through when cluster-id labels coincide).
   108	# The THIRD component — full member-set equality — is genuinely NOT
   109	# reconstructable: the validator's `reference_members` is a sibling of `partition`
   110	# and is never persisted. That check is left to the build-time gate; the dev-stack
   111	# e2e exercises the true membership-vs-validation recompute path.
   112	# --------------------------------------------------------------------------- #
   113	
   114	#' Parse the manifest `validation_json` column to a plain list (or empty list).
   115	#' @noRd
   116	.analysis_release_parse_validation_json <- function(manifest) {
   117	  raw <- suppressWarnings(as.character(.analysis_release_manifest_scalar(manifest, "validation_json", NA_character_)))
   118	  if (length(raw) == 0L || is.na(raw[[1]]) || !nzchar(raw[[1]])) {
   119	    return(list())
   120	  }
   121	  parsed <- tryCatch(jsonlite::fromJSON(raw[[1]], simplifyVector = TRUE), error = function(e) NULL)
   122	  if (is.null(parsed) || !is.list(parsed)) {
   123	    return(list())
   124	  }
   125	  parsed
   126	}
   127	
   128	#' @noRd
   129	.analysis_release_cluster_has_stability <- function(metadata_json) {
   130	  txt <- suppressWarnings(as.character(metadata_json))
   131	  if (length(txt) == 0L || is.na(txt[[1]]) || !nzchar(txt[[1]])) {
   132	    return(FALSE)
   133	  }
   134	  parsed <- tryCatch(jsonlite::fromJSON(txt[[1]], simplifyVector = TRUE), error = function(e) NULL)
   135	  if (is.null(parsed)) {
   136	    return(FALSE)
   137	  }
   138	  score <- parsed$jaccard_mean %||% parsed$stability %||% parsed$stability_score
   139	  !is.null(score) && length(score) >= 1L && !is.na(suppressWarnings(as.numeric(score[[1]])))
   140	}
   141	
   142	#' Hard coherence re-check over a loaded cluster snapshot. Default `coherence_assert`.
   143	#' @export
   144	analysis_snapshot_release_assert_coherent <- function(snapshot, kind) {
   145	  clusters <- .analysis_release_rows(snapshot$clusters)
   146	  members <- .analysis_release_rows(snapshot$cluster_members)
   147	  if ("cluster_kind" %in% names(clusters)) {
   148	    clusters <- clusters[as.character(clusters$cluster_kind) == kind, , drop = FALSE]
   149	  }
   150	  if ("cluster_kind" %in% names(members)) {
   151	    members <- members[as.character(members$cluster_kind) == kind, , drop = FALSE]
   152	  }
   153	
   154	  membership_ids <- if ("cluster_id" %in% names(members)) unique(as.character(members$cluster_id)) else character(0)
   155	  membership <- tibble::tibble(cluster = membership_ids)
   156	
   157	  valid_ids <- character(0)
   158	  if (nrow(clusters) > 0L && "cluster_id" %in% names(clusters)) {
   159	    metadata <- if ("metadata_json" %in% names(clusters)) clusters$metadata_json else rep(NA_character_, nrow(clusters))
   160	    has_stability <- vapply(
   161	      seq_len(nrow(clusters)),
   162	      function(i) .analysis_release_cluster_has_stability(metadata[[i]]),
   163	      logical(1)
   164	    )
   165	    valid_ids <- as.character(clusters$cluster_id[has_stability])
   166	  }
   167	  per_cluster <- tibble::tibble(cluster_id = valid_ids)
   168	
   169	  # Channel match (functional axis only): both channels live in validation_json;
   170	  # when both are present they must agree. Absent/older snapshots skip this
   171	  # comparison (assert_partition_coherent only fires channel_mismatch when BOTH
   172	  # membership_channel and validation_channel are non-NULL).
   173	  membership_channel <- NULL
   174	  validation_channel <- NULL
   175	  if (identical(kind, "functional")) {
   176	    validation <- .analysis_release_parse_validation_json(snapshot$manifest)
   177	    membership_channel <- validation$membership_weight_channel
   178	    validation_channel <- validation$weight_channel
   179	  }
   180	
   181	  tryCatch(
   182	    analysis_snapshot_assert_partition_coherent(
   183	      membership, per_cluster, kind,
   184	      membership_channel = membership_channel,
   185	      validation_channel = validation_channel,
   186	      require_coherence = TRUE
   187	    ),
   188	    error = function(e) {
   189	      stop(.analysis_release_condition(
   190	        "release_source_incoherent",
   191	        sprintf("%s snapshot failed hard coherence re-check: %s", kind, conditionMessage(e)),
   192	        kind = kind
   193	      ))
   194	    }
   195	  )
   196	  invisible(TRUE)
   197	}
   198	
   199	# --------------------------------------------------------------------------- #
   200	# Cross-layer lineage gates (step 2). Re-asserted immediately before insert.
   201	# --------------------------------------------------------------------------- #
   202	
   203	#' @noRd
   204	.analysis_release_dep_matches <- function(dependencies, key, entry) {
   205	  if (!is.list(dependencies)) {
   206	    return(FALSE)
   207	  }
   208	  dep <- dependencies[[key]]
   209	  if (!is.list(dep)) {
   210	    return(FALSE)
   211	  }
   212	  dep_id <- suppressWarnings(as.integer(dep$snapshot_id %||% NA))
   213	  dep_hash <- as.character(dep$payload_hash %||% "")
   214	  entry_id <- suppressWarnings(as.integer(entry$snapshot_id))
   215	  entry_hash <- as.character(entry$payload_hash %||% "")
   216	  !is.na(dep_id) && !is.na(entry_id) && identical(dep_id, entry_id) &&
   217	    nzchar(dep_hash) && nzchar(entry_hash) && identical(dep_hash, entry_hash)
   218	}
   219	
   220	#' Assert one shared source_data_version + correlation dependency lineage.
   221	#' @noRd
   222	.analysis_release_assert_lineage <- function(loaded) {
   223	  versions <- vapply(
   224	    loaded,
   225	    function(e) as.character(e$source_data_version %||% NA_character_),
   226	    character(1)
   227	  )
   228	  uniq <- unique(versions)
   229	  if (length(uniq) != 1L || is.na(uniq[[1]]) || !nzchar(uniq[[1]])) {
   230	    stop(.analysis_release_condition(
   231	      "release_source_version_mismatch",
   232	      sprintf(
   233	        "release layers do not share one source_data_version (found: %s)",
   234	        paste(ifelse(is.na(versions), "<NA>", versions), collapse = ", ")
   235	      )
   236	    ))
   237	  }
   238	
   239	  corr <- loaded[["phenotype_functional_correlations"]]
   240	  func <- loaded[["functional_clusters"]]
   241	  phen <- loaded[["phenotype_clusters"]]
   242	  if (!is.null(corr) && !is.null(func) && !is.null(phen)) {
   243	    dependencies <- analysis_snapshot_manifest_dependencies(corr$manifest)
   244	    ok <- .analysis_release_dep_matches(dependencies, "functional_clusters", func) &&
   245	      .analysis_release_dep_matches(dependencies, "phenotype_clusters", phen)
   246	    if (!ok) {
   247	      stop(.analysis_release_condition(
   248	        "release_dependency_lineage_mismatch",
   249	        paste(
   250	          "correlation snapshot dependency lineage does not match the pinned",
   251	          "functional/phenotype cluster snapshots (a cluster axis was refreshed",
   252	          "after the correlation was computed)"
   253	        )
   254	      ))
   255	    }
   256	  }
   257	  invisible(TRUE)
   258	}
   259	
   260	# --------------------------------------------------------------------------- #
   261	# File materialization
   262	# --------------------------------------------------------------------------- #
   263	
   264	#' Layer-appropriate payload object (its own bytes; NOT the snapshot payload_hash).
   265	#' @noRd
   266	.analysis_release_layer_payload <- function(snapshot, layer) {
   267	  if (isTRUE(layer$has_reproducibility)) {
   268	    list(
   269	      clusters = .analysis_release_rows(snapshot$clusters),
   270	      cluster_members = .analysis_release_rows(snapshot$cluster_members)
   271	    )
   272	  } else if (grepl("correlation", layer$analysis_type, fixed = TRUE)) {
   273	    list(correlations = .analysis_release_rows(snapshot$correlations))
   274	  } else {
   275	    list(
   276	      network_nodes = .analysis_release_rows(snapshot$network_nodes),
   277	      network_edges = .analysis_release_rows(snapshot$network_edges)
   278	    )
   279	  }
   280	}
   281	
   282	#' Assemble one materialized artifact with its own sha256 + byte_size.
   283	#' @noRd
   284	.analysis_release_artifact <- function(path, bytes, media_type) {
   285	  list(
   286	    path = path,
   287	    bytes = bytes,
   288	    media_type = media_type,
   289	    sha256 = analysis_release_sha256(bytes),
   290	    byte_size = length(bytes)
   291	  )
   292	}
   293	
   294	#' README.md content bytes (scope + independent-verification recipe).
   295	#' @noRd
   296	.analysis_release_readme_bytes <- function(release_id, title, scope_statement, license,
   297	                                           source_data_version, layer_entries) {
   298	  layer_lines <- vapply(
   299	    layer_entries,
   300	    function(e) {
   301	      sprintf(
   302	        "- %s (snapshot_id %s, payload_hash %s)",
   303	        e$analysis_type, as.character(e$snapshot_id), substr(e$payload_hash, 1, 12)
   304	      )
   305	    },
   306	    character(1)
   307	  )
   308	  lines <- c(
   309	    sprintf("# %s", title %||% "SysNDD analysis-snapshot release"),
   310	    "",
   311	    sprintf("Release: `%s`", release_id),
   312	    sprintf("License: %s", license %||% "CC-BY-4.0"),
   313	    sprintf("Source data version: %s", source_data_version %||% "unknown"),
   314	    "",
   315	    "## Scope",
   316	    "",
   317	    scope_statement %||% paste(
   318	      "Immutable, content-addressed public export of the curated derived",
   319	      "cluster-analysis snapshots served by the SysNDD analysis API."
   320	    ),
   321	    "",
   322	    "## Layers",
   323	    "",
   324	    layer_lines,
   325	    "",
   326	    "## Verify",
   327	    "",
   328	    "1. `sha256sum -c checksums.sha256` verifies every file against its recorded digest.",
   329	    "2. `manifest.json` records each layer's source snapshot lineage",
   330	    "   (`snapshot_id`, `payload_hash`, `input_hash`) plus the reproducibility hash.",
   331	    "3. Each cluster layer's `reproducibility.json` hashes exactly to its",
   332	    "   `reproducibility_hash` and carries the inputs to independently recompute",
   333	    "   the served separation metric (modularity / silhouette).",
   334	    ""
   335	  )
   336	  charToRaw(enc2utf8(paste(lines, collapse = "\n")))
   337	}
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
    97	#' Fresh pre-insert re-read: re-load each layer via the loader seam (NOT the
    98	#' cached step-1 `loaded`) and confirm each layer's {snapshot_id, payload_hash}
    99	#' and the correlation dependencies still equal the pinned lineage. Throws a
   100	#' classed gate error if a source snapshot changed between the first read and the
   101	#' insert (the real TOCTOU catch).
   102	#' @noRd
   103	.analysis_release_verify_lineage_unchanged <- function(layer_specs, loaded, loader, conn) {
   104	  for (spec in layer_specs) {
   105	    at <- spec$analysis_type
   106	    entry <- loaded[[at]]
   107	    fresh <- loader(at, spec$parameter_hash, conn = conn)
   108	    status_code <- if (is.null(fresh)) "snapshot_missing" else (fresh$status_code %||% "snapshot_missing")
   109	    if (!identical(status_code, "available")) {
   110	      stop(.analysis_release_condition(
   111	        "release_snapshot_not_available",
   112	        sprintf("layer %s became unavailable before insert: %s", at, status_code),
   113	        analysis_type = at, status_code = status_code
   114	      ))
   115	    }
   116	    fresh_id <- suppressWarnings(as.integer(.analysis_release_manifest_scalar(fresh$manifest, "snapshot_id")))
   117	    fresh_hash <- as.character(.analysis_release_manifest_scalar(fresh$manifest, "payload_hash", NA_character_))
   118	    if (!identical(fresh_id, suppressWarnings(as.integer(entry$snapshot_id))) ||
   119	      !identical(fresh_hash, entry$payload_hash)) {
   120	      stop(.analysis_release_condition(
   121	        "release_dependency_lineage_mismatch",
   122	        sprintf(
   123	          "layer %s snapshot changed between read and insert (was snapshot_id %s, now %s)",
   124	          at, as.character(entry$snapshot_id), as.character(fresh_id)
   125	        ),
   126	        analysis_type = at
   127	      ))
   128	    }
   129	    if (identical(at, "phenotype_functional_correlations") &&
   130	      !is.null(loaded[["functional_clusters"]]) && !is.null(loaded[["phenotype_clusters"]])) {
   131	      fresh_deps <- analysis_snapshot_manifest_dependencies(fresh$manifest)
   132	      ok <- .analysis_release_dep_matches(fresh_deps, "functional_clusters", loaded[["functional_clusters"]]) &&
   133	        .analysis_release_dep_matches(fresh_deps, "phenotype_clusters", loaded[["phenotype_clusters"]])
   134	      if (!ok) {
   135	        stop(.analysis_release_condition(
   136	          "release_dependency_lineage_mismatch",
   137	          "correlation dependency lineage changed between read and insert",
   138	          analysis_type = at
   139	        ))
   140	      }
   141	    }
   142	  }
   143	  invisible(TRUE)
   144	}
   145	
   146	# --------------------------------------------------------------------------- #
   147	# Orchestrator
   148	# --------------------------------------------------------------------------- #
   149	
   150	#' Build (and optionally publish) an immutable analysis-snapshot release.
   151	#'
   152	#' @param layers Layer registry (default `analysis_snapshot_release_layers()`).
   153	#' @param title,scope_statement,license Presentation metadata (excluded from the
   154	#'   content digest / release identity).
   155	#' @param publish If TRUE the inserted draft is flipped to `published`.
   156	#' @param created_by Optional user id recorded on the head row.
   157	#' @param conn A real DBIConnection (required for persistence; A5 checks one out).
   158	#' @param loader,reproducibility_loader,coherence_assert Injectable seams (see file
   159	#'   header); call-time defaults are the real functions.
   160	#' @return `list(release = <head>, created = TRUE|FALSE)`.
   161	#' @export
   162	analysis_snapshot_release_build <- function(layers = analysis_snapshot_release_layers(),
   163	                                            title = NULL,
   164	                                            scope_statement = NULL,
   165	                                            license = "CC-BY-4.0",
   166	                                            publish = TRUE,
   167	                                            created_by = NULL,
   168	                                            conn = NULL,
   169	                                            loader = analysis_snapshot_get_public,
   170	                                            reproducibility_loader = analysis_snapshot_get_reproducibility,
   171	                                            coherence_assert = analysis_snapshot_release_assert_coherent) {
   172	  # Resolve (analysis_type, parameter_hash) per layer once (pure; validates params).
   173	  layer_specs <- lapply(layers, function(layer) {
   174	    at <- as.character(layer$analysis_type[[1]])
   175	    list(
   176	      analysis_type = at,
   177	      layer = layer,
   178	      parameter_hash = analysis_snapshot_normalize_params(at, layer$params %||% list())$parameter_hash
   179	    )
   180	  })
   181	
   182	  # --- Step 0: per-preset TOCTOU advisory locks (best-effort) --------------
   183	  # Acquire the SAME per-preset lock the axis refresh holds, so a mid-flight
   184	  # refresh of a source preset serializes against this read. Released on exit.
   185	  if (inherits(conn, "DBIConnection")) {
   186	    acquired_locks <- character(0)
   187	    for (spec in layer_specs) {
   188	      lock_name <- .analysis_release_preset_lock_name(spec$analysis_type, spec$parameter_hash)
   189	      if (.analysis_release_get_lock(conn, lock_name, 5L)) {
   190	        acquired_locks <- c(acquired_locks, lock_name)
   191	      }
   192	    }
   193	    if (length(acquired_locks) > 0L) {
   194	      on.exit(
   195	        for (lock_name in acquired_locks) .analysis_release_release_named_lock(conn, lock_name),
   196	        add = TRUE
   197	      )
   198	    }
   199	  }
   200	
   201	  # --- Step 1/1b/1c: load + gate each layer --------------------------------
   202	  loaded <- list()
   203	  for (spec in layer_specs) {
   204	    layer <- spec$layer
   205	    at <- spec$analysis_type
   206	    parameter_hash <- spec$parameter_hash
   207	
   208	    snapshot <- loader(at, parameter_hash, conn = conn)
   209	    status_code <- if (is.null(snapshot)) "snapshot_missing" else (snapshot$status_code %||% "snapshot_missing")
   210	    if (!identical(status_code, "available")) {
   211	      stop(.analysis_release_condition(
   212	        "release_snapshot_not_available",
   213	        sprintf("layer %s is not available for release: %s", at, status_code),
   214	        analysis_type = at, status_code = status_code
   215	      ))
   216	    }
   217	
   218	    manifest <- snapshot$manifest
   219	    entry <- list(
   220	      analysis_type = at,
   221	      kind = .analysis_release_layer_kind(at),
   222	      layer = layer,
   223	      snapshot = snapshot,
   224	      manifest = manifest,
   225	      snapshot_id = .analysis_release_manifest_scalar(manifest, "snapshot_id"),
   226	      payload_hash = as.character(.analysis_release_manifest_scalar(manifest, "payload_hash", NA_character_)),
   227	      input_hash = as.character(.analysis_release_manifest_scalar(manifest, "input_hash", NA_character_)),
   228	      schema_version = as.character(.analysis_release_manifest_scalar(manifest, "schema_version", NA_character_)),
   229	      source_data_version = as.character(
   230	        .analysis_release_manifest_scalar(manifest, "source_data_version", NA_character_)
   231	      ),
   232	      parameter_hash = parameter_hash,
   233	      reproducibility_hash = NULL,
   234	      dependencies = NULL,
   235	      reproducibility_bundle = NULL
   236	    )
   237	
   238	    if (isTRUE(layer$has_reproducibility)) {
   239	      # 1b: HARD coherence re-check (any failure -> release_source_incoherent).
   240	      tryCatch(
   241	        coherence_assert(snapshot, entry$kind),
   242	        release_source_incoherent = function(e) stop(e),
   243	        error = function(e) {
   244	          stop(.analysis_release_condition(
   245	            "release_source_incoherent",
   246	            sprintf("layer %s failed the hard coherence re-check: %s", at, conditionMessage(e)),
   247	            analysis_type = at
   248	          ))
   249	        }
   250	      )
   251	
   252	      # 1c: reproducibility bundle presence.
   253	      repro <- reproducibility_loader(entry$snapshot_id, conn = conn)
   254	      repro_hash <- .analysis_release_repro_hash(repro)
   255	      if (is.na(repro_hash) || !nzchar(repro_hash)) {
   256	        stop(.analysis_release_condition(
   257	          "release_reproducibility_missing",
   258	          sprintf("layer %s has no reproducibility bundle; the release requires one", at),
   259	          analysis_type = at
   260	        ))
   261	      }
   262	      entry$reproducibility_hash <- repro_hash
   263	      entry$reproducibility_bundle <- repro$bundle_gzip_json
   264	    }
   265	
   266	    loaded[[at]] <- entry
   267	  }
   268	
   269	  # --- Step 2: shared source version + correlation dependency lineage ------
   270	  .analysis_release_assert_lineage(loaded)
   271	  shared_source_version <- unique(vapply(
   272	    loaded, function(e) as.character(e$source_data_version), character(1)
   273	  ))[[1]]
   274	
   275	  # For the correlation layer, pin the actual dependency lineage into its entry.
   276	  corr <- loaded[["phenotype_functional_correlations"]]
   277	  if (!is.null(corr)) {
   278	    loaded[["phenotype_functional_correlations"]]$dependencies <-
   279	      analysis_snapshot_manifest_dependencies(corr$manifest)
   280	  }
   281	
   282	  # --- Step 3/4/5: materialize per-layer files + README, build layer_entries
   283	  artifacts <- list()
   284	  layer_entries <- list()
   285	
   286	  for (layer in layers) {
   287	    at <- as.character(layer$analysis_type[[1]])
   288	    entry <- loaded[[at]]
   289	    prefix <- layer$files_prefix %||% at
   290	
   291	    payload_bytes <- analysis_release_canonical_bytes(.analysis_release_layer_payload(entry$snapshot, layer))
   292	    artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   293	      paste0(prefix, "/payload.json"), payload_bytes, "application/json"
   294	    )
   295	
   296	    if (isTRUE(layer$has_reproducibility)) {
   297	      repro_bytes <- charToRaw(analysis_reproducibility_decode_raw(entry$reproducibility_bundle))
   298	      artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   299	        paste0(prefix, "/reproducibility.json"), repro_bytes, "application/json"
   300	      )
   301	    }
   302	
   303	    layer_entries[[length(layer_entries) + 1L]] <- list(
   304	      analysis_type = at,
   305	      parameter_hash = entry$parameter_hash,
   306	      snapshot_id = entry$snapshot_id,
   307	      input_hash = entry$input_hash,
   308	      payload_hash = entry$payload_hash,
   309	      schema_version = entry$schema_version,
   310	      reproducibility_hash = entry$reproducibility_hash,
   311	      dependencies = entry$dependencies
   312	    )
   313	  }
   314	
   315	  # --- Step 6: content_digest -> release_id + idempotency ------------------
   316	  content_digest <- analysis_release_content_digest(
   317	    layer_entries, shared_source_version, ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION
   318	  )
   319	  release_id <- analysis_release_id(content_digest)
   320	
   321	  if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
   322	    existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   323	    if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
   324	      return(list(release = existing, created = FALSE))
   325	    }
   326	    stop(sprintf(
   327	      "release id %s already exists with a different content_digest (identity anomaly)",
   328	      release_id
   329	    ), call. = FALSE)
   330	  }
   331	
   332	  # README carries the resolved release_id now that it is known.
   333	  readme_bytes <- .analysis_release_readme_bytes(
   334	    release_id, title, scope_statement, license, shared_source_version, layer_entries
   335	  )
   336	  artifacts <- c(
   337	    list(.analysis_release_artifact("README.md", readme_bytes, "text/markdown")),
   338	    artifacts
   339	  )
   340	
   341	  created_at <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
   342	
   343	  # --- Step 7: manifest.json (files[] excludes manifest + checksums) -------
   344	  content_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256, bytes = a$byte_size))
   345	  manifest_obj <- analysis_release_build_manifest(list(
   346	    release_id = release_id,
   347	    release_version = NULL,
   348	    title = title,
   349	    created_at = created_at,
   350	    license = license %||% "CC-BY-4.0",
   351	    scope_statement = scope_statement,
   352	    generator = list(
   353	      name = "sysndd-analysis-snapshot-release-build",
   354	      manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
   355	      reproducibility_schema_version = if (exists("ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION")) {
   356	        ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION
   357	      } else {
   358	        NULL
   359	      }
   360	    ),
   361	    source = list(
   362	      source_data_version = shared_source_version,
   363	      snapshots = lapply(layer_entries, function(e) {
   364	        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
   365	      })
   366	    ),
   367	    layers = layer_entries,
   368	    files = content_files,
   369	    content_digest = content_digest
   370	  ))
   371	  manifest_bytes <- analysis_release_canonical_bytes(manifest_obj)
   372	  manifest_artifact <- .analysis_release_artifact("manifest.json", manifest_bytes, "application/json")
   373	  manifest_sha256 <- manifest_artifact$sha256
   374	  artifacts[[length(artifacts) + 1L]] <- manifest_artifact
   375	
   376	  # --- Step 8: checksums.sha256 (all files incl. manifest, excl. checksums)-
   377	  checksum_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256))
   378	  checksums_bytes <- charToRaw(enc2utf8(analysis_release_checksums_text(checksum_files)))
   379	  artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   380	    "checksums.sha256", checksums_bytes, "text/plain"
   381	  )
   382	
   383	  # --- Step 9: bundle.tar.gz (all files) -----------------------------------
   384	  named_raw <- stats::setNames(
   385	    lapply(artifacts, function(a) a$bytes),
   386	    vapply(artifacts, function(a) a$path, character(1))
   387	  )
   388	  bundle_gzip <- analysis_release_build_tar_gz(named_raw)
   389	  bundle_sha256 <- analysis_release_sha256(bundle_gzip)
   390	
   391	  # --- Step 2 (re-assert immediately before insert) ------------------------
   392	  # A FRESH DB re-read via the loader seam (not the cached `loaded`) so a source
   393	  # snapshot that was refreshed between the first read and now is caught. Combined
   394	  # with the per-preset locks above, this closes the TOCTOU window.
   395	  .analysis_release_assert_lineage(loaded)
   396	  .analysis_release_verify_lineage_unchanged(layer_specs, loaded, loader, conn)
   397	
   398	  # --- Step 10: persist ----------------------------------------------------
   399	  release_head <- list(
   400	    release_id = release_id,
   401	    release_version = NULL,
   402	    title = title,
   403	    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
   404	    content_digest = content_digest,
   405	    manifest_sha256 = manifest_sha256,
   406	    bundle_sha256 = bundle_sha256,
   407	    bundle_gzip = bundle_gzip,
   408	    source_data_version = shared_source_version,
   409	    scope_statement = scope_statement,
   410	    license = license %||% "CC-BY-4.0",
   411	    created_by_user_id = created_by
   412	  )
   413	
   414	  members <- lapply(layer_entries, function(e) {
   415	    list(
   416	      analysis_type = e$analysis_type,
   417	      parameter_hash = e$parameter_hash,
   418	      snapshot_id = e$snapshot_id,
   419	      input_hash = e$input_hash,
   420	      payload_hash = e$payload_hash,
   421	      schema_version = e$schema_version,
   422	      reproducibility_hash = e$reproducibility_hash,
   423	      role = "layer"
   424	    )
   425	  })
   426	
   427	  insert_files <- lapply(artifacts, function(a) {
   428	    list(
   429	      file_path = a$path,
   430	      content_sha256 = a$sha256,
   431	      byte_size = a$byte_size,
   432	      media_type = a$media_type,
   433	      content_gzip = memCompress(a$bytes, type = "gzip")
   434	    )
   435	  })
   436	
   437	  analysis_release_insert(release_head, members, insert_files, conn)
   438	  if (isTRUE(publish)) {
   439	    analysis_release_publish(release_id, conn = conn)
   440	  }
   441	
   442	  list(
   443	    release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
   444	    created = TRUE
   445	  )
   446	}

exec
/bin/bash -lc "nl -ba api/services/analysis-snapshot-release-service.R && nl -ba api/endpoints/analysis_endpoints.R | sed -n '1,520p' && nl -ba api/endpoints/admin_analysis_snapshot_endpoints.R | sed -n '1,520p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
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
    92	    release_snapshot_not_available = function(e) stop_for_bad_request(conditionMessage(e)),
    93	    release_source_incoherent = function(e) stop_for_bad_request(conditionMessage(e)),
    94	    release_reproducibility_missing = function(e) stop_for_bad_request(conditionMessage(e)),
    95	    release_source_version_mismatch = function(e) stop_for_bad_request(conditionMessage(e)),
    96	    release_dependency_lineage_mismatch = function(e) stop_for_bad_request(conditionMessage(e))
    97	  )
    98	
    99	  res$status <- if (isTRUE(result$created)) 201L else 200L
   100	  result$release
   101	}
   102	
   103	#' Publish a draft release.
   104	#'
   105	#' Publishing an unknown release id is the only failure mode (404).
   106	#' Publishing an already-published release is an idempotent no-op (the
   107	#' repository's `analysis_release_publish()` already no-ops when the row is
   108	#' not currently a draft) — either way the caller gets the current head back.
   109	#'
   110	#' @param release_id Release id (`asr_<16 hex>`).
   111	#' @param conn A real DBIConnection.
   112	#' @return The (published) release head.
   113	#' @export
   114	svc_release_publish <- function(release_id, conn = NULL) {
   115	  analysis_release_publish(release_id, conn = conn)
   116	  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   117	  if (is.null(head)) {
   118	    stop_for_not_found(sprintf("Release '%s' not found", release_id))
   119	  }
   120	  head
   121	}
   122	
   123	#' Record external Zenodo/DOI provenance on an existing release.
   124	#'
   125	#' Additive metadata only (forwarded verbatim to the repository, which never
   126	#' touches `content_digest`/`manifest_sha256` — release scientific identity
   127	#' is immutable once minted). Unknown release id -> 404.
   128	#'
   129	#' @param release_id Release id.
   130	#' @param doi_fields Named list, any subset of `zenodo_record_id`,
   131	#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
   132	#' @param conn A real DBIConnection.
   133	#' @return The updated release head.
   134	#' @export
   135	svc_release_set_doi <- function(release_id, doi_fields, conn = NULL) {
   136	  analysis_release_set_doi(release_id, doi_fields = doi_fields, conn = conn)
   137	  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   138	  if (is.null(head)) {
   139	    stop_for_not_found(sprintf("Release '%s' not found", release_id))
   140	  }
   141	  head
   142	}
   143	
   144	#' Delete a draft release (e.g. a failed/aborted build).
   145	#'
   146	#' Unknown release id -> 404. A published release is immutable/retained
   147	#' indefinitely -> 400 (only drafts are deletable). A draft is deleted and
   148	#' `list(deleted = TRUE, release_id = release_id)` is returned.
   149	#'
   150	#' @param release_id Release id.
   151	#' @param conn A real DBIConnection.
   152	#' @return `list(deleted = TRUE, release_id = release_id)`.
   153	#' @export
   154	svc_release_delete_draft <- function(release_id, conn = NULL) {
   155	  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   156	  if (is.null(head)) {
   157	    stop_for_not_found(sprintf("Release '%s' not found", release_id))
   158	  }
   159	  if (!identical(as.character(head$status), "draft")) {
   160	    stop_for_bad_request("Cannot delete a published release; only drafts are deletable")
   161	  }
   162	  analysis_release_delete_draft(release_id, conn = conn)
   163	  list(deleted = TRUE, release_id = release_id)
   164	}
   165	
   166	# --------------------------------------------------------------------------- #
   167	# Public (published-only)
   168	# --------------------------------------------------------------------------- #
   169	
   170	#' List published releases (newest first).
   171	#'
   172	#' @param limit,offset Pagination.
   173	#' @param conn A real DBIConnection.
   174	#' @return Whatever shape `analysis_release_list()` returns (a list of
   175	#'   release-head-plus-layers entries); never includes drafts.
   176	#' @export
   177	svc_release_list <- function(limit = 50, offset = 0, conn = NULL) {
   178	  analysis_release_list(status = "published", limit = limit, offset = offset, conn = conn)
   179	}
   180	
   181	#' Fetch one published release's head + parsed manifest.
   182	#'
   183	#' Unknown id OR a draft release -> 404 (indistinguishable to the caller;
   184	#' `include_draft = FALSE` makes the repository's own SQL filter the only
   185	#' source of truth for visibility).
   186	#'
   187	#' @param release_id Release id.
   188	#' @param conn A real DBIConnection.
   189	#' @return The release head (+ `$manifest`).
   190	#' @export
   191	svc_release_get <- function(release_id, conn = NULL) {
   192	  head <- analysis_release_get(release_id, include_draft = FALSE, conn = conn)
   193	  if (is.null(head)) {
   194	    stop_for_not_found("Release not found")
   195	  }
   196	  head
   197	}
   198	
   199	#' Fetch a published release's stored `manifest.json` file.
   200	#'
   201	#' @param release_id Release id.
   202	#' @param conn A real DBIConnection.
   203	#' @return `list(bytes, media_type = "application/json", content_sha256)`.
   204	#' @export
   205	svc_release_manifest <- function(release_id, conn = NULL) {
   206	  file <- analysis_release_get_file(release_id, "manifest.json", include_draft = FALSE, conn = conn)
   207	  if (is.null(file)) {
   208	    stop_for_not_found("Release not found")
   209	  }
   210	  list(bytes = file$bytes, media_type = "application/json", content_sha256 = file$content_sha256)
   211	}
   212	
   213	#' Fetch one archive file's bytes from a published release by exact path.
   214	#'
   215	#' Unknown release, a draft release, or an unknown `file_path` all resolve to
   216	#' the same 404 (never distinguished for the caller).
   217	#'
   218	#' @param release_id Release id.
   219	#' @param file_path Exact archive-relative path (e.g. `"README.md"`,
   220	#'   `"functional_clusters/payload.json"`).
   221	#' @param conn A real DBIConnection.
   222	#' @return `list(bytes, media_type, content_sha256)`.
   223	#' @export
   224	svc_release_file <- function(release_id, file_path, conn = NULL) {
   225	  file <- analysis_release_get_file(release_id, file_path, include_draft = FALSE, conn = conn)
   226	  if (is.null(file)) {
   227	    stop_for_not_found(sprintf("Release file not found: %s", file_path))
   228	  }
   229	  list(bytes = file$bytes, media_type = file$media_type, content_sha256 = file$content_sha256)
   230	}
   231	
   232	#' Fetch a published release's whole archive (`bundle.tar.gz`) verbatim.
   233	#'
   234	#' @param release_id Release id.
   235	#' @param conn A real DBIConnection.
   236	#' @return `list(bytes, sha256, filename)`.
   237	#' @export
   238	svc_release_bundle <- function(release_id, conn = NULL) {
   239	  bundle <- analysis_release_get_bundle(release_id, include_draft = FALSE, conn = conn)
   240	  if (is.null(bundle)) {
   241	    stop_for_not_found("Release not found")
   242	  }
   243	  list(bytes = bundle$bytes, sha256 = bundle$sha256, filename = bundle$filename)
   244	}
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
/bin/bash -lc "nl -ba api/endpoints/analysis_endpoints.R | sed -n '340,620p'; rg -n \"analysis_snapshot_lock_name|GET_LOCK|analysis_snapshot_get_public|analysis_snapshot_get_reproducibility|analysis_snapshot_assert_partition_coherent|analysis_snapshot_manifest_dependencies\" api/functions/{analysis-snapshot-repository.R,analysis-snapshot-coherence.R,analysis-snapshot-dependencies.R,analysis-reproducibility.R,analysis-snapshot-builder.R,async-job-analysis-snapshot-handlers.R} api -g '*.R' | head -240; nl -ba api/functions/analysis-snapshot-repository.R | sed -n '1,330p'; nl -ba api/functions/analysis-reproducibility.R | sed -n '1,220p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
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
api/functions/analysis-reproducibility.R:378:  row <- analysis_snapshot_get_reproducibility(snapshot_id, conn = conn)
api/functions/analysis-reproducibility.R:461:analysis_snapshot_get_reproducibility <- function(snapshot_id, conn = NULL) {
api/functions/analysis-snapshot-repository.R:7:analysis_snapshot_lock_name <- function(analysis_type, parameter_hash) {
api/functions/analysis-snapshot-repository.R:8:  # MySQL GET_LOCK() names must be <= 64 characters (errno 4163 otherwise). The
api/functions/analysis-snapshot-repository.R:10:  # so GET_LOCK always failed and the refresh job aborted before writing a
api/functions/analysis-snapshot-repository.R:23:  lock_name <- analysis_snapshot_lock_name(analysis_type, parameter_hash)
api/functions/analysis-snapshot-repository.R:25:    "SELECT GET_LOCK(?, ?) AS acquired",
api/functions/analysis-snapshot-repository.R:34:  lock_name <- analysis_snapshot_lock_name(analysis_type, parameter_hash)
api/functions/analysis-snapshot-repository.R:305:analysis_snapshot_get_public <- function(analysis_type,
api/functions/analysis-snapshot-repository.R:436:#' Mirrors the public-ready predicate of `analysis_snapshot_get_public()` but
api/functions/analysis-snapshot-repository.R:460:#' Like `analysis_snapshot_get_public()` but returns just the single manifest row
api/functions/analysis-snapshot-coherence.R:51:analysis_snapshot_assert_partition_coherent <- function(membership, per_cluster, kind,
api/functions/analysis-snapshot-coherence.R:174:  analysis_snapshot_assert_partition_coherent(
api/functions/analysis-snapshot-dependencies.R:19:                                                      cluster_snapshot_loader = analysis_snapshot_get_public,
api/functions/analysis-snapshot-dependencies.R:75:    cluster_snapshot_loader = analysis_snapshot_get_public,
api/functions/analysis-snapshot-dependencies.R:166:analysis_snapshot_manifest_dependencies <- function(manifest) {
api/functions/analysis-snapshot-dependencies.R:199:  dependencies <- analysis_snapshot_manifest_dependencies(manifest)
api/services/analysis-snapshot-service.R:28:                                           repo_get_public = analysis_snapshot_get_public) {
api/services/analysis-snapshot-service.R:352:      # public-ready manifest row already selected by analysis_snapshot_get_public().
api/functions/publication-date-backfill.R:23:#' Single-flights via `GET_LOCK('sysndd_backfill_publication_dates', 0)`. Selects
api/functions/publication-date-backfill.R:68:    conn, "SELECT GET_LOCK('sysndd_backfill_publication_dates', 0) AS acquired"
api/functions/analysis-snapshot-release.R:12:#   - analysis-snapshot-coherence.R        : analysis_snapshot_assert_partition_coherent
api/functions/analysis-snapshot-release.R:13:#   - analysis-snapshot-dependencies.R     : analysis_snapshot_manifest_dependencies
api/functions/analysis-snapshot-release.R:46:# `analysis_snapshot_lock_name(analysis_type, parameter_hash)` — so a mid-flight
api/functions/analysis-snapshot-release.R:48:# named GET_LOCKs). Best-effort: engaged only on a real DBIConnection (a
api/functions/analysis-snapshot-release.R:49:# pooled/NULL conn cannot hold a session-scoped GET_LOCK meaningfully), and a
api/functions/analysis-snapshot-release.R:57:  if (exists("analysis_snapshot_lock_name", mode = "function")) {
api/functions/analysis-snapshot-release.R:58:    return(analysis_snapshot_lock_name(analysis_type, parameter_hash))
api/functions/analysis-snapshot-release.R:61:  # defines analysis_snapshot_lock_name() is not sourced.
api/functions/analysis-snapshot-release.R:73:        conn, "SELECT GET_LOCK(?, ?) AS acquired",
api/functions/analysis-snapshot-release.R:131:      fresh_deps <- analysis_snapshot_manifest_dependencies(fresh$manifest)
api/functions/analysis-snapshot-release.R:169:                                            loader = analysis_snapshot_get_public,
api/functions/analysis-snapshot-release.R:170:                                            reproducibility_loader = analysis_snapshot_get_reproducibility,
api/functions/analysis-snapshot-release.R:279:      analysis_snapshot_manifest_dependencies(corr$manifest)
api/tests/testthat/test-mcp-snapshot-diagnostics.R:64:  old_get_public <- get0("analysis_snapshot_get_public", envir = .GlobalEnv, ifnotfound = NULL)
api/tests/testthat/test-mcp-snapshot-diagnostics.R:70:  assign("analysis_snapshot_get_public", function(...) stop("full snapshot getter called"), envir = .GlobalEnv)
api/tests/testthat/test-mcp-snapshot-diagnostics.R:78:      rm("analysis_snapshot_get_public", envir = .GlobalEnv)
api/tests/testthat/test-mcp-snapshot-diagnostics.R:80:      assign("analysis_snapshot_get_public", old_get_public, envir = .GlobalEnv)
api/functions/pubtatornidd-nightly.R:9:#   1. single-flights via a MySQL advisory lock (GET_LOCK, non-blocking),
api/functions/pubtatornidd-nightly.R:28:#' Mirrors the NDDScore import-lock pattern. `GET_LOCK(..., 0)` returns
api/functions/pubtatornidd-nightly.R:39:    "SELECT GET_LOCK(?, 0) AS acquired",
api/functions/analysis-reproducibility.R:378:  row <- analysis_snapshot_get_reproducibility(snapshot_id, conn = conn)
api/functions/analysis-reproducibility.R:461:analysis_snapshot_get_reproducibility <- function(snapshot_id, conn = NULL) {
api/functions/disease-ontology-mapping-refresh.R:9:#   1. single-flights via a MySQL advisory lock (GET_LOCK, non-blocking),
api/functions/disease-ontology-mapping-refresh.R:43:#' Mirrors the PubtatorNDD nightly lock pattern. `GET_LOCK(..., 0)` returns
api/functions/disease-ontology-mapping-refresh.R:54:    "SELECT GET_LOCK(?, 0) AS acquired",
api/functions/analysis-snapshot-release-materialize.R:182:    analysis_snapshot_assert_partition_coherent(
api/functions/analysis-snapshot-release-materialize.R:243:    dependencies <- analysis_snapshot_manifest_dependencies(corr$manifest)
api/functions/nddscore-import.R:64:    "SELECT GET_LOCK(?, 0) AS acquired",
api/functions/nddscore-import.R:73:    "SELECT GET_LOCK(?, 30) AS acquired",
api/functions/analysis-snapshot-coherence.R:51:analysis_snapshot_assert_partition_coherent <- function(membership, per_cluster, kind,
api/functions/analysis-snapshot-coherence.R:174:  analysis_snapshot_assert_partition_coherent(
api/tests/testthat/test-mcp-repository.R:74:  expect_false(grepl("analysis_snapshot_get_public", source_text, fixed = TRUE))
api/functions/migration-runner.R:65:#' Uses MySQL GET_LOCK() to coordinate migrations across multiple API workers.
api/functions/migration-runner.R:75:#' - MySQL GET_LOCK returns: 1 = acquired, 0 = timeout, NULL = error
api/functions/migration-runner.R:95:  sql <- sprintf("SELECT GET_LOCK('%s', %d) AS acquired", lock_name, timeout)
api/tests/testthat/test-unit-analysis-snapshot-repository.R:9:  expect_true(exists("analysis_snapshot_lock_name", mode = "function"))
api/tests/testthat/test-unit-analysis-snapshot-repository.R:10:  expect_true(exists("analysis_snapshot_get_public", mode = "function"))
api/tests/testthat/test-unit-analysis-snapshot-repository.R:16:test_that("snapshot lock names are scoped by hash and fit MySQL's 64-char GET_LOCK limit", {
api/tests/testthat/test-unit-analysis-snapshot-repository.R:24:  net_lock <- analysis_snapshot_lock_name(net$analysis_type, net$parameter_hash)
api/tests/testthat/test-unit-analysis-snapshot-repository.R:30:  # Every supported preset's lock name MUST fit MySQL GET_LOCK()'s 64-char cap.
api/tests/testthat/test-unit-analysis-snapshot-repository.R:31:  # If it overflows, GET_LOCK fails (errno 4163) and the refresh job can never
api/tests/testthat/test-unit-analysis-snapshot-repository.R:35:    analysis_snapshot_lock_name(p$analysis_type, h)
api/tests/testthat/test-unit-analysis-snapshot-repository.R:126:  snapshot <- env$analysis_snapshot_get_public("phenotype_clusters", "hash")
api/functions/analysis-snapshot-repository.R:7:analysis_snapshot_lock_name <- function(analysis_type, parameter_hash) {
api/functions/analysis-snapshot-repository.R:8:  # MySQL GET_LOCK() names must be <= 64 characters (errno 4163 otherwise). The
api/functions/analysis-snapshot-repository.R:10:  # so GET_LOCK always failed and the refresh job aborted before writing a
api/functions/analysis-snapshot-repository.R:23:  lock_name <- analysis_snapshot_lock_name(analysis_type, parameter_hash)
api/functions/analysis-snapshot-repository.R:25:    "SELECT GET_LOCK(?, ?) AS acquired",
api/functions/analysis-snapshot-repository.R:34:  lock_name <- analysis_snapshot_lock_name(analysis_type, parameter_hash)
api/functions/analysis-snapshot-repository.R:305:analysis_snapshot_get_public <- function(analysis_type,
api/functions/analysis-snapshot-repository.R:436:#' Mirrors the public-ready predicate of `analysis_snapshot_get_public()` but
api/functions/analysis-snapshot-repository.R:460:#' Like `analysis_snapshot_get_public()` but returns just the single manifest row
api/functions/analysis-snapshot-dependencies.R:19:                                                      cluster_snapshot_loader = analysis_snapshot_get_public,
api/functions/analysis-snapshot-dependencies.R:75:    cluster_snapshot_loader = analysis_snapshot_get_public,
api/functions/analysis-snapshot-dependencies.R:166:analysis_snapshot_manifest_dependencies <- function(manifest) {
api/functions/analysis-snapshot-dependencies.R:199:  dependencies <- analysis_snapshot_manifest_dependencies(manifest)
api/tests/testthat/test-mcp-analysis-service.R:349:  old_get_public <- get0("analysis_snapshot_get_public", envir = .GlobalEnv, ifnotfound = NULL)
api/tests/testthat/test-mcp-analysis-service.R:357:  assign("analysis_snapshot_get_public", function(...) stop("full snapshot getter called"), envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-service.R:366:      rm("analysis_snapshot_get_public", envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-service.R:368:      assign("analysis_snapshot_get_public", old_get_public, envir = .GlobalEnv)
api/tests/testthat/test-mcp-analysis-repository.R:183:  expect_false(grepl("analysis_snapshot_get_public|nddscore_repo_|readRDS|memoise::|MCP_CACHE_DIR", repository))
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R:134:  result <- env$analysis_snapshot_get_public(
api/tests/testthat/test-unit-pubtatornidd-nightly.R:65:test_that("nightly lock helpers map GET_LOCK / RELEASE_LOCK results", {
api/tests/testthat/test-unit-pubtatornidd-nightly.R:68:      if (grepl("GET_LOCK", statement)) return(data.frame(acquired = 1L))
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:29:  res <- analysis_snapshot_assert_partition_coherent(
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:41:    analysis_snapshot_assert_partition_coherent(m, v$per_cluster, kind = "functional"),
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:50:    analysis_snapshot_assert_partition_coherent(m, v$per_cluster, kind = "functional"),
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:59:    analysis_snapshot_assert_partition_coherent(
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:72:    res <- analysis_snapshot_assert_partition_coherent(m, v$per_cluster, kind = "functional"),
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:81:  res <- analysis_snapshot_assert_partition_coherent(m, v$per_cluster, kind = "functional")
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:132:    analysis_snapshot_assert_partition_coherent(
api/tests/testthat/test-unit-analysis-snapshot-coherence.R:142:  res <- analysis_snapshot_assert_partition_coherent(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:9:#   - loader(analysis_type, parameter_hash, conn)  (default analysis_snapshot_get_public)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:10:#   - reproducibility_loader(snapshot_id, conn)    (default analysis_snapshot_get_reproducibility)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:38:# Fixtures: fake loaded snapshots mirroring analysis_snapshot_get_public()'s
     1	# functions/analysis-snapshot-repository.R
     2	
     3	if (!exists("%||%", mode = "function")) {
     4	  `%||%` <- function(x, y) if (is.null(x)) y else x
     5	}
     6	
     7	analysis_snapshot_lock_name <- function(analysis_type, parameter_hash) {
     8	  # MySQL GET_LOCK() names must be <= 64 characters (errno 4163 otherwise). The
     9	  # previous "analysis_snapshot_refresh:<type>:<sha256>" form was 109-124 chars,
    10	  # so GET_LOCK always failed and the refresh job aborted before writing a
    11	  # snapshot -> permanent `snapshot_missing` on every public analysis endpoint.
    12	  # parameter_hash is a 64-char SHA-256 that already encodes (analysis_type,
    13	  # params) (see analysis_snapshot_parameter_hash), so a short prefix + a
    14	  # truncated hash stays unique per preset while fitting the limit. analysis_type
    15	  # is intentionally not inlined — the long preset names overflow the cap.
    16	  paste0("asr:", substr(as.character(parameter_hash[[1]]), 1, 56))
    17	}
    18	
    19	analysis_snapshot_acquire_lock <- function(analysis_type,
    20	                                           parameter_hash,
    21	                                           timeout_seconds = 30L,
    22	                                           conn = NULL) {
    23	  lock_name <- analysis_snapshot_lock_name(analysis_type, parameter_hash)
    24	  result <- db_execute_query(
    25	    "SELECT GET_LOCK(?, ?) AS acquired",
    26	    unname(list(lock_name, as.integer(timeout_seconds))),
    27	    conn = conn
    28	  )
    29	
    30	  isTRUE(as.integer(result$acquired[[1]]) == 1L)
    31	}
    32	
    33	analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
    34	  lock_name <- analysis_snapshot_lock_name(analysis_type, parameter_hash)
    35	  result <- db_execute_query(
    36	    "SELECT RELEASE_LOCK(?) AS released",
    37	    unname(list(lock_name)),
    38	    conn = conn
    39	  )
    40	
    41	  invisible(isTRUE(as.integer(result$released[[1]]) == 1L))
    42	}
    43	
    44	analysis_snapshot_json <- function(value) {
    45	  if (is.null(value)) {
    46	    return(NA_character_)
    47	  }
    48	
    49	  as.character(jsonlite::toJSON(
    50	    value,
    51	    auto_unbox = TRUE,
    52	    null = "null",
    53	    na = "null",
    54	    dataframe = "rows",
    55	    POSIXt = "ISO8601",
    56	    Date = "ISO8601"
    57	  ))
    58	}
    59	
    60	analysis_snapshot_scalar <- function(value, default = NA) {
    61	  if (is.null(value) || length(value) == 0L) {
    62	    return(default)
    63	  }
    64	
    65	  value[[1]]
    66	}
    67	
    68	analysis_snapshot_with_repository_connection <- function(conn = NULL, code) {
    69	  if (!is.null(conn) && inherits(conn, "Pool")) {
    70	    checked_out <- pool::poolCheckout(conn)
    71	    on.exit(pool::poolReturn(checked_out), add = TRUE)
    72	    return(code(checked_out))
    73	  }
    74	
    75	  if (!is.null(conn)) {
    76	    return(code(conn))
    77	  }
    78	
    79	  db_connection <- get_db_connection()
    80	  if (inherits(db_connection, "Pool")) {
    81	    checked_out <- pool::poolCheckout(db_connection)
    82	    on.exit(pool::poolReturn(checked_out), add = TRUE)
    83	    return(code(checked_out))
    84	  }
    85	
    86	  if (inherits(db_connection, "DBIConnection")) {
    87	    is_daemon_conn <- base::exists("daemon_db_conn", envir = .GlobalEnv) &&
    88	      identical(db_connection, base::get("daemon_db_conn", envir = .GlobalEnv))
    89	    if (!is_daemon_conn) {
    90	      on.exit(DBI::dbDisconnect(db_connection), add = TRUE)
    91	    }
    92	  }
    93	
    94	  code(db_connection)
    95	}
    96	
    97	analysis_snapshot_append_rows <- function(table_name, rows, conn) {
    98	  rows <- as.data.frame(rows, stringsAsFactors = FALSE)
    99	  if (nrow(rows) == 0L) {
   100	    return(invisible(0L))
   101	  }
   102	  DBI::dbAppendTable(conn, table_name, rows)
   103	  invisible(nrow(rows))
   104	}
   105	
   106	analysis_snapshot_create_manifest <- function(manifest, conn = NULL) {
   107	  generated_at <- analysis_snapshot_scalar(manifest$generated_at, NA)
   108	  stale_after <- analysis_snapshot_scalar(manifest$stale_after, NA)
   109	
   110	  analysis_snapshot_with_repository_connection(conn, function(manifest_conn) {
   111	    db_execute_statement(
   112	      "INSERT INTO analysis_snapshot_manifest (
   113	         analysis_type, parameter_hash, schema_version, data_class, status,
   114	         public_ready, generated_by_job_id, generated_at, stale_after,
   115	         source_versions_json, source_data_version, parameters_json,
   116	         input_hash, payload_hash, algorithm_name, algorithm_version,
   117	         package_versions_json, row_counts_json, warnings_json, last_error_message,
   118	         validation_json, db_release_version, db_release_commit
   119	       ) VALUES (
   120	         ?, ?, ?, ?, ?, 0, ?, COALESCE(?, NOW(6)), ?,
   121	         ?, ?, ?, ?, ?, ?, ?,
   122	         ?, ?, ?, ?,
   123	         ?, ?, ?
   124	       )",
   125	      unname(list(
   126	        manifest$analysis_type,
   127	        manifest$parameter_hash,
   128	        manifest$schema_version,
   129	        manifest$data_class,
   130	        manifest$status %||% "pending",
   131	        analysis_snapshot_scalar(manifest$generated_by_job_id, NA_character_),
   132	        generated_at,
   133	        stale_after,
   134	        analysis_snapshot_json(manifest$source_versions),
   135	        analysis_snapshot_scalar(manifest$source_data_version, NA_character_),
   136	        manifest$parameters_json,
   137	        manifest$input_hash,
   138	        manifest$payload_hash,
   139	        analysis_snapshot_scalar(manifest$algorithm_name, NA_character_),
   140	        analysis_snapshot_scalar(manifest$algorithm_version, NA_character_),
   141	        analysis_snapshot_json(manifest$package_versions),
   142	        analysis_snapshot_json(manifest$row_counts),
   143	        analysis_snapshot_json(manifest$warnings),
   144	        analysis_snapshot_scalar(manifest$last_error_message, NA_character_),
   145	        analysis_snapshot_json(manifest$validation),                       # JSON column
   146	        analysis_snapshot_scalar(manifest$db_release_version, NA_character_),
   147	        analysis_snapshot_scalar(manifest$db_release_commit,  NA_character_)
   148	      )),
   149	      conn = manifest_conn
   150	    )
   151	
   152	    id <- db_execute_query("SELECT LAST_INSERT_ID() AS snapshot_id", conn = manifest_conn)
   153	    as.numeric(id$snapshot_id[[1]])
   154	  })
   155	}
   156	
   157	analysis_snapshot_insert_network_rows <- function(snapshot_id, rows, conn = NULL) {
   158	  nodes <- tibble::as_tibble(rows$nodes %||% tibble::tibble())
   159	  edges <- tibble::as_tibble(rows$edges %||% tibble::tibble())
   160	
   161	  if (nrow(nodes) > 0L) {
   162	    node_rows <- data.frame(
   163	      snapshot_id = rep(snapshot_id, nrow(nodes)),
   164	      hgnc_id = as.character(nodes$hgnc_id),
   165	      symbol = as.character(nodes$symbol),
   166	      cluster_id = as.character(nodes$cluster_id),
   167	      category = as.character(nodes$category),
   168	      degree = suppressWarnings(as.integer(nodes$degree)),
   169	      x = suppressWarnings(as.numeric(nodes$x)),
   170	      y = suppressWarnings(as.numeric(nodes$y)),
   171	      layout_x = suppressWarnings(as.numeric(nodes$layout_x)),
   172	      layout_y = suppressWarnings(as.numeric(nodes$layout_y)),
   173	      igraph_x = suppressWarnings(as.numeric(nodes$igraph_x)),
   174	      igraph_y = suppressWarnings(as.numeric(nodes$igraph_y)),
   175	      display_order = suppressWarnings(as.integer(nodes$display_order)),
   176	      stringsAsFactors = FALSE
   177	    )
   178	    analysis_snapshot_append_rows("analysis_snapshot_network_node", node_rows, conn)
   179	  }
   180	
   181	  if (nrow(edges) > 0L) {
   182	    edge_rows <- data.frame(
   183	      snapshot_id = rep(snapshot_id, nrow(edges)),
   184	      edge_rank = suppressWarnings(as.integer(edges$edge_rank)),
   185	      source_hgnc_id = as.character(edges$source_hgnc_id),
   186	      target_hgnc_id = as.character(edges$target_hgnc_id),
   187	      confidence = suppressWarnings(as.numeric(edges$confidence)),
   188	      stringsAsFactors = FALSE
   189	    )
   190	    analysis_snapshot_append_rows("analysis_snapshot_network_edge", edge_rows, conn)
   191	  }
   192	
   193	  invisible(list(nodes = nrow(nodes), edges = nrow(edges)))
   194	}
   195	
   196	analysis_snapshot_insert_cluster_rows <- function(snapshot_id, clusters, members, conn = NULL) {
   197	  clusters <- tibble::as_tibble(clusters %||% tibble::tibble())
   198	  members <- tibble::as_tibble(members %||% tibble::tibble())
   199	
   200	  if (nrow(clusters) > 0L) {
   201	    cluster_rows <- data.frame(
   202	      snapshot_id = rep(snapshot_id, nrow(clusters)),
   203	      cluster_kind = as.character(clusters$cluster_kind),
   204	      cluster_id = as.character(clusters$cluster_id),
   205	      cluster_hash = as.character(clusters$cluster_hash),
   206	      cluster_size = suppressWarnings(as.integer(clusters$cluster_size)),
   207	      label = as.character(clusters$label),
   208	      metadata_json = as.character(clusters$metadata_json),
   209	      stringsAsFactors = FALSE
   210	    )
   211	    analysis_snapshot_append_rows("analysis_snapshot_cluster", cluster_rows, conn)
   212	  }
   213	
   214	  if (nrow(members) > 0L) {
   215	    member_rows <- data.frame(
   216	      snapshot_id = rep(snapshot_id, nrow(members)),
   217	      cluster_kind = as.character(members$cluster_kind),
   218	      cluster_id = as.character(members$cluster_id),
   219	      member_rank = suppressWarnings(as.integer(members$member_rank)),
   220	      entity_id = suppressWarnings(as.integer(members$entity_id)),
   221	      hgnc_id = as.character(members$hgnc_id),
   222	      symbol = as.character(members$symbol),
   223	      stringsAsFactors = FALSE
   224	    )
   225	    analysis_snapshot_append_rows("analysis_snapshot_cluster_member", member_rows, conn)
   226	  }
   227	
   228	  invisible(list(clusters = nrow(clusters), members = nrow(members)))
   229	}
   230	
   231	analysis_snapshot_insert_correlation_rows <- function(snapshot_id, correlations, conn = NULL) {
   232	  correlations <- tibble::as_tibble(correlations %||% tibble::tibble())
   233	  if (nrow(correlations) == 0L) {
   234	    return(invisible(0L))
   235	  }
   236	
   237	  correlation_rows <- data.frame(
   238	    snapshot_id = rep(snapshot_id, nrow(correlations)),
   239	    row_rank = suppressWarnings(as.integer(correlations$row_rank)),
   240	    correlation_kind = as.character(correlations$correlation_kind),
   241	    x_key = as.character(correlations$x_key),
   242	    y_key = as.character(correlations$y_key),
   243	    value = suppressWarnings(as.numeric(correlations$value)),
   244	    abs_value = suppressWarnings(as.numeric(correlations$abs_value)),
   245	    metadata_json = as.character(correlations$metadata_json),
   246	    stringsAsFactors = FALSE
   247	  )
   248	  analysis_snapshot_append_rows("analysis_snapshot_correlation", correlation_rows, conn)
   249	
   250	  invisible(nrow(correlations))
   251	}
   252	
   253	analysis_snapshot_activate <- function(snapshot_id,
   254	                                       analysis_type,
   255	                                       parameter_hash,
   256	                                       conn = NULL,
   257	                                       use_transaction = TRUE) {
   258	  tx <- function(txn_conn) {
   259	    db_execute_statement(
   260	      "UPDATE analysis_snapshot_manifest
   261	          SET public_ready = 0,
   262	              status = 'superseded',
   263	              superseded_at = NOW(6)
   264	        WHERE analysis_type = ?
   265	          AND parameter_hash = ?
   266	          AND public_ready = 1
   267	          AND snapshot_id <> ?",
   268	      unname(list(analysis_type, parameter_hash, snapshot_id)),
   269	      conn = txn_conn
   270	    )
   271	
   272	    affected <- db_execute_statement(
   273	      "UPDATE analysis_snapshot_manifest
   274	          SET public_ready = 1,
   275	              status = 'public_ready',
   276	              activated_at = NOW(6),
   277	              last_error_message = NULL
   278	        WHERE snapshot_id = ?
   279	          AND analysis_type = ?
   280	          AND parameter_hash = ?",
   281	      unname(list(snapshot_id, analysis_type, parameter_hash)),
   282	      conn = txn_conn
   283	    )
   284	
   285	    if (affected != 1L) {
   286	      stop("Analysis snapshot activation target was not found", call. = FALSE)
   287	    }
   288	
   289	    invisible(snapshot_id)
   290	  }
   291	
   292	  if (!isTRUE(use_transaction)) {
   293	    return(tx(conn))
   294	  }
   295	
   296	  if (exists("db_with_transaction", mode = "function")) {
   297	    return(db_with_transaction(function(txn_conn) {
   298	      tx(txn_conn)
   299	    }, pool_obj = conn))
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
   181	    combined_score = suppressWarnings(as.numeric(el$combined_score)),
   182	    stringsAsFactors = FALSE
   183	  )
   184	  if (!is.null(el$exp_db_score)) {
   185	    edges$exp_db_score <- suppressWarnings(as.numeric(el$exp_db_score))
   186	  }
   187	
   188	  membership <- data.frame(
   189	    node = as.character(igraph::V(lcc)$name),
   190	    cluster = as.integer(membership_int),
   191	    stringsAsFactors = FALSE
   192	  )
   193	
   194	  partition <- val$partition %||% list()
   195	  bundle_params <- utils::modifyList(
   196	    list(
   197	      score_threshold = score_threshold,
   198	      resolution = resolution,
   199	      seed = seed,
   200	      weight_channel = partition$weight_channel %||% "combined_score",
   201	      modularity_full_partition = analysis_reproducibility_scalar_num(partition$modularity),
   202	      modularity_z = analysis_reproducibility_scalar_num(partition$modularity_z),
   203	      n_clusters = partition$n_clusters %||% NA_integer_,
   204	      giant_component = partition$giant_component %||% NULL
   205	    ),
   206	    params %||% list()
   207	  )
   208	
   209	  list(
   210	    edges = edges,
   211	    membership = membership,
   212	    served_modularity = served_modularity,
   213	    params = bundle_params
   214	  )
   215	}
   216	
   217	#' Flatten the served phenotype cluster tibble to an (entity_id, cluster) frame.
   218	#' @noRd
   219	analysis_reproducibility_phenotype_membership <- function(clusters) {
   220	  clusters <- tibble::as_tibble(clusters %||% tibble::tibble())

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-repository.R | sed -n '1,110p;305,470p;570,690p'; nl -ba api/functions/analysis-snapshot-coherence.R | sed -n '1,240p'; nl -ba api/functions/analysis-snapshot-dependencies.R | sed -n '150,250p'; nl -ba api/functions/analysis-reproducibility.R | sed -n '440,500p'; rg -n \"analysis_snapshot_acquire_lock|analysis_snapshot_release_lock|analysis_snapshot_activate|analysis_snapshot_lock\" api/functions/async-job-analysis-snapshot-handlers.R api -g '*.R' | head -100" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
     1	# functions/analysis-snapshot-repository.R
     2	
     3	if (!exists("%||%", mode = "function")) {
     4	  `%||%` <- function(x, y) if (is.null(x)) y else x
     5	}
     6	
     7	analysis_snapshot_lock_name <- function(analysis_type, parameter_hash) {
     8	  # MySQL GET_LOCK() names must be <= 64 characters (errno 4163 otherwise). The
     9	  # previous "analysis_snapshot_refresh:<type>:<sha256>" form was 109-124 chars,
    10	  # so GET_LOCK always failed and the refresh job aborted before writing a
    11	  # snapshot -> permanent `snapshot_missing` on every public analysis endpoint.
    12	  # parameter_hash is a 64-char SHA-256 that already encodes (analysis_type,
    13	  # params) (see analysis_snapshot_parameter_hash), so a short prefix + a
    14	  # truncated hash stays unique per preset while fitting the limit. analysis_type
    15	  # is intentionally not inlined — the long preset names overflow the cap.
    16	  paste0("asr:", substr(as.character(parameter_hash[[1]]), 1, 56))
    17	}
    18	
    19	analysis_snapshot_acquire_lock <- function(analysis_type,
    20	                                           parameter_hash,
    21	                                           timeout_seconds = 30L,
    22	                                           conn = NULL) {
    23	  lock_name <- analysis_snapshot_lock_name(analysis_type, parameter_hash)
    24	  result <- db_execute_query(
    25	    "SELECT GET_LOCK(?, ?) AS acquired",
    26	    unname(list(lock_name, as.integer(timeout_seconds))),
    27	    conn = conn
    28	  )
    29	
    30	  isTRUE(as.integer(result$acquired[[1]]) == 1L)
    31	}
    32	
    33	analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
    34	  lock_name <- analysis_snapshot_lock_name(analysis_type, parameter_hash)
    35	  result <- db_execute_query(
    36	    "SELECT RELEASE_LOCK(?) AS released",
    37	    unname(list(lock_name)),
    38	    conn = conn
    39	  )
    40	
    41	  invisible(isTRUE(as.integer(result$released[[1]]) == 1L))
    42	}
    43	
    44	analysis_snapshot_json <- function(value) {
    45	  if (is.null(value)) {
    46	    return(NA_character_)
    47	  }
    48	
    49	  as.character(jsonlite::toJSON(
    50	    value,
    51	    auto_unbox = TRUE,
    52	    null = "null",
    53	    na = "null",
    54	    dataframe = "rows",
    55	    POSIXt = "ISO8601",
    56	    Date = "ISO8601"
    57	  ))
    58	}
    59	
    60	analysis_snapshot_scalar <- function(value, default = NA) {
    61	  if (is.null(value) || length(value) == 0L) {
    62	    return(default)
    63	  }
    64	
    65	  value[[1]]
    66	}
    67	
    68	analysis_snapshot_with_repository_connection <- function(conn = NULL, code) {
    69	  if (!is.null(conn) && inherits(conn, "Pool")) {
    70	    checked_out <- pool::poolCheckout(conn)
    71	    on.exit(pool::poolReturn(checked_out), add = TRUE)
    72	    return(code(checked_out))
    73	  }
    74	
    75	  if (!is.null(conn)) {
    76	    return(code(conn))
    77	  }
    78	
    79	  db_connection <- get_db_connection()
    80	  if (inherits(db_connection, "Pool")) {
    81	    checked_out <- pool::poolCheckout(db_connection)
    82	    on.exit(pool::poolReturn(checked_out), add = TRUE)
    83	    return(code(checked_out))
    84	  }
    85	
    86	  if (inherits(db_connection, "DBIConnection")) {
    87	    is_daemon_conn <- base::exists("daemon_db_conn", envir = .GlobalEnv) &&
    88	      identical(db_connection, base::get("daemon_db_conn", envir = .GlobalEnv))
    89	    if (!is_daemon_conn) {
    90	      on.exit(DBI::dbDisconnect(db_connection), add = TRUE)
    91	    }
    92	  }
    93	
    94	  code(db_connection)
    95	}
    96	
    97	analysis_snapshot_append_rows <- function(table_name, rows, conn) {
    98	  rows <- as.data.frame(rows, stringsAsFactors = FALSE)
    99	  if (nrow(rows) == 0L) {
   100	    return(invisible(0L))
   101	  }
   102	  DBI::dbAppendTable(conn, table_name, rows)
   103	  invisible(nrow(rows))
   104	}
   105	
   106	analysis_snapshot_create_manifest <- function(manifest, conn = NULL) {
   107	  generated_at <- analysis_snapshot_scalar(manifest$generated_at, NA)
   108	  stale_after <- analysis_snapshot_scalar(manifest$stale_after, NA)
   109	
   110	  analysis_snapshot_with_repository_connection(conn, function(manifest_conn) {
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
   431	  "available"
   432	}
   433	
   434	#' Cheap existence probe for an active public-ready snapshot.
   435	#'
   436	#' Mirrors the public-ready predicate of `analysis_snapshot_get_public()` but
   437	#' fetches no child-table rows — used by the startup bootstrap and admin refresh
   438	#' to decide whether a preset still needs a refresh job.
   439	#'
   440	#' @return TRUE when a `public_ready = 1, status = 'public_ready'` manifest row
   441	#'   exists for the (analysis_type, parameter_hash); FALSE otherwise.
   442	#' @export
   443	analysis_snapshot_public_exists <- function(analysis_type, parameter_hash, conn = NULL) {
   444	  row <- db_execute_query(
   445	    "SELECT snapshot_id
   446	       FROM analysis_snapshot_manifest
   447	      WHERE analysis_type = ?
   448	        AND parameter_hash = ?
   449	        AND public_ready = 1
   450	        AND status = 'public_ready'
   451	      LIMIT 1",
   452	    unname(list(analysis_type, parameter_hash)),
   453	    conn = conn
   454	  )
   455	  nrow(row) > 0L
   456	}
   457	
   458	#' Metadata-only read of the active public-ready manifest row.
   459	#'
   460	#' Like `analysis_snapshot_get_public()` but returns just the single manifest row
   461	#' annotated with the computed `status_code` (no network/cluster/correlation
   462	#' child queries). Used by the admin status endpoint to report per-preset state.
   463	#'
   464	#' @return A 1-row data frame with an added `status_code` column, or NULL when no
   465	#'   public-ready row exists.
   466	#' @export
   467	analysis_snapshot_public_manifest <- function(analysis_type,
   468	                                              parameter_hash,
   469	                                              conn = NULL,
   470	                                              current_source_data_version = NULL) {
   570	  candidates <- db_execute_query(
   571	    "SELECT snapshot_id
   572	       FROM analysis_snapshot_manifest
   573	      WHERE analysis_type = ?
   574	        AND parameter_hash = ?
   575	        AND status = 'superseded'
   576	        AND COALESCE(superseded_at, updated_at, created_at) < ?",
   577	    unname(list(analysis_type, parameter_hash, cutoff)),
   578	    conn = conn
   579	  )
   580	
   581	  # Never prune a snapshot a release (#573) still references (its LIVE
   582	  # reproducibility endpoint would 503). analysis_release_referenced_snapshot_ids()
   583	  # is the single source of truth for this -- do not inline a NOT IN subquery.
   584	  referenced_ids <- as.numeric(analysis_release_referenced_snapshot_ids(conn = conn))
   585	
   586	  delete_ids <- setdiff(as.numeric(candidates$snapshot_id %||% numeric()), union(keep_ids, referenced_ids))
   587	  if (length(delete_ids) == 0L) {
   588	    return(invisible(0L))
   589	  }
   590	
   591	  placeholders <- paste(rep("?", length(delete_ids)), collapse = ", ")
   592	  db_execute_statement(
   593	    paste0("DELETE FROM analysis_snapshot_manifest WHERE snapshot_id IN (", placeholders, ")"),
   594	    unname(as.list(delete_ids)),
   595	    conn = conn
   596	  )
   597	}
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
   150	      "SELECT snapshot_id, payload_hash",
   151	      "FROM analysis_snapshot_manifest",
   152	      "WHERE analysis_type = ?",
   153	      "AND parameter_hash = ?",
   154	      "AND public_ready = 1",
   155	      "AND status = 'public_ready'",
   156	      "ORDER BY activated_at DESC, snapshot_id DESC",
   157	      "LIMIT 1"
   158	    ),
   159	    unname(list(normalized$analysis_type, normalized$parameter_hash)),
   160	    conn = conn
   161	  )
   162	}
   163	
   164	#' Read dependency lineage from a correlation manifest's source-version record.
   165	#' @noRd
   166	analysis_snapshot_manifest_dependencies <- function(manifest) {
   167	  manifest <- tibble::as_tibble(manifest %||% tibble::tibble())
   168	  if (nrow(manifest) != 1L || !("source_versions_json" %in% names(manifest))) {
   169	    return(NULL)
   170	  }
   171	  raw <- as.character(manifest$source_versions_json[[1]] %||% "")
   172	  if (!nzchar(raw)) {
   173	    return(NULL)
   174	  }
   175	  parsed <- tryCatch(
   176	    jsonlite::fromJSON(raw, simplifyVector = FALSE),
   177	    error = function(e) NULL
   178	  )
   179	  dependencies <- parsed$dependencies %||% NULL
   180	  if (!is.list(dependencies)) {
   181	    return(NULL)
   182	  }
   183	  dependencies
   184	}
   185	
   186	#' Verify that a phenotype-functional snapshot still matches active cluster axes.
   187	#'
   188	#' @noRd
   189	analysis_snapshot_dependency_status_code <- function(
   190	    manifest,
   191	    active_manifest_loader = analysis_snapshot_active_cluster_manifest,
   192	    conn = NULL) {
   193	  manifest <- tibble::as_tibble(manifest %||% tibble::tibble())
   194	  if (nrow(manifest) != 1L ||
   195	      !identical(as.character(manifest$analysis_type[[1]] %||% ""), "phenotype_functional_correlations")) {
   196	    return("available")
   197	  }
   198	
   199	  dependencies <- analysis_snapshot_manifest_dependencies(manifest)
   200	  expected <- list(
   201	    functional_clusters = list(algorithm = "leiden"),
   202	    phenotype_clusters = list()
   203	  )
   204	  if (is.null(dependencies) || !identical(sort(names(dependencies)), sort(names(expected)))) {
   205	    return("dependency_snapshot_mismatch")
   206	  }
   207	
   208	  for (analysis_type in names(expected)) {
   209	    dependency <- dependencies[[analysis_type]]
   210	    if (!is.list(dependency)) {
   211	      return("dependency_snapshot_mismatch")
   212	    }
   213	    expected_id <- suppressWarnings(as.integer(dependency$snapshot_id %||% NA_integer_))
   214	    expected_hash <- as.character(dependency$payload_hash %||% "")
   215	    active <- tibble::as_tibble(
   216	      active_manifest_loader(analysis_type, expected[[analysis_type]], conn = conn) %||% tibble::tibble()
   217	    )
   218	    if (nrow(active) != 1L || !all(c("snapshot_id", "payload_hash") %in% names(active))) {
   219	      return("dependency_snapshot_mismatch")
   220	    }
   221	    active_id <- suppressWarnings(as.integer(active$snapshot_id[[1]]))
   222	    active_hash <- as.character(active$payload_hash[[1]])
   223	    if (is.na(expected_id) || !nzchar(expected_hash) ||
   224	        is.na(active_id) || !nzchar(active_hash) ||
   225	        !identical(expected_id, active_id) || !identical(expected_hash, active_hash)) {
   226	      return("dependency_snapshot_mismatch")
   227	    }
   228	  }
   229	
   230	  "available"
   231	}
   440	       VALUES (?, ?, ?, ?, ?)"
   441	    )
   442	    on.exit(DBI::dbClearResult(stmt), add = TRUE)
   443	    DBI::dbBind(stmt, unname(list(
   444	      as.numeric(snapshot_id),
   445	      as.character(bundle$kind %||% NA_character_),
   446	      list(gz), # bind the raw gzip vector as a single BLOB value
   447	      as.character(bundle$reproducibility_hash %||% NA_character_),
   448	      as.integer(bundle$byte_size %||% length(gz))
   449	    )))
   450	    DBI::dbGetRowsAffected(stmt)
   451	  })
   452	
   453	  invisible(1L)
   454	}
   455	
   456	#' Fetch the reproducibility row for a snapshot (raw blob + metadata).
   457	#'
   458	#' @return A 1-row data frame (kind, bundle_gzip_json blob, reproducibility_hash,
   459	#'   byte_size, created_at) or NULL when the snapshot has no bundle.
   460	#' @export
   461	analysis_snapshot_get_reproducibility <- function(snapshot_id, conn = NULL) {
   462	  rows <- db_execute_query(
   463	    "SELECT kind, bundle_gzip_json, reproducibility_hash, byte_size, created_at
   464	       FROM analysis_snapshot_reproducibility
   465	      WHERE snapshot_id = ?
   466	      LIMIT 1",
   467	    unname(list(as.numeric(snapshot_id))),
   468	    conn = conn
   469	  )
   470	  if (is.null(rows) || nrow(rows) == 0L) {
   471	    return(NULL)
   472	  }
   473	  rows
   474	}
api/functions/analysis-snapshot-release.R:46:# `analysis_snapshot_lock_name(analysis_type, parameter_hash)` — so a mid-flight
api/functions/analysis-snapshot-release.R:57:  if (exists("analysis_snapshot_lock_name", mode = "function")) {
api/functions/analysis-snapshot-release.R:58:    return(analysis_snapshot_lock_name(analysis_type, parameter_hash))
api/functions/analysis-snapshot-release.R:61:  # defines analysis_snapshot_lock_name() is not sourced.
api/functions/analysis-snapshot-builder.R:476:    lock_acquired <- analysis_snapshot_acquire_lock(
api/functions/analysis-snapshot-builder.R:486:        analysis_snapshot_release_lock(normalized$analysis_type, normalized$parameter_hash, conn = refresh_conn),
api/functions/analysis-snapshot-builder.R:567:      analysis_snapshot_activate(
api/functions/analysis-snapshot-repository.R:7:analysis_snapshot_lock_name <- function(analysis_type, parameter_hash) {
api/functions/analysis-snapshot-repository.R:19:analysis_snapshot_acquire_lock <- function(analysis_type,
api/functions/analysis-snapshot-repository.R:23:  lock_name <- analysis_snapshot_lock_name(analysis_type, parameter_hash)
api/functions/analysis-snapshot-repository.R:33:analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
api/functions/analysis-snapshot-repository.R:34:  lock_name <- analysis_snapshot_lock_name(analysis_type, parameter_hash)
api/functions/analysis-snapshot-repository.R:253:analysis_snapshot_activate <- function(snapshot_id,
api/tests/testthat/test-unit-analysis-snapshot-repository.R:9:  expect_true(exists("analysis_snapshot_lock_name", mode = "function"))
api/tests/testthat/test-unit-analysis-snapshot-repository.R:12:  expect_true(exists("analysis_snapshot_activate", mode = "function"))
api/tests/testthat/test-unit-analysis-snapshot-repository.R:24:  net_lock <- analysis_snapshot_lock_name(net$analysis_type, net$parameter_hash)
api/tests/testthat/test-unit-analysis-snapshot-repository.R:35:    analysis_snapshot_lock_name(p$analysis_type, h)
api/tests/testthat/test-unit-analysis-snapshot-repository.R:334:  result <- env$analysis_snapshot_activate(
api/tests/testthat/test-unit-analysis-snapshot-builder.R:119:  env$analysis_snapshot_acquire_lock <- function(analysis_type, parameter_hash, timeout_seconds = 30L, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R:123:  env$analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R:152:  env$analysis_snapshot_activate <- function(snapshot_id, analysis_type, parameter_hash, conn = NULL, ...) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R:228:  env$analysis_snapshot_acquire_lock <- function(analysis_type, parameter_hash, timeout_seconds = 30L, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R:232:  env$analysis_snapshot_release_lock <- function(analysis_type, parameter_hash, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R:256:  env$analysis_snapshot_activate <- function(snapshot_id, analysis_type, parameter_hash, conn = NULL, ...) {
api/tests/testthat/test-unit-analysis-snapshot-builder.R:301:  env$analysis_snapshot_acquire_lock <- function(...) TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R:302:  env$analysis_snapshot_release_lock <- function(...) TRUE
api/tests/testthat/test-unit-analysis-snapshot-builder.R:315:  env$analysis_snapshot_activate <- function(...) NULL

codex
The main route and repository paths are parameterized and published-only. I’m now checking adversarial state changes between build steps (including malformed/corrupt snapshot artifacts), where happy-path integration tests often miss invariant breaks.
exec
/bin/bash -lc "rg -n -C 4 \"analysis_snapshot_reproducibility|CREATE TABLE.*analysis_snapshot_reproducibility|reproducibility_hash\" db/migrations api/functions api/tests/testthat/test-integration-analysis-snapshot-release-build.R api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R && nl -ba api/functions/analysis-snapshot-builder.R | sed -n '430,600p' && nl -ba api/tests/testthat/test-integration-analysis-snapshot-release-build.R | sed -n '1,520p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-63-})
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-64-
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-65-test_that("content_digest and release_id are pure functions of scientific content", {
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-66-  entries <- list(
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:67:    list(analysis_type = "functional_clusters", input_hash = "a", payload_hash = "b", reproducibility_hash = "c", dependencies = NULL),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:68:    list(analysis_type = "phenotype_clusters", input_hash = "d", payload_hash = "e", reproducibility_hash = "f", dependencies = NULL)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-69-  )
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-70-  d1 <- analysis_release_content_digest(entries, "srcv1", "1.0")
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-71-  d2 <- analysis_release_content_digest(rev(entries), "srcv1", "1.0") # order-independent (sorted internally)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-72-  expect_identical(d1, d2)
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-161-  if (is.null(b)) {
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-162-    return(NULL)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-163-  }
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-164-  row <- data.frame(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:165:    kind = b$kind, reproducibility_hash = b$reproducibility_hash,
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-166-    byte_size = b$byte_size, stringsAsFactors = FALSE
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-167-  )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-168-  row$bundle_gzip_json <- list(b$bundle_gzip_json) # DBI blob column shape: list-of-raw
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-169-  row
--
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-377-    release_id <- result$release$release_id
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-378-    expect_match(release_id, "^asr_[0-9a-f]{16}$")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-379-    expect_equal(result$release$status, "published")
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-380-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:381:    # reproducibility.json hashes EXACTLY to the stored reproducibility_hash
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-382-    # (materialized from the raw pre-gzip bytes, not a parse round-trip).
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-383-    rf <- analysis_release_get_file(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-384-      release_id, "functional_clusters/reproducibility.json",
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-385-      include_draft = TRUE, conn = conn
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-386-    )
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-387-    expect_false(is.null(rf))
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:388:    expect_identical(rf$content_sha256, FUNC_BUNDLE$reproducibility_hash)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-389-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-390-    # manifest per-layer payload_hash is the cross-checkable LINEAGE ANCHOR
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-391-    # (== the source snapshot's payload_hash), NOT the payload.json file hash.
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-392-    manifest_file <- analysis_release_get_file(release_id, "manifest.json", include_draft = TRUE, conn = conn)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-393-    manifest <- jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-394-    fc <- Filter(function(l) identical(l$analysis_type, "functional_clusters"), manifest$layers)[[1]]
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-395-    expect_identical(fc$payload_hash, FUNC_HASH)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R:396:    expect_identical(fc$reproducibility_hash, FUNC_BUNDLE$reproducibility_hash)
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-397-
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-398-    payload_file <- analysis_release_get_file(
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-399-      release_id, "functional_clusters/payload.json",
api/tests/testthat/test-integration-analysis-snapshot-release-build.R-400-      include_draft = TRUE, conn = conn
--
api/functions/analysis-snapshot-release.R-229-      source_data_version = as.character(
api/functions/analysis-snapshot-release.R-230-        .analysis_release_manifest_scalar(manifest, "source_data_version", NA_character_)
api/functions/analysis-snapshot-release.R-231-      ),
api/functions/analysis-snapshot-release.R-232-      parameter_hash = parameter_hash,
api/functions/analysis-snapshot-release.R:233:      reproducibility_hash = NULL,
api/functions/analysis-snapshot-release.R-234-      dependencies = NULL,
api/functions/analysis-snapshot-release.R-235-      reproducibility_bundle = NULL
api/functions/analysis-snapshot-release.R-236-    )
api/functions/analysis-snapshot-release.R-237-
--
api/functions/analysis-snapshot-release.R-258-          sprintf("layer %s has no reproducibility bundle; the release requires one", at),
api/functions/analysis-snapshot-release.R-259-          analysis_type = at
api/functions/analysis-snapshot-release.R-260-        ))
api/functions/analysis-snapshot-release.R-261-      }
api/functions/analysis-snapshot-release.R:262:      entry$reproducibility_hash <- repro_hash
api/functions/analysis-snapshot-release.R-263-      entry$reproducibility_bundle <- repro$bundle_gzip_json
api/functions/analysis-snapshot-release.R-264-    }
api/functions/analysis-snapshot-release.R-265-
api/functions/analysis-snapshot-release.R-266-    loaded[[at]] <- entry
--
api/functions/analysis-snapshot-release.R-306-      snapshot_id = entry$snapshot_id,
api/functions/analysis-snapshot-release.R-307-      input_hash = entry$input_hash,
api/functions/analysis-snapshot-release.R-308-      payload_hash = entry$payload_hash,
api/functions/analysis-snapshot-release.R-309-      schema_version = entry$schema_version,
api/functions/analysis-snapshot-release.R:310:      reproducibility_hash = entry$reproducibility_hash,
api/functions/analysis-snapshot-release.R-311-      dependencies = entry$dependencies
api/functions/analysis-snapshot-release.R-312-    )
api/functions/analysis-snapshot-release.R-313-  }
api/functions/analysis-snapshot-release.R-314-
--
api/functions/analysis-snapshot-release.R-418-      snapshot_id = e$snapshot_id,
api/functions/analysis-snapshot-release.R-419-      input_hash = e$input_hash,
api/functions/analysis-snapshot-release.R-420-      payload_hash = e$payload_hash,
api/functions/analysis-snapshot-release.R-421-      schema_version = e$schema_version,
api/functions/analysis-snapshot-release.R:422:      reproducibility_hash = e$reproducibility_hash,
api/functions/analysis-snapshot-release.R-423-      role = "layer"
api/functions/analysis-snapshot-release.R-424-    )
api/functions/analysis-snapshot-release.R-425-  })
api/functions/analysis-snapshot-release.R-426-
--
db/migrations/041_add_analysis_reproducibility.sql-3---   gzipped canonical JSON of the inputs needed to INDEPENDENTLY recompute the
db/migrations/041_add_analysis_reproducibility.sql-4---   served separation metric (functional modularity / phenotype silhouette):
db/migrations/041_add_analysis_reproducibility.sql-5---   the full LCC edge list + complete membership (functional) or the MCA
db/migrations/041_add_analysis_reproducibility.sql-6---   coordinate matrix + membership (phenotype), plus params, the served metric,
db/migrations/041_add_analysis_reproducibility.sql:7:--   and a SHA-256 reproducibility_hash over the canonical pre-gzip JSON.
db/migrations/041_add_analysis_reproducibility.sql-8---
db/migrations/041_add_analysis_reproducibility.sql-9--- One row per clustering snapshot (UNIQUE on snapshot_id). Cascades on delete of
db/migrations/041_add_analysis_reproducibility.sql-10--- the parent manifest row. `snapshot_id` is BIGINT to match
db/migrations/041_add_analysis_reproducibility.sql-11--- `analysis_snapshot_manifest.snapshot_id` (an INT reference would fail with
db/migrations/041_add_analysis_reproducibility.sql-12--- errno 1215 "Cannot add foreign key constraint").
db/migrations/041_add_analysis_reproducibility.sql-13-
db/migrations/041_add_analysis_reproducibility.sql:14:CREATE TABLE IF NOT EXISTS `analysis_snapshot_reproducibility` (
db/migrations/041_add_analysis_reproducibility.sql-15-  `reproducibility_id`   INT NOT NULL AUTO_INCREMENT,
db/migrations/041_add_analysis_reproducibility.sql-16-  `snapshot_id`          BIGINT NOT NULL,
db/migrations/041_add_analysis_reproducibility.sql-17-  `kind`                 VARCHAR(32) NOT NULL,
db/migrations/041_add_analysis_reproducibility.sql-18-  `bundle_gzip_json`     LONGBLOB NOT NULL,
db/migrations/041_add_analysis_reproducibility.sql:19:  `reproducibility_hash` CHAR(64) NOT NULL,
db/migrations/041_add_analysis_reproducibility.sql-20-  `byte_size`            INT NOT NULL,
db/migrations/041_add_analysis_reproducibility.sql-21-  `created_at`           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
db/migrations/041_add_analysis_reproducibility.sql-22-  PRIMARY KEY (`reproducibility_id`),
db/migrations/041_add_analysis_reproducibility.sql-23-  UNIQUE KEY `uq_repro_snapshot` (`snapshot_id`),
db/migrations/041_add_analysis_reproducibility.sql:24:  KEY `idx_repro_hash` (`reproducibility_hash`),
db/migrations/041_add_analysis_reproducibility.sql-25-  CONSTRAINT `fk_repro_snapshot`
db/migrations/041_add_analysis_reproducibility.sql-26-    FOREIGN KEY (`snapshot_id`) REFERENCES `analysis_snapshot_manifest` (`snapshot_id`)
db/migrations/041_add_analysis_reproducibility.sql-27-    ON DELETE CASCADE
db/migrations/041_add_analysis_reproducibility.sql-28-) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
--
db/migrations/045_add_analysis_snapshot_release.sql-46-  `snapshot_id` BIGINT NOT NULL,
db/migrations/045_add_analysis_snapshot_release.sql-47-  `input_hash` CHAR(64) NOT NULL,
db/migrations/045_add_analysis_snapshot_release.sql-48-  `payload_hash` CHAR(64) NOT NULL,
db/migrations/045_add_analysis_snapshot_release.sql-49-  `schema_version` VARCHAR(16) NOT NULL,
db/migrations/045_add_analysis_snapshot_release.sql:50:  `reproducibility_hash` CHAR(64) DEFAULT NULL,
db/migrations/045_add_analysis_snapshot_release.sql-51-  `role` ENUM('layer','dependency') NOT NULL DEFAULT 'layer',
db/migrations/045_add_analysis_snapshot_release.sql-52-  PRIMARY KEY (`release_id`, `analysis_type`, `parameter_hash`),
db/migrations/045_add_analysis_snapshot_release.sql-53-  KEY `idx_asrm_snapshot` (`snapshot_id`),
db/migrations/045_add_analysis_snapshot_release.sql-54-  CONSTRAINT `fk_asrm_release`
--
api/functions/analysis-snapshot-release-manifest.R-81-#' sorted by `analysis_type` before hashing so caller-supplied ordering never
api/functions/analysis-snapshot-release-manifest.R-82-#' changes the digest.
api/functions/analysis-snapshot-release-manifest.R-83-#'
api/functions/analysis-snapshot-release-manifest.R-84-#' @param layer_entries list of list(analysis_type, input_hash, payload_hash,
api/functions/analysis-snapshot-release-manifest.R:85:#'   reproducibility_hash, dependencies).
api/functions/analysis-snapshot-release-manifest.R-86-#' @param source_data_version chr.
api/functions/analysis-snapshot-release-manifest.R-87-#' @param manifest_schema_version chr.
api/functions/analysis-snapshot-release-manifest.R-88-#' @return chr, a 64-character lowercase hex sha256 digest.
api/functions/analysis-snapshot-release-manifest.R-89-analysis_release_content_digest <- function(layer_entries, source_data_version, manifest_schema_version) {
api/functions/analysis-snapshot-release-manifest.R-90-  analysis_types <- vapply(layer_entries, function(entry) entry$analysis_type, character(1))
api/functions/analysis-snapshot-release-manifest.R-91-  sorted_entries <- layer_entries[order(analysis_types)]
api/functions/analysis-snapshot-release-manifest.R-92-
api/functions/analysis-snapshot-release-manifest.R-93-  identity_layers <- lapply(sorted_entries, function(entry) {
api/functions/analysis-snapshot-release-manifest.R:94:    entry[c("analysis_type", "input_hash", "payload_hash", "reproducibility_hash", "dependencies")]
api/functions/analysis-snapshot-release-manifest.R-95-  })
api/functions/analysis-snapshot-release-manifest.R-96-
api/functions/analysis-snapshot-release-manifest.R-97-  identity_obj <- list(
api/functions/analysis-snapshot-release-manifest.R-98-    manifest_schema_version = manifest_schema_version,
--
api/functions/analysis-reproducibility.R-11-#     (every community, incl. clusters below min_size) + params + served_modularity
api/functions/analysis-reproducibility.R-12-#   - phenotype:  the MCA coordinate matrix (entity_id, Dim.1..Dim.k) + membership
api/functions/analysis-reproducibility.R-13-#     (entity_id, cluster) + params (ncp, kk, consol, seed, prevalence band) +
api/functions/analysis-reproducibility.R-14-#     served_silhouette
api/functions/analysis-reproducibility.R:15:# plus a SHA-256 `reproducibility_hash` over the CANONICAL pre-gzip JSON so the
api/functions/analysis-reproducibility.R-16-# served validation numbers are verifiably tied to their inputs.
api/functions/analysis-reproducibility.R-17-#
api/functions/analysis-reproducibility.R-18-# The bundle serializer (`analysis_reproducibility_bundle`) is representation-
api/functions/analysis-reproducibility.R-19-# agnostic: it serializes whatever payload it is given, gzips it, and hashes the
--
api/functions/analysis-reproducibility.R-69-#' - `kind = "phenotype"`: `payload$coords` (entity_id/Dim.*),
api/functions/analysis-reproducibility.R-70-#'   `payload$membership` (entity_id/cluster), `payload$params`,
api/functions/analysis-reproducibility.R-71-#'   `payload$served_silhouette`.
api/functions/analysis-reproducibility.R-72-#'
api/functions/analysis-reproducibility.R:73:#' @return list(kind, bundle_gzip_json = <raw gzip>, reproducibility_hash =
api/functions/analysis-reproducibility.R-74-#'   <64-char sha256 over the pre-gzip canonical JSON>, byte_size = <length of
api/functions/analysis-reproducibility.R-75-#'   the gzip blob>).
api/functions/analysis-reproducibility.R-76-#' @export
api/functions/analysis-reproducibility.R-77-analysis_reproducibility_bundle <- function(kind, payload) {
--
api/functions/analysis-reproducibility.R-104-  gz <- memCompress(charToRaw(json), type = "gzip")
api/functions/analysis-reproducibility.R-105-  list(
api/functions/analysis-reproducibility.R-106-    kind = kind,
api/functions/analysis-reproducibility.R-107-    bundle_gzip_json = gz,
api/functions/analysis-reproducibility.R:108:    reproducibility_hash = digest::digest(json, algo = "sha256", serialize = FALSE),
api/functions/analysis-reproducibility.R-109-    byte_size = length(gz)
api/functions/analysis-reproducibility.R-110-  )
api/functions/analysis-reproducibility.R-111-}
api/functions/analysis-reproducibility.R-112-
--
api/functions/analysis-reproducibility.R-129-#' Decode a stored bundle blob back to its RAW pre-gzip canonical-JSON string.
api/functions/analysis-reproducibility.R-130-#'
api/functions/analysis-reproducibility.R-131-#' Identical blob-unwrap to `analysis_reproducibility_decode()`, but returns the
api/functions/analysis-reproducibility.R-132-#' verbatim `memDecompress(..., asChar = TRUE)` string WITHOUT parsing. This is
api/functions/analysis-reproducibility.R:133:#' the exact byte content the `reproducibility_hash` was computed over
api/functions/analysis-reproducibility.R-134-#' (`digest::digest(json, algo = "sha256", serialize = FALSE)`), so
api/functions/analysis-reproducibility.R:135:#' `sha256(charToRaw(<this>)) == reproducibility_hash` bit-for-bit. The immutable
api/functions/analysis-reproducibility.R-136-#' release (#573) materializes `reproducibility.json` from THIS string, never from
api/functions/analysis-reproducibility.R-137-#' `analysis_reproducibility_decode()` — a parse + re-serialize round-trip drops
api/functions/analysis-reproducibility.R-138-#' the `digits = NA` precision and would break the content-address hash.
api/functions/analysis-reproducibility.R-139-#'
--
api/functions/analysis-reproducibility.R-338-#' preset, fetches its reproducibility row, and returns the decoded bundle. Sets
api/functions/analysis-reproducibility.R-339-#' `res$status` on the miss paths. DB-only — never computes clusters/nulls.
api/functions/analysis-reproducibility.R-340-#'
api/functions/analysis-reproducibility.R-341-#' @param analysis_type "functional_clusters" or "phenotype_clusters".
api/functions/analysis-reproducibility.R:342:#' @return A list with reproducibility_hash, kind, byte_size, snapshot_id, bundle.
api/functions/analysis-reproducibility.R-343-#' @export
api/functions/analysis-reproducibility.R-344-analysis_reproducibility_endpoint <- function(analysis_type, res = NULL, conn = NULL) {
api/functions/analysis-reproducibility.R-345-  normalized <- analysis_snapshot_normalize_params(analysis_type, list())
api/functions/analysis-reproducibility.R-346-  manifest <- analysis_snapshot_public_manifest(
--
api/functions/analysis-reproducibility.R-400-    ))
api/functions/analysis-reproducibility.R-401-  }
api/functions/analysis-reproducibility.R-402-
api/functions/analysis-reproducibility.R-403-  list(
api/functions/analysis-reproducibility.R:404:    reproducibility_hash = as.character(row$reproducibility_hash[[1]]),
api/functions/analysis-reproducibility.R-405-    kind = as.character(row$kind[[1]]),
api/functions/analysis-reproducibility.R-406-    byte_size = as.integer(row$byte_size[[1]]),
api/functions/analysis-reproducibility.R-407-    snapshot_id = snapshot_id,
api/functions/analysis-reproducibility.R-408-    bundle = bundle
--
api/functions/analysis-reproducibility.R-434-
api/functions/analysis-reproducibility.R-435-  analysis_snapshot_with_repository_connection(conn, function(repro_conn) {
api/functions/analysis-reproducibility.R-436-    stmt <- DBI::dbSendStatement(
api/functions/analysis-reproducibility.R-437-      repro_conn,
api/functions/analysis-reproducibility.R:438:      "INSERT INTO analysis_snapshot_reproducibility
api/functions/analysis-reproducibility.R:439:         (snapshot_id, kind, bundle_gzip_json, reproducibility_hash, byte_size)
api/functions/analysis-reproducibility.R-440-       VALUES (?, ?, ?, ?, ?)"
api/functions/analysis-reproducibility.R-441-    )
api/functions/analysis-reproducibility.R-442-    on.exit(DBI::dbClearResult(stmt), add = TRUE)
api/functions/analysis-reproducibility.R-443-    DBI::dbBind(stmt, unname(list(
api/functions/analysis-reproducibility.R-444-      as.numeric(snapshot_id),
api/functions/analysis-reproducibility.R-445-      as.character(bundle$kind %||% NA_character_),
api/functions/analysis-reproducibility.R-446-      list(gz), # bind the raw gzip vector as a single BLOB value
api/functions/analysis-reproducibility.R:447:      as.character(bundle$reproducibility_hash %||% NA_character_),
api/functions/analysis-reproducibility.R-448-      as.integer(bundle$byte_size %||% length(gz))
api/functions/analysis-reproducibility.R-449-    )))
api/functions/analysis-reproducibility.R-450-    DBI::dbGetRowsAffected(stmt)
api/functions/analysis-reproducibility.R-451-  })
--
api/functions/analysis-reproducibility.R-454-}
api/functions/analysis-reproducibility.R-455-
api/functions/analysis-reproducibility.R-456-#' Fetch the reproducibility row for a snapshot (raw blob + metadata).
api/functions/analysis-reproducibility.R-457-#'
api/functions/analysis-reproducibility.R:458:#' @return A 1-row data frame (kind, bundle_gzip_json blob, reproducibility_hash,
api/functions/analysis-reproducibility.R-459-#'   byte_size, created_at) or NULL when the snapshot has no bundle.
api/functions/analysis-reproducibility.R-460-#' @export
api/functions/analysis-reproducibility.R-461-analysis_snapshot_get_reproducibility <- function(snapshot_id, conn = NULL) {
api/functions/analysis-reproducibility.R-462-  rows <- db_execute_query(
api/functions/analysis-reproducibility.R:463:    "SELECT kind, bundle_gzip_json, reproducibility_hash, byte_size, created_at
api/functions/analysis-reproducibility.R:464:       FROM analysis_snapshot_reproducibility
api/functions/analysis-reproducibility.R-465-      WHERE snapshot_id = ?
api/functions/analysis-reproducibility.R-466-      LIMIT 1",
api/functions/analysis-reproducibility.R-467-    unname(list(as.numeric(snapshot_id))),
api/functions/analysis-reproducibility.R-468-    conn = conn
--
api/functions/analysis-snapshot-release-repository.R-93-#' from the caller) from `bundle_gzip`/`files` directly, so they can never
api/functions/analysis-snapshot-release-repository.R-94-#' drift from the actual stored bytes.
api/functions/analysis-snapshot-release-repository.R-95-#'
api/functions/analysis-snapshot-release-repository.R-96-#' `members` is a list of `list(analysis_type, parameter_hash, snapshot_id,
api/functions/analysis-snapshot-release-repository.R:97:#' input_hash, payload_hash, schema_version, reproducibility_hash = NULL,
api/functions/analysis-snapshot-release-repository.R-98-#' role = "layer")`.
api/functions/analysis-snapshot-release-repository.R-99-#'
api/functions/analysis-snapshot-release-repository.R-100-#' `files` is a list of `list(file_path, content_sha256, byte_size,
api/functions/analysis-snapshot-release-repository.R-101-#' media_type = "application/json", content_gzip)` (`content_gzip` a raw
--
api/functions/analysis-snapshot-release-repository.R-150-      DBI::dbExecute(
api/functions/analysis-snapshot-release-repository.R-151-        conn,
api/functions/analysis-snapshot-release-repository.R-152-        "INSERT INTO analysis_snapshot_release_member (
api/functions/analysis-snapshot-release-repository.R-153-           release_id, analysis_type, parameter_hash, snapshot_id, input_hash,
api/functions/analysis-snapshot-release-repository.R:154:           payload_hash, schema_version, reproducibility_hash, role
api/functions/analysis-snapshot-release-repository.R-155-         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
api/functions/analysis-snapshot-release-repository.R-156-        params = unname(list(
api/functions/analysis-snapshot-release-repository.R-157-          release_id,
api/functions/analysis-snapshot-release-repository.R-158-          .analysis_release_chr(m$analysis_type),
--
api/functions/analysis-snapshot-release-repository.R-160-          as.numeric(m$snapshot_id),
api/functions/analysis-snapshot-release-repository.R-161-          .analysis_release_chr(m$input_hash),
api/functions/analysis-snapshot-release-repository.R-162-          .analysis_release_chr(m$payload_hash),
api/functions/analysis-snapshot-release-repository.R-163-          .analysis_release_chr(m$schema_version),
api/functions/analysis-snapshot-release-repository.R:164:          .analysis_release_chr(m$reproducibility_hash),
api/functions/analysis-snapshot-release-repository.R-165-          m$role %||% "layer"
api/functions/analysis-snapshot-release-repository.R-166-        ))
api/functions/analysis-snapshot-release-repository.R-167-      )
api/functions/analysis-snapshot-release-repository.R-168-    }
--
api/functions/analysis-snapshot-release-materialize.R-72-    NA_character_
api/functions/analysis-snapshot-release-materialize.R-73-  )
api/functions/analysis-snapshot-release-materialize.R-74-}
api/functions/analysis-snapshot-release-materialize.R-75-
api/functions/analysis-snapshot-release-materialize.R:76:#' Extract the reproducibility_hash from a loader row (df or list), or NA.
api/functions/analysis-snapshot-release-materialize.R-77-#' @noRd
api/functions/analysis-snapshot-release-materialize.R-78-.analysis_release_repro_hash <- function(repro) {
api/functions/analysis-snapshot-release-materialize.R-79-  if (is.null(repro)) {
api/functions/analysis-snapshot-release-materialize.R-80-    return(NA_character_)
api/functions/analysis-snapshot-release-materialize.R-81-  }
api/functions/analysis-snapshot-release-materialize.R-82-  if (is.data.frame(repro) && nrow(repro) == 0L) {
api/functions/analysis-snapshot-release-materialize.R-83-    return(NA_character_)
api/functions/analysis-snapshot-release-materialize.R-84-  }
api/functions/analysis-snapshot-release-materialize.R:85:  hash <- repro$reproducibility_hash
api/functions/analysis-snapshot-release-materialize.R-86-  if (is.null(hash) || length(hash) == 0L) {
api/functions/analysis-snapshot-release-materialize.R-87-    return(NA_character_)
api/functions/analysis-snapshot-release-materialize.R-88-  }
api/functions/analysis-snapshot-release-materialize.R-89-  as.character(hash[[1]])
--
api/functions/analysis-snapshot-release-materialize.R-328-    "1. `sha256sum -c checksums.sha256` verifies every file against its recorded digest.",
api/functions/analysis-snapshot-release-materialize.R-329-    "2. `manifest.json` records each layer's source snapshot lineage",
api/functions/analysis-snapshot-release-materialize.R-330-    "   (`snapshot_id`, `payload_hash`, `input_hash`) plus the reproducibility hash.",
api/functions/analysis-snapshot-release-materialize.R-331-    "3. Each cluster layer's `reproducibility.json` hashes exactly to its",
api/functions/analysis-snapshot-release-materialize.R:332:    "   `reproducibility_hash` and carries the inputs to independently recompute",
api/functions/analysis-snapshot-release-materialize.R-333-    "   the served separation metric (modularity / silhouette).",
api/functions/analysis-snapshot-release-materialize.R-334-    ""
api/functions/analysis-snapshot-release-materialize.R-335-  )
api/functions/analysis-snapshot-release-materialize.R-336-  charToRaw(enc2utf8(paste(lines, collapse = "\n")))
   430	           members = built$members, row_counts = built$row_counts,
   431	           partition_validation = val$partition, reproducibility = reproducibility)
   432	    },
   433	    phenotype_correlations = {
   434	      rows <- generate_phenotype_correlations_mem(
   435	        filter = params$filter,
   436	        min_abs_correlation = NULL
   437	      )
   438	      built <- analysis_snapshot_build_correlation_rows(rows, correlation_kind = "phenotype")
   439	      list(kind = "correlations", raw = rows, correlations = built$correlations, row_counts = built$row_counts)
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
   571	        conn = txn_conn,
   572	        use_transaction = FALSE
   573	      )
   574	      pruned <- analysis_snapshot_prune(normalized$analysis_type, normalized$parameter_hash, conn = txn_conn)
   575	
   576	      list(snapshot_id = snapshot_id, pruned = pruned)
   577	    })
   578	    llm_generation <- analysis_snapshot_trigger_llm_generation(
   579	      normalized$analysis_type,
   580	      payload,
   581	      parent_job_id = job_id %||% write_result$snapshot_id,
   582	      conn = refresh_conn
   583	    )
   584	
   585	    list(
   586	      snapshot_id = write_result$snapshot_id,
   587	      analysis_type = normalized$analysis_type,
   588	      parameter_hash = normalized$parameter_hash,
   589	      status = "public_ready",
   590	      row_counts = row_counts,
   591	      payload_hash = payload_hash,
   592	      input_hash = input_hash,
   593	      source_data_version = source_data_version,
   594	      dependencies = payload$dependencies,
   595	      stale_after = stale_after,
   596	      pruned = write_result$pruned,
   597	      llm_generation = llm_generation
   598	    )
   599	  })
   600	}
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
    28	source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
    29	source(file.path("functions", "analysis-snapshot-dependencies.R"), local = TRUE)
    30	source(file.path("functions", "analysis-snapshot-coherence.R"), local = TRUE)
    31	source(file.path("functions", "analysis-reproducibility.R"), local = TRUE)
    32	source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = TRUE)
    33	source(file.path("functions", "analysis-snapshot-release-repository.R"), local = TRUE)
    34	source(file.path("functions", "analysis-snapshot-release-materialize.R"), local = TRUE)
    35	source(file.path("functions", "analysis-snapshot-release.R"), local = TRUE)
    36	
    37	# --------------------------------------------------------------------------- #
    38	# Fixtures: fake loaded snapshots mirroring analysis_snapshot_get_public()'s
    39	# return shape (status_code + manifest [1-row df] + payload tibbles).
    40	# --------------------------------------------------------------------------- #
    41	
    42	SRC_V <- "srcv-2026-07-18"
    43	FUNC_ID <- 101L
    44	PHEN_ID <- 202L
    45	CORR_ID <- 303L
    46	FUNC_HASH <- analysis_release_sha256("functional-payload")
    47	PHEN_HASH <- analysis_release_sha256("phenotype-payload")
    48	CORR_HASH <- analysis_release_sha256("correlation-payload")
    49	
    50	make_manifest <- function(analysis_type, snapshot_id, payload_hash,
    51	                          source_data_version = SRC_V,
    52	                          input_hash = analysis_release_sha256(paste0(analysis_type, "-input")),
    53	                          schema_version = "1.2",
    54	                          source_versions_json = NA_character_) {
    55	  data.frame(
    56	    analysis_type = analysis_type,
    57	    snapshot_id = as.integer(snapshot_id),
    58	    payload_hash = payload_hash,
    59	    input_hash = input_hash,
    60	    source_data_version = source_data_version,
    61	    schema_version = schema_version,
    62	    source_versions_json = source_versions_json,
    63	    stringsAsFactors = FALSE
    64	  )
    65	}
    66	
    67	make_cluster_snap <- function(analysis_type, kind, snapshot_id, payload_hash,
    68	                              source_data_version = SRC_V, status_code = "available",
    69	                              stability_ok = TRUE) {
    70	  meta <- if (stability_ok) {
    71	    c('{"jaccard_mean":0.82,"jaccard_n_resamples":50}', '{"jaccard_mean":0.61,"jaccard_n_resamples":50}')
    72	  } else {
    73	    c('{"jaccard_mean":0.82,"jaccard_n_resamples":50}', '{"jaccard_n_resamples":0}')
    74	  }
    75	  clusters <- data.frame(
    76	    cluster_kind = c(kind, kind),
    77	    cluster_id = c("1", "2"),
    78	    cluster_hash = c(analysis_release_sha256(paste0(kind, "-c1")), analysis_release_sha256(paste0(kind, "-c2"))),
    79	    cluster_size = c(3L, 2L),
    80	    label = c("Cluster A", "Cluster B"),
    81	    metadata_json = meta,
    82	    stringsAsFactors = FALSE
    83	  )
    84	  members <- data.frame(
    85	    cluster_kind = kind,
    86	    cluster_id = c("1", "1", "1", "2", "2"),
    87	    member_rank = c(1L, 2L, 3L, 1L, 2L),
    88	    entity_id = c(10L, 11L, 12L, 13L, 14L),
    89	    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3", "HGNC:4", "HGNC:5"),
    90	    symbol = c("G1", "G2", "G3", "G4", "G5"),
    91	    stringsAsFactors = FALSE
    92	  )
    93	  list(
    94	    status_code = status_code,
    95	    manifest = make_manifest(analysis_type, snapshot_id, payload_hash, source_data_version),
    96	    clusters = clusters,
    97	    cluster_members = members
    98	  )
    99	}
   100	
   101	make_corr_snap <- function(func_id = FUNC_ID, func_hash = FUNC_HASH,
   102	                           phen_id = PHEN_ID, phen_hash = PHEN_HASH,
   103	                           source_data_version = SRC_V, status_code = "available") {
   104	  deps_json <- analysis_snapshot_canonical_json(list(dependencies = list(
   105	    functional_clusters = list(snapshot_id = func_id, payload_hash = func_hash),
   106	    phenotype_clusters = list(snapshot_id = phen_id, payload_hash = phen_hash)
   107	  )))
   108	  correlations <- data.frame(
   109	    row_rank = 1:3,
   110	    correlation_kind = c("pc_fc", "pc_fc", "pc_fc"),
   111	    x_key = c("fc_1", "fc_1", "pc_1"),
   112	    y_key = c("fc_1", "pc_1", "pc_1"),
   113	    value = c(1.0, 0.21, 1.0),
   114	    abs_value = c(1.0, 0.21, 1.0),
   115	    metadata_json = NA_character_,
   116	    stringsAsFactors = FALSE
   117	  )
   118	  list(
   119	    status_code = status_code,
   120	    manifest = make_manifest("phenotype_functional_correlations", CORR_ID, CORR_HASH,
   121	      source_data_version,
   122	      source_versions_json = deps_json
   123	    ),
   124	    correlations = correlations
   125	  )
   126	}
   127	
   128	make_repro_bundle <- function(kind) {
   129	  payload <- if (identical(kind, "functional")) {
   130	    list(
   131	      edges = data.frame(
   132	        source = c("1", "2"), target = c("2", "3"),
   133	        combined_score = c(0.987654321098765, 0.6543210987654321),
   134	        stringsAsFactors = FALSE
   135	      ),
   136	      membership = data.frame(node = c("1", "2", "3"), cluster = c(1L, 1L, 2L), stringsAsFactors = FALSE),
   137	      served_modularity = 0.123456789012345,
   138	      params = list(seed = 42L, weight_channel = "experimental_database")
   139	    )
   140	  } else {
   141	    list(
   142	      coords = data.frame(
   143	        entity_id = c("10", "11"), Dim.1 = c(0.111111111, 0.222222222),
   144	        Dim.2 = c(0.333333333, 0.444444444), stringsAsFactors = FALSE
   145	      ),
   146	      membership = data.frame(entity_id = c("10", "11"), cluster = c(1L, 2L), stringsAsFactors = FALSE),
   147	      served_silhouette = 0.234567890123,
   148	      params = list(seed = 42L)
   149	    )
   150	  }
   151	  analysis_reproducibility_bundle(kind, payload)
   152	}
   153	
   154	FUNC_BUNDLE <- make_repro_bundle("functional")
   155	PHEN_BUNDLE <- make_repro_bundle("phenotype")
   156	
   157	# reproducibility_loader fake returning the real bundle row-shape for cluster ids.
   158	present_repro_loader <- function(snapshot_id, conn = NULL) {
   159	  sid <- as.integer(snapshot_id)
   160	  b <- if (identical(sid, FUNC_ID)) FUNC_BUNDLE else if (identical(sid, PHEN_ID)) PHEN_BUNDLE else NULL
   161	  if (is.null(b)) {
   162	    return(NULL)
   163	  }
   164	  row <- data.frame(
   165	    kind = b$kind, reproducibility_hash = b$reproducibility_hash,
   166	    byte_size = b$byte_size, stringsAsFactors = FALSE
   167	  )
   168	  row$bundle_gzip_json <- list(b$bundle_gzip_json) # DBI blob column shape: list-of-raw
   169	  row
   170	}
   171	
   172	pass_coherence <- function(snapshot, kind) invisible(TRUE)
   173	
   174	# Base loader returning a coherent, available snapshot for every default layer.
   175	make_loader <- function(overrides = list()) {
   176	  base <- list(
   177	    functional_clusters = make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH),
   178	    phenotype_clusters = make_cluster_snap("phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH),
   179	    phenotype_functional_correlations = make_corr_snap()
   180	  )
   181	  snaps <- utils::modifyList(base, overrides)
   182	  function(analysis_type, parameter_hash, conn = NULL) snaps[[analysis_type]]
   183	}
   184	
   185	# A functional cluster snapshot whose manifest validation_json carries the served
   186	# membership channel + the validation channel (the exp+db-vs-text-mining #514 case).
   187	make_functional_snap_with_channels <- function(membership_channel, validation_channel) {
   188	  snap <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
   189	  snap$manifest$validation_json <- analysis_snapshot_canonical_json(list(
   190	    weight_channel = validation_channel,
   191	    membership_weight_channel = membership_channel
   192	  ))
   193	  snap
   194	}
   195	
   196	# A STATEFUL loader: returns the original snapshot on the first read of each
   197	# preset, then a DIFFERENT {snapshot_id, payload_hash} for `changed_type` on the
   198	# pre-insert re-read — simulating a concurrent axis refresh mid-build. Proves the
   199	# pre-insert re-read is a FRESH DB read, not a tautological re-check of `loaded`.
   200	make_stateful_loader <- function(changed_type = "functional_clusters") {
   201	  counts <- new.env(parent = emptyenv())
   202	  base <- make_loader()
   203	  function(analysis_type, parameter_hash, conn = NULL) {
   204	    n <- (counts[[analysis_type]] %||% 0L) + 1L
   205	    counts[[analysis_type]] <- n
   206	    snap <- base(analysis_type, parameter_hash, conn)
   207	    if (identical(analysis_type, changed_type) && n >= 2L) {
   208	      snap$manifest <- make_manifest(analysis_type, 999L, analysis_release_sha256("refreshed-payload"))
   209	    }
   210	    snap
   211	  }
   212	}
   213	
   214	# --------------------------------------------------------------------------- #
   215	# Gate tests (no DB: they fail before any persistence; conn = NULL).
   216	# --------------------------------------------------------------------------- #
   217	
   218	test_that("build refuses when any layer snapshot is not available", {
   219	  loader <- make_loader(list(
   220	    phenotype_clusters = make_cluster_snap(
   221	      "phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH,
   222	      status_code = "snapshot_stale"
   223	    )
   224	  ))
   225	  expect_error(
   226	    analysis_snapshot_release_build(
   227	      conn = NULL, publish = TRUE,
   228	      loader = loader, reproducibility_loader = present_repro_loader,
   229	      coherence_assert = pass_coherence
   230	    ),
   231	    class = "release_snapshot_not_available"
   232	  )
   233	})
   234	
   235	test_that("build refuses an available-but-incoherent snapshot (hard coherence re-check)", {
   236	  throwing_coherence <- function(snapshot, kind) stop("planted incoherence")
   237	  expect_error(
   238	    analysis_snapshot_release_build(
   239	      conn = NULL, publish = TRUE,
   240	      loader = make_loader(), reproducibility_loader = present_repro_loader,
   241	      coherence_assert = throwing_coherence
   242	    ),
   243	    class = "release_source_incoherent"
   244	  )
   245	})
   246	
   247	test_that("build refuses when a cluster layer's reproducibility bundle is missing", {
   248	  missing_repro_loader <- function(snapshot_id, conn = NULL) {
   249	    if (identical(as.integer(snapshot_id), FUNC_ID)) {
   250	      return(NULL)
   251	    }
   252	    present_repro_loader(snapshot_id, conn)
   253	  }
   254	  expect_error(
   255	    analysis_snapshot_release_build(
   256	      conn = NULL, publish = TRUE,
   257	      loader = make_loader(), reproducibility_loader = missing_repro_loader,
   258	      coherence_assert = pass_coherence
   259	    ),
   260	    class = "release_reproducibility_missing"
   261	  )
   262	})
   263	
   264	test_that("build refuses layers that do not share one source_data_version", {
   265	  loader <- make_loader(list(
   266	    phenotype_clusters = make_cluster_snap(
   267	      "phenotype_clusters", "phenotype", PHEN_ID, PHEN_HASH,
   268	      source_data_version = "srcv-DIFFERENT"
   269	    )
   270	  ))
   271	  expect_error(
   272	    analysis_snapshot_release_build(
   273	      conn = NULL, publish = TRUE,
   274	      loader = loader, reproducibility_loader = present_repro_loader,
   275	      coherence_assert = pass_coherence
   276	    ),
   277	    class = "release_source_version_mismatch"
   278	  )
   279	})
   280	
   281	test_that("build refuses a correlation snapshot whose dependency lineage is stale", {
   282	  # Correlation manifest pins a functional snapshot_id that no longer matches.
   283	  loader <- make_loader(list(
   284	    phenotype_functional_correlations = make_corr_snap(func_id = 999L)
   285	  ))
   286	  expect_error(
   287	    analysis_snapshot_release_build(
   288	      conn = NULL, publish = TRUE,
   289	      loader = loader, reproducibility_loader = present_repro_loader,
   290	      coherence_assert = pass_coherence
   291	    ),
   292	    class = "release_dependency_lineage_mismatch"
   293	  )
   294	})
   295	
   296	test_that("build refuses a functional snapshot whose served channel != validation channel", {
   297	  # Real coherence default reads validation_json; membership (combined_score) was
   298	  # clustered on a different STRING channel than the validation scored (exp+db).
   299	  loader <- make_loader(list(
   300	    functional_clusters = make_functional_snap_with_channels(
   301	      membership_channel = "combined_score", validation_channel = "experimental_database"
   302	    )
   303	  ))
   304	  expect_error(
   305	    analysis_snapshot_release_build(
   306	      conn = NULL, publish = TRUE,
   307	      loader = loader, reproducibility_loader = present_repro_loader,
   308	      coherence_assert = analysis_snapshot_release_assert_coherent # the REAL default
   309	    ),
   310	    class = "release_source_incoherent"
   311	  )
   312	})
   313	
   314	# --------------------------------------------------------------------------- #
   315	# Real default coherence seam: pass when internally consistent, throw
   316	# release_source_incoherent when a visible cluster lacks a stability score.
   317	# --------------------------------------------------------------------------- #
   318	
   319	test_that("analysis_snapshot_release_assert_coherent gates stored-snapshot integrity", {
   320	  ok <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
   321	  expect_invisible(analysis_snapshot_release_assert_coherent(ok, "functional"))
   322	
   323	  incoherent <- make_cluster_snap(
   324	    "functional_clusters", "functional", FUNC_ID, FUNC_HASH,
   325	    stability_ok = FALSE
   326	  )
   327	  expect_error(
   328	    analysis_snapshot_release_assert_coherent(incoherent, "functional"),
   329	    class = "release_source_incoherent"
   330	  )
   331	})
   332	
   333	test_that("analysis_snapshot_release_assert_coherent enforces the functional channel match", {
   334	  # Both channels present + equal -> passes; present + differ -> throws; absent -> skip.
   335	  matched <- make_functional_snap_with_channels("experimental_database", "experimental_database")
   336	  expect_invisible(analysis_snapshot_release_assert_coherent(matched, "functional"))
   337	
   338	  mismatched <- make_functional_snap_with_channels("combined_score", "experimental_database")
   339	  expect_error(
   340	    analysis_snapshot_release_assert_coherent(mismatched, "functional"),
   341	    class = "release_source_incoherent"
   342	  )
   343	
   344	  # No validation_json -> channel comparison skipped (older snapshots still pass).
   345	  no_channels <- make_cluster_snap("functional_clusters", "functional", FUNC_ID, FUNC_HASH)
   346	  expect_invisible(analysis_snapshot_release_assert_coherent(no_channels, "functional"))
   347	})
   348	
   349	# --------------------------------------------------------------------------- #
   350	# Success + idempotency (real release persistence).
   351	# --------------------------------------------------------------------------- #
   352	
   353	with_release_build_db <- function(code) {
   354	  skip_if_no_test_db()
   355	
   356	  schema_conn <- get_test_db_connection()
   357	  ensure_test_release_schema(schema_conn)
   358	  DBI::dbDisconnect(schema_conn)
   359	
   360	  conn <- get_test_db_connection()
   361	  withr::defer(DBI::dbDisconnect(conn))
   362	  DBI::dbExecute(conn, "DELETE FROM analysis_snapshot_release")
   363	  withr::defer(DBI::dbExecute(conn, "DELETE FROM analysis_snapshot_release"))
   364	
   365	  code(conn)
   366	}
   367	
   368	test_that("build materializes a content-addressed release; repro hash + payload lineage anchor hold", {
   369	  with_release_build_db(function(conn) {
   370	    result <- analysis_snapshot_release_build(
   371	      conn = conn, publish = TRUE, title = "SysNDD analysis snapshot release",
   372	      scope_statement = "Curated derived cluster analysis.",
   373	      loader = make_loader(), reproducibility_loader = present_repro_loader,
   374	      coherence_assert = pass_coherence
   375	    )
   376	    expect_true(result$created)
   377	    release_id <- result$release$release_id
   378	    expect_match(release_id, "^asr_[0-9a-f]{16}$")
   379	    expect_equal(result$release$status, "published")
   380	
   381	    # reproducibility.json hashes EXACTLY to the stored reproducibility_hash
   382	    # (materialized from the raw pre-gzip bytes, not a parse round-trip).
   383	    rf <- analysis_release_get_file(
   384	      release_id, "functional_clusters/reproducibility.json",
   385	      include_draft = TRUE, conn = conn
   386	    )
   387	    expect_false(is.null(rf))
   388	    expect_identical(rf$content_sha256, FUNC_BUNDLE$reproducibility_hash)
   389	
   390	    # manifest per-layer payload_hash is the cross-checkable LINEAGE ANCHOR
   391	    # (== the source snapshot's payload_hash), NOT the payload.json file hash.
   392	    manifest_file <- analysis_release_get_file(release_id, "manifest.json", include_draft = TRUE, conn = conn)
   393	    manifest <- jsonlite::fromJSON(rawToChar(manifest_file$bytes), simplifyVector = FALSE)
   394	    fc <- Filter(function(l) identical(l$analysis_type, "functional_clusters"), manifest$layers)[[1]]
   395	    expect_identical(fc$payload_hash, FUNC_HASH)
   396	    expect_identical(fc$reproducibility_hash, FUNC_BUNDLE$reproducibility_hash)
   397	
   398	    payload_file <- analysis_release_get_file(
   399	      release_id, "functional_clusters/payload.json",
   400	      include_draft = TRUE, conn = conn
   401	    )
   402	    expect_false(is.null(payload_file))
   403	    # the file's OWN hash is not the lineage payload_hash:
   404	    expect_false(identical(payload_file$content_sha256, fc$payload_hash))
   405	
   406	    # the correlation layer carries dependency lineage but no reproducibility file:
   407	    corr <- Filter(function(l) identical(l$analysis_type, "phenotype_functional_correlations"), manifest$layers)[[1]]
   408	    expect_false(is.null(corr$dependencies))
   409	    expect_null(analysis_release_get_file(
   410	      release_id, "phenotype_functional_correlations/reproducibility.json",
   411	      include_draft = TRUE, conn = conn
   412	    ))
   413	
   414	    # the whole-archive bundle is retrievable and checksummed:
   415	    bundle <- analysis_release_get_bundle(release_id, include_draft = TRUE, conn = conn)
   416	    expect_false(is.null(bundle))
   417	    expect_equal(bundle$sha256, result$release$bundle_sha256)
   418	  })
   419	})
   420	
   421	test_that("build is idempotent by content: same sources -> same release_id, no duplicate row", {
   422	  with_release_build_db(function(conn) {
   423	    args <- list(
   424	      conn = conn, publish = TRUE,
   425	      loader = make_loader(), reproducibility_loader = present_repro_loader,
   426	      coherence_assert = pass_coherence
   427	    )
   428	    r1 <- do.call(analysis_snapshot_release_build, args)
   429	    expect_true(r1$created)
   430	    expect_match(r1$release$release_id, "^asr_[0-9a-f]{16}$")
   431	
   432	    r2 <- do.call(analysis_snapshot_release_build, args)
   433	    expect_false(r2$created)
   434	    expect_identical(r1$release$release_id, r2$release$release_id)
   435	
   436	    published <- analysis_release_list(status = "published", conn = conn)
   437	    expect_identical(1L, length(published))
   438	  })
   439	})
   440	
   441	test_that("pre-insert re-read catches a source snapshot refreshed mid-build (fresh, not tautological)", {
   442	  with_release_build_db(function(conn) {
   443	    # The stateful loader returns snapshot_id 101 on the first functional read but
   444	    # snapshot_id 999 on the pre-insert re-read: if the re-read were tautological
   445	    # (re-checking the cached `loaded`) this would build; a FRESH read must catch it.
   446	    expect_error(
   447	      analysis_snapshot_release_build(
   448	        conn = conn, publish = TRUE,
   449	        loader = make_stateful_loader("functional_clusters"),
   450	        reproducibility_loader = present_repro_loader,
   451	        coherence_assert = pass_coherence
   452	      ),
   453	      class = "release_dependency_lineage_mismatch"
   454	    )
   455	    # nothing was persisted (the mismatch fired before insert):
   456	    expect_identical(0L, length(analysis_release_list(status = "published", conn = conn)))
   457	  })
   458	})
   459	
   460	test_that("build with publish = FALSE leaves a draft (not visible as published)", {
   461	  with_release_build_db(function(conn) {
   462	    result <- analysis_snapshot_release_build(
   463	      conn = conn, publish = FALSE,
   464	      loader = make_loader(), reproducibility_loader = present_repro_loader,
   465	      coherence_assert = pass_coherence
   466	    )
   467	    expect_true(result$created)
   468	    expect_equal(result$release$status, "draft")
   469	    expect_identical(0L, length(analysis_release_list(status = "published", conn = conn)))
   470	  })
   471	})

exec
/bin/bash -lc "rg -n \"\\b(paste0|paste|sprintf|glue|dbGetQuery|dbExecute|dbSend|dbBind|system|writeBin|file\\.path|unlink|setwd|memDecompress|Content-|setHeader)\\b\" api/functions/analysis-snapshot-release*.R api/services/analysis-snapshot-release-service.R api/endpoints/{analysis_endpoints.R,admin_analysis_snapshot_endpoints.R} && rg -n \"analysis_snapshot_release_build\\(|analysis_release_(insert|set_doi|get_file|get_bundle|get|list|publish|delete)|svc_release_\" api -g '*.R' | grep -v 'tests/' && git diff --check 67cf6003..HEAD && git diff --unified=80 67cf6003..HEAD -- api/functions/analysis-snapshot-repository.R api/bootstrap/load_modules.R api/endpoints/analysis_endpoints.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 exited 2 in 0ms:
api/endpoints/admin_analysis_snapshot_endpoints.R:170:  # dbExecute()/dbGetQuery() calls, which pool::Pool supports directly.
api/endpoints/analysis_endpoints.R:23:      res$setHeader("Retry-After", as.character(snapshot_result$retry_after))
api/endpoints/analysis_endpoints.R:476:#* @response 200 OK. Raw manifest.json bytes, Content-Type application/json.
api/endpoints/analysis_endpoints.R:482:  # Content-Type is set by the octet serializer (application/json) -- do NOT also
api/endpoints/analysis_endpoints.R:483:  # res$setHeader() it, which would emit a duplicate Content-Type header.
api/endpoints/analysis_endpoints.R:500:#* @response 200 OK. Raw file bytes, Content-Type from the stored file's media type.
api/endpoints/analysis_endpoints.R:508:  # serializer's type dynamically rather than res$setHeader()-ing a second
api/endpoints/analysis_endpoints.R:509:  # Content-Type alongside the octet serializer's default.
api/endpoints/analysis_endpoints.R:527:  # Content-Type (application/gzip) is set by the octet serializer -- do NOT also
api/endpoints/analysis_endpoints.R:528:  # res$setHeader() it (duplicate header). Content-Disposition/Length are distinct.
api/endpoints/analysis_endpoints.R:529:  res$setHeader("Content-Disposition", sprintf('attachment; filename="%s"', bundle$filename))
api/endpoints/analysis_endpoints.R:530:  res$setHeader("Content-Length", as.character(length(bundle$bytes)))
api/services/analysis-snapshot-release-service.R:118:    stop_for_not_found(sprintf("Release '%s' not found", release_id))
api/services/analysis-snapshot-release-service.R:139:    stop_for_not_found(sprintf("Release '%s' not found", release_id))
api/services/analysis-snapshot-release-service.R:157:    stop_for_not_found(sprintf("Release '%s' not found", release_id))
api/services/analysis-snapshot-release-service.R:227:    stop_for_not_found(sprintf("Release file not found: %s", file_path))
api/functions/analysis-snapshot-release-repository.R:9:# Deliberately self-contained: uses raw `DBI::dbGetQuery()` / `DBI::dbExecute()`
api/functions/analysis-snapshot-release-repository.R:62:.analysis_release_head_columns <- paste(
api/functions/analysis-snapshot-release-repository.R:71:#' Convert a single-row data.frame (as returned by dbGetQuery) into a plain
api/functions/analysis-snapshot-release-repository.R:120:    DBI::dbExecute(
api/functions/analysis-snapshot-release-repository.R:150:      DBI::dbExecute(
api/functions/analysis-snapshot-release-repository.R:171:      DBI::dbExecute(
api/functions/analysis-snapshot-release-repository.R:207:  sql <- paste0(
api/functions/analysis-snapshot-release-repository.R:213:  rows <- DBI::dbGetQuery(conn, sql, params = unname(list(as.character(release_id))))
api/functions/analysis-snapshot-release-repository.R:252:  sql <- paste0(
api/functions/analysis-snapshot-release-repository.R:259:  rows <- DBI::dbGetQuery(conn, sql, params = unname(params))
api/functions/analysis-snapshot-release-repository.R:265:  placeholders <- paste(rep("?", length(release_ids)), collapse = ",")
api/functions/analysis-snapshot-release-repository.R:266:  members <- DBI::dbGetQuery(
api/functions/analysis-snapshot-release-repository.R:268:    paste0(
api/functions/analysis-snapshot-release-repository.R:303:  sql <- paste0(
api/functions/analysis-snapshot-release-repository.R:310:  rows <- DBI::dbGetQuery(
api/functions/analysis-snapshot-release-repository.R:320:    bytes = memDecompress(gz, type = "gzip"),
api/functions/analysis-snapshot-release-repository.R:338:  sql <- paste0(
api/functions/analysis-snapshot-release-repository.R:344:  rows <- DBI::dbGetQuery(conn, sql, params = unname(list(as.character(release_id))))
api/functions/analysis-snapshot-release-repository.R:352:    filename = paste0(as.character(release_id), ".tar.gz")
api/functions/analysis-snapshot-release-repository.R:360:  rows <- DBI::dbGetQuery(
api/functions/analysis-snapshot-release-repository.R:373:  rows <- DBI::dbGetQuery(
api/functions/analysis-snapshot-release-repository.R:388:  affected <- DBI::dbExecute(
api/functions/analysis-snapshot-release-repository.R:416:  set_clause <- paste(paste0(present, " = ?"), collapse = ", ")
api/functions/analysis-snapshot-release-repository.R:418:  affected <- DBI::dbExecute(
api/functions/analysis-snapshot-release-repository.R:420:    paste0("UPDATE analysis_snapshot_release SET ", set_clause, " WHERE release_id = ?"),
api/functions/analysis-snapshot-release-repository.R:435:  affected <- DBI::dbExecute(
api/functions/analysis-snapshot-release-materialize.R:191:        sprintf("%s snapshot failed hard coherence re-check: %s", kind, conditionMessage(e)),
api/functions/analysis-snapshot-release-materialize.R:232:      sprintf(
api/functions/analysis-snapshot-release-materialize.R:234:        paste(ifelse(is.na(versions), "<NA>", versions), collapse = ", ")
api/functions/analysis-snapshot-release-materialize.R:249:        paste(
api/functions/analysis-snapshot-release-materialize.R:301:      sprintf(
api/functions/analysis-snapshot-release-materialize.R:309:    sprintf("# %s", title %||% "SysNDD analysis-snapshot release"),
api/functions/analysis-snapshot-release-materialize.R:311:    sprintf("Release: `%s`", release_id),
api/functions/analysis-snapshot-release-materialize.R:312:    sprintf("License: %s", license %||% "CC-BY-4.0"),
api/functions/analysis-snapshot-release-materialize.R:313:    sprintf("Source data version: %s", source_data_version %||% "unknown"),
api/functions/analysis-snapshot-release-materialize.R:317:    scope_statement %||% paste(
api/functions/analysis-snapshot-release-materialize.R:336:  charToRaw(enc2utf8(paste(lines, collapse = "\n")))
api/functions/analysis-snapshot-release.R:62:  paste0("asr:", substr(as.character(parameter_hash[[1]]), 1, 56))
api/functions/analysis-snapshot-release.R:72:      rows <- DBI::dbGetQuery(
api/functions/analysis-snapshot-release.R:88:    DBI::dbGetQuery(
api/functions/analysis-snapshot-release.R:112:        sprintf("layer %s became unavailable before insert: %s", at, status_code),
api/functions/analysis-snapshot-release.R:122:        sprintf(
api/functions/analysis-snapshot-release.R:213:        sprintf("layer %s is not available for release: %s", at, status_code),
api/functions/analysis-snapshot-release.R:246:            sprintf("layer %s failed the hard coherence re-check: %s", at, conditionMessage(e)),
api/functions/analysis-snapshot-release.R:258:          sprintf("layer %s has no reproducibility bundle; the release requires one", at),
api/functions/analysis-snapshot-release.R:293:      paste0(prefix, "/payload.json"), payload_bytes, "application/json"
api/functions/analysis-snapshot-release.R:299:        paste0(prefix, "/reproducibility.json"), repro_bytes, "application/json"
api/functions/analysis-snapshot-release.R:326:    stop(sprintf(
api/functions/analysis-snapshot-release-manifest.R:115:  paste0("asr_", substr(content_digest, 1, 16))
api/functions/analysis-snapshot-release-manifest.R:162:  lines <- vapply(files, function(f) paste0(f$sha256, "  ", f$path), character(1))
api/functions/analysis-snapshot-release-manifest.R:163:  paste0(paste(lines, collapse = "\n"), "\n")
api/functions/analysis-snapshot-release-manifest.R:188:  on.exit(unlink(src_dir, recursive = TRUE, force = TRUE), add = TRUE)
api/functions/analysis-snapshot-release-manifest.R:191:    full_path <- file.path(src_dir, path)
api/functions/analysis-snapshot-release-manifest.R:193:    writeBin(named_raw_list[[path]], full_path)
api/functions/analysis-snapshot-release-manifest.R:197:  on.exit(unlink(tar_file, force = TRUE), add = TRUE)
api/functions/analysis-snapshot-release-manifest.R:199:  previous_wd <- setwd(src_dir)
api/functions/analysis-snapshot-release-manifest.R:200:  on.exit(setwd(previous_wd), add = TRUE)
api/functions/analysis-snapshot-release-manifest.R:202:  # never depends on a system `tar` binary being present/compatible.
api/bootstrap/load_modules.R:78:    # Slice A). Synchronous admin/API-only build path (svc_release_build(),
api/services/analysis-snapshot-release-service.R:19:# BUILD MAPPING. `svc_release_build()` calls the A4 orchestrator inside a
api/services/analysis-snapshot-release-service.R:30:# PUBLIC SURFACE. `svc_release_list/get/manifest/file/bundle()` are the
api/services/analysis-snapshot-release-service.R:37:# ADMIN SURFACE. `svc_release_build/publish/set_doi/delete_draft()` are
api/services/analysis-snapshot-release-service.R:53:#' Thin problem+json shim over `analysis_snapshot_release_build()`. On
api/services/analysis-snapshot-release-service.R:70:svc_release_build <- function(res,
api/services/analysis-snapshot-release-service.R:107:#' repository's `analysis_release_publish()` already no-ops when the row is
api/services/analysis-snapshot-release-service.R:114:svc_release_publish <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R:115:  analysis_release_publish(release_id, conn = conn)
api/services/analysis-snapshot-release-service.R:116:  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/services/analysis-snapshot-release-service.R:135:svc_release_set_doi <- function(release_id, doi_fields, conn = NULL) {
api/services/analysis-snapshot-release-service.R:136:  analysis_release_set_doi(release_id, doi_fields = doi_fields, conn = conn)
api/services/analysis-snapshot-release-service.R:137:  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/services/analysis-snapshot-release-service.R:154:svc_release_delete_draft <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R:155:  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/services/analysis-snapshot-release-service.R:162:  analysis_release_delete_draft(release_id, conn = conn)
api/services/analysis-snapshot-release-service.R:174:#' @return Whatever shape `analysis_release_list()` returns (a list of
api/services/analysis-snapshot-release-service.R:177:svc_release_list <- function(limit = 50, offset = 0, conn = NULL) {
api/services/analysis-snapshot-release-service.R:178:  analysis_release_list(status = "published", limit = limit, offset = offset, conn = conn)
api/services/analysis-snapshot-release-service.R:191:svc_release_get <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R:192:  head <- analysis_release_get(release_id, include_draft = FALSE, conn = conn)
api/services/analysis-snapshot-release-service.R:205:svc_release_manifest <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R:206:  file <- analysis_release_get_file(release_id, "manifest.json", include_draft = FALSE, conn = conn)
api/services/analysis-snapshot-release-service.R:224:svc_release_file <- function(release_id, file_path, conn = NULL) {
api/services/analysis-snapshot-release-service.R:225:  file <- analysis_release_get_file(release_id, file_path, include_draft = FALSE, conn = conn)
api/services/analysis-snapshot-release-service.R:238:svc_release_bundle <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R:239:  bundle <- analysis_release_get_bundle(release_id, include_draft = FALSE, conn = conn)
api/endpoints/admin_analysis_snapshot_endpoints.R:18:# (services/analysis-snapshot-release-service.R, `svc_release_*`); the two
api/endpoints/admin_analysis_snapshot_endpoints.R:22:# svc_release_list()/svc_release_get() in the service layer are
api/endpoints/admin_analysis_snapshot_endpoints.R:93:#' layer shares the same param keys. `analysis_snapshot_release_build()`
api/endpoints/admin_analysis_snapshot_endpoints.R:105:#' `svc_release_build()`. `req$postBody` is populated by Plumber's default
api/endpoints/admin_analysis_snapshot_endpoints.R:164:  # analysis_snapshot_release_build() ultimately calls
api/endpoints/admin_analysis_snapshot_endpoints.R:165:  # analysis_release_insert(), which wraps its writes in ONE
api/endpoints/admin_analysis_snapshot_endpoints.R:174:  svc_release_build(
api/endpoints/admin_analysis_snapshot_endpoints.R:189:#* `svc_release_list()`), this admin listing includes draft rows so an
api/endpoints/admin_analysis_snapshot_endpoints.R:205:  releases <- analysis_release_list(status = NULL, limit = limit_int, offset = offset_int, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R:216:#* `svc_release_get()`), this admin detail resolves a draft release too.
api/endpoints/admin_analysis_snapshot_endpoints.R:225:  head <- analysis_release_get(release_id, include_draft = TRUE, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R:243:  svc_release_publish(release_id, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R:277:  svc_release_set_doi(release_id, doi_fields = doi_fields, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R:292:  svc_release_delete_draft(release_id, conn = pool)
api/endpoints/analysis_endpoints.R:382:# contract). DB-only, published-only: every svc_release_* read is pinned to
api/endpoints/analysis_endpoints.R:419:  releases <- svc_release_list(limit = limit_int, offset = offset_int, conn = pool)
api/endpoints/analysis_endpoints.R:444:  newest <- svc_release_list(limit = 1, offset = 0, conn = pool)
api/endpoints/analysis_endpoints.R:448:  svc_release_get(as.character(newest[[1]]$release_id), conn = pool)
api/endpoints/analysis_endpoints.R:463:  svc_release_get(release_id, conn = pool)
api/endpoints/analysis_endpoints.R:481:  content <- svc_release_manifest(release_id, conn = pool)
api/endpoints/analysis_endpoints.R:506:  content <- svc_release_file(release_id, file_path, conn = pool)
api/endpoints/analysis_endpoints.R:526:  bundle <- svc_release_bundle(release_id, conn = pool)
api/functions/analysis-snapshot-release.R:16:#   - analysis-snapshot-release-repository.R: analysis_release_insert/get/exists/... (A3)
api/functions/analysis-snapshot-release.R:66:.analysis_release_get_lock <- function(conn, name, timeout_seconds = 5L) {
api/functions/analysis-snapshot-release.R:189:      if (.analysis_release_get_lock(conn, lock_name, 5L)) {
api/functions/analysis-snapshot-release.R:322:    existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/functions/analysis-snapshot-release.R:437:  analysis_release_insert(release_head, members, insert_files, conn)
api/functions/analysis-snapshot-release.R:439:    analysis_release_publish(release_id, conn = conn)
api/functions/analysis-snapshot-release.R:443:    release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
api/functions/analysis-snapshot-release-repository.R:22:# `analysis-snapshot-repository.R`). Two reasons: (1) `analysis_release_insert()`
api/functions/analysis-snapshot-release-repository.R:29:# `analysis_release_insert()` on a connection that already has an open
api/functions/analysis-snapshot-release-repository.R:60:#' for via `analysis_release_get_bundle()`).
api/functions/analysis-snapshot-release-repository.R:90:#' `analysis_release_publish()` is the only way to flip it.
api/functions/analysis-snapshot-release-repository.R:106:analysis_release_insert <- function(release_head, members = list(), files = list(), conn) {
api/functions/analysis-snapshot-release-repository.R:205:analysis_release_get <- function(release_id, include_draft = FALSE, conn) {
api/functions/analysis-snapshot-release-repository.R:220:  manifest_file <- analysis_release_get_file(
api/functions/analysis-snapshot-release-repository.R:245:analysis_release_list <- function(status = "published", limit = 50L, offset = 0L, conn) {
api/functions/analysis-snapshot-release-repository.R:301:analysis_release_get_file <- function(release_id, file_path, include_draft = FALSE, conn) {
api/functions/analysis-snapshot-release-repository.R:329:#' decompress it (unlike `analysis_release_get_file()`, which stores each
api/functions/analysis-snapshot-release-repository.R:336:analysis_release_get_bundle <- function(release_id, include_draft = FALSE, conn) {
api/functions/analysis-snapshot-release-repository.R:387:analysis_release_publish <- function(release_id, conn) {
api/functions/analysis-snapshot-release-repository.R:409:analysis_release_set_doi <- function(release_id, doi_fields = list(), conn) {
api/functions/analysis-snapshot-release-repository.R:434:analysis_release_delete_draft <- function(release_id, conn) {
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

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-presets.R | sed -n '1,300p'; rg -n \"analysis_snapshot_normalize_params|analysis_snapshot_supported|data_class|approved_public|analysis_snapshot_presets\" api/functions/analysis-snapshot-presets.R api/functions/analysis-snapshot-builder.R api -g '*.R' | head -250; nl -ba api/tests/testthat/test-unit-analysis-snapshot-release-service.R | sed -n '1,540p'; nl -ba api/tests/testthat/test-integration-analysis-release-admin-endpoints.R | sed -n '1,540p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
     1	ANALYSIS_SNAPSHOT_SCHEMA_VERSION <- "1.2"
     2	
     3	analysis_snapshot_unsupported_parameter <- function(message, fields = list()) {
     4	  rlang::abort(
     5	    message = message,
     6	    class = "analysis_snapshot_unsupported_parameter_error",
     7	    !!!fields
     8	  )
     9	}
    10	
    11	analysis_snapshot_supported_presets <- function() {
    12	  list(
    13	    list(
    14	      analysis_type = "functional_clusters",
    15	      data_class = "curated_derived_analysis",
    16	      params = list(algorithm = "leiden"),
    17	      # "heavy": recursive STRING enrichment; staggered behind the cheap presets
    18	      # at first-start to avoid worker-lease contention (#447, #440).
    19	      weight = "heavy"
    20	    ),
    21	    list(
    22	      analysis_type = "phenotype_clusters",
    23	      data_class = "curated_derived_analysis",
    24	      params = list(),
    25	      # "heavy": now runs subsampling MCA+HCPC bootstrap validation, so it is
    26	      # staggered behind the cheap presets at first-start like functional_clusters.
    27	      weight = "heavy"
    28	    ),
    29	    list(
    30	      analysis_type = "phenotype_correlations",
    31	      data_class = "curated_derived_analysis",
    32	      params = list(filter = "contains(ndd_phenotype_word,Yes),any(category,Definitive)"),
    33	      weight = "light"
    34	    ),
    35	    list(
    36	      analysis_type = "phenotype_functional_correlations",
    37	      data_class = "curated_derived_analysis",
    38	      params = list(algorithm = "leiden"),
    39	      weight = "light"
    40	    ),
    41	    list(
    42	      analysis_type = "gene_network_edges",
    43	      data_class = "curated_derived_analysis",
    44	      params = list(cluster_type = "clusters", min_confidence = 400L, max_edges = 10000L),
    45	      weight = "light"
    46	    )
    47	  )
    48	}
    49	
    50	#' Bootstrap weight for a supported preset.
    51	#'
    52	#' "heavy" presets (`functional_clusters`, with its recursive STRING enrichment
    53	#' build, and `phenotype_clusters`, which now runs subsampling MCA+HCPC bootstrap
    54	#' validation) are staggered behind the cheap "light" presets at first-start so a
    55	#' single small-host worker does not contend for the shared DB pool / CPU and
    56	#' push the heavy build over its lease (#447). Unknown types fail open to "light"
    57	#' so an unrecognized preset is never delayed.
    58	#'
    59	#' @param analysis_type Character analysis type.
    60	#' @return "heavy" or "light".
    61	#' @export
    62	analysis_snapshot_preset_weight <- function(analysis_type) {
    63	  at <- as.character(analysis_type[[1]])
    64	  for (p in analysis_snapshot_supported_presets()) {
    65	    if (identical(p$analysis_type, at)) {
    66	      w <- p$weight
    67	      if (is.null(w) || !nzchar(as.character(w[[1]]))) {
    68	        return("light")
    69	      }
    70	      return(as.character(w[[1]]))
    71	    }
    72	  }
    73	  "light"
    74	}
    75	
    76	analysis_snapshot_canonical_json <- function(value) {
    77	  as.character(jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", dataframe = "rows"))
    78	}
    79	
    80	analysis_snapshot_parameter_hash <- function(analysis_type, params) {
    81	  digest::digest(
    82	    paste0(analysis_type, ":", analysis_snapshot_canonical_json(params)),
    83	    algo = "sha256",
    84	    serialize = FALSE
    85	  )
    86	}
    87	
    88	analysis_snapshot_normalize_params <- function(analysis_type, params = list()) {
    89	  analysis_type <- as.character(analysis_type[[1]])
    90	  if (is.null(params)) {
    91	    params <- list()
    92	  }
    93	  if (!is.list(params)) {
    94	    analysis_snapshot_unsupported_parameter(
    95	      "Analysis snapshot parameters must be a list",
    96	      fields = list(analysis_type = analysis_type)
    97	    )
    98	  }
    99	
   100	  presets <- analysis_snapshot_supported_presets()
   101	  preset <- NULL
   102	  for (candidate in presets) {
   103	    if (identical(candidate$analysis_type, analysis_type)) {
   104	      preset <- candidate
   105	      break
   106	    }
   107	  }
   108	
   109	  if (is.null(preset)) {
   110	    analysis_snapshot_unsupported_parameter(
   111	      sprintf("Unsupported analysis snapshot type: %s", analysis_type),
   112	      fields = list(analysis_type = analysis_type)
   113	    )
   114	  }
   115	
   116	  normalized_params <- preset$params
   117	  supported_names <- names(preset$params)
   118	  supplied_names <- names(params)
   119	  if (length(params) > 0L && (is.null(supplied_names) || any(is.na(supplied_names) | !nzchar(supplied_names)))) {
   120	    analysis_snapshot_unsupported_parameter(
   121	      "Analysis snapshot parameters must be named",
   122	      fields = list(analysis_type = analysis_type)
   123	    )
   124	  }
   125	  unsupported_names <- setdiff(supplied_names, supported_names)
   126	
   127	  if (length(unsupported_names) > 0L) {
   128	    analysis_snapshot_unsupported_parameter(
   129	      sprintf("Unsupported analysis snapshot parameter: %s", paste(unsupported_names, collapse = ", ")),
   130	      fields = list(analysis_type = analysis_type, parameters = unsupported_names)
   131	    )
   132	  }
   133	
   134	  for (name in supplied_names) {
   135	    normalized_params[[name]] <- params[[name]]
   136	  }
   137	
   138	  if (identical(analysis_type, "phenotype_correlations") && "filter" %in% supplied_names) {
   139	    normalized_params$filter <- analysis_snapshot_normalize_filter_param(
   140	      normalized_params$filter,
   141	      preset$params$filter
   142	    )
   143	  }
   144	
   145	  if (identical(analysis_type, "gene_network_edges")) {
   146	    normalized_params$min_confidence <- analysis_snapshot_coerce_integer(
   147	      normalized_params$min_confidence,
   148	      "min_confidence",
   149	      analysis_type
   150	    )
   151	    normalized_params$max_edges <- analysis_snapshot_coerce_integer(
   152	      normalized_params$max_edges,
   153	      "max_edges",
   154	      analysis_type
   155	    )
   156	  }
   157	
   158	  if (!identical(normalized_params, preset$params)) {
   159	    analysis_snapshot_unsupported_parameter(
   160	      sprintf(
   161	        paste(
   162	          "Unsupported parameters for analysis snapshot type: %s.",
   163	          "Only supported public preset values are accepted.",
   164	          "Phenotype correlation filters tolerate case and whitespace differences only."
   165	        ),
   166	        analysis_type
   167	      ),
   168	      fields = list(
   169	        analysis_type = analysis_type,
   170	        params = normalized_params,
   171	        supported_params = preset$params
   172	      )
   173	    )
   174	  }
   175	
   176	  parameters_json <- analysis_snapshot_canonical_json(normalized_params)
   177	  list(
   178	    analysis_type = analysis_type,
   179	    data_class = preset$data_class,
   180	    params = normalized_params,
   181	    parameters_json = parameters_json,
   182	    parameter_hash = analysis_snapshot_parameter_hash(analysis_type, normalized_params)
   183	  )
   184	}
   185	
   186	analysis_snapshot_normalize_filter_param <- function(value, supported_value) {
   187	  if (is.null(value) || length(value) == 0L || is.null(value[[1]])) {
   188	    return(value)
   189	  }
   190	  value <- as.character(value[[1]])
   191	  normalize <- function(x) {
   192	    gsub("\\s+", "", tolower(trimws(as.character(x[[1]]))))
   193	  }
   194	  if (identical(normalize(value), normalize(supported_value))) {
   195	    return(supported_value)
   196	  }
   197	  value
   198	}
   199	
   200	analysis_snapshot_coerce_integer <- function(value, field, analysis_type) {
   201	  if (length(value) == 0L || is.null(value[[1]])) {
   202	    analysis_snapshot_unsupported_parameter(
   203	      sprintf("Unsupported integer value for %s", field),
   204	      fields = list(analysis_type = analysis_type, parameter = field)
   205	    )
   206	  }
   207	  coerced <- suppressWarnings(as.integer(value[[1]]))
   208	  numeric_value <- suppressWarnings(as.numeric(value[[1]]))
   209	  if (is.na(coerced) || is.na(numeric_value) || !identical(as.numeric(coerced), numeric_value)) {
   210	    analysis_snapshot_unsupported_parameter(
   211	      sprintf("Unsupported integer value for %s", field),
   212	      fields = list(analysis_type = analysis_type, parameter = field)
   213	    )
   214	  }
   215	  coerced
   216	}
api/functions/analysis-snapshot-builder.R:387:  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
api/functions/analysis-snapshot-builder.R:474:  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
api/functions/analysis-snapshot-builder.R:536:          data_class = normalized$data_class,
api/functions/analysis-snapshot-presets.R:11:analysis_snapshot_supported_presets <- function() {
api/functions/analysis-snapshot-presets.R:15:      data_class = "curated_derived_analysis",
api/functions/analysis-snapshot-presets.R:23:      data_class = "curated_derived_analysis",
api/functions/analysis-snapshot-presets.R:31:      data_class = "curated_derived_analysis",
api/functions/analysis-snapshot-presets.R:37:      data_class = "curated_derived_analysis",
api/functions/analysis-snapshot-presets.R:43:      data_class = "curated_derived_analysis",
api/functions/analysis-snapshot-presets.R:64:  for (p in analysis_snapshot_supported_presets()) {
api/functions/analysis-snapshot-presets.R:88:analysis_snapshot_normalize_params <- function(analysis_type, params = list()) {
api/functions/analysis-snapshot-presets.R:100:  presets <- analysis_snapshot_supported_presets()
api/functions/analysis-snapshot-presets.R:179:    data_class = preset$data_class,
api/scripts/verify-mcp-select-principal-fixtures.R:118:      "(analysis_type,parameter_hash,schema_version,data_class,status,public_ready,",
api/scripts/verify-mcp-select-principal-fixtures.R:127:      normalized$data_class, source_version, normalized$parameters_json
api/scripts/verify-mcp-select-principal-fixtures.R:138:  presets <- analysis_snapshot_supported_presets()
api/scripts/verify-mcp-select-principal-fixtures.R:141:    normalized <- analysis_snapshot_normalize_params(
api/scripts/mcp-smoke.R:205:if (is.null(capabilities_payload$analysis_data_classes$ml_prediction) ||
api/scripts/mcp-smoke.R:286:  if (!identical(nddscore_payload$data_class, "ml_prediction") || !isTRUE(nddscore_payload$not_evidence_tier)) {
api/scripts/refresh-analysis-snapshots.R:57:presets <- analysis_snapshot_supported_presets()
api/services/mcp-capabilities-service.R:94:    analysis_data_classes = list(
api/services/mcp-tool-core.R:128:    data_class = list(type = "string", description = "Data class label, for example curated_derived_analysis, ml_prediction, or llm_generated_summary."),
api/services/analysis-snapshot-refresh-service.R:108:    presets <- analysis_snapshot_supported_presets()
api/services/analysis-snapshot-refresh-service.R:129:    normalized <- analysis_snapshot_normalize_params(preset$analysis_type, preset$params)
api/services/analysis-snapshot-refresh-service.R:215:    presets <- analysis_snapshot_supported_presets()
api/services/analysis-snapshot-refresh-service.R:225:    normalized <- analysis_snapshot_normalize_params(preset$analysis_type, preset$params)
api/services/analysis-snapshot-service.R:30:    analysis_snapshot_normalize_params(analysis_type, params),
api/services/analysis-snapshot-service.R:332:      data_class = service_analysis_snapshot_json_scalar(service_analysis_snapshot_scalar_value(row$data_class)),
api/services/mcp-analysis-service.R:19:      data_class = "operational_metadata",
api/services/mcp-analysis-service.R:29:      data_class = "ml_prediction",
api/services/mcp-analysis-service.R:38:      data_class = "curated_derived_analysis",
api/services/mcp-analysis-service.R:47:      data_class = "curated_derived_analysis",
api/services/mcp-analysis-service.R:56:      data_class = "curated_derived_analysis",
api/services/mcp-analysis-service.R:65:      data_class = "llm_generated_summary",
api/services/mcp-analysis-service.R:76:    analyses <- lapply(analyses, function(x) x[c("analysis_id", "tool", "data_class", "availability")])
api/services/mcp-analysis-service.R:470:    meta$data_classes <- list(validation = "curated_derived_analysis")
api/services/mcp-analysis-service.R:477:      # field is doubled under two conflicting data_class labels (code-review).
api/services/mcp-analysis-service.R:480:      meta$data_classes$separation_statistics <- "operational_metadata"
api/services/mcp-analysis-service.R:506:    analysis_snapshot_normalize_params(
api/services/mcp-analysis-shaping.R:33:mcp_analysis_provenance <- function(data_class,
api/services/mcp-analysis-shaping.R:39:  data_class <- mcp_validate_enum(data_class, MCP_ANALYSIS_DATA_CLASSES, "data_class")
api/services/mcp-analysis-shaping.R:41:  if (identical(data_class, "curated_sysndd_evidence")) {
api/services/mcp-analysis-shaping.R:50:    data_class,
api/services/mcp-analysis-shaping.R:71:    data_class = data_class,
api/tests/testthat/test-unit-publication-date-backfill.R:24:    seed_primary_approved_publication(conn, publication_id = "PMID:999100", source = NULL)
api/tests/testthat/test-unit-publication-date-backfill.R:55:    seed_primary_approved_publication(conn, publication_id = "PMID:999102", source = NULL)
api/tests/testthat/test-unit-publication-date-backfill.R:86:    seed_primary_approved_publication(conn, publication_id = "PMID:999103", source = NULL)
api/tests/testthat/test-unit-publication-date-backfill.R:104:    seed_primary_approved_publication(conn, publication_id = "PMID:999101", source = NULL)
api/tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R:69:       (analysis_type, parameter_hash, schema_version, data_class, status,
api/tests/testthat/test-unit-analysis-snapshot-repository.R:20:  net <- analysis_snapshot_normalize_params(
api/tests/testthat/test-unit-analysis-snapshot-repository.R:33:  locks <- vapply(analysis_snapshot_supported_presets(), function(p) {
api/tests/testthat/test-unit-analysis-snapshot-repository.R:117:        data_class = "curated_derived_analysis",
api/tests/testthat/test-unit-analysis-snapshot-repository.R:189:      data_class = "curated_derived_analysis",
api/tests/testthat/test-mcp-analysis-research-context.R:21:    list(data_class = "ml_prediction", gene = list(hgnc_id = "HGNC:61"))
api/tests/testthat/test-mcp-analysis-research-context.R:24:    list(data_class = "curated_derived_analysis", rows = list())
api/tests/testthat/test-mcp-analysis-research-context.R:187:      data_class = "llm_generated_summary",
api/tests/testthat/test-mcp-analysis-research-context.R:248:    list(data_class = "ml_prediction", gene = list(hgnc_id = "HGNC:61"), payload = paste(rep("x", 2000), collapse = ""))
api/functions/analysis-snapshot-release.R:178:      parameter_hash = analysis_snapshot_normalize_params(at, layer$params %||% list())$parameter_hash
api/tests/testthat/test-endpoint-analysis-snapshot-read.R:45:    data_class = "curated_derived_analysis",
api/tests/testthat/helper-publication-dates.R:39:seed_primary_approved_publication <- function(conn, publication_id, source = NULL,
api/tests/testthat/helper-mcp-select-principal.R:49:      "data_class", "generated_at", "activated_at", "stale_after",
api/tests/testthat/test-mcp-analysis-service.R:12:    data_class = "curated_sysndd_evidence",
api/tests/testthat/test-mcp-analysis-service.R:17:  expect_equal(curated$data_class, "curated_sysndd_evidence")
api/tests/testthat/test-mcp-analysis-service.R:22:    data_class = "ml_prediction",
api/tests/testthat/test-mcp-analysis-service.R:32:    data_class = "llm_generated_summary",
api/tests/testthat/test-mcp-analysis-service.R:101:  expect_equal(catalog$data_class, "operational_metadata")
api/tests/testthat/test-mcp-analysis-service.R:132:  expect_equal(result$data_class, "ml_prediction")
api/tests/testthat/test-mcp-analysis-service.R:157:  expect_equal(result$data_class, "curated_derived_analysis")
api/tests/testthat/test-mcp-analysis-service.R:206:  expect_equal(result[[1]]$data_class, "llm_generated_summary")
api/tests/testthat/test-mcp-analysis-service.R:225:  expect_equal(result[[1]]$data_class, "llm_generated_summary")
api/tests/testthat/test-mcp-analysis-service.R:244:  expect_equal(result$data_class, "curated_derived_analysis")
api/tests/testthat/test-mcp-analysis-service.R:505:  expect_equal(result$meta$data_classes$validation, "curated_derived_analysis")
api/tests/testthat/test-mcp-analysis-service.R:506:  expect_null(result$meta$data_classes$db_release)
api/tests/testthat/test-mcp-analysis-service.R:514:  expect_equal(result$meta$data_classes$separation_statistics, "operational_metadata")
api/tests/testthat/test-mcp-analysis-service.R:540:  expect_null(result$meta$data_classes$separation_statistics)
api/tests/testthat/test-mcp-analysis-service.R:541:  expect_equal(result$meta$data_classes$validation, "curated_derived_analysis")
api/functions/mcp-readonly-contract.R:48:      "snapshot_id", "analysis_type", "parameter_hash", "schema_version", "data_class",
api/tests/testthat/test-mcp-select-principal-projections.R:89:    "`m`.`data_class` AS `data_class`,`m`.`generated_at` AS `generated_at`,",
api/tests/testthat/test-mcp-analysis-repository.R:95:      schema_version = "1.2", data_class = "curated_derived_analysis",
api/tests/testthat/test-mcp-analysis-repository.R:120:        schema_version = "1.2", data_class = "curated_derived_analysis",
api/tests/testthat/test-mcp-analysis-repository.R:152:        schema_version = "1.2", data_class = "curated_derived_analysis",
api/functions/analysis-reproducibility.R:345:  normalized <- analysis_snapshot_normalize_params(analysis_type, list())
api/tests/testthat/test-mcp-tools.R:225:  expect_true("data_class" %in% names(nddscore$properties))
api/tests/testthat/test-mcp-tools.R:397:  expect_false(is.null(caps$analysis_data_classes$ml_prediction))
api/tests/testthat/test-mcp-tools.R:398:  expect_true(caps$analysis_data_classes$ml_prediction$not_evidence_tier)
api/tests/testthat/test-mcp-tools.R:399:  expect_match(caps$analysis_data_classes$llm_generated_summary$note, "validated stored", ignore.case = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-provenance.R:18:      data_class = "curated_derived_analysis",
api/tests/testthat/test-unit-analysis-snapshot-provenance.R:48:  expect_equal(as.character(meta$data_class), "curated_derived_analysis")
api/tests/testthat/test-unit-analysis-snapshot-provenance.R:115:      data_class = "curated_derived_analysis",
api/tests/testthat/test-unit-snapshot-bootstrap-stagger.R:24:  for (p in analysis_snapshot_supported_presets()) {
api/tests/testthat/test-unit-analysis-snapshot-dependencies.R:153:      data_class = "curated_derived_analysis",
api/tests/testthat/test-unit-analysis-snapshot-presets.R:8:  network <- analysis_snapshot_normalize_params(
api/tests/testthat/test-unit-analysis-snapshot-presets.R:18:  functional <- analysis_snapshot_normalize_params(
api/tests/testthat/test-unit-analysis-snapshot-presets.R:24:  phenotype <- analysis_snapshot_normalize_params(
api/tests/testthat/test-unit-analysis-snapshot-presets.R:38:    analysis_snapshot_normalize_params("functional_clusters", list(algorithm = "walktrap")),
api/tests/testthat/test-unit-analysis-snapshot-presets.R:43:    analysis_snapshot_normalize_params(
api/tests/testthat/test-unit-analysis-snapshot-presets.R:50:    analysis_snapshot_normalize_params("unknown_analysis", list()),
api/tests/testthat/test-unit-analysis-snapshot-presets.R:54:    analysis_snapshot_normalize_params("phenotype_clusters", list("unexpected")),
api/tests/testthat/test-unit-analysis-snapshot-presets.R:59:test_that("snapshot presets define data_class for every public analysis type", {
api/tests/testthat/test-unit-analysis-snapshot-presets.R:62:  presets <- analysis_snapshot_supported_presets()
api/tests/testthat/test-unit-analysis-snapshot-presets.R:63:  expect_true(all(vapply(presets, function(x) identical(x$data_class, "curated_derived_analysis"), logical(1))))
api/functions/async-job-analysis-snapshot-handlers.R:13:  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
api/functions/analysis-snapshot-presets.R:11:analysis_snapshot_supported_presets <- function() {
api/functions/analysis-snapshot-presets.R:15:      data_class = "curated_derived_analysis",
api/functions/analysis-snapshot-presets.R:23:      data_class = "curated_derived_analysis",
api/functions/analysis-snapshot-presets.R:31:      data_class = "curated_derived_analysis",
api/functions/analysis-snapshot-presets.R:37:      data_class = "curated_derived_analysis",
api/functions/analysis-snapshot-presets.R:43:      data_class = "curated_derived_analysis",
api/functions/analysis-snapshot-presets.R:64:  for (p in analysis_snapshot_supported_presets()) {
api/functions/analysis-snapshot-presets.R:88:analysis_snapshot_normalize_params <- function(analysis_type, params = list()) {
api/functions/analysis-snapshot-presets.R:100:  presets <- analysis_snapshot_supported_presets()
api/functions/analysis-snapshot-presets.R:179:    data_class = preset$data_class,
api/functions/analysis-snapshot-builder.R:387:  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
api/functions/analysis-snapshot-builder.R:474:  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
api/functions/analysis-snapshot-builder.R:536:          data_class = normalized$data_class,
api/functions/analysis-snapshot-repository.R:113:         analysis_type, parameter_hash, schema_version, data_class, status,
api/functions/analysis-snapshot-repository.R:129:        manifest$data_class,
api/functions/analysis-snapshot-dependencies.R:21:  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
api/functions/analysis-snapshot-dependencies.R:147:  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
api/functions/mcp-analysis-repository.R:228:  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
api/functions/mcp-analysis-repository.R:230:    "SELECT snapshot_id, analysis_type, parameter_hash, schema_version, data_class,
     1	# tests/testthat/test-unit-analysis-snapshot-release-service.R
     2	#
     3	# Unit tests for the analysis-snapshot RELEASE service layer (#573 Slice A /
     4	# Task A5): api/services/analysis-snapshot-release-service.R.
     5	#
     6	# Pure unit tests, NO DATABASE. The A4 build orchestrator
     7	# (`analysis_snapshot_release_build`) and the A3 repository functions
     8	# (`analysis_release_list/get/get_file/get_bundle/publish/set_doi/
     9	# delete_draft`) are entirely STUBBED: this file never sources
    10	# `functions/analysis-snapshot-release.R` or
    11	# `functions/analysis-snapshot-release-repository.R`, it only defines
    12	# minimal stand-ins for the names the service calls, then reassigns them
    13	# per-test via `with_release_mocks()`. This mirrors the established
    14	# `test-unit-metadata-vocabulary-service.R` mocking pattern: source
    15	# core/errors.R + the service with `source_api_file(local = FALSE)`, look up
    16	# `environment(<a service fn>)` to find where the service's free-variable
    17	# lookups resolve, then temporarily reassign bindings there.
    18	
    19	library(testthat)
    20	
    21	source_api_file("core/errors.R", local = FALSE)
    22	
    23	# Minimal stand-ins for the A3/A4 functions the service calls, so the service
    24	# file sources cleanly (its body only looks these names up at CALL time, but
    25	# defining them up front keeps `with_release_mocks()`'s get/assign symmetric
    26	# and self-documenting about the service's full dependency surface).
    27	analysis_snapshot_release_build <- function(...) stop("stub: analysis_snapshot_release_build not mocked")
    28	analysis_release_list <- function(...) stop("stub: analysis_release_list not mocked")
    29	analysis_release_get <- function(...) stop("stub: analysis_release_get not mocked")
    30	analysis_release_get_file <- function(...) stop("stub: analysis_release_get_file not mocked")
    31	analysis_release_get_bundle <- function(...) stop("stub: analysis_release_get_bundle not mocked")
    32	analysis_release_publish <- function(...) stop("stub: analysis_release_publish not mocked")
    33	analysis_release_set_doi <- function(...) stop("stub: analysis_release_set_doi not mocked")
    34	analysis_release_delete_draft <- function(...) stop("stub: analysis_release_delete_draft not mocked")
    35	
    36	source_api_file("services/analysis-snapshot-release-service.R", local = FALSE)
    37	
    38	# The environment the service functions were defined in (same top-level frame
    39	# the stand-ins above and core/errors.R were sourced into).
    40	release_svc_env <- environment(svc_release_build)
    41	
    42	#' Temporarily reassign a set of names in `release_svc_env`, restoring the
    43	#' previous bindings on exit (mirrors `with_repo_mocks()` in
    44	#' test-unit-metadata-vocabulary-service.R).
    45	with_release_mocks <- function(mocks, code) {
    46	  originals <- list()
    47	  for (name in names(mocks)) {
    48	    originals[[name]] <- get(name, envir = release_svc_env)
    49	    assign(name, mocks[[name]], envir = release_svc_env)
    50	  }
    51	  on.exit({
    52	    for (name in names(originals)) {
    53	      assign(name, originals[[name]], envir = release_svc_env)
    54	    }
    55	  }, add = TRUE)
    56	  force(code)
    57	}
    58	
    59	#' Build a classed condition matching A4's `c(<name>, "error", "condition")`
    60	#' shape (see functions/analysis-snapshot-release.R `.analysis_release_condition`).
    61	release_condition <- function(class_name, message) {
    62	  structure(
    63	    class = c(class_name, "error", "condition"),
    64	    list(message = message, call = NULL)
    65	  )
    66	}
    67	
    68	#' Minimal Plumber-response stand-in: just needs a settable `$status`.
    69	release_fake_res <- function() {
    70	  res <- new.env()
    71	  res$status <- NULL
    72	  res
    73	}
    74	
    75	# =============================================================================
    76	# svc_release_build
    77	# =============================================================================
    78	
    79	test_that("build success (created=TRUE) sets 201 and returns the head", {
    80	  head <- list(release_id = "asr_abc123", status = "published")
    81	  res <- release_fake_res()
    82	  with_release_mocks(
    83	    list(analysis_snapshot_release_build = function(...) list(release = head, created = TRUE)),
    84	    {
    85	      out <- svc_release_build(res)
    86	      expect_equal(res$status, 201L)
    87	      expect_identical(out, head)
    88	    }
    89	  )
    90	})
    91	
    92	test_that("build idempotent (created=FALSE) sets 200 and returns the SAME head, no error", {
    93	  head <- list(release_id = "asr_dup456", status = "published")
    94	  res <- release_fake_res()
    95	  with_release_mocks(
    96	    list(analysis_snapshot_release_build = function(...) list(release = head, created = FALSE)),
    97	    {
    98	      out <- svc_release_build(res)
    99	      expect_equal(res$status, 200L)
   100	      expect_identical(out, head)
   101	    }
   102	  )
   103	})
   104	
   105	test_that("build forwards layers/title/etc through to the orchestrator", {
   106	  captured <- NULL
   107	  res <- release_fake_res()
   108	  with_release_mocks(
   109	    list(analysis_snapshot_release_build = function(...) {
   110	      captured <<- list(...)
   111	      list(release = list(release_id = "asr_x"), created = TRUE)
   112	    }),
   113	    {
   114	      svc_release_build(
   115	        res,
   116	        title = "My Title",
   117	        scope_statement = "scope",
   118	        license = "CC0-1.0",
   119	        publish = FALSE,
   120	        created_by = 7L,
   121	        conn = "conn-stub"
   122	      )
   123	    }
   124	  )
   125	  expect_equal(captured$title, "My Title")
   126	  expect_equal(captured$scope_statement, "scope")
   127	  expect_equal(captured$license, "CC0-1.0")
   128	  expect_false(captured$publish)
   129	  expect_equal(captured$created_by, 7L)
   130	  expect_equal(captured$conn, "conn-stub")
   131	  expect_false("layers" %in% names(captured)) # NULL layers -> not forwarded, orchestrator uses its own default
   132	})
   133	
   134	release_build_condition_cases <- list(
   135	  release_snapshot_not_available = "layer functional_clusters is not available for release: snapshot_missing",
   136	  release_source_incoherent = "layer functional_clusters failed the hard coherence re-check: boom",
   137	  release_reproducibility_missing = "layer phenotype_clusters has no reproducibility bundle; the release requires one",
   138	  release_source_version_mismatch = "shared source_data_version mismatch across layers: v1 vs v2",
   139	  release_dependency_lineage_mismatch = "layer phenotype_functional_correlations snapshot changed between read and insert"
   140	)
   141	
   142	test_that("build maps release_snapshot_not_available to a 400 carrying the reason", {
   143	  res <- release_fake_res()
   144	  msg <- release_build_condition_cases$release_snapshot_not_available
   145	  with_release_mocks(
   146	    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_snapshot_not_available", msg))),
   147	    {
   148	      err <- tryCatch(svc_release_build(res), error = function(e) e)
   149	      expect_s3_class(err, "error_400")
   150	      expect_match(conditionMessage(err), "functional_clusters", fixed = TRUE)
   151	      expect_match(conditionMessage(err), "snapshot_missing", fixed = TRUE)
   152	    }
   153	  )
   154	})
   155	
   156	test_that("build maps release_source_incoherent to a 400 carrying the reason", {
   157	  res <- release_fake_res()
   158	  msg <- release_build_condition_cases$release_source_incoherent
   159	  with_release_mocks(
   160	    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_source_incoherent", msg))),
   161	    {
   162	      err <- tryCatch(svc_release_build(res), error = function(e) e)
   163	      expect_s3_class(err, "error_400")
   164	      expect_match(conditionMessage(err), "functional_clusters", fixed = TRUE)
   165	      expect_match(conditionMessage(err), "hard coherence", fixed = TRUE)
   166	    }
   167	  )
   168	})
   169	
   170	test_that("build maps release_reproducibility_missing to a 400 carrying the reason", {
   171	  res <- release_fake_res()
   172	  msg <- release_build_condition_cases$release_reproducibility_missing
   173	  with_release_mocks(
   174	    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_reproducibility_missing", msg))),
   175	    {
   176	      err <- tryCatch(svc_release_build(res), error = function(e) e)
   177	      expect_s3_class(err, "error_400")
   178	      expect_match(conditionMessage(err), "phenotype_clusters", fixed = TRUE)
   179	      expect_match(conditionMessage(err), "reproducibility bundle", fixed = TRUE)
   180	    }
   181	  )
   182	})
   183	
   184	test_that("build maps release_source_version_mismatch to a 400 carrying the reason", {
   185	  res <- release_fake_res()
   186	  msg <- release_build_condition_cases$release_source_version_mismatch
   187	  with_release_mocks(
   188	    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_source_version_mismatch", msg))),
   189	    {
   190	      err <- tryCatch(svc_release_build(res), error = function(e) e)
   191	      expect_s3_class(err, "error_400")
   192	      expect_match(conditionMessage(err), "v1 vs v2", fixed = TRUE)
   193	    }
   194	  )
   195	})
   196	
   197	test_that("build maps release_dependency_lineage_mismatch to a 400 carrying the reason", {
   198	  res <- release_fake_res()
   199	  msg <- release_build_condition_cases$release_dependency_lineage_mismatch
   200	  with_release_mocks(
   201	    list(analysis_snapshot_release_build = function(...) stop(release_condition("release_dependency_lineage_mismatch", msg))),
   202	    {
   203	      err <- tryCatch(svc_release_build(res), error = function(e) e)
   204	      expect_s3_class(err, "error_400")
   205	      expect_match(conditionMessage(err), "phenotype_functional_correlations", fixed = TRUE)
   206	      expect_match(conditionMessage(err), "changed between read and insert", fixed = TRUE)
   207	    }
   208	  )
   209	})
   210	
   211	test_that("build lets a non-release_* error propagate unmapped (500 path)", {
   212	  res <- release_fake_res()
   213	  with_release_mocks(
   214	    list(analysis_snapshot_release_build = function(...) stop("boom: unexpected DB error")),
   215	    {
   216	      err <- tryCatch(svc_release_build(res), error = function(e) e)
   217	      expect_false(inherits(err, "error_400"))
   218	      expect_false(inherits(err, "http_problem_error"))
   219	      expect_match(conditionMessage(err), "boom: unexpected DB error", fixed = TRUE)
   220	    }
   221	  )
   222	})
   223	
   224	# =============================================================================
   225	# svc_release_publish
   226	# =============================================================================
   227	
   228	test_that("publish: unknown id -> 404", {
   229	  with_release_mocks(
   230	    list(
   231	      analysis_release_publish = function(...) FALSE,
   232	      analysis_release_get = function(...) NULL
   233	    ),
   234	    {
   235	      expect_error(svc_release_publish("asr_missing"), class = "error_404")
   236	    }
   237	  )
   238	})
   239	
   240	test_that("publish: success returns the (now-published) head", {
   241	  head <- list(release_id = "asr_pub1", status = "published")
   242	  with_release_mocks(
   243	    list(
   244	      analysis_release_publish = function(...) TRUE,
   245	      analysis_release_get = function(release_id, include_draft, conn = NULL) {
   246	        expect_true(include_draft)
   247	        head
   248	      }
   249	    ),
   250	    {
   251	      out <- svc_release_publish("asr_pub1")
   252	      expect_identical(out, head)
   253	    }
   254	  )
   255	})
   256	
   257	# =============================================================================
   258	# svc_release_set_doi
   259	# =============================================================================
   260	
   261	test_that("set_doi: unknown id -> 404", {
   262	  with_release_mocks(
   263	    list(
   264	      analysis_release_set_doi = function(...) FALSE,
   265	      analysis_release_get = function(...) NULL
   266	    ),
   267	    {
   268	      expect_error(
   269	        svc_release_set_doi("asr_missing", list(version_doi = "10.5281/zenodo.1")),
   270	        class = "error_404"
   271	      )
   272	    }
   273	  )
   274	})
   275	
   276	test_that("set_doi: success returns the updated head and forwards doi_fields verbatim", {
   277	  head <- list(release_id = "asr_doi1", version_doi = "10.5281/zenodo.1")
   278	  captured <- NULL
   279	  with_release_mocks(
   280	    list(
   281	      analysis_release_set_doi = function(release_id, doi_fields, conn = NULL) {
   282	        captured <<- doi_fields
   283	        TRUE
   284	      },
   285	      analysis_release_get = function(...) head
   286	    ),
   287	    {
   288	      out <- svc_release_set_doi("asr_doi1", list(version_doi = "10.5281/zenodo.1"))
   289	      expect_identical(out, head)
   290	      expect_equal(captured$version_doi, "10.5281/zenodo.1")
   291	    }
   292	  )
   293	})
   294	
   295	# =============================================================================
   296	# svc_release_delete_draft
   297	# =============================================================================
   298	
   299	test_that("delete_draft: unknown id -> 404", {
   300	  with_release_mocks(
   301	    list(analysis_release_get = function(...) NULL),
   302	    {
   303	      expect_error(svc_release_delete_draft("asr_missing"), class = "error_404")
   304	    }
   305	  )
   306	})
   307	
   308	test_that("delete_draft: published release -> 400 with the exact reason message", {
   309	  with_release_mocks(
   310	    list(analysis_release_get = function(...) list(release_id = "asr_pub", status = "published")),
   311	    {
   312	      err <- tryCatch(svc_release_delete_draft("asr_pub"), error = function(e) e)
   313	      expect_s3_class(err, "error_400")
   314	      expect_equal(
   315	        conditionMessage(err),
   316	        "Cannot delete a published release; only drafts are deletable"
   317	      )
   318	    }
   319	  )
   320	})
   321	
   322	test_that("delete_draft: draft release deletes and returns deleted=TRUE", {
   323	  delete_called_with <- NULL
   324	  with_release_mocks(
   325	    list(
   326	      analysis_release_get = function(...) list(release_id = "asr_draft1", status = "draft"),
   327	      analysis_release_delete_draft = function(release_id, conn = NULL) {
   328	        delete_called_with <<- release_id
   329	        TRUE
   330	      }
   331	    ),
   332	    {
   333	      out <- svc_release_delete_draft("asr_draft1")
   334	      expect_equal(out, list(deleted = TRUE, release_id = "asr_draft1"))
   335	      expect_equal(delete_called_with, "asr_draft1")
   336	    }
   337	  )
   338	})
   339	
   340	# =============================================================================
   341	# svc_release_list (public)
   342	# =============================================================================
   343	
   344	test_that("list: reads only status='published' from the repository and returns it verbatim", {
   345	  captured <- NULL
   346	  rows <- list(list(release_id = "asr_1"), list(release_id = "asr_2"))
   347	  with_release_mocks(
   348	    list(analysis_release_list = function(status, limit, offset, conn = NULL) {
   349	      captured <<- list(status = status, limit = limit, offset = offset)
   350	      rows
   351	    }),
   352	    {
   353	      out <- svc_release_list(limit = 10, offset = 5)
   354	      expect_identical(out, rows)
   355	      expect_equal(captured$status, "published")
   356	      expect_equal(captured$limit, 10)
   357	      expect_equal(captured$offset, 5)
   358	    }
   359	  )
   360	})
   361	
   362	# =============================================================================
   363	# svc_release_get (public)
   364	# =============================================================================
   365	
   366	test_that("get: draft or unknown (stub returns NULL) -> 404, and include_draft is FALSE", {
   367	  captured_include_draft <- NULL
   368	  with_release_mocks(
   369	    list(analysis_release_get = function(release_id, include_draft, conn = NULL) {
   370	      captured_include_draft <<- include_draft
   371	      NULL
   372	    }),
   373	    {
   374	      expect_error(svc_release_get("asr_draft_or_missing"), class = "error_404")
   375	    }
   376	  )
   377	  expect_false(captured_include_draft)
   378	})
   379	
   380	test_that("get: success returns the head", {
   381	  head <- list(release_id = "asr_pub2", status = "published")
   382	  with_release_mocks(
   383	    list(analysis_release_get = function(...) head),
   384	    {
   385	      out <- svc_release_get("asr_pub2")
   386	      expect_identical(out, head)
   387	    }
   388	  )
   389	})
   390	
   391	# =============================================================================
   392	# svc_release_manifest (public)
   393	# =============================================================================
   394	
   395	test_that("manifest: unknown -> 404", {
   396	  with_release_mocks(
   397	    list(analysis_release_get_file = function(...) NULL),
   398	    {
   399	      expect_error(svc_release_manifest("asr_missing"), class = "error_404")
   400	    }
   401	  )
   402	})
   403	
   404	test_that("manifest: returns {bytes, media_type='application/json', content_sha256} and asks for manifest.json only", {
   405	  captured_path <- NULL
   406	  bytes <- charToRaw('{"release_id":"asr_1"}')
   407	  with_release_mocks(
   408	    list(analysis_release_get_file = function(release_id, file_path, include_draft, conn = NULL) {
   409	      captured_path <<- file_path
   410	      expect_false(include_draft)
   411	      list(bytes = bytes, media_type = "application/json", content_sha256 = "abc123")
   412	    }),
   413	    {
   414	      out <- svc_release_manifest("asr_1")
   415	      expect_identical(out, list(bytes = bytes, media_type = "application/json", content_sha256 = "abc123"))
   416	    }
   417	  )
   418	  expect_equal(captured_path, "manifest.json")
   419	})
   420	
   421	# =============================================================================
   422	# svc_release_file (public)
   423	# =============================================================================
   424	
   425	test_that("file: unknown path -> 404", {
   426	  with_release_mocks(
   427	    list(analysis_release_get_file = function(...) NULL),
   428	    {
   429	      expect_error(svc_release_file("asr_1", "does/not/exist.json"), class = "error_404")
   430	    }
   431	  )
   432	})
   433	
   434	test_that("file: returns {bytes, media_type, content_sha256} for a known path", {
   435	  bytes <- charToRaw("# README")
   436	  with_release_mocks(
   437	    list(analysis_release_get_file = function(release_id, file_path, include_draft, conn = NULL) {
   438	      expect_false(include_draft)
   439	      list(bytes = bytes, media_type = "text/markdown", content_sha256 = "def456")
   440	    }),
   441	    {
   442	      out <- svc_release_file("asr_1", "README.md")
   443	      expect_identical(out, list(bytes = bytes, media_type = "text/markdown", content_sha256 = "def456"))
   444	    }
   445	  )
   446	})
   447	
   448	# =============================================================================
   449	# svc_release_bundle (public)
   450	# =============================================================================
   451	
   452	test_that("bundle: unknown -> 404", {
   453	  with_release_mocks(
   454	    list(analysis_release_get_bundle = function(...) NULL),
   455	    {
   456	      expect_error(svc_release_bundle("asr_missing"), class = "error_404")
   457	    }
   458	  )
   459	})
   460	
   461	test_that("bundle: returns {bytes, sha256, filename}", {
   462	  bytes <- as.raw(c(1, 2, 3))
   463	  with_release_mocks(
   464	    list(analysis_release_get_bundle = function(release_id, include_draft, conn = NULL) {
   465	      expect_false(include_draft)
   466	      list(bytes = bytes, sha256 = "ghi789", filename = "asr_1.tar.gz")
   467	    }),
   468	    {
   469	      out <- svc_release_bundle("asr_1")
   470	      expect_identical(out, list(bytes = bytes, sha256 = "ghi789", filename = "asr_1.tar.gz"))
   471	    }
   472	  )
   473	})
     1	# tests/testthat/test-integration-analysis-release-admin-endpoints.R
     2	#
     3	# Integration tests for the ADMIN routes of immutable analysis-snapshot
     4	# releases (#573 Slice A / Task A7): the 6 routes appended to
     5	# endpoints/admin_analysis_snapshot_endpoints.R -- POST /releases (build),
     6	# GET /releases (admin list, incl. drafts), GET /releases/<id> (admin
     7	# detail, incl. draft), POST /releases/<id>/publish, PATCH
     8	# /releases/<id>/doi, DELETE /releases/<id>.
     9	#
    10	# Handler-extraction idiom (mirrors test-integration-analysis-release-endpoints.R,
    11	# A6's public-route test, which itself mirrors test-endpoint-analysis-snapshot-read.R):
    12	# each route handler is extracted from admin_analysis_snapshot_endpoints.R by
    13	# decorator regex + brace-depth scan, then eval()'d and called directly with a
    14	# fake `req`/`res` -- no live plumber router needed. Every free variable an
    15	# extracted handler references at call time (require_role, svc_release_*,
    16	# analysis_release_*, stop_for_not_found, `pool`, `%||%`) is bound straight
    17	# into .GlobalEnv via base source(file, local = FALSE) -- see A6's file header
    18	# for the empirically-verified reason a test_that()-local source() does not
    19	# reach a sibling top-level closure's lexical chain, while .GlobalEnv always
    20	# does.
    21	#
    22	# UNLIKE A6, this file sources core/middleware.R FOR REAL (not stubbed) so
    23	# require_role()'s actual 403-vs-pass-through behaviour is exercised, matching
    24	# the brief's explicit ask to "verify against how require_role signals".
    25	# core/middleware.R only needs library(jose)/library(stringr)/library(logger),
    26	# all available on host.
    27	#
    28	# POST /releases (build) is tested against a STUBBED
    29	# analysis_snapshot_release_build() (real snapshot-backed building is
    30	# integration-tested in A4's own test file and end-to-end in the dev-stack;
    31	# seeding the full analysis_snapshot_* source tables here would duplicate
    32	# that coverage for no benefit). The stub is bound into .GlobalEnv the same
    33	# way `pool` is -- assign + withr::defer(rm(...)).
    34	#
    35	# analysis_snapshot_release_build()'s ultimate persistence call,
    36	# analysis_release_insert(), wraps its writes in ONE
    37	# DBI::dbWithTransaction() and binds blob params via list(<raw>) -- both need
    38	# a real DBIConnection, never a bare pool::Pool (see
    39	# functions/analysis-snapshot-release-repository.R's file header). The
    40	# production POST /releases route therefore does
    41	# pool::poolCheckout(pool)/pool::poolReturn(conn) around the build call, so
    42	# `pool` must be bound to a GENUINE pool::dbPool() here (not just a raw
    43	# connection, unlike A6's `pool <- conn` shortcut) or poolCheckout() errors.
    44	# make_test_pool() mirrors test-integration-entity-rename.R's identically-named
    45	# helper.
    46	
    47	release_admin_test_wd <- getwd()
    48	setwd(get_api_dir())
    49	withr::defer(setwd(release_admin_test_wd), testthat::teardown_env())
    50	
    51	release_a7_globals_before <- ls(envir = .GlobalEnv)
    52	source(file.path("core", "errors.R"), local = FALSE)
    53	source(file.path("core", "middleware.R"), local = FALSE)
    54	source(file.path("functions", "analysis-snapshot-presets.R"), local = FALSE)
    55	source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = FALSE)
    56	source(file.path("functions", "analysis-snapshot-release-repository.R"), local = FALSE)
    57	source(file.path("services", "analysis-snapshot-release-service.R"), local = FALSE)
    58	release_a7_new_globals <- setdiff(ls(envir = .GlobalEnv), release_a7_globals_before)
    59	withr::defer(
    60	  rm(list = intersect(release_a7_new_globals, ls(envir = .GlobalEnv)), envir = .GlobalEnv),
    61	  testthat::teardown_env()
    62	)
    63	
    64	# --------------------------------------------------------------------------- #
    65	# Fixture builders (mirrors test-integration-analysis-release-endpoints.R)
    66	# --------------------------------------------------------------------------- #
    67	
    68	TEST_PUBLISHED_RELEASE_ID <- "asr_test0000000701"
    69	TEST_DRAFT_PUBLISH_RELEASE_ID <- "asr_test0000000702"
    70	TEST_DRAFT_DELETE_RELEASE_ID <- "asr_test0000000703"
    71	ALL_TEST_A7_RELEASE_IDS <- c(
    72	  TEST_PUBLISHED_RELEASE_ID, TEST_DRAFT_PUBLISH_RELEASE_ID, TEST_DRAFT_DELETE_RELEASE_ID
    73	)
    74	
    75	.delete_test_a7_releases <- function(conn) {
    76	  placeholders <- paste(rep("?", length(ALL_TEST_A7_RELEASE_IDS)), collapse = ",")
    77	  DBI::dbExecute(
    78	    conn,
    79	    sprintf("DELETE FROM analysis_snapshot_release WHERE release_id IN (%s)", placeholders),
    80	    params = unname(as.list(ALL_TEST_A7_RELEASE_IDS))
    81	  )
    82	}
    83	
    84	make_gzip_file <- function(file_path, text, media_type = "application/json") {
    85	  raw_bytes <- charToRaw(text)
    86	  list(
    87	    file_path = file_path,
    88	    content_sha256 = analysis_release_sha256(raw_bytes),
    89	    byte_size = length(raw_bytes),
    90	    media_type = media_type,
    91	    content_gzip = memCompress(raw_bytes, type = "gzip")
    92	  )
    93	}
    94	
    95	make_manifest_file <- function(release_id, payload_file) {
    96	  manifest_json <- analysis_snapshot_canonical_json(list(
    97	    release_id = release_id,
    98	    release_version = "v1",
    99	    files = list(list(
   100	      path = payload_file$file_path,
   101	      sha256 = payload_file$content_sha256,
   102	      bytes = payload_file$byte_size
   103	    ))
   104	  ))
   105	  make_gzip_file("manifest.json", manifest_json)
   106	}
   107	
   108	make_release_head <- function(release_id, manifest_file) {
   109	  bundle_gzip <- memCompress(charToRaw(paste0("bundle contents for ", release_id)), type = "gzip")
   110	  list(
   111	    release_id = release_id,
   112	    release_version = "v1",
   113	    title = "Test admin release",
   114	    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
   115	    content_digest = analysis_release_sha256(paste0("digest-", release_id)),
   116	    # manifest_sha256 MUST equal the manifest.json FILE's own content_sha256.
   117	    manifest_sha256 = manifest_file$content_sha256,
   118	    bundle_sha256 = analysis_release_sha256(bundle_gzip),
   119	    bundle_gzip = bundle_gzip,
   120	    source_data_version = "srcv1",
   121	    license = "CC-BY-4.0"
   122	  )
   123	}
   124	
   125	make_member <- function() {
   126	  list(
   127	    analysis_type = "functional_clusters",
   128	    parameter_hash = analysis_release_sha256("functional_clusters-params"),
   129	    snapshot_id = 701L,
   130	    input_hash = analysis_release_sha256("functional_clusters-input"),
   131	    payload_hash = analysis_release_sha256("functional_clusters-payload"),
   132	    schema_version = "1.2",
   133	    reproducibility_hash = analysis_release_sha256("functional_clusters-repro"),
   134	    role = "layer"
   135	  )
   136	}
   137	
   138	#' Seed one release directly via the A3 repository (not the A4 build
   139	#' orchestrator -- mirrors A6's fixture style).
   140	seed_release <- function(conn, release_id, publish) {
   141	  payload_file <- make_gzip_file("functional_clusters/payload.json", paste0("{\"id\":\"", release_id, "\"}"))
   142	  manifest_file <- make_manifest_file(release_id, payload_file)
   143	  head <- make_release_head(release_id, manifest_file)
   144	  analysis_release_insert(head, list(make_member()), list(manifest_file, payload_file), conn)
   145	  if (isTRUE(publish)) {
   146	    analysis_release_publish(release_id, conn = conn)
   147	  }
   148	  head
   149	}
   150	
   151	#' A GENUINE pool::dbPool(), required by the build route's
   152	#' pool::poolCheckout(pool) -- mirrors test-integration-entity-rename.R's
   153	#' identically-named helper.
   154	make_test_pool <- function() {
   155	  test_config <- get_test_config()
   156	  pool::dbPool(
   157	    RMariaDB::MariaDB(),
   158	    dbname = test_config$dbname,
   159	    host = test_config$host,
   160	    user = test_config$user,
   161	    password = test_config$password,
   162	    port = as.integer(test_config$port)
   163	  )
   164	}
   165	
   166	# --------------------------------------------------------------------------- #
   167	# Handler extraction idiom
   168	# --------------------------------------------------------------------------- #
   169	
   170	release_endpoint_fake_res <- function() {
   171	  env <- new.env(parent = emptyenv())
   172	  env$status <- 200L
   173	  env$headers <- list()
   174	  env$setHeader <- function(name, value) {
   175	    env$headers[[name]] <- value
   176	    invisible(NULL)
   177	  }
   178	  env
   179	}
   180	
   181	release_admin_fake_req <- function(role = "Administrator", user_id = 42L, post_body = NULL) {
   182	  req <- new.env(parent = emptyenv())
   183	  req$user_role <- role
   184	  req$user_id <- user_id
   185	  req$postBody <- post_body
   186	  req$PATH_INFO <- "/api/admin/analysis/releases"
   187	  req
   188	}
   189	
   190	release_admin_handler <- function(decorator_regex) {
   191	  source(file.path("endpoints", "admin_analysis_snapshot_endpoints.R"), local = TRUE)
   192	
   193	  src <- readLines(file.path("endpoints", "admin_analysis_snapshot_endpoints.R"), warn = FALSE)
   194	  dec_idx <- grep(decorator_regex, src)[[1L]]
   195	  function_start <- dec_idx + which(grepl("^function\\(", src[dec_idx:length(src)]))[[1L]] - 1L
   196	  depth <- 0L
   197	  function_end <- function_start
   198	  for (idx in function_start:length(src)) {
   199	    depth <- depth +
   200	      lengths(regmatches(src[[idx]], gregexpr("\\{", src[[idx]], fixed = FALSE))) -
   201	      lengths(regmatches(src[[idx]], gregexpr("\\}", src[[idx]], fixed = FALSE)))
   202	    if (idx > function_start && depth == 0L) {
   203	      function_end <- idx
   204	      break
   205	    }
   206	  }
   207	
   208	  eval(parse(text = paste(src[function_start:function_end], collapse = "\n")))
   209	}
   210	
   211	#' Build a classed condition matching A4's `c(<name>, "error", "condition")`
   212	#' shape (functions/analysis-snapshot-release.R `.analysis_release_condition`).
   213	release_condition <- function(class_name, message) {
   214	  structure(class = c(class_name, "error", "condition"), list(message = message, call = NULL))
   215	}
   216	
   217	ADMIN_A7_DECORATORS <- list(
   218	  build = "^#\\*\\s+@post\\s+/releases\\s*$",
   219	  list = "^#\\*\\s+@get\\s+/releases\\s*$",
   220	  detail = "^#\\*\\s+@get\\s+/releases/<release_id>\\s*$",
   221	  publish = "^#\\*\\s+@post\\s+/releases/<release_id>/publish\\s*$",
   222	  doi = "^#\\*\\s+@patch\\s+/releases/<release_id>/doi\\s*$",
   223	  delete = "^#\\*\\s+@delete\\s+/releases/<release_id>\\s*$"
   224	)
   225	
   226	# =============================================================================
   227	# Role gate
   228	# =============================================================================
   229	
   230	test_that("all 6 admin release routes reject a non-Administrator request with error_403", {
   231	  for (dec in ADMIN_A7_DECORATORS) {
   232	    handler <- release_admin_handler(dec)
   233	    err <- tryCatch(
   234	      handler(req = release_admin_fake_req(role = "Viewer"), res = release_endpoint_fake_res()),
   235	      error = function(e) e
   236	    )
   237	    expect_s3_class(err, "error_403")
   238	  }
   239	})
   240	
   241	test_that("require_role lets an Administrator-role request through", {
   242	  passed <- tryCatch(
   243	    {
   244	      require_role(release_admin_fake_req(role = "Administrator"), release_endpoint_fake_res(), "Administrator")
   245	      TRUE
   246	    },
   247	    error = function(e) FALSE
   248	  )
   249	  expect_true(passed)
   250	})
   251	
   252	# =============================================================================
   253	# POST /releases (stubbed orchestrator)
   254	# =============================================================================
   255	
   256	test_that("POST /releases: 201 on a new build, 200 on an idempotent duplicate, 400 naming the failing layer on a gate error", {
   257	  skip_if_no_test_db()
   258	
   259	  admin_pool <- make_test_pool()
   260	  withr::defer(pool::poolClose(admin_pool))
   261	  assign("pool", admin_pool, envir = .GlobalEnv)
   262	  withr::defer(if (exists("pool", envir = .GlobalEnv, inherits = FALSE)) rm("pool", envir = .GlobalEnv))
   263	
   264	  build_handler <- release_admin_handler(ADMIN_A7_DECORATORS$build)
   265	  withr::defer(if (exists("analysis_snapshot_release_build", envir = .GlobalEnv, inherits = FALSE)) {
   266	    rm("analysis_snapshot_release_build", envir = .GlobalEnv)
   267	  })
   268	
   269	  # --- 201: newly created ---------------------------------------------------
   270	  head_new <- list(release_id = "asr_admin_new", status = "draft")
   271	  assign("analysis_snapshot_release_build", function(...) list(release = head_new, created = TRUE), envir = .GlobalEnv)
   272	  res_new <- release_endpoint_fake_res()
   273	  out_new <- build_handler(req = release_admin_fake_req(post_body = "{}"), res = res_new)
   274	  expect_equal(res_new$status, 201L)
   275	  expect_identical(out_new, head_new)
   276	
   277	  # --- 200: idempotent duplicate ---------------------------------------------
   278	  head_dup <- list(release_id = "asr_admin_dup", status = "published")
   279	  assign("analysis_snapshot_release_build", function(...) list(release = head_dup, created = FALSE), envir = .GlobalEnv)
   280	  res_dup <- release_endpoint_fake_res()
   281	  out_dup <- build_handler(req = release_admin_fake_req(post_body = "{}"), res = res_dup)
   282	  expect_equal(res_dup$status, 200L)
   283	  expect_identical(out_dup, head_dup)
   284	
   285	  # --- 400: gate failure, message names the failing layer --------------------
   286	  assign(
   287	    "analysis_snapshot_release_build",
   288	    function(...) {
   289	      stop(release_condition(
   290	        "release_snapshot_not_available",
   291	        "layer functional_clusters is not available for release: snapshot_stale"
   292	      ))
   293	    },
   294	    envir = .GlobalEnv
   295	  )
   296	  gate_err <- tryCatch(
   297	    build_handler(req = release_admin_fake_req(post_body = "{}"), res = release_endpoint_fake_res()),
   298	    error = function(e) e
   299	  )
   300	  expect_s3_class(gate_err, "error_400")
   301	  expect_match(conditionMessage(gate_err), "functional_clusters", fixed = TRUE)
   302	  expect_match(conditionMessage(gate_err), "snapshot_stale", fixed = TRUE)
   303	})
   304	
   305	test_that("POST /releases: a caller-supplied `layers` JSON body array parses as list-of-lists, never a data.frame", {
   306	  skip_if_no_test_db()
   307	
   308	  admin_pool <- make_test_pool()
   309	  withr::defer(pool::poolClose(admin_pool))
   310	  assign("pool", admin_pool, envir = .GlobalEnv)
   311	  withr::defer(if (exists("pool", envir = .GlobalEnv, inherits = FALSE)) rm("pool", envir = .GlobalEnv))
   312	
   313	  build_handler <- release_admin_handler(ADMIN_A7_DECORATORS$build)
   314	  withr::defer(if (exists("analysis_snapshot_release_build", envir = .GlobalEnv, inherits = FALSE)) {
   315	    rm("analysis_snapshot_release_build", envir = .GlobalEnv)
   316	  })
   317	
   318	  captured <- NULL
   319	  assign(
   320	    "analysis_snapshot_release_build",
   321	    function(...) {
   322	      captured <<- list(...)
   323	      list(release = list(release_id = "asr_admin_layers"), created = TRUE)
   324	    },
   325	    envir = .GlobalEnv
   326	  )
   327	
   328	  post_body <- paste0(
   329	    '{"title":"Manual build","publish":false,"layers":[',
   330	    '{"analysis_type":"functional_clusters","params":{"algorithm":"leiden"},',
   331	    '"files_prefix":"functional_clusters","has_reproducibility":true},',
   332	    '{"analysis_type":"phenotype_clusters","params":{},',
   333	    '"files_prefix":"phenotype_clusters","has_reproducibility":true}',
   334	    "]}"
   335	  )
   336	  build_handler(req = release_admin_fake_req(post_body = post_body), res = release_endpoint_fake_res())
   337	
   338	  expect_false(is.null(captured$layers))
   339	  expect_false(is.data.frame(captured$layers))
   340	  expect_type(captured$layers, "list")
   341	  expect_length(captured$layers, 2L)
   342	  expect_equal(captured$layers[[1]]$analysis_type, "functional_clusters")
   343	  expect_equal(captured$layers[[1]]$params$algorithm, "leiden")
   344	  expect_true(isTRUE(captured$layers[[1]]$has_reproducibility))
   345	  expect_equal(captured$layers[[2]]$analysis_type, "phenotype_clusters")
   346	  expect_length(captured$layers[[2]]$params, 0L) # jsonlite parses {} as a named empty list
   347	  expect_equal(captured$title, "Manual build")
   348	  expect_false(isTRUE(captured$publish))
   349	})
   350	
   351	test_that("POST /releases: an empty body omits `layers` (lets the orchestrator default apply) and defaults publish=TRUE/license", {
   352	  skip_if_no_test_db()
   353	
   354	  admin_pool <- make_test_pool()
   355	  withr::defer(pool::poolClose(admin_pool))
   356	  assign("pool", admin_pool, envir = .GlobalEnv)
   357	  withr::defer(if (exists("pool", envir = .GlobalEnv, inherits = FALSE)) rm("pool", envir = .GlobalEnv))
   358	
   359	  build_handler <- release_admin_handler(ADMIN_A7_DECORATORS$build)
   360	  withr::defer(if (exists("analysis_snapshot_release_build", envir = .GlobalEnv, inherits = FALSE)) {
   361	    rm("analysis_snapshot_release_build", envir = .GlobalEnv)
   362	  })
   363	
   364	  captured <- NULL
   365	  assign(
   366	    "analysis_snapshot_release_build",
   367	    function(...) {
   368	      captured <<- list(...)
   369	      list(release = list(release_id = "asr_admin_default"), created = TRUE)
   370	    },
   371	    envir = .GlobalEnv
   372	  )
   373	
   374	  build_handler(req = release_admin_fake_req(post_body = NULL), res = release_endpoint_fake_res())
   375	
   376	  expect_null(captured$layers)
   377	  expect_true(isTRUE(captured$publish))
   378	  expect_equal(captured$license, "CC-BY-4.0")
   379	  expect_equal(captured$created_by, 42L)
   380	})
   381	
   382	# =============================================================================
   383	# Admin lifecycle: list (incl. drafts), detail (incl. draft), publish,
   384	# DOI patch, delete
   385	# =============================================================================
   386	
   387	test_that("admin release lifecycle: list shows drafts, detail returns a draft, publish flips a draft, DOI patch is additive, delete refuses published/removes a draft", {
   388	  skip_if_no_test_db()
   389	
   390	  schema_conn <- get_test_db_connection()
   391	  ensure_test_release_schema(schema_conn)
   392	  DBI::dbDisconnect(schema_conn)
   393	
   394	  conn <- get_test_db_connection()
   395	  withr::defer(DBI::dbDisconnect(conn))
   396	  .delete_test_a7_releases(conn) # pre-clean any leftovers from a crashed run
   397	  withr::defer(.delete_test_a7_releases(conn)) # post-clean
   398	
   399	  admin_pool <- make_test_pool()
   400	  withr::defer(pool::poolClose(admin_pool))
   401	  assign("pool", admin_pool, envir = .GlobalEnv)
   402	  withr::defer(if (exists("pool", envir = .GlobalEnv, inherits = FALSE)) rm("pool", envir = .GlobalEnv))
   403	
   404	  seed_release(conn, TEST_PUBLISHED_RELEASE_ID, publish = TRUE)
   405	  seed_release(conn, TEST_DRAFT_PUBLISH_RELEASE_ID, publish = FALSE)
   406	  seed_release(conn, TEST_DRAFT_DELETE_RELEASE_ID, publish = FALSE)
   407	
   408	  admin_req <- release_admin_fake_req()
   409	
   410	  # =========================================================================
   411	  # GET /releases (admin): published AND both drafts appear
   412	  # =========================================================================
   413	  list_handler <- release_admin_handler(ADMIN_A7_DECORATORS$list)
   414	  list_result <- list_handler(req = admin_req, res = release_endpoint_fake_res())
   415	  listed_ids <- vapply(list_result$releases, function(r) as.character(r$release_id), character(1))
   416	  expect_true(TEST_PUBLISHED_RELEASE_ID %in% listed_ids)
   417	  expect_true(TEST_DRAFT_PUBLISH_RELEASE_ID %in% listed_ids)
   418	  expect_true(TEST_DRAFT_DELETE_RELEASE_ID %in% listed_ids)
   419	
   420	  # =========================================================================
   421	  # GET /releases/<release_id> (admin): a draft id returns the draft; unknown -> 404
   422	  # =========================================================================
   423	  detail_handler <- release_admin_handler(ADMIN_A7_DECORATORS$detail)
   424	  draft_detail <- detail_handler(
   425	    req = admin_req, res = release_endpoint_fake_res(), release_id = TEST_DRAFT_PUBLISH_RELEASE_ID
   426	  )
   427	  expect_equal(as.character(draft_detail$release_id), TEST_DRAFT_PUBLISH_RELEASE_ID)
   428	  expect_equal(as.character(draft_detail$status), "draft")
   429	
   430	  unknown_err <- tryCatch(
   431	    detail_handler(req = admin_req, res = release_endpoint_fake_res(), release_id = "asr_does_not_exist"),
   432	    error = function(e) e
   433	  )
   434	  expect_s3_class(unknown_err, "error_404")
   435	
   436	  # =========================================================================
   437	  # POST /releases/<release_id>/publish: flips a seeded draft
   438	  # =========================================================================
   439	  publish_handler <- release_admin_handler(ADMIN_A7_DECORATORS$publish)
   440	  published_result <- publish_handler(
   441	    req = admin_req, res = release_endpoint_fake_res(), release_id = TEST_DRAFT_PUBLISH_RELEASE_ID
   442	  )
   443	  expect_equal(as.character(published_result$status), "published")
   444	
   445	  reread_after_publish <- analysis_release_get(TEST_DRAFT_PUBLISH_RELEASE_ID, include_draft = TRUE, conn = conn)
   446	  expect_equal(as.character(reread_after_publish$status), "published")
   447	
   448	  # =========================================================================
   449	  # PATCH /releases/<release_id>/doi: additive, content_digest/manifest_sha256 unchanged
   450	  # =========================================================================
   451	  doi_handler <- release_admin_handler(ADMIN_A7_DECORATORS$doi)
   452	  before_doi <- analysis_release_get(TEST_PUBLISHED_RELEASE_ID, include_draft = TRUE, conn = conn)
   453	
   454	  doi_result <- doi_handler(
   455	    req = admin_req, res = release_endpoint_fake_res(),
   456	    release_id = TEST_PUBLISHED_RELEASE_ID,
   457	    version_doi = "10.5281/zenodo.999999"
   458	  )
   459	  expect_equal(as.character(doi_result$version_doi), "10.5281/zenodo.999999")
   460	  expect_equal(as.character(doi_result$content_digest), as.character(before_doi$content_digest))
   461	  expect_equal(as.character(doi_result$manifest_sha256), as.character(before_doi$manifest_sha256))
   462	  # only the supplied field was touched -- an omitted field stays unset, it
   463	  # is never nulled out by the partial update.
   464	  expect_true(is.na(doi_result$zenodo_record_id))
   465	
   466	  # =========================================================================
   467	  # DELETE /releases/<release_id>: refuses published, removes a draft
   468	  # =========================================================================
   469	  delete_handler <- release_admin_handler(ADMIN_A7_DECORATORS$delete)
   470	  published_delete_err <- tryCatch(
   471	    delete_handler(req = admin_req, res = release_endpoint_fake_res(), release_id = TEST_PUBLISHED_RELEASE_ID),
   472	    error = function(e) e
   473	  )
   474	  expect_s3_class(published_delete_err, "error_400")
   475	  expect_true(analysis_release_exists(TEST_PUBLISHED_RELEASE_ID, conn = conn))
   476	
   477	  draft_delete_result <- delete_handler(
   478	    req = admin_req, res = release_endpoint_fake_res(), release_id = TEST_DRAFT_DELETE_RELEASE_ID
   479	  )
   480	  expect_true(isTRUE(draft_delete_result$deleted))
   481	  expect_false(analysis_release_exists(TEST_DRAFT_DELETE_RELEASE_ID, conn = conn))
   482	
   483	  delete_unknown_err <- tryCatch(
   484	    delete_handler(req = admin_req, res = release_endpoint_fake_res(), release_id = "asr_does_not_exist"),
   485	    error = function(e) e
   486	  )
   487	  expect_s3_class(delete_unknown_err, "error_404")
   488	})

exec
/bin/bash -lc "rg -n -C 3 \"layers|override|fixed.*(layer|registry)|registry\" .planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md .planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md | head -260; nl -ba api/functions/analysis-snapshot-builder.R | sed -n '460,590p'; nl -ba api/tests/testthat/test-unit-cheap-route-isolation.R | sed -n '1,260p'; nl -ba api/tests/testthat/test-unit-admin-snapshot-endpoint-guard.R | sed -n '1,220p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-2-
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-3-> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-4-
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:5:**Goal:** Ship a read-only, immutable, content-addressed public "analysis-snapshot release" that pins the functional, phenotype, and phenotype-functional-correlation layers together with verifiable lineage and per-file SHA-256 checksums, plus a Zenodo operator archival path, a category-selected clustering submit (#574), and the #572 production lineage runbook.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-6-
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-7-**Architecture:** A release freezes canonical-JSON copies of the currently-active, coherent, lineage-verified public snapshots into three new DB tables (`analysis_snapshot_release`, `_member`, `_file`), identified by a content-addressed `release_id`. Admin builds synchronously (DB-only, fail-closed on incoherent/stale/mismatched sources); the public reads catalog/manifest/files/bundle retrieval-only. Mirrors the in-repo `nddscore_release` pattern and the `../nddscore` Zenodo flow.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-8-
--
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-152-**Interfaces:**
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-153-- Produces:
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-154-  - `ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION` (chr `"1.0"`)
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:155:  - `analysis_snapshot_release_layers()` → list of `list(analysis_type, params, files_prefix, has_reproducibility)` (default 3 manuscript layers).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-156-  - `analysis_release_canonical_bytes(obj)` → raw (UTF-8 of `analysis_snapshot_canonical_json(obj)`).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-157-  - `analysis_release_sha256(raw_or_chr)` → chr sha256 hex.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:158:  - `analysis_release_content_digest(layer_entries, source_data_version, manifest_schema_version)` → chr (identity basis; layers sorted internally by `analysis_type`).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-159-  - `analysis_release_id(content_digest)` → `paste0("asr_", substr(content_digest, 1, 16))` (64-bit readable handle; full digest stored separately).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:160:  - `analysis_release_build_manifest(list(release_id, release_version, title, created_at, license, scope_statement, generator, source, layers, files, content_digest))` → the manifest R list (files[] excludes manifest.json + checksums.sha256).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-161-  - `analysis_release_checksums_text(files)` → chr (`"<sha256>  <path>\n"` per file, excludes `checksums.sha256`).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-162-  - `analysis_release_build_tar_gz(named_raw_list)` → raw. Built **once** and stored; byte-level rebuild-determinism is not required (per-file checksums + manifest are the verification anchors). Use `utils::tar` on a temp dir with sorted paths + `memCompress(type="gzip")`, or a small ustar writer; keep it simple.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-163-
--
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-202-
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-203-- [ ] **Step 2: Run tests, expect FAIL** (`docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-analysis-snapshot-release-manifest.R')"` after `docker cp`, or host `Rscript` if the shim resolves).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-204-- [ ] **Step 3: Implement** `analysis-snapshot-release-manifest.R`. Key logic:
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:205:  - `analysis_release_content_digest`: sort `layer_entries` by `analysis_type`; build `list(manifest_schema_version, source_data_version, layers = lapply(sorted, \(e) e[c("analysis_type","input_hash","payload_hash","reproducibility_hash","dependencies")]))`; `analysis_release_sha256(analysis_release_canonical_bytes(that))`.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-206-  - `analysis_release_build_tar_gz`: write each named raw to a temp dir (sorted paths), `utils::tar(tarfile, files, compression="none")`, then `memCompress(readBin(tarfile,"raw",...), type="gzip")`. Byte-stable rebuilds are NOT required (bundle is stored once and served verbatim); the round-trip test above is the only contract.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-207-- [ ] **Step 4: Run tests, expect PASS.**
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-208-- [ ] **Step 5: Commit** — `feat(api): release manifest + deterministic archive helpers (#573)`.
--
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-239-
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-240-**Interfaces:**
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-241-- Consumes: `analysis_snapshot_get_public` + `analysis_snapshot_assert_partition_coherent` (hard coherence re-check) + `analysis_snapshot_get_reproducibility`, a **new** `analysis_reproducibility_decode_raw()` (raw pre-gzip bytes, added to `analysis-reproducibility.R`), manifest helpers (A2), release repository (A3).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:242:- Produces: `analysis_snapshot_release_build(layers = analysis_snapshot_release_layers(), title, scope_statement, license = "CC-BY-4.0", publish = TRUE, created_by = NULL, conn = NULL)` → `list(release = head, created = TRUE|FALSE)` (`created=FALSE` when an identical release already existed → idempotent).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-243-- Error contract: `stop()` with classed conditions the service maps to **HTTP 400** (`stop_for_bad_request`, since the contract has no 409 class): `release_snapshot_not_available` (carries the failing `analysis_type` + `status_code`), `release_source_incoherent`, `release_reproducibility_missing`, `release_source_version_mismatch`, `release_dependency_lineage_mismatch`. A duplicate build is **not** an error: it returns the existing head with `created=FALSE` (service → 200).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-244-
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-245-- [ ] **Step 1: Write failing tests** (build order + gates):
--
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-266-
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-267-test_that("build is idempotent by content (same snapshots -> same release_id, no duplicate row)", {
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-268-  with_test_db_transaction(function(conn) {
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:269:    # seed coherent public snapshots for the three layers ...
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-270-    r1 <- analysis_snapshot_release_build(conn = conn, publish = TRUE)
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-271-    expect_match(r1$release$release_id, "^asr_[0-9a-f]{16}$")
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-272-    expect_true(r1$created)
--
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-282-    r <- analysis_snapshot_release_build(conn = conn)$release
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-283-    rf <- analysis_release_get_file(r$release_id, "functional_clusters/reproducibility.json", include_draft = TRUE, conn = conn)
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-284-    manifest <- jsonlite::fromJSON(rawToChar(analysis_release_get_file(r$release_id, "manifest.json", include_draft = TRUE, conn = conn)$bytes), simplifyVector = FALSE)
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:285:    fc <- Filter(function(l) l$analysis_type == "functional_clusters", manifest$layers)[[1]]
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-286-    # exact equality holds for the reproducibility bundle (stored canonical bytes):
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-287-    expect_identical(rf$content_sha256, fc$reproducibility_hash)
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-288-    # payload_hash is recorded as the lineage anchor (matches the live meta.snapshot), NOT the payload.json file hash:
--
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-298-  1. For each layer: `snap <- analysis_snapshot_get_public(at, ph, conn)`; if `is.null(snap)` or `snap$status_code != "available"` → `stop(structure(class = c("release_snapshot_not_available","error","condition"), message = sprintf("layer %s not available: %s", at, snap$status_code %||% "snapshot_missing")))`.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-299-  1b. **Hard coherence re-check** per cluster layer: `available` does NOT prove coherence (the #514 gate can be `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false`). Re-run `analysis_snapshot_assert_partition_coherent(<snap membership>, <snap validation>, ..., require_coherence = TRUE)` — hard, ignoring the env — else `stop(class = "release_source_incoherent")`.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-300-  1c. **Reproducibility presence** per cluster layer: `repro <- analysis_snapshot_get_reproducibility(snapshot_id, conn)`; if empty or no `reproducibility_hash` → `stop(class = "release_reproducibility_missing")` (the builder is best-effort: a NULL bundle still activates the snapshot, but the release requires it).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:301:  2. Assert one shared `source_data_version` across layers (else `release_source_version_mismatch`); assert the correlation manifest's `dependencies` (`analysis_snapshot_manifest_dependencies`) equal the pinned functional+phenotype `{snapshot_id, payload_hash}` (else `release_dependency_lineage_mismatch`). Re-assert dependencies immediately before insert.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-302-  3. Materialize per-layer files:
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-303-     - `payload.json` bytes = `analysis_release_canonical_bytes(<stored payload rows>)`, where the rows are the layer-appropriate tibbles from `snap` (`clusters` + `cluster_members`; or `correlations`; or `network_nodes` + `network_edges`). This is the file's **own** content; `content_sha256` is its own hash (NOT `payload_hash`). Record the snapshot `payload_hash`/`input_hash`/`snapshot_id` in `layer_entries` as the **lineage anchor**.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:304:     - `reproducibility.json` bytes = the **exact pre-gzip string** `memDecompress(bundle_gzip_json, type = "gzip", asChar = TRUE)` (add helper `analysis_reproducibility_decode_raw()` to `analysis-reproducibility.R`). **Do NOT** use `analysis_reproducibility_decode()` — it runs `jsonlite::fromJSON()` and re-serialization drops the `digits = NA` precision, breaking the hash. Store/hash the raw bytes verbatim; assert `sha256(bytes) == reproducibility_hash` (test A4). Only for cluster layers.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-305-  4. Generate `README.md` bytes (scope + verify recipe).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-306-  5. Compute each file's `content_sha256` + `byte_size`; build `layer_entries` (`analysis_type`, `snapshot_id`, `parameter_hash`, `input_hash`, `payload_hash`, `reproducibility_hash`, `dependencies`).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-307-  6. `content_digest` → `release_id`; if `analysis_release_exists(release_id, conn)`: read the existing head; if its stored `content_digest` matches → **return `list(release = existing, created = FALSE)`** (idempotent); if it differs → `stop()` (500-level anomaly).
--
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-377-- [ ] **B1**: `releases.ts` client (`listReleases`, `getLatestRelease`, `getReleaseManifest(id)`, `getReleaseFileUrl(id,path)`, `downloadReleaseBundle(id)` via `apiClient.raw.get<Blob>(..., {responseType:'blob'})`) + `releases.spec.ts` (MSW), mirroring `about.ts`/`nddscore.ts`; unwrap via `unwrapScalar`, errors via `extractApiErrorMessage`.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-378-- [ ] **B2**: `DataReleases.vue` (`AnalysisShell` + `useHead`) with a releases `GenericTable` (flat keys) → `SectionCard`-wrapped `ReleaseManifestPanel.vue` (`<dl>` grid styled like `NddScoreModelCard.vue`: release_id, version, source_data_version, mono hashes + copy, per-layer snapshot_id+payload_hash, dependency lineage, DOI links) + download buttons + "How to verify" disclosure. View spec asserts render + download call.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-379-- [ ] **B3**: `routes.ts` public route `/DataReleases` (`meta.sitemap {priority:0.7, changefreq:'monthly'}`) + `main_nav_constants.ts` `analyses_dropdown` item + `routes.spec.ts` assertion.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:380:- [ ] **B4**: admin `ManageAnalysisReleases.vue` (build/publish/record-DOI + current-coherence status; disable build unless all layers `available`) using `AuthenticatedPageShell`.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-381-- [ ] **B5**: SEO — add `/DataReleases` to backend `/api/seo/routes` `static`; optional `buildReleaseSeo()` + `sitemap-releases.xml` + fixture; `make verify-seo-app`.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-382-- [ ] **B6**: gates `npm run type-check`, `npm run test:unit`, `make lint-app`; commit per task.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-383-
--
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-48-## 3. Goals / Non-goals
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-49-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-50-### Goals
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:51:- G1. A stable, immutable, content-addressed public release that pins the functional, phenotype, and phenotype-functional-correlation layers together with their dependency lineage and per-file SHA-256 checksums.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-52-- G2. Public read-only catalog, per-release manifest, per-file retrieval, and a single downloadable bundle via documented stable API URLs — retrieval-only (no compute, refresh, LLM, external calls, or writes).
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-53-- G3. Admin can build a release only from coherent, public-ready, non-stale, lineage-verified snapshots; a build from incoherent/stale/mismatched sources is rejected with a specific reason.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-54-- G4. A later snapshot refresh leaves every prior release **byte-identical** and publicly retrievable; releases are retained indefinitely.
--
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-95-| `bundle_sha256` | CHAR(64) | SHA-256 over the stored `bundle.tar.gz` bytes |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-96-| `bundle_gzip` | LONGBLOB | the frozen `bundle.tar.gz` bytes, served verbatim |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-97-| `bundle_bytes` | BIGINT | |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:98:| `source_data_version` | VARCHAR(128) | shared source-data version pinned across all layers |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-99-| `db_release_version` | VARCHAR(64) / `db_release_commit` VARCHAR(64) | human DB release label at build time |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-100-| `scope_statement` | TEXT | what is reproducible vs served-only |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-101-| `license` | VARCHAR(64) DEFAULT 'CC-BY-4.0' | |
--
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-117-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-118-## 6. Release identity, files, and manifest
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-119-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:120:**Layer registry** `analysis_snapshot_release_layers()` (new; single source of truth), default 3 manuscript layers, registry-driven so more can be added:
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-121-- `functional_clusters` (`{algorithm:"leiden"}`) → files `functional_clusters/payload.json`, `functional_clusters/reproducibility.json`
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-122-- `phenotype_clusters` (`{}`) → files `phenotype_clusters/payload.json`, `phenotype_clusters/reproducibility.json`
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:123:- `phenotype_functional_correlations` (`{algorithm:"leiden"}`) → file `phenotype_functional_correlations/payload.json` (+ its dependency lineage on the two cluster layers)
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-124-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-125-**File set per release** (canonical JSON; each file carries its own SHA-256):
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-126-- per-layer `payload.json` = the **complete** stored snapshot payload rows returned by `analysis_snapshot_get_public()` (all clusters + members, or correlation rows, or network nodes + edges — **not** a paginated GET page), serialized with `analysis_snapshot_canonical_json`. Its `content_sha256` is the **file's own hash** (verifies the download). It is **not** equal to the snapshot's `payload_hash`: `payload_hash` is computed over the in-memory build object *before* DB storage, and the child tables round-trip through `DECIMAL(8,7)`/`DECIMAL(8,5)` columns, so a reconstructed byte-for-byte match is neither guaranteed nor attempted. **Instead, `payload_hash` (and `input_hash`, `snapshot_id`) are recorded in the manifest as the cross-checkable lineage anchor** — a client verifies the release pins the exact snapshot the public API served by comparing them to the live `/api/analysis/*` `meta.snapshot.{payload_hash,input_hash,snapshot_id}`.
--
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-148-    "cluster_logic_version": "2026-07-06.510-expdb"
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-149-  },
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-150-  "source": { "source_data_version": "c41b5d8...", "db_release": { "version": "1.0.0", "commit": "..." } },
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:151:  "layers": [
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-152-    { "analysis_type": "functional_clusters", "parameter_hash": "ef3a...", "snapshot_id": 41,
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-153-      "schema_version": "1.2", "input_hash": "390e...", "payload_hash": "a142...",
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-154-      "reproducibility_hash": "...", "record_counts": {"members":2605,"clusters":18},
--
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-166-```
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-167-- `files[]` excludes `manifest.json` and `checksums.sha256` (Frictionless-style, mirrors `../nddscore` `datapackage.json`).
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-168-- `manifest_sha256` (row) = SHA-256 of the exact `manifest.json` bytes — served in LIST/HEAD so a client can verify the manifest itself.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:169:- `content_digest` = `sha256(canonical({ manifest_schema_version, source_data_version, layers:[sorted {analysis_type, input_hash, payload_hash, reproducibility_hash, dependencies}] }))`. **Excludes `created_at`, `title`, and DOI** so identity is a pure function of scientific content. The full 64-char `content_digest` is the true identity and is stored + in the manifest; `release_id = "asr_" + content_digest[:16]` (64-bit readable handle). Insert is guarded: if a row with that `release_id` exists but its stored `content_digest` differs (astronomically unlikely at 64 bits), the build fails loudly rather than colliding.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-170-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-171-## 7. Build path — `analysis_snapshot_release_build()` (admin, synchronous, DB-only)
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-172-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-173-New `api/functions/analysis-snapshot-release.R` (registered in `bootstrap/load_modules.R`) + service `api/services/analysis-snapshot-release-service.R`.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-174-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:175:1. **Load + gate each layer** under one read connection: for each registry layer, `analysis_snapshot_get_public(analysis_type, parameter_hash, conn)` and require `status_code == "available"`. Note `status_code` only checks **freshness/schema/source-version** (+ the #571 dependency gate for the correlation) — it does **not** re-run the #514 coherence gate, and that gate can be downgraded to a warning via `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false` at snapshot build. So `available` is necessary but **not** proof of coherence. Any `snapshot_missing | snapshot_stale | source_version_mismatch | schema_version_mismatch | dependency_snapshot_mismatch` → **reject build** with **HTTP 400** (`stop_for_bad_request`) whose `detail` names the failing `analysis_type` + `status_code`. (The existing error contract has only `error_400/401/403/404/500`; a "sources not ready" rejection is a 400, not a new 409 class — no error-handler change.)
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-176-2. **Hard coherence re-check (per cluster layer)**: independently re-assert partition coherence on the loaded snapshot with `analysis_snapshot_assert_partition_coherent(..., require_coherence = TRUE)` (membership cluster-set == validation cluster-set, channel match, per-cluster member-set equality), **ignoring** the env downgrade, so an incoherent-but-`public_ready` snapshot can never be frozen into a release. Failure → 400 `release_source_incoherent`.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-177-3. **Reproducibility presence (per cluster layer)**: require a stored reproducibility bundle (`analysis_snapshot_get_reproducibility(snapshot_id)` non-empty with a `reproducibility_hash`). The snapshot builder makes the bundle **best-effort** (a failed build returns `NULL` yet the snapshot still activates; `reproducibility_hash` is nullable), but the release makes `reproducibility.json` mandatory — so a missing bundle → 400 `release_reproducibility_missing`, never a crash or a non-reproducible release.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:178:4. **Cross-layer coherence** (belt-and-suspenders): assert all layers share one `source_data_version`; assert the correlation's stored `dependencies` point at exactly the pinned functional + phenotype `snapshot_id`+`payload_hash`. Mismatch → 400 with detail.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:179:5. **TOCTOU guard**: take the standard analysis-snapshot advisory lock (or read all layers within a single consistent transaction/`REPEATABLE READ` snapshot) so a concurrent axis refresh cannot swap an active snapshot between the per-layer reads and the dependency check. Re-assert the correlation's active dependencies immediately before insert.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-180-6. **Materialize files**: canonical-JSON of each layer's stored payload rows (own `content_sha256`) + the verbatim raw reproducibility bytes (`memDecompress(..., asChar = TRUE)`, **not** the parsing `decode()`); generate `README.md`; compute per-file `content_sha256` + `byte_size`.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-181-7. **Assemble manifest** (§6), compute `content_digest` → `release_id`. If a release with that `release_id` already exists → **idempotent HTTP 200** returning the existing head (content-addressed create is idempotent; identical sources never duplicate). A same-id row with a *different* stored `content_digest` (impossible short of a 64-bit collision) → 500 to surface the anomaly.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-182-8. **Build `checksums.sha256`** (over all files incl. `manifest.json`, excl. `checksums.sha256` itself) and the **`bundle.tar.gz`** (built once, stored); compute `manifest_sha256`, `bundle_sha256`.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-183-9. **Persist in one transaction**: insert release (status per `publish` flag), members, files. `DBI::dbBind` with `unname()`; blobs bound as `list(raw)`. Blob size is a few MB gzipped — well within `max_allowed_packet` (verify the dev value ≥ 16 MB; the migration/docs note the requirement).
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-184-10. Return the release head. **No external calls, no clustering recompute, no LLM, no cache writes.**
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-185-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:186:`POST /api/admin/analysis/releases` body: `{ layers?: [...], title?, scope_statement?, license?, publish?: true }` (default `publish:true`; `false` stages a draft for review before a Zenodo run). Administrator-gated.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-187-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-188-## 8. Public read routes (retrieval-only) — `analysis_endpoints.R` (`/api/analysis`, unauthenticated)
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-189-
--
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-191-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-192-| Route | Returns |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-193-|---|---|
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:194:| `GET /releases?limit=&offset=` | list of **published** releases: `{release_id, release_version, title, created_at, published_at, source_data_version, manifest_sha256, bundle_sha256, license, file_count, total_bytes, layers:[{analysis_type, snapshot_id, payload_hash}], zenodo:{record_url,version_doi,concept_doi}|null}` + pagination |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-195-| `GET /releases/latest` | newest published release head (same shape as detail) |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-196-| `GET /releases/<release_id>` | release head + full manifest object |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-197-| `GET /releases/<release_id>/manifest.json` | the **exact stored** `manifest.json` bytes (Content-Type `application/json`), so `sha256(bytes)==manifest_sha256` |
--
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-334-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-335-- **Deterministic tar**: base-R `utils::tar` is not deterministic by default → build the archive once at build time with sorted entries, `mtime=0`, `uid/gid=0`, mode `0644`, store the bytes, serve verbatim. (If R determinism is fiddly, the stored-once approach makes determinism moot; `bundle_sha256` is fixed regardless.)
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-336-- **Storage growth**: frozen copies cost a few MB/release; acceptable and bounded by manual, admin-initiated builds. No auto-build.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:337:- **Build cost**: synchronous admin op is DB-only and fast (copy + hash + gzip of a few MB). If it ever grows (more layers), it can move to a durable job; not needed for v1.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-338-- **Idempotency vs timestamps**: `content_digest` excludes `created_at` so identity is pure content; `created_at` is metadata only.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-339-- **DOI immutability**: DOI stored outside the hashed manifest so recording it never changes release bytes; the manifest is minted before Zenodo (no DOI inside), matching Zenodo's "DOI reserved only at publish" model.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-340-- **#574 scope creep**: kept to the async submit endpoint only; the fixed public GET is untouched; category GET stays `unsupported_parameter` until an explicit preset is built.
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
   571	        conn = txn_conn,
   572	        use_transaction = FALSE
   573	      )
   574	      pruned <- analysis_snapshot_prune(normalized$analysis_type, normalized$parameter_hash, conn = txn_conn)
   575	
   576	      list(snapshot_id = snapshot_id, pruned = pruned)
   577	    })
   578	    llm_generation <- analysis_snapshot_trigger_llm_generation(
   579	      normalized$analysis_type,
   580	      payload,
   581	      parent_job_id = job_id %||% write_result$snapshot_id,
   582	      conn = refresh_conn
   583	    )
   584	
   585	    list(
   586	      snapshot_id = write_result$snapshot_id,
   587	      analysis_type = normalized$analysis_type,
   588	      parameter_hash = normalized$parameter_hash,
   589	      status = "public_ready",
   590	      row_counts = row_counts,
     1	# tests/testthat/test-unit-cheap-route-isolation.R
     2	#
     3	# Static guard (#344): cheap routes (health, auth, statistics) must never call an
     4	# external provider fetcher, so a slow upstream cannot leak into their latency.
     5	# This locks in the categorical isolation the issue's acceptance criteria require.
     6	#
     7	# Pure test (no DB / no network) — runs on host.
     8	
     9	cheap_route_files <- c(
    10	  "health_endpoints.R",
    11	  "authentication_endpoints.R",
    12	  "statistics_endpoints.R"
    13	)
    14	
    15	test_that("cheap-route handlers never reference an external provider fetcher", {
    16	  edir <- file.path(get_api_dir(), "endpoints")
    17	  offenders <- character()
    18	  for (f in cheap_route_files) {
    19	    path <- file.path(edir, f)
    20	    if (!file.exists(path)) next
    21	    src <- readLines(path, warn = FALSE)
    22	    # Strip comment lines so a doc mention can't trip the guard.
    23	    src <- src[!grepl("^\\s*#", src)]
    24	    pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)"
    25	    hits <- grep(pattern, src, value = TRUE)
    26	    if (length(hits)) offenders <- c(offenders, paste0(f, ": ", trimws(hits)))
    27	  }
    28	  expect_identical(
    29	    offenders, character(),
    30	    info = paste(
    31	      "Cheap route calls an external fetcher (would couple its latency to a slow upstream):",
    32	      paste(offenders, collapse = " | ")
    33	    )
    34	  )
    35	})
    36	
    37	test_that("disease endpoint never references an external provider fetcher", {
    38	  path <- file.path(get_api_dir(), "endpoints", "disease_mapping_endpoints.R")
    39	  if (!file.exists(path)) skip("disease_mapping_endpoints.R not found")
    40	  src <- readLines(path, warn = FALSE)
    41	  src <- src[!grepl("^\\s*#", src)]
    42	  pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)"
    43	  hits <- grep(pattern, src, value = TRUE)
    44	  expect_identical(
    45	    hits, character(),
    46	    info = paste("disease endpoint calls an external fetcher:", paste(hits, collapse = " | "))
    47	  )
    48	})
    49	
    50	test_that("disease mapping repository never references an external provider fetcher", {
    51	  path <- file.path(get_api_dir(), "functions", "disease-ontology-mapping-repository.R")
    52	  if (!file.exists(path)) skip("disease-ontology-mapping-repository.R not found")
    53	  src <- readLines(path, warn = FALSE)
    54	  src <- src[!grepl("^\\s*#", src)]
    55	  pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)"
    56	  hits <- grep(pattern, src, value = TRUE)
    57	  expect_identical(
    58	    hits, character(),
    59	    info = paste("disease mapping repository calls an external fetcher:", paste(hits, collapse = " | "))
    60	  )
    61	})
    62	
    63	# Immutable analysis-snapshot RELEASES (#573 Slice A / Task A8). Both the
    64	# public read routes (`releases*` in analysis_endpoints.R) and the
    65	# Administrator build/publish/DOI/delete routes (admin_analysis_snapshot_
    66	# endpoints.R) only ever read/write the DB-only release tables added by
    67	# migration 045 -- they never call an external provider. Unlike the
    68	# whole-file checks above, `analysis_endpoints.R` and
    69	# admin_analysis_snapshot_endpoints.R also carry PRE-EXISTING non-release
    70	# routes, so this scans just the dedicated release function/service files
    71	# (which contain nothing but release logic) rather than the whole endpoint
    72	# files.
    73	release_source_files <- c(
    74	  "functions/analysis-snapshot-release-manifest.R",
    75	  "functions/analysis-snapshot-release-repository.R",
    76	  "functions/analysis-snapshot-release-materialize.R",
    77	  "functions/analysis-snapshot-release.R",
    78	  "services/analysis-snapshot-release-service.R"
    79	)
    80	
    81	test_that("analysis-snapshot release build/read files never reference an external provider fetcher", {
    82	  offenders <- character()
    83	  for (rel in release_source_files) {
    84	    path <- file.path(get_api_dir(), rel)
    85	    if (!file.exists(path)) next
    86	    src <- readLines(path, warn = FALSE)
    87	    src <- src[!grepl("^\\s*#", src)]
    88	    pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)|httr2::|make_external_request"
    89	    hits <- grep(pattern, src, value = TRUE)
    90	    if (length(hits)) offenders <- c(offenders, paste0(rel, ": ", trimws(hits)))
    91	  }
    92	  expect_identical(
    93	    offenders, character(),
    94	    info = paste(
    95	      "Analysis-snapshot release file calls an external fetcher (releases must stay DB-only):",
    96	      paste(offenders, collapse = " | ")
    97	    )
    98	  )
    99	})
   100	
   101	test_that("the public releases* routes in analysis_endpoints.R never reference an external provider fetcher", {
   102	  path <- file.path(get_api_dir(), "endpoints", "analysis_endpoints.R")
   103	  if (!file.exists(path)) skip("analysis_endpoints.R not found")
   104	  src <- readLines(path, warn = FALSE)
   105	  # Isolate the "RELEASES" section (bounded by its own header comment through
   106	  # end-of-file, since it is the last block in the file) so a pre-existing,
   107	  # non-release route elsewhere in this shared endpoint file cannot mask a
   108	  # release regression under an unrelated diff.
   109	  start <- grep("Analysis-snapshot RELEASES: public read routes", src)
   110	  if (length(start) == 0L) skip("releases section marker not found in analysis_endpoints.R")
   111	  section <- src[start[[1]]:length(src)]
   112	  section <- section[!grepl("^\\s*#", section)]
   113	  pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)|httr2::|make_external_request"
   114	  hits <- grep(pattern, section, value = TRUE)
   115	  expect_identical(
   116	    hits, character(),
   117	    info = paste("public releases* routes call an external fetcher:", paste(hits, collapse = " | "))
   118	  )
   119	})
   120	
   121	test_that("admin release routes in admin_analysis_snapshot_endpoints.R never reference an external provider fetcher", {
   122	  path <- file.path(get_api_dir(), "endpoints", "admin_analysis_snapshot_endpoints.R")
   123	  if (!file.exists(path)) skip("admin_analysis_snapshot_endpoints.R not found")
   124	  src <- readLines(path, warn = FALSE)
   125	  src <- src[!grepl("^\\s*#", src)]
   126	  pattern <- "external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)|httr2::|make_external_request"
   127	  hits <- grep(pattern, src, value = TRUE)
   128	  expect_identical(
   129	    hits, character(),
   130	    info = paste(
   131	      "admin_analysis_snapshot_endpoints.R (incl. release routes) calls an external fetcher:",
   132	      paste(hits, collapse = " | ")
   133	    )
   134	  )
   135	})
     1	# Static guard: the admin snapshot AND admin release endpoints must gate
     2	# every route on the Administrator role and must be mounted via
     3	# mount_endpoint() (#420 / #573 Slice A Task A7).
     4	
     5	# Resolve files relative to the API directory via the shared get_api_dir()
     6	# helper (helper-paths.R, auto-loaded by testthat), mirroring how
     7	# test-unit-endpoint-error-handler.R locates bootstrap/mount_endpoints.R.
     8	read_api_lines <- function(rel) {
     9	  path <- file.path(get_api_dir(), rel)
    10	  if (!file.exists(path)) stop(sprintf("cannot locate %s", path))
    11	  readLines(path, warn = FALSE)
    12	}
    13	
    14	test_that("both admin snapshot routes require the Administrator role", {
    15	  src <- read_api_lines("endpoints/admin_analysis_snapshot_endpoints.R")
    16	  joined <- paste(src, collapse = "\n")
    17	  expect_true(grepl("@post /snapshots/refresh", joined, fixed = TRUE))
    18	  expect_true(grepl("@get /snapshots/status", joined, fixed = TRUE))
    19	  role_gate <- grepl('require_role(req, res, "Administrator")', src, fixed = TRUE)
    20	  expect_gte(sum(role_gate), 2L)
    21	})
    22	
    23	test_that("all 6 admin analysis-release routes are declared and Administrator-gated", {
    24	  src <- read_api_lines("endpoints/admin_analysis_snapshot_endpoints.R")
    25	  joined <- paste(src, collapse = "\n")
    26	
    27	  expect_true(grepl("@post /releases", joined, fixed = TRUE))
    28	  expect_true(grepl("@get /releases", joined, fixed = TRUE))
    29	  expect_true(grepl("@get /releases/<release_id>", joined, fixed = TRUE))
    30	  expect_true(grepl("@post /releases/<release_id>/publish", joined, fixed = TRUE))
    31	  expect_true(grepl("@patch /releases/<release_id>/doi", joined, fixed = TRUE))
    32	  expect_true(grepl("@delete /releases/<release_id>", joined, fixed = TRUE))
    33	
    34	  # 2 pre-existing snapshot routes + 6 new release routes = at least 8 gates.
    35	  role_gate <- grepl('require_role(req, res, "Administrator")', src, fixed = TRUE)
    36	  expect_gte(sum(role_gate), 8L)
    37	})
    38	
    39	test_that("admin snapshot endpoint is mounted via mount_endpoint", {
    40	  src <- read_api_lines("bootstrap/mount_endpoints.R")
    41	  joined <- paste(src, collapse = "\n")
    42	  expect_true(grepl(
    43	    'pr_mount("/api/admin/analysis", mount_endpoint("endpoints/admin_analysis_snapshot_endpoints.R"))',
    44	    joined, fixed = TRUE
    45	  ))
    46	})

exec
/bin/bash -lc "rg -n -C 2 \"LIMIT \\? OFFSET \\?|limit_int.*min\\(|offset_int.*max\\(|as.integer\\(.*limit|pagination.*limit\" api/endpoints api/functions api/services -g '*.R' | head -260; rg -n \"analysis_release|release\" api/tests/testthat/test-unit-.*guard.R api/tests/testthat/test-integration-analysis-release-endpoints.R | head -280; nl -ba api/tests/testthat/test-integration-analysis-release-endpoints.R | sed -n '1,430p'; nl -ba api/functions/analysis-snapshot-release-repository.R | sed -n '100,190p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
api/services/mcp-service.R-106-mcp_validate_limit <- function(limit, default = 25L, max = 50L, name = "limit") {
api/services/mcp-service.R-107-  if (is.null(limit)) limit <- default
api/services/mcp-service.R:108:  limit <- suppressWarnings(as.integer(limit))
api/services/mcp-service.R-109-  if (is.na(limit) || limit < 1L || limit > max) {
api/services/mcp-service.R-110-    stop(mcp_error("invalid_input", sprintf("%s must be between 1 and %d", name, max), list(argument = name)))
--
api/services/admin-nddscore-endpoint-service.R-16-                                       release_fn = nddscore_repo_current_release,
api/services/admin-nddscore-endpoint-service.R-17-                                       history_fn = async_job_service_history) {
api/services/admin-nddscore-endpoint-service.R:18:  limit <- suppressWarnings(as.integer(limit))
api/services/admin-nddscore-endpoint-service.R-19-  if (is.na(limit) || limit < 1L) {
api/services/admin-nddscore-endpoint-service.R-20-    limit <- 10L
--
api/functions/llm-cache-admin-repository.R-182-     WHERE", where_clauses,
api/functions/llm-cache-admin-repository.R-183-    "ORDER BY created_at DESC
api/functions/llm-cache-admin-repository.R:184:     LIMIT ? OFFSET ?"
api/functions/llm-cache-admin-repository.R-185-  )
api/functions/llm-cache-admin-repository.R-186-  data_params <- append(params, list(per_page, offset))
--
api/functions/llm-cache-admin-repository.R-322-     WHERE", where_clauses,
api/functions/llm-cache-admin-repository.R-323-    "ORDER BY created_at DESC
api/functions/llm-cache-admin-repository.R:324:     LIMIT ? OFFSET ?"
api/functions/llm-cache-admin-repository.R-325-  )
api/functions/llm-cache-admin-repository.R-326-  data_params <- append(params, list(per_page, offset))
--
api/services/disease-ontology-mapping-service.R-163-#' @export
api/services/disease-ontology-mapping-service.R-164-service_disease_ontology_mapping_status <- function(query_fn = db_execute_query, limit = 5L) {
api/services/disease-ontology-mapping-service.R:165:  limit <- as.integer(limit)
api/services/disease-ontology-mapping-service.R-166-  rows <- tryCatch(
api/services/disease-ontology-mapping-service.R-167-    query_fn(
--
api/services/backup-endpoint-service.R-48-  # fall back to defaults. Clamp to reasonable bounds to prevent invalid slicing.
api/services/backup-endpoint-service.R-49-  page_size <- 20L
api/services/backup-endpoint-service.R:50:  limit_raw  <- suppressWarnings(as.integer(limit))
api/services/backup-endpoint-service.R-51-  offset_raw <- suppressWarnings(as.integer(offset))
api/services/backup-endpoint-service.R-52-
--
api/functions/pagination-helpers.R-134-paginate_offset <- function(data, limit = 50, offset = 0, base_url = NULL) {
api/functions/pagination-helpers.R-135-  # Coerce & validate
api/functions/pagination-helpers.R:136:  limit  <- suppressWarnings(as.integer(limit))
api/functions/pagination-helpers.R-137-  offset <- suppressWarnings(as.integer(offset))
api/functions/pagination-helpers.R-138-
--
api/services/job-query-endpoint-service.R-19-svc_job_get_history <- function(limit = 20) {
api/services/job-query-endpoint-service.R-20-  # Validate and constrain limit parameter
api/services/job-query-endpoint-service.R:21:  limit <- as.integer(limit)
api/services/job-query-endpoint-service.R-22-  if (is.na(limit) || limit < 1) {
api/services/job-query-endpoint-service.R-23-    limit <- 20
--
api/endpoints/admin_analysis_snapshot_endpoints.R-207-  list(
api/endpoints/admin_analysis_snapshot_endpoints.R-208-    releases = releases,
api/endpoints/admin_analysis_snapshot_endpoints.R:209:    pagination = list(limit = limit_int, offset = offset_int, count = length(releases))
api/endpoints/admin_analysis_snapshot_endpoints.R-210-  )
api/endpoints/admin_analysis_snapshot_endpoints.R-211-}
--
api/functions/async-job-service.R-382-async_job_service_history <- function(limit = 20L, include_result = FALSE, conn = NULL) {
api/functions/async-job-service.R-383-  args <- list(
api/functions/async-job-service.R:384:    limit = max(1L, as.integer(.async_job_service_scalar(limit, 20L))),
api/functions/async-job-service.R-385-    conn = conn
api/functions/async-job-service.R-386-  )
--
api/services/re-review-selection-service.R-375-     WHERE ", where_clause, "
api/services/re-review-selection-service.R-376-     ORDER BY r.review_date ASC, e.entity_id ASC
api/services/re-review-selection-service.R:377:     LIMIT ? OFFSET ?"
api/services/re-review-selection-service.R-378-  )
api/services/re-review-selection-service.R-379-  rows <- db_execute_query(data_sql, c(params, list(page_size, offset)), conn = pool)
--
api/endpoints/admin_publications_endpoints.R-41-    NULL
api/endpoints/admin_publications_endpoints.R-42-  } else {
api/endpoints/admin_publications_endpoints.R:43:    parsed <- suppressWarnings(as.integer(as.character(limit)[[1]]))
api/endpoints/admin_publications_endpoints.R-44-    if (is.na(parsed) || parsed < 1L) {
api/endpoints/admin_publications_endpoints.R-45-      stop_for_bad_request("limit must be a positive integer")
--
api/services/llm-admin-endpoint-service.R-134-}
api/services/llm-admin-endpoint-service.R-135-
api/services/llm-admin-endpoint-service.R:136:#' Resolve the legacy page/per_page pagination contract (D5 limit/offset
api/services/llm-admin-endpoint-service.R-137-#' aliases). Shared by the cache-summaries and generation-logs listings.
api/services/llm-admin-endpoint-service.R-138-#' @keywords internal
api/services/llm-admin-endpoint-service.R:139:.svc_llm_admin_resolve_pagination <- function(page, per_page, limit, offset) {
api/services/llm-admin-endpoint-service.R-140-  page_val     <- .svc_llm_admin_coerce_int(page)
api/services/llm-admin-endpoint-service.R-141-  per_page_val <- .svc_llm_admin_coerce_int(per_page)
--
api/services/llm-admin-endpoint-service.R-178-                                           page = NULL, per_page = NULL,
api/services/llm-admin-endpoint-service.R-179-                                           limit = NULL, offset = NULL) {
api/services/llm-admin-endpoint-service.R:180:  resolved <- .svc_llm_admin_resolve_pagination(page, per_page, limit, offset)
api/services/llm-admin-endpoint-service.R-181-
api/services/llm-admin-endpoint-service.R-182-  if (!is.null(cluster_type) && cluster_type == "") cluster_type <- NULL
--
api/services/llm-admin-endpoint-service.R-322-                                           page = NULL, per_page = NULL,
api/services/llm-admin-endpoint-service.R-323-                                           limit = NULL, offset = NULL) {
api/services/llm-admin-endpoint-service.R:324:  resolved <- .svc_llm_admin_resolve_pagination(page, per_page, limit, offset)
api/services/llm-admin-endpoint-service.R-325-
api/services/llm-admin-endpoint-service.R-326-  if (!is.null(cluster_type) && cluster_type == "") cluster_type <- NULL
--
api/functions/analysis-snapshot-release-repository.R-254-       FROM analysis_snapshot_release",
api/functions/analysis-snapshot-release-repository.R-255-    where_clause,
api/functions/analysis-snapshot-release-repository.R:256:    " ORDER BY created_at DESC LIMIT ? OFFSET ?"
api/functions/analysis-snapshot-release-repository.R-257-  )
api/functions/analysis-snapshot-release-repository.R:258:  params <- c(params, list(as.integer(limit), as.integer(offset)))
api/functions/analysis-snapshot-release-repository.R-259-  rows <- DBI::dbGetQuery(conn, sql, params = unname(params))
api/functions/analysis-snapshot-release-repository.R-260-  if (nrow(rows) == 0L) {
--
api/functions/publication-date-backfill.R-96-       OR p.publication_date_source NOT IN ('pubmed', 'pubmed_partial', 'medline_date', 'unknown')")
api/functions/publication-date-backfill.R-97-
api/functions/publication-date-backfill.R:98:  if (!is.null(limit) && !is.na(suppressWarnings(as.integer(limit)))) {
api/functions/publication-date-backfill.R:99:    linked <- utils::head(linked, as.integer(limit))
api/functions/publication-date-backfill.R-100-  }
api/functions/publication-date-backfill.R-101-  targeted <- nrow(linked)
--
api/functions/llm-cache-repository.R-459-     ORDER BY created_at DESC
api/functions/llm-cache-repository.R-460-     LIMIT ?",
api/functions/llm-cache-repository.R:461:    list(cluster_type, cluster_number, as.integer(limit))
api/functions/llm-cache-repository.R-462-  )
api/functions/llm-cache-repository.R-463-}
--
api/functions/mcp-repository.R-34-  tokens <- mcp_search_tokens(query)
api/functions/mcp-repository.R-35-  token_like <- paste0("%", tokens, "%")
api/functions/mcp-repository.R:36:  candidate_limit <- min(max(as.integer(limit) * 5L, as.integer(limit)), 125L)
api/functions/mcp-repository.R-37-  results <- list()
api/functions/mcp-repository.R-38-
--
api/functions/mcp-repository.R-252-      WHERE ", paste(filters, collapse = " AND "), "
api/functions/mcp-repository.R-253-      ORDER BY ev.symbol, ev.entity_id
api/functions/mcp-repository.R:254:      LIMIT ? OFFSET ?"
api/functions/mcp-repository.R-255-  )
api/functions/mcp-repository.R-256-  db_execute_query(sql, c(params, list(limit, offset)))
--
api/functions/mcp-repository.R-374-        AND (? IS NULL OR UPPER(rp.modifier_name) = UPPER(?))
api/functions/mcp-repository.R-375-      ORDER BY ev.symbol, ev.entity_id
api/functions/mcp-repository.R:376:      LIMIT ? OFFSET ?",
api/functions/mcp-repository.R-377-    list(phenotype, like, category, category, modifier, modifier, limit, offset)
api/functions/mcp-repository.R-378-  )
--
api/functions/mcp-repository.R-410-         OR UPPER(ev.disease_ontology_name) LIKE UPPER(?)
api/functions/mcp-repository.R-411-      ORDER BY ev.symbol, ev.entity_id
api/functions/mcp-repository.R:412:      LIMIT ? OFFSET ?",
api/functions/mcp-repository.R-413-    list(disease, like, limit, offset)
api/functions/mcp-repository.R-414-  )
--
api/functions/async-job-repository.R-586-#' @export
api/functions/async-job-repository.R-587-async_job_repository_history <- function(limit = 20L, include_result = FALSE, conn = NULL) {
api/functions/async-job-repository.R:588:  limit <- max(1L, as.integer(limit))
api/functions/async-job-repository.R-589-  sql <- paste(
api/functions/async-job-repository.R-590-    .async_job_build_select(include_result),
--
api/functions/nddscore-repository.R-310-    where_sql,
api/functions/nddscore-repository.R-311-    sprintf("ORDER BY %s %s, `rank` ASC, `hgnc_id` ASC", sort_spec$column, sort_spec$direction),
api/functions/nddscore-repository.R:312:    "LIMIT ? OFFSET ?"
api/functions/nddscore-repository.R-313-  )
api/functions/nddscore-repository.R-314-  data <- db_execute_query(
--
api/functions/nddscore-repository.R-452-      sort_spec$direction
api/functions/nddscore-repository.R-453-    ),
api/functions/nddscore-repository.R:454:    "LIMIT ? OFFSET ?"
api/functions/nddscore-repository.R-455-  )
api/functions/nddscore-repository.R-456-  data <- db_execute_query(
--
api/functions/mcp-analysis-repository.R-8-
api/functions/mcp-analysis-repository.R-9-mcp_analysis_repo_limit <- function(limit, default = 25L, max = 50L) {
api/functions/mcp-analysis-repository.R:10:  limit <- suppressWarnings(as.integer(limit))
api/functions/mcp-analysis-repository.R-11-  if (is.na(limit) || limit < 1L) return(default)
api/functions/mcp-analysis-repository.R-12-  min(limit, max)
--
api/functions/mcp-analysis-repository.R-123-              dominant_shap_group, top_features_json, prediction_note
api/functions/mcp-analysis-repository.R-124-         FROM mcp_public_nddscore_gene_prediction",
api/functions/mcp-analysis-repository.R:125:      where_sql, "ORDER BY", unname(sort_columns[[sort_name]]), direction, "LIMIT ? OFFSET ?"
api/functions/mcp-analysis-repository.R-126-    ),
api/functions/mcp-analysis-repository.R-127-    unname(c(params, list(page_size, offset)))
--
api/functions/mcp-analysis-repository.R-171-              pathogenicity_mode, `list`, version
api/functions/mcp-analysis-repository.R-172-         FROM mcp_public_comparison",
api/functions/mcp-analysis-repository.R:173:      filter$where, "ORDER BY hgnc_id, `list`, disease_ontology_id LIMIT ? OFFSET ?"
api/functions/mcp-analysis-repository.R-174-    ),
api/functions/mcp-analysis-repository.R-175-    unname(c(filter$params, list(page_size, offset)))
rg: api/tests/testthat/test-unit-.*guard.R: No such file or directory (os error 2)
api/tests/testthat/test-integration-analysis-release-endpoints.R:1:# tests/testthat/test-integration-analysis-release-endpoints.R
api/tests/testthat/test-integration-analysis-release-endpoints.R:4:# releases (#573 Slice A / Task A6): the 6 routes appended to
api/tests/testthat/test-integration-analysis-release-endpoints.R:5:# `endpoints/analysis_endpoints.R` -- releases, releases/latest,
api/tests/testthat/test-integration-analysis-release-endpoints.R:6:# releases/<release_id>, releases/<release_id>/manifest.json,
api/tests/testthat/test-integration-analysis-release-endpoints.R:7:# releases/<release_id>/file, releases/<release_id>/bundle.
api/tests/testthat/test-integration-analysis-release-endpoints.R:9:# Seeds a release DIRECTLY via the A3 repository (analysis_release_insert),
api/tests/testthat/test-integration-analysis-release-endpoints.R:12:# used by test-integration-analysis-snapshot-release-repository.R.
api/tests/testthat/test-integration-analysis-release-endpoints.R:15:# repository & build tests): analysis_release_insert() opens its own
api/tests/testthat/test-integration-analysis-release-endpoints.R:17:# with_test_db_transaction(); ensure_test_release_schema() applies DDL
api/tests/testthat/test-integration-analysis-release-endpoints.R:36:# (svc_release_*, analysis_release_*, stop_for_not_found, `pool`) is bound
api/tests/testthat/test-integration-analysis-release-endpoints.R:46:release_endpoint_test_wd <- getwd()
api/tests/testthat/test-integration-analysis-release-endpoints.R:48:withr::defer(setwd(release_endpoint_test_wd), testthat::teardown_env())
api/tests/testthat/test-integration-analysis-release-endpoints.R:50:release_a6_globals_before <- ls(envir = .GlobalEnv)
api/tests/testthat/test-integration-analysis-release-endpoints.R:53:source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = FALSE)
api/tests/testthat/test-integration-analysis-release-endpoints.R:54:source(file.path("functions", "analysis-snapshot-release-repository.R"), local = FALSE)
api/tests/testthat/test-integration-analysis-release-endpoints.R:55:source(file.path("services", "analysis-snapshot-release-service.R"), local = FALSE)
api/tests/testthat/test-integration-analysis-release-endpoints.R:56:release_a6_new_globals <- setdiff(ls(envir = .GlobalEnv), release_a6_globals_before)
api/tests/testthat/test-integration-analysis-release-endpoints.R:58:  rm(list = intersect(release_a6_new_globals, ls(envir = .GlobalEnv)), envir = .GlobalEnv),
api/tests/testthat/test-integration-analysis-release-endpoints.R:63:# Fixture builders (mirrors test-integration-analysis-snapshot-release-repository.R)
api/tests/testthat/test-integration-analysis-release-endpoints.R:69:.delete_test_a6_releases <- function(conn) {
api/tests/testthat/test-integration-analysis-release-endpoints.R:72:    "DELETE FROM analysis_snapshot_release WHERE release_id IN (?, ?)",
api/tests/testthat/test-integration-analysis-release-endpoints.R:81:    content_sha256 = analysis_release_sha256(raw_bytes),
api/tests/testthat/test-integration-analysis-release-endpoints.R:88:make_manifest_file <- function(release_id, payload_file) {
api/tests/testthat/test-integration-analysis-release-endpoints.R:90:    release_id = release_id,
api/tests/testthat/test-integration-analysis-release-endpoints.R:91:    release_version = "v1",
api/tests/testthat/test-integration-analysis-release-endpoints.R:101:make_release_head <- function(release_id, manifest_file) {
api/tests/testthat/test-integration-analysis-release-endpoints.R:102:  bundle_gzip <- memCompress(charToRaw(paste0("bundle contents for ", release_id)), type = "gzip")
api/tests/testthat/test-integration-analysis-release-endpoints.R:104:    release_id = release_id,
api/tests/testthat/test-integration-analysis-release-endpoints.R:105:    release_version = "v1",
api/tests/testthat/test-integration-analysis-release-endpoints.R:106:    title = "Test release",
api/tests/testthat/test-integration-analysis-release-endpoints.R:108:    content_digest = analysis_release_sha256(paste0("digest-", release_id)),
api/tests/testthat/test-integration-analysis-release-endpoints.R:113:    bundle_sha256 = analysis_release_sha256(bundle_gzip),
api/tests/testthat/test-integration-analysis-release-endpoints.R:123:    parameter_hash = analysis_release_sha256("functional_clusters-params"),
api/tests/testthat/test-integration-analysis-release-endpoints.R:125:    input_hash = analysis_release_sha256("functional_clusters-input"),
api/tests/testthat/test-integration-analysis-release-endpoints.R:126:    payload_hash = analysis_release_sha256("functional_clusters-payload"),
api/tests/testthat/test-integration-analysis-release-endpoints.R:128:    reproducibility_hash = analysis_release_sha256("functional_clusters-repro"),
api/tests/testthat/test-integration-analysis-release-endpoints.R:137:release_endpoint_fake_res <- function() {
api/tests/testthat/test-integration-analysis-release-endpoints.R:148:release_endpoint_handler <- function(decorator_regex) {
api/tests/testthat/test-integration-analysis-release-endpoints.R:169:test_that("public analysis-release read routes serve a published release and hide drafts", {
api/tests/testthat/test-integration-analysis-release-endpoints.R:173:  ensure_test_release_schema(schema_conn)
api/tests/testthat/test-integration-analysis-release-endpoints.R:178:  .delete_test_a6_releases(conn) # pre-clean any leftovers from a crashed run
api/tests/testthat/test-integration-analysis-release-endpoints.R:179:  withr::defer(.delete_test_a6_releases(conn)) # post-clean
api/tests/testthat/test-integration-analysis-release-endpoints.R:181:  # --- seed one published release: manifest.json + a layer payload + a
api/tests/testthat/test-integration-analysis-release-endpoints.R:187:  head <- make_release_head(TEST_RELEASE_ID, manifest_file)
api/tests/testthat/test-integration-analysis-release-endpoints.R:188:  analysis_release_insert(head, list(make_member()), list(manifest_file, payload_file, repro_file), conn)
api/tests/testthat/test-integration-analysis-release-endpoints.R:189:  expect_true(analysis_release_publish(TEST_RELEASE_ID, conn = conn))
api/tests/testthat/test-integration-analysis-release-endpoints.R:191:  # --- seed one DRAFT release (never published) -----------------------------
api/tests/testthat/test-integration-analysis-release-endpoints.R:194:  draft_head <- make_release_head(TEST_DRAFT_RELEASE_ID, draft_manifest_file)
api/tests/testthat/test-integration-analysis-release-endpoints.R:195:  analysis_release_insert(
api/tests/testthat/test-integration-analysis-release-endpoints.R:208:  # releases: lists the published release, hides the draft
api/tests/testthat/test-integration-analysis-release-endpoints.R:210:  list_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases\\s*$")
api/tests/testthat/test-integration-analysis-release-endpoints.R:211:  list_result <- list_handler(res = release_endpoint_fake_res())
api/tests/testthat/test-integration-analysis-release-endpoints.R:212:  listed_ids <- vapply(list_result$releases, function(r) as.character(r$release_id), character(1))
api/tests/testthat/test-integration-analysis-release-endpoints.R:217:  # releases/latest
api/tests/testthat/test-integration-analysis-release-endpoints.R:219:  latest_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/latest\\s*$")
api/tests/testthat/test-integration-analysis-release-endpoints.R:220:  latest_result <- latest_handler(res = release_endpoint_fake_res())
api/tests/testthat/test-integration-analysis-release-endpoints.R:221:  expect_equal(as.character(latest_result$release_id), TEST_RELEASE_ID)
api/tests/testthat/test-integration-analysis-release-endpoints.R:225:  # releases/<release_id>
api/tests/testthat/test-integration-analysis-release-endpoints.R:227:  detail_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>\\s*$")
api/tests/testthat/test-integration-analysis-release-endpoints.R:228:  detail_result <- detail_handler(release_id = TEST_RELEASE_ID, res = release_endpoint_fake_res())
api/tests/testthat/test-integration-analysis-release-endpoints.R:229:  expect_equal(as.character(detail_result$release_id), TEST_RELEASE_ID)
api/tests/testthat/test-integration-analysis-release-endpoints.R:230:  expect_equal(detail_result$manifest$release_id, TEST_RELEASE_ID)
api/tests/testthat/test-integration-analysis-release-endpoints.R:233:    detail_handler(release_id = "asr_does_not_exist", res = release_endpoint_fake_res()),
api/tests/testthat/test-integration-analysis-release-endpoints.R:239:    detail_handler(release_id = TEST_DRAFT_RELEASE_ID, res = release_endpoint_fake_res()),
api/tests/testthat/test-integration-analysis-release-endpoints.R:245:  # releases/<release_id>/manifest.json
api/tests/testthat/test-integration-analysis-release-endpoints.R:247:  manifest_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>/manifest\\.json\\s*$")
api/tests/testthat/test-integration-analysis-release-endpoints.R:248:  manifest_res <- release_endpoint_fake_res()
api/tests/testthat/test-integration-analysis-release-endpoints.R:249:  manifest_bytes <- manifest_handler(release_id = TEST_RELEASE_ID, res = manifest_res)
api/tests/testthat/test-integration-analysis-release-endpoints.R:250:  expect_equal(analysis_release_sha256(manifest_bytes), head$manifest_sha256)
api/tests/testthat/test-integration-analysis-release-endpoints.R:257:    manifest_handler(release_id = TEST_DRAFT_RELEASE_ID, res = release_endpoint_fake_res()),
api/tests/testthat/test-integration-analysis-release-endpoints.R:263:  # releases/<release_id>/file?path=...
api/tests/testthat/test-integration-analysis-release-endpoints.R:265:  file_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>/file\\s*$")
api/tests/testthat/test-integration-analysis-release-endpoints.R:266:  file_res <- release_endpoint_fake_res()
api/tests/testthat/test-integration-analysis-release-endpoints.R:268:    release_id = TEST_RELEASE_ID,
api/tests/testthat/test-integration-analysis-release-endpoints.R:274:  expect_equal(analysis_release_sha256(file_bytes), payload_file$content_sha256)
api/tests/testthat/test-integration-analysis-release-endpoints.R:282:  repro_res <- release_endpoint_fake_res()
api/tests/testthat/test-integration-analysis-release-endpoints.R:284:    release_id = TEST_RELEASE_ID,
api/tests/testthat/test-integration-analysis-release-endpoints.R:288:  expect_equal(analysis_release_sha256(repro_bytes), repro_file$content_sha256)
api/tests/testthat/test-integration-analysis-release-endpoints.R:291:    file_handler(release_id = TEST_RELEASE_ID, path = "does/not/exist.json", res = release_endpoint_fake_res()),
api/tests/testthat/test-integration-analysis-release-endpoints.R:298:      release_id = TEST_DRAFT_RELEASE_ID,
api/tests/testthat/test-integration-analysis-release-endpoints.R:300:      res = release_endpoint_fake_res()
api/tests/testthat/test-integration-analysis-release-endpoints.R:307:  # releases/<release_id>/bundle
api/tests/testthat/test-integration-analysis-release-endpoints.R:309:  bundle_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>/bundle\\s*$")
api/tests/testthat/test-integration-analysis-release-endpoints.R:310:  bundle_res <- release_endpoint_fake_res()
api/tests/testthat/test-integration-analysis-release-endpoints.R:311:  bundle_bytes <- bundle_handler(release_id = TEST_RELEASE_ID, res = bundle_res)
api/tests/testthat/test-integration-analysis-release-endpoints.R:313:  expect_equal(analysis_release_sha256(bundle_bytes), head$bundle_sha256)
api/tests/testthat/test-integration-analysis-release-endpoints.R:317:    bundle_handler(release_id = "asr_does_not_exist", res = release_endpoint_fake_res()),
api/tests/testthat/test-integration-analysis-release-endpoints.R:323:    bundle_handler(release_id = TEST_DRAFT_RELEASE_ID, res = release_endpoint_fake_res()),
api/tests/testthat/test-integration-analysis-release-endpoints.R:329:test_that("releases/latest is declared before releases/<release_id> (plumber declaration-order guard)", {
api/tests/testthat/test-integration-analysis-release-endpoints.R:331:  latest_idx <- grep("^#\\*\\s+@get\\s+releases/latest\\s*$", src)
api/tests/testthat/test-integration-analysis-release-endpoints.R:332:  detail_idx <- grep("^#\\*\\s+@get\\s+releases/<release_id>\\s*$", src)
api/tests/testthat/test-integration-analysis-release-endpoints.R:339:test_that("byte-serving release routes set Content-Type via the serializer, never a duplicate manual header", {
api/tests/testthat/test-integration-analysis-release-endpoints.R:350:  # No release route may manually set Content-Type (it duplicates the serializer's).
api/tests/testthat/test-integration-analysis-release-endpoints.R:353:    info = "a release byte-route sets Content-Type manually -> duplicate header"
     1	# tests/testthat/test-integration-analysis-release-endpoints.R
     2	#
     3	# Integration tests for the PUBLIC read routes of immutable analysis-snapshot
     4	# releases (#573 Slice A / Task A6): the 6 routes appended to
     5	# `endpoints/analysis_endpoints.R` -- releases, releases/latest,
     6	# releases/<release_id>, releases/<release_id>/manifest.json,
     7	# releases/<release_id>/file, releases/<release_id>/bundle.
     8	#
     9	# Seeds a release DIRECTLY via the A3 repository (analysis_release_insert),
    10	# NOT the A4 build orchestrator, to avoid needing the (very complex)
    11	# analysis_snapshot_* source tables -- mirrors the fixture style already
    12	# used by test-integration-analysis-snapshot-release-repository.R.
    13	#
    14	# DDL / transaction traps (verified live against RMariaDB, same as the A3/A4
    15	# repository & build tests): analysis_release_insert() opens its own
    16	# DBI::dbWithTransaction() and cannot be nested inside
    17	# with_test_db_transaction(); ensure_test_release_schema() applies DDL
    18	# (auto-commits) on its OWN short-lived connection first. So this file uses a
    19	# single plain connection for the whole test and cleans up via DELETE
    20	# (children cascade via the migration's ON DELETE CASCADE FKs), never
    21	# with_test_db_transaction().
    22	#
    23	# Handler-extraction idiom (mirrors test-endpoint-analysis-snapshot-read.R,
    24	# which is NOT a helper-*.R file so is not auto-loaded -- this file keeps its
    25	# own copy): each route handler is extracted from
    26	# endpoints/analysis_endpoints.R by decorator regex + brace-depth scan, then
    27	# eval()'d and called directly with a fake `res` -- no live plumber router
    28	# needed. The extracted closure's enclosing environment is the (per-call,
    29	# throwaway) frame the extraction helper sources `analysis_endpoints.R`
    30	# into, whose lexical PARENT is wherever the extraction helper itself was
    31	# DEFINED (this file's own top level) -- a `source(x, local = TRUE)` inside a
    32	# `test_that()` block does NOT land on that chain (verified empirically: a
    33	# test_that()-local source() is invisible to a sibling top-level closure).
    34	# So, exactly like the reference file's `assign(..., envir = .GlobalEnv)`
    35	# pattern, every free variable an extracted handler references at call time
    36	# (svc_release_*, analysis_release_*, stop_for_not_found, `pool`) is bound
    37	# straight into `.GlobalEnv` here via base `source(file, local = FALSE)` --
    38	# every environment chain in R eventually passes through `.GlobalEnv`, so
    39	# this is reachable regardless of exactly which frame testthat runs the
    40	# test_that() block in. `pool` mirrors the production endpoint's `conn =
    41	# pool` global (see endpoints/seo_endpoints.R), bound to the SAME real
    42	# test-DB connection used to seed the fixture. Newly-added globals are
    43	# removed again on teardown so they don't leak into sibling test files in a
    44	# full-suite run.
    45	
    46	release_endpoint_test_wd <- getwd()
    47	setwd(get_api_dir())
    48	withr::defer(setwd(release_endpoint_test_wd), testthat::teardown_env())
    49	
    50	release_a6_globals_before <- ls(envir = .GlobalEnv)
    51	source(file.path("core", "errors.R"), local = FALSE)
    52	source(file.path("functions", "analysis-snapshot-presets.R"), local = FALSE)
    53	source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = FALSE)
    54	source(file.path("functions", "analysis-snapshot-release-repository.R"), local = FALSE)
    55	source(file.path("services", "analysis-snapshot-release-service.R"), local = FALSE)
    56	release_a6_new_globals <- setdiff(ls(envir = .GlobalEnv), release_a6_globals_before)
    57	withr::defer(
    58	  rm(list = intersect(release_a6_new_globals, ls(envir = .GlobalEnv)), envir = .GlobalEnv),
    59	  testthat::teardown_env()
    60	)
    61	
    62	# --------------------------------------------------------------------------- #
    63	# Fixture builders (mirrors test-integration-analysis-snapshot-release-repository.R)
    64	# --------------------------------------------------------------------------- #
    65	
    66	TEST_RELEASE_ID <- "asr_test0000000601"
    67	TEST_DRAFT_RELEASE_ID <- "asr_test0000000602"
    68	
    69	.delete_test_a6_releases <- function(conn) {
    70	  DBI::dbExecute(
    71	    conn,
    72	    "DELETE FROM analysis_snapshot_release WHERE release_id IN (?, ?)",
    73	    params = unname(list(TEST_RELEASE_ID, TEST_DRAFT_RELEASE_ID))
    74	  )
    75	}
    76	
    77	make_gzip_file <- function(file_path, text, media_type = "application/json") {
    78	  raw_bytes <- charToRaw(text)
    79	  list(
    80	    file_path = file_path,
    81	    content_sha256 = analysis_release_sha256(raw_bytes),
    82	    byte_size = length(raw_bytes),
    83	    media_type = media_type,
    84	    content_gzip = memCompress(raw_bytes, type = "gzip")
    85	  )
    86	}
    87	
    88	make_manifest_file <- function(release_id, payload_file) {
    89	  manifest_json <- analysis_snapshot_canonical_json(list(
    90	    release_id = release_id,
    91	    release_version = "v1",
    92	    files = list(list(
    93	      path = payload_file$file_path,
    94	      sha256 = payload_file$content_sha256,
    95	      bytes = payload_file$byte_size
    96	    ))
    97	  ))
    98	  make_gzip_file("manifest.json", manifest_json)
    99	}
   100	
   101	make_release_head <- function(release_id, manifest_file) {
   102	  bundle_gzip <- memCompress(charToRaw(paste0("bundle contents for ", release_id)), type = "gzip")
   103	  list(
   104	    release_id = release_id,
   105	    release_version = "v1",
   106	    title = "Test release",
   107	    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
   108	    content_digest = analysis_release_sha256(paste0("digest-", release_id)),
   109	    # manifest_sha256 MUST equal the manifest.json FILE's own content_sha256
   110	    # (it is the checksum of that file's bytes) -- reusing it directly here
   111	    # keeps the fixture internally consistent by construction.
   112	    manifest_sha256 = manifest_file$content_sha256,
   113	    bundle_sha256 = analysis_release_sha256(bundle_gzip),
   114	    bundle_gzip = bundle_gzip,
   115	    source_data_version = "srcv1",
   116	    license = "CC-BY-4.0"
   117	  )
   118	}
   119	
   120	make_member <- function() {
   121	  list(
   122	    analysis_type = "functional_clusters",
   123	    parameter_hash = analysis_release_sha256("functional_clusters-params"),
   124	    snapshot_id = 601L,
   125	    input_hash = analysis_release_sha256("functional_clusters-input"),
   126	    payload_hash = analysis_release_sha256("functional_clusters-payload"),
   127	    schema_version = "1.2",
   128	    reproducibility_hash = analysis_release_sha256("functional_clusters-repro"),
   129	    role = "layer"
   130	  )
   131	}
   132	
   133	# --------------------------------------------------------------------------- #
   134	# Handler extraction idiom (copied from test-endpoint-analysis-snapshot-read.R)
   135	# --------------------------------------------------------------------------- #
   136	
   137	release_endpoint_fake_res <- function() {
   138	  env <- new.env(parent = emptyenv())
   139	  env$status <- 200L
   140	  env$headers <- list()
   141	  env$setHeader <- function(name, value) {
   142	    env$headers[[name]] <- value
   143	    invisible(NULL)
   144	  }
   145	  env
   146	}
   147	
   148	release_endpoint_handler <- function(decorator_regex) {
   149	  source(file.path("endpoints", "analysis_endpoints.R"), local = TRUE)
   150	
   151	  src <- readLines(file.path("endpoints", "analysis_endpoints.R"), warn = FALSE)
   152	  dec_idx <- grep(decorator_regex, src)[[1L]]
   153	  function_start <- dec_idx + which(grepl("^function\\(", src[dec_idx:length(src)]))[[1L]] - 1L
   154	  depth <- 0L
   155	  function_end <- function_start
   156	  for (idx in function_start:length(src)) {
   157	    depth <- depth +
   158	      lengths(regmatches(src[[idx]], gregexpr("\\{", src[[idx]], fixed = FALSE))) -
   159	      lengths(regmatches(src[[idx]], gregexpr("\\}", src[[idx]], fixed = FALSE)))
   160	    if (idx > function_start && depth == 0L) {
   161	      function_end <- idx
   162	      break
   163	    }
   164	  }
   165	
   166	  eval(parse(text = paste(src[function_start:function_end], collapse = "\n")))
   167	}
   168	
   169	test_that("public analysis-release read routes serve a published release and hide drafts", {
   170	  skip_if_no_test_db()
   171	
   172	  schema_conn <- get_test_db_connection()
   173	  ensure_test_release_schema(schema_conn)
   174	  DBI::dbDisconnect(schema_conn)
   175	
   176	  conn <- get_test_db_connection()
   177	  withr::defer(DBI::dbDisconnect(conn))
   178	  .delete_test_a6_releases(conn) # pre-clean any leftovers from a crashed run
   179	  withr::defer(.delete_test_a6_releases(conn)) # post-clean
   180	
   181	  # --- seed one published release: manifest.json + a layer payload + a
   182	  #     reproducibility.json (the brief's own worked path example) ---------
   183	  payload_text <- "{\"a\":1}"
   184	  payload_file <- make_gzip_file("functional_clusters/payload.json", payload_text)
   185	  repro_file <- make_gzip_file("functional_clusters/reproducibility.json", "{\"modularity\":0.42}")
   186	  manifest_file <- make_manifest_file(TEST_RELEASE_ID, payload_file)
   187	  head <- make_release_head(TEST_RELEASE_ID, manifest_file)
   188	  analysis_release_insert(head, list(make_member()), list(manifest_file, payload_file, repro_file), conn)
   189	  expect_true(analysis_release_publish(TEST_RELEASE_ID, conn = conn))
   190	
   191	  # --- seed one DRAFT release (never published) -----------------------------
   192	  draft_payload_file <- make_gzip_file("functional_clusters/payload.json", "{\"draft\":true}")
   193	  draft_manifest_file <- make_manifest_file(TEST_DRAFT_RELEASE_ID, draft_payload_file)
   194	  draft_head <- make_release_head(TEST_DRAFT_RELEASE_ID, draft_manifest_file)
   195	  analysis_release_insert(
   196	    draft_head, list(make_member()),
   197	    list(draft_manifest_file, draft_payload_file), conn
   198	  )
   199	  # deliberately never published -- stays status='draft'
   200	
   201	  # Bind the global `pool` the handlers reference (mirrors
   202	  # endpoints/seo_endpoints.R's `conn = pool` production pattern). MUST land
   203	  # in .GlobalEnv -- see the file-header comment for why.
   204	  assign("pool", conn, envir = .GlobalEnv)
   205	  withr::defer(if (exists("pool", envir = .GlobalEnv, inherits = FALSE)) rm("pool", envir = .GlobalEnv))
   206	
   207	  # =========================================================================
   208	  # releases: lists the published release, hides the draft
   209	  # =========================================================================
   210	  list_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases\\s*$")
   211	  list_result <- list_handler(res = release_endpoint_fake_res())
   212	  listed_ids <- vapply(list_result$releases, function(r) as.character(r$release_id), character(1))
   213	  expect_true(TEST_RELEASE_ID %in% listed_ids)
   214	  expect_false(TEST_DRAFT_RELEASE_ID %in% listed_ids)
   215	
   216	  # =========================================================================
   217	  # releases/latest
   218	  # =========================================================================
   219	  latest_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/latest\\s*$")
   220	  latest_result <- latest_handler(res = release_endpoint_fake_res())
   221	  expect_equal(as.character(latest_result$release_id), TEST_RELEASE_ID)
   222	  expect_false(is.null(latest_result$manifest))
   223	
   224	  # =========================================================================
   225	  # releases/<release_id>
   226	  # =========================================================================
   227	  detail_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>\\s*$")
   228	  detail_result <- detail_handler(release_id = TEST_RELEASE_ID, res = release_endpoint_fake_res())
   229	  expect_equal(as.character(detail_result$release_id), TEST_RELEASE_ID)
   230	  expect_equal(detail_result$manifest$release_id, TEST_RELEASE_ID)
   231	
   232	  unknown_err <- tryCatch(
   233	    detail_handler(release_id = "asr_does_not_exist", res = release_endpoint_fake_res()),
   234	    error = function(e) e
   235	  )
   236	  expect_s3_class(unknown_err, "error_404")
   237	
   238	  draft_err <- tryCatch(
   239	    detail_handler(release_id = TEST_DRAFT_RELEASE_ID, res = release_endpoint_fake_res()),
   240	    error = function(e) e
   241	  )
   242	  expect_s3_class(draft_err, "error_404")
   243	
   244	  # =========================================================================
   245	  # releases/<release_id>/manifest.json
   246	  # =========================================================================
   247	  manifest_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>/manifest\\.json\\s*$")
   248	  manifest_res <- release_endpoint_fake_res()
   249	  manifest_bytes <- manifest_handler(release_id = TEST_RELEASE_ID, res = manifest_res)
   250	  expect_equal(analysis_release_sha256(manifest_bytes), head$manifest_sha256)
   251	  # Content-Type (application/json) is set by the octet serializer annotation,
   252	  # not a manual header (see the duplicate-header regression guard below); the
   253	  # handler-extraction harness does not run the serializer, so the live
   254	  # dev-stack check + the static guard verify the header.
   255	
   256	  manifest_draft_err <- tryCatch(
   257	    manifest_handler(release_id = TEST_DRAFT_RELEASE_ID, res = release_endpoint_fake_res()),
   258	    error = function(e) e
   259	  )
   260	  expect_s3_class(manifest_draft_err, "error_404")
   261	
   262	  # =========================================================================
   263	  # releases/<release_id>/file?path=...
   264	  # =========================================================================
   265	  file_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>/file\\s*$")
   266	  file_res <- release_endpoint_fake_res()
   267	  file_bytes <- file_handler(
   268	    release_id = TEST_RELEASE_ID,
   269	    path = "functional_clusters/payload.json",
   270	    res = file_res
   271	  )
   272	  # the FILE's own content_sha256 (matches the manifest files[] entry),
   273	  # NOT the layer's snapshot payload_hash.
   274	  expect_equal(analysis_release_sha256(file_bytes), payload_file$content_sha256)
   275	  # The per-file route sets its (per-file) media type by assigning a dynamic
   276	  # octet serializer to res$serializer (avoiding a duplicate Content-Type); the
   277	  # handler-extraction harness can at least confirm the handler installed it.
   278	  expect_true(is.function(file_res$serializer))
   279	
   280	  # the brief's own worked path example (functional_clusters/reproducibility.json):
   281	  # same arbitrary-path -> own content_sha256 mechanism, a different file.
   282	  repro_res <- release_endpoint_fake_res()
   283	  repro_bytes <- file_handler(
   284	    release_id = TEST_RELEASE_ID,
   285	    path = "functional_clusters/reproducibility.json",
   286	    res = repro_res
   287	  )
   288	  expect_equal(analysis_release_sha256(repro_bytes), repro_file$content_sha256)
   289	
   290	  garbage_err <- tryCatch(
   291	    file_handler(release_id = TEST_RELEASE_ID, path = "does/not/exist.json", res = release_endpoint_fake_res()),
   292	    error = function(e) e
   293	  )
   294	  expect_s3_class(garbage_err, "error_404")
   295	
   296	  file_draft_err <- tryCatch(
   297	    file_handler(
   298	      release_id = TEST_DRAFT_RELEASE_ID,
   299	      path = "functional_clusters/payload.json",
   300	      res = release_endpoint_fake_res()
   301	    ),
   302	    error = function(e) e
   303	  )
   304	  expect_s3_class(file_draft_err, "error_404")
   305	
   306	  # =========================================================================
   307	  # releases/<release_id>/bundle
   308	  # =========================================================================
   309	  bundle_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>/bundle\\s*$")
   310	  bundle_res <- release_endpoint_fake_res()
   311	  bundle_bytes <- bundle_handler(release_id = TEST_RELEASE_ID, res = bundle_res)
   312	  expect_identical(bundle_bytes, head$bundle_gzip)
   313	  expect_equal(analysis_release_sha256(bundle_bytes), head$bundle_sha256)
   314	  expect_match(bundle_res$headers[["Content-Disposition"]], "^attachment")
   315	
   316	  bundle_unknown_err <- tryCatch(
   317	    bundle_handler(release_id = "asr_does_not_exist", res = release_endpoint_fake_res()),
   318	    error = function(e) e
   319	  )
   320	  expect_s3_class(bundle_unknown_err, "error_404")
   321	
   322	  bundle_draft_err <- tryCatch(
   323	    bundle_handler(release_id = TEST_DRAFT_RELEASE_ID, res = release_endpoint_fake_res()),
   324	    error = function(e) e
   325	  )
   326	  expect_s3_class(bundle_draft_err, "error_404")
   327	})
   328	
   329	test_that("releases/latest is declared before releases/<release_id> (plumber declaration-order guard)", {
   330	  src <- readLines(file.path("endpoints", "analysis_endpoints.R"), warn = FALSE)
   331	  latest_idx <- grep("^#\\*\\s+@get\\s+releases/latest\\s*$", src)
   332	  detail_idx <- grep("^#\\*\\s+@get\\s+releases/<release_id>\\s*$", src)
   333	
   334	  expect_length(latest_idx, 1L)
   335	  expect_length(detail_idx, 1L)
   336	  expect_lt(latest_idx[[1L]], detail_idx[[1L]])
   337	})
   338	
   339	test_that("byte-serving release routes set Content-Type via the serializer, never a duplicate manual header", {
   340	  # Regression guard (found in live dev-stack verification): combining
   341	  # `@serializer octet` with a manual res$setHeader("Content-Type", ...) emits
   342	  # TWO Content-Type headers (the serializer's application/octet-stream + the
   343	  # manual one). The routes must instead set the type THROUGH the serializer:
   344	  # a static `@serializer octet list(type = ...)` for manifest.json/bundle, and
   345	  # a dynamic res$serializer for the per-file route. The handler-extraction
   346	  # tests above cannot observe serializer output, so this scans the source.
   347	  src <- readLines(file.path("endpoints", "analysis_endpoints.R"), warn = FALSE)
   348	  joined <- paste(src, collapse = "\n")
   349	
   350	  # No release route may manually set Content-Type (it duplicates the serializer's).
   351	  expect_false(
   352	    any(grepl("setHeader\\(\\s*[\"']Content-Type[\"']", src)),
   353	    info = "a release byte-route sets Content-Type manually -> duplicate header"
   354	  )
   355	  # manifest.json + bundle carry the type on the serializer annotation.
   356	  expect_true(grepl('@serializer octet list(type = "application/json")', joined, fixed = TRUE))
   357	  expect_true(grepl('@serializer octet list(type = "application/gzip")', joined, fixed = TRUE))
   358	  # The per-file route sets its (per-file) type dynamically on res$serializer.
   359	  expect_true(grepl("res$serializer <- plumber::serializer_octet(type = content$media_type)", joined, fixed = TRUE))
   360	})
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

exec
/bin/bash -lc "rg -n -C 4 \"path.*travers|files_prefix|has_reproducibility|layer.*valid|validate.*layer|release layers|optional.*layers\" .planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md .planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md api/tests/testthat/test-integration-analysis-snapshot-release-build.R api/tests/testthat/test-integration-analysis-release-admin-endpoints.R && nl -ba .planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md | sed -n '118,190p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a
 succeeded in 0ms:
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-327-
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-328-  post_body <- paste0(
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-329-    '{"title":"Manual build","publish":false,"layers":[',
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-330-    '{"analysis_type":"functional_clusters","params":{"algorithm":"leiden"},',
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:331:    '"files_prefix":"functional_clusters","has_reproducibility":true},',
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-332-    '{"analysis_type":"phenotype_clusters","params":{},',
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:333:    '"files_prefix":"phenotype_clusters","has_reproducibility":true}',
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-334-    "]}"
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-335-  )
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-336-  build_handler(req = release_admin_fake_req(post_body = post_body), res = release_endpoint_fake_res())
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-337-
--
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-340-  expect_type(captured$layers, "list")
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-341-  expect_length(captured$layers, 2L)
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-342-  expect_equal(captured$layers[[1]]$analysis_type, "functional_clusters")
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-343-  expect_equal(captured$layers[[1]]$params$algorithm, "leiden")
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R:344:  expect_true(isTRUE(captured$layers[[1]]$has_reproducibility))
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-345-  expect_equal(captured$layers[[2]]$analysis_type, "phenotype_clusters")
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-346-  expect_length(captured$layers[[2]]$params, 0L) # jsonlite parses {} as a named empty list
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-347-  expect_equal(captured$title, "Manual build")
api/tests/testthat/test-integration-analysis-release-admin-endpoints.R-348-  expect_false(isTRUE(captured$publish))
--
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-11-**Spec:** `.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md`
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-12-
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-13-## Global Constraints
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-14-
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:15:- Release construction is a **pure additive provenance layer**: never alter cluster membership, validation metrics, cache keys, LLM-summary validity, or recompute any analysis to publish an archive.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-16-- Public release routes are **retrieval-only**: no compute, snapshot refresh, LLM generation, external provider calls, or DB writes. Add them to the cheap-route / external-budget isolation guards.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-17-- Build fails **closed**: only `public_ready`, non-stale, source/schema-matching, **hard-coherence-re-checked**, reproducibility-bearing, dependency-lineage-verified snapshots may enter a release; otherwise **HTTP 400** with the exact reason (no 409 class exists). A duplicate build is idempotent (200, existing head).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-18-- A published release is **immutable** and retained indefinitely; a later snapshot refresh mints a **new** release. DOI columns are additive external provenance, **excluded** from `content_digest`/`manifest_sha256`.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-19-- Canonical serializer = `analysis_snapshot_canonical_json()` (`jsonlite::toJSON(auto_unbox=TRUE, null="null", dataframe="rows")`); SHA-256 via `digest::digest(x, algo="sha256", serialize=FALSE)`. `release_id = "asr_" + content_digest[:16]` (64-bit handle; full digest stored).
--
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-151-
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-152-**Interfaces:**
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-153-- Produces:
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-154-  - `ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION` (chr `"1.0"`)
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:155:  - `analysis_snapshot_release_layers()` → list of `list(analysis_type, params, files_prefix, has_reproducibility)` (default 3 manuscript layers).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-156-  - `analysis_release_canonical_bytes(obj)` → raw (UTF-8 of `analysis_snapshot_canonical_json(obj)`).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-157-  - `analysis_release_sha256(raw_or_chr)` → chr sha256 hex.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-158-  - `analysis_release_content_digest(layer_entries, source_data_version, manifest_schema_version)` → chr (identity basis; layers sorted internally by `analysis_type`).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-159-  - `analysis_release_id(content_digest)` → `paste0("asr_", substr(content_digest, 1, 16))` (64-bit readable handle; full digest stored separately).
--
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-295-- [ ] **Step 2: Run, expect FAIL.**
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-296-- [ ] **Step 3: Implement** with this exact **build order** (prevents hash cycles and TOCTOU drift):
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-297-  0. Open/settle one read connection; acquire the analysis-snapshot advisory lock for the correlation preset (or run steps 1–2 inside one `REPEATABLE READ` transaction) so a concurrent axis refresh can't swap a snapshot between reads. Release on exit.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-298-  1. For each layer: `snap <- analysis_snapshot_get_public(at, ph, conn)`; if `is.null(snap)` or `snap$status_code != "available"` → `stop(structure(class = c("release_snapshot_not_available","error","condition"), message = sprintf("layer %s not available: %s", at, snap$status_code %||% "snapshot_missing")))`.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:299:  1b. **Hard coherence re-check** per cluster layer: `available` does NOT prove coherence (the #514 gate can be `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false`). Re-run `analysis_snapshot_assert_partition_coherent(<snap membership>, <snap validation>, ..., require_coherence = TRUE)` — hard, ignoring the env — else `stop(class = "release_source_incoherent")`.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-300-  1c. **Reproducibility presence** per cluster layer: `repro <- analysis_snapshot_get_reproducibility(snapshot_id, conn)`; if empty or no `reproducibility_hash` → `stop(class = "release_reproducibility_missing")` (the builder is best-effort: a NULL bundle still activates the snapshot, but the release requires it).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-301-  2. Assert one shared `source_data_version` across layers (else `release_source_version_mismatch`); assert the correlation manifest's `dependencies` (`analysis_snapshot_manifest_dependencies`) equal the pinned functional+phenotype `{snapshot_id, payload_hash}` (else `release_dependency_lineage_mismatch`). Re-assert dependencies immediately before insert.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-302-  3. Materialize per-layer files:
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-303-     - `payload.json` bytes = `analysis_release_canonical_bytes(<stored payload rows>)`, where the rows are the layer-appropriate tibbles from `snap` (`clusters` + `cluster_members`; or `correlations`; or `network_nodes` + `network_edges`). This is the file's **own** content; `content_sha256` is its own hash (NOT `payload_hash`). Record the snapshot `payload_hash`/`input_hash`/`snapshot_id` in `layer_entries` as the **lineage anchor**.
--
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-333-**Interfaces:** routes per spec §8. `latest` **before** `/<release_id>`.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-334-
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-335-- [ ] **Step 1: Write failing router tests** — build+publish a release in a test DB, then hit each route; assert: `/releases` lists it; `/releases/latest` returns it; `/releases/<id>/manifest.json` bytes hash to `manifest_sha256`; `/releases/<id>/file?path=functional_clusters/reproducibility.json` hashes to that layer's `reproducibility_hash` and `?path=functional_clusters/payload.json` hashes to its **own** `content_sha256` (matches the manifest `files[]` entry, NOT `payload_hash`); `/releases/<id>/bundle` returns `application/gzip` + `Content-Disposition attachment` and hashes to `bundle_sha256`; unknown/draft id → 404; `?path=<garbage>` → 404.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-336-- [ ] **Step 2: Run, expect FAIL.**
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md:337:- [ ] **Step 3: Implement.** `manifest.json` route serves the **stored** file bytes verbatim (`res$body <- bytes; res$setHeader("Content-Type","application/json")`); `/bundle` uses `@serializer octet` + Content-Disposition + `readBin`-style raw body (backup-endpoint template `services/backup-endpoint-service.R:220-269`). **File retrieval is `GET /releases/<release_id>/file` with a `path` QUERY parameter** resolved by exact `(release_id, file_path)` DB lookup — Plumber 1.3.2 has no `<path:.*>` multi-segment param, so a nested path segment would 404; the query param avoids that and has no traversal surface (exact PK match only).
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-338-- [ ] **Step 4: Run, expect PASS.**
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-339-- [ ] **Step 5: Commit** — `feat(api): public analysis-release read routes (#573)`.
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-340-
.planning/superpowers/plans/2026-07-18-analysis-snapshot-releases-573-plan.md-341-### Task A7: Admin routes
--
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-33-`nddscore_release` (`db/migrations/023`) is a full content-addressed public-release table: `release_id` PK, `is_active` + generated `active_release_slot` UNIQUE, `import_status` ENUM, `artifact_hashes_json`, `source_archive_checksum/bytes`, `zenodo_record_url/version_doi/concept_doi/source_record_id`, `imported_by` FK, `*_current` views. The analysis-snapshot release table mirrors this shape (minus the single-active constraint — analysis releases coexist and are all retained). The frontend `NddScoreModelCard.vue` (Version / Version DOI / Concept DOI / Zenodo links, fed by `fetchCurrentRelease()`) is the exact per-release manifest UI precedent to generalize into a list + detail.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-34-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-35-### 2.3 Reusable building blocks
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-36-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:37:- **Byte-streaming download**: `backup_endpoints.R` + `services/backup-endpoint-service.R` (`@serializer octet`, `Content-Type`, `Content-Disposition: attachment`, `Content-Length`, path-traversal guard, `readBin` stream). Template for `/bundle` and `/file?path=`.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-38-- **Checksum helpers**: `digest::digest(..., algo="sha256", serialize=FALSE)` (repo-wide), `digest::digest(file=path, algo="sha256")` (`nddscore-release-source.R:224`).
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-39-- **Zenodo download/verify precedent (consumer side)**: `nddscore-release-source.R` (`nddscore_fetch_zenodo_metadata`, `nddscore_verify_archive_checksum`, `nddscore_extract_and_verify` per-file SHA-256). The producer script mirrors the `../nddscore` upload flow.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-40-- **`mount_endpoint()`** (RFC 9457 problem+json), `require_role()`, `with_test_db_transaction()`, cheap-route / external-budget static guards.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-41-
--
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-172-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-173-New `api/functions/analysis-snapshot-release.R` (registered in `bootstrap/load_modules.R`) + service `api/services/analysis-snapshot-release-service.R`.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-174-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-175-1. **Load + gate each layer** under one read connection: for each registry layer, `analysis_snapshot_get_public(analysis_type, parameter_hash, conn)` and require `status_code == "available"`. Note `status_code` only checks **freshness/schema/source-version** (+ the #571 dependency gate for the correlation) — it does **not** re-run the #514 coherence gate, and that gate can be downgraded to a warning via `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false` at snapshot build. So `available` is necessary but **not** proof of coherence. Any `snapshot_missing | snapshot_stale | source_version_mismatch | schema_version_mismatch | dependency_snapshot_mismatch` → **reject build** with **HTTP 400** (`stop_for_bad_request`) whose `detail` names the failing `analysis_type` + `status_code`. (The existing error contract has only `error_400/401/403/404/500`; a "sources not ready" rejection is a 400, not a new 409 class — no error-handler change.)
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:176:2. **Hard coherence re-check (per cluster layer)**: independently re-assert partition coherence on the loaded snapshot with `analysis_snapshot_assert_partition_coherent(..., require_coherence = TRUE)` (membership cluster-set == validation cluster-set, channel match, per-cluster member-set equality), **ignoring** the env downgrade, so an incoherent-but-`public_ready` snapshot can never be frozen into a release. Failure → 400 `release_source_incoherent`.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-177-3. **Reproducibility presence (per cluster layer)**: require a stored reproducibility bundle (`analysis_snapshot_get_reproducibility(snapshot_id)` non-empty with a `reproducibility_hash`). The snapshot builder makes the bundle **best-effort** (a failed build returns `NULL` yet the snapshot still activates; `reproducibility_hash` is nullable), but the release makes `reproducibility.json` mandatory — so a missing bundle → 400 `release_reproducibility_missing`, never a crash or a non-reproducible release.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-178-4. **Cross-layer coherence** (belt-and-suspenders): assert all layers share one `source_data_version`; assert the correlation's stored `dependencies` point at exactly the pinned functional + phenotype `snapshot_id`+`payload_hash`. Mismatch → 400 with detail.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-179-5. **TOCTOU guard**: take the standard analysis-snapshot advisory lock (or read all layers within a single consistent transaction/`REPEATABLE READ` snapshot) so a concurrent axis refresh cannot swap an active snapshot between the per-layer reads and the dependency check. Re-assert the correlation's active dependencies immediately before insert.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-180-6. **Materialize files**: canonical-JSON of each layer's stored payload rows (own `content_sha256`) + the verbatim raw reproducibility bytes (`memDecompress(..., asChar = TRUE)`, **not** the parsing `decode()`); generate `README.md`; compute per-file `content_sha256` + `byte_size`.
--
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-194-| `GET /releases?limit=&offset=` | list of **published** releases: `{release_id, release_version, title, created_at, published_at, source_data_version, manifest_sha256, bundle_sha256, license, file_count, total_bytes, layers:[{analysis_type, snapshot_id, payload_hash}], zenodo:{record_url,version_doi,concept_doi}|null}` + pagination |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-195-| `GET /releases/latest` | newest published release head (same shape as detail) |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-196-| `GET /releases/<release_id>` | release head + full manifest object |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-197-| `GET /releases/<release_id>/manifest.json` | the **exact stored** `manifest.json` bytes (Content-Type `application/json`), so `sha256(bytes)==manifest_sha256` |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:198:| `GET /releases/<release_id>/file?path=<file_path>` | one content-addressed file; decompress `content_gzip`; `media_type`; resolved by **exact `(release_id, file_path)` DB lookup** — **anything not in the table → 404** (no filesystem, no traversal surface). A **query param** is used, not a nested `<path>` segment: Plumber 1.3.2 only supports named, typed, single-segment path params (`<id>`, `<id:int>`) — `<path:.*>` does not exist and would 404 every nested file URL. The manifest's `files[].path` values are the caller's index into this route. |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-199-| `GET /releases/<release_id>/bundle` | `@serializer octet`, `Content-Disposition: attachment; filename="<release_id>.tar.gz"`, stream `bundle_gzip` verbatim (backup-endpoint template) |
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-200-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-201-- Unknown or `draft` release → 404 (drafts never public).
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-202-- A release being minted is a synchronous admin op, so there is no public "preparing" state; still, reuse the friendly-error frontend classifier for any transient 5xx.
--
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-303----
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-304-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-305-## 14. Testing & hardening strategy
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-306-
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md:307:- **R unit** (`api/tests/testthat/`): manifest determinism (same snapshots → same `content_digest`/`release_id`/`manifest.json` bytes); per-file `content_sha256` correctness; `content_sha256(reproducibility.json) == reproducibility_hash` (exact); `payload_hash`/`input_hash`/`snapshot_id` recorded as manifest lineage anchors matching the live `meta.snapshot`; immutability (a rebuild after a snapshot refresh mints a new release; the prior release stays byte-identical); **400 rejection** of incoherent / stale / `source_version_mismatch` / `schema_version_mismatch` / `dependency_snapshot_mismatch` sources with the specific reason; **idempotent 200** on an identical rebuild (no duplicate row); `latest` route ordering; `/file?path=` unknown-path → 404 (exact PK lookup, no traversal); reproducibility-bundle-missing source → 400; incoherent source (hard re-check) → 400; draft never public; DOI patch stays outside the content hash.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-308-- **Integration** (`with_test_db_transaction()`): build → list → fetch manifest/files/bundle → verify checksums via the router; admin auth (public write routes forbidden; drafts hidden from public).
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-309-- **Static guards**: `mount_endpoint` wrapping (problem+json) for the new sub-routers; extend cheap-route/external-budget isolation guards to the release routes (DB-only, no external fetcher); bound-parameter SQL only (no interpolation of `<release_id>`/`<path>`); confirm release payloads contain only approved-public snapshot data.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-310-- **#574**: the unit + integration coverage in §13.
.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md-311-- **Frontend**: `releases.spec.ts` (MSW), a `DataReleases.vue` view spec, dotted-key/tooltip-reactivity guards if `BTable` is used, `routes.spec.ts` assertion, `make verify-seo-app`.
   118	## 6. Release identity, files, and manifest
   119	
   120	**Layer registry** `analysis_snapshot_release_layers()` (new; single source of truth), default 3 manuscript layers, registry-driven so more can be added:
   121	- `functional_clusters` (`{algorithm:"leiden"}`) → files `functional_clusters/payload.json`, `functional_clusters/reproducibility.json`
   122	- `phenotype_clusters` (`{}`) → files `phenotype_clusters/payload.json`, `phenotype_clusters/reproducibility.json`
   123	- `phenotype_functional_correlations` (`{algorithm:"leiden"}`) → file `phenotype_functional_correlations/payload.json` (+ its dependency lineage on the two cluster layers)
   124	
   125	**File set per release** (canonical JSON; each file carries its own SHA-256):
   126	- per-layer `payload.json` = the **complete** stored snapshot payload rows returned by `analysis_snapshot_get_public()` (all clusters + members, or correlation rows, or network nodes + edges — **not** a paginated GET page), serialized with `analysis_snapshot_canonical_json`. Its `content_sha256` is the **file's own hash** (verifies the download). It is **not** equal to the snapshot's `payload_hash`: `payload_hash` is computed over the in-memory build object *before* DB storage, and the child tables round-trip through `DECIMAL(8,7)`/`DECIMAL(8,5)` columns, so a reconstructed byte-for-byte match is neither guaranteed nor attempted. **Instead, `payload_hash` (and `input_hash`, `snapshot_id`) are recorded in the manifest as the cross-checkable lineage anchor** — a client verifies the release pins the exact snapshot the public API served by comparing them to the live `/api/analysis/*` `meta.snapshot.{payload_hash,input_hash,snapshot_id}`.
   127	- per-cluster-layer `reproducibility.json` = the **exact pre-gzip canonical bytes** of the stored bundle. **Critical:** do **not** use `analysis_reproducibility_decode()` — it runs `jsonlite::fromJSON()` and returns a *parsed R object*; re-serializing it drops the bundle's `digits = NA` full-precision contract (`analysis-reproducibility.R:31`) and the SHA-256 no longer matches. Instead take the raw string with `memDecompress(bundle_gzip_json, type = "gzip", asChar = TRUE)` (add a small `analysis_reproducibility_decode_raw()` helper) and store/hash **those bytes verbatim**. Then the equality holds exactly: `content_sha256(reproducibility.json) == reproducibility_hash`. This is the scientific-reproduction anchor (recompute modularity/silhouette from it).
   128	- `README.md` = generated human scope + verification instructions
   129	- `manifest.json` = the release manifest (below)
   130	- `checksums.sha256` = `"<sha256>  <path>"` for every file **except `checksums.sha256` itself** (includes `manifest.json`)
   131	- `bundle.tar.gz` = a tar of all the above, gzipped; **built once at release time, stored on the release row, and served verbatim**, so `bundle_sha256` is the hash of the stored bytes and is trivially fixed/citeable. Byte-level *rebuild* determinism (tar mtime/order, gzip header timestamp via `memCompress`) is **not required and not relied upon**: the verification anchors are the per-file `checksums.sha256` + `manifest.json`, which a client recomputes per file. (Build with sorted entries + fixed mtime as a courtesy, but correctness does not depend on it.)
   132	
   133	**`manifest.json` (the verifiability core):**
   134	```jsonc
   135	{
   136	  "manifest_schema_version": "1.0",
   137	  "release_id": "asr_<12hex>",
   138	  "release_version": "2026.07.18",
   139	  "title": "...",
   140	  "created_at": "2026-07-18T10:00:00Z",
   141	  "content_digest": "<sha256>",              // == basis of release_id
   142	  "license": "CC-BY-4.0",
   143	  "scope_statement": "...",
   144	  "generator": {
   145	    "api_version": "0.30.0",
   146	    "analysis_snapshot_schema_version": "1.2",
   147	    "reproducibility_schema_version": "1.0",
   148	    "cluster_logic_version": "2026-07-06.510-expdb"
   149	  },
   150	  "source": { "source_data_version": "c41b5d8...", "db_release": { "version": "1.0.0", "commit": "..." } },
   151	  "layers": [
   152	    { "analysis_type": "functional_clusters", "parameter_hash": "ef3a...", "snapshot_id": 41,
   153	      "schema_version": "1.2", "input_hash": "390e...", "payload_hash": "a142...",
   154	      "reproducibility_hash": "...", "record_counts": {"members":2605,"clusters":18},
   155	      "files": ["functional_clusters/payload.json","functional_clusters/reproducibility.json"] },
   156	    { "analysis_type": "phenotype_clusters", "...": "..." },
   157	    { "analysis_type": "phenotype_functional_correlations", "snapshot_id": 42, "payload_hash": "...",
   158	      "dependencies": {
   159	        "functional_clusters": { "snapshot_id": 41, "payload_hash": "a142..." },
   160	        "phenotype_clusters":  { "snapshot_id": 39, "payload_hash": "bbce..." } },
   161	      "files": ["phenotype_functional_correlations/payload.json"] }
   162	  ],
   163	  "files": [ { "path": "functional_clusters/payload.json", "sha256": "...", "bytes": 12345, "media_type": "application/json" }, "..." ],
   164	  "reproducibility_boundary": "Reproduces the served separation metrics (functional modularity, phenotype silhouette) and the cross-cluster correlation from the bundled reproducibility inputs. LLM summaries and fCoSE layout coordinates are served-only and excluded."
   165	}
   166	```
   167	- `files[]` excludes `manifest.json` and `checksums.sha256` (Frictionless-style, mirrors `../nddscore` `datapackage.json`).
   168	- `manifest_sha256` (row) = SHA-256 of the exact `manifest.json` bytes — served in LIST/HEAD so a client can verify the manifest itself.
   169	- `content_digest` = `sha256(canonical({ manifest_schema_version, source_data_version, layers:[sorted {analysis_type, input_hash, payload_hash, reproducibility_hash, dependencies}] }))`. **Excludes `created_at`, `title`, and DOI** so identity is a pure function of scientific content. The full 64-char `content_digest` is the true identity and is stored + in the manifest; `release_id = "asr_" + content_digest[:16]` (64-bit readable handle). Insert is guarded: if a row with that `release_id` exists but its stored `content_digest` differs (astronomically unlikely at 64 bits), the build fails loudly rather than colliding.
   170	
   171	## 7. Build path — `analysis_snapshot_release_build()` (admin, synchronous, DB-only)
   172	
   173	New `api/functions/analysis-snapshot-release.R` (registered in `bootstrap/load_modules.R`) + service `api/services/analysis-snapshot-release-service.R`.
   174	
   175	1. **Load + gate each layer** under one read connection: for each registry layer, `analysis_snapshot_get_public(analysis_type, parameter_hash, conn)` and require `status_code == "available"`. Note `status_code` only checks **freshness/schema/source-version** (+ the #571 dependency gate for the correlation) — it does **not** re-run the #514 coherence gate, and that gate can be downgraded to a warning via `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE=false` at snapshot build. So `available` is necessary but **not** proof of coherence. Any `snapshot_missing | snapshot_stale | source_version_mismatch | schema_version_mismatch | dependency_snapshot_mismatch` → **reject build** with **HTTP 400** (`stop_for_bad_request`) whose `detail` names the failing `analysis_type` + `status_code`. (The existing error contract has only `error_400/401/403/404/500`; a "sources not ready" rejection is a 400, not a new 409 class — no error-handler change.)
   176	2. **Hard coherence re-check (per cluster layer)**: independently re-assert partition coherence on the loaded snapshot with `analysis_snapshot_assert_partition_coherent(..., require_coherence = TRUE)` (membership cluster-set == validation cluster-set, channel match, per-cluster member-set equality), **ignoring** the env downgrade, so an incoherent-but-`public_ready` snapshot can never be frozen into a release. Failure → 400 `release_source_incoherent`.
   177	3. **Reproducibility presence (per cluster layer)**: require a stored reproducibility bundle (`analysis_snapshot_get_reproducibility(snapshot_id)` non-empty with a `reproducibility_hash`). The snapshot builder makes the bundle **best-effort** (a failed build returns `NULL` yet the snapshot still activates; `reproducibility_hash` is nullable), but the release makes `reproducibility.json` mandatory — so a missing bundle → 400 `release_reproducibility_missing`, never a crash or a non-reproducible release.
   178	4. **Cross-layer coherence** (belt-and-suspenders): assert all layers share one `source_data_version`; assert the correlation's stored `dependencies` point at exactly the pinned functional + phenotype `snapshot_id`+`payload_hash`. Mismatch → 400 with detail.
   179	5. **TOCTOU guard**: take the standard analysis-snapshot advisory lock (or read all layers within a single consistent transaction/`REPEATABLE READ` snapshot) so a concurrent axis refresh cannot swap an active snapshot between the per-layer reads and the dependency check. Re-assert the correlation's active dependencies immediately before insert.
   180	6. **Materialize files**: canonical-JSON of each layer's stored payload rows (own `content_sha256`) + the verbatim raw reproducibility bytes (`memDecompress(..., asChar = TRUE)`, **not** the parsing `decode()`); generate `README.md`; compute per-file `content_sha256` + `byte_size`.
   181	7. **Assemble manifest** (§6), compute `content_digest` → `release_id`. If a release with that `release_id` already exists → **idempotent HTTP 200** returning the existing head (content-addressed create is idempotent; identical sources never duplicate). A same-id row with a *different* stored `content_digest` (impossible short of a 64-bit collision) → 500 to surface the anomaly.
   182	8. **Build `checksums.sha256`** (over all files incl. `manifest.json`, excl. `checksums.sha256` itself) and the **`bundle.tar.gz`** (built once, stored); compute `manifest_sha256`, `bundle_sha256`.
   183	9. **Persist in one transaction**: insert release (status per `publish` flag), members, files. `DBI::dbBind` with `unname()`; blobs bound as `list(raw)`. Blob size is a few MB gzipped — well within `max_allowed_packet` (verify the dev value ≥ 16 MB; the migration/docs note the requirement).
   184	10. Return the release head. **No external calls, no clustering recompute, no LLM, no cache writes.**
   185	
   186	`POST /api/admin/analysis/releases` body: `{ layers?: [...], title?, scope_statement?, license?, publish?: true }` (default `publish:true`; `false` stages a draft for review before a Zenodo run). Administrator-gated.
   187	
   188	## 8. Public read routes (retrieval-only) — `analysis_endpoints.R` (`/api/analysis`, unauthenticated)
   189	
   190	Mounted in the same sub-router as the reproducibility routes (Plumber cannot mount a second router on `/api/analysis`). All DB-only; problem+json via `mount_endpoint`. `latest` declared **before** the dynamic `/<release_id>` route (the `/status/_list` shadowing lesson).

codex
I found a policy-boundary issue in the optional `layers` request body: it currently lets an Administrator alter the fields that decide whether coherence/reproducibility gates run, and that same unvalidated prefix is used as a filesystem path while assembling the tarball. I’m doing a final pass for race/idempotency and provenance omissions before reporting.
codex
## BLOCKER

- [admin_analysis_snapshot_endpoints.R:176](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/endpoints/admin_analysis_snapshot_endpoints.R:176), [analysis-snapshot-release.R:238](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:238), [analysis-snapshot-release-manifest.R:191](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release-manifest.R:191): caller-supplied `layers` controls `has_reproducibility` and `files_prefix`, which are release-policy fields, not input data. An Administrator can submit a functional layer with `"has_reproducibility": false`; this skips both the hard coherence and reproducibility gates and can publish an incoherent/non-reproducible snapshot. The same request can set `"files_prefix":"../../target"`; tar materialization writes `file.path(src_dir, path)` without containment validation, escaping its temporary directory and leaving the external file behind. Fix: derive gate policy and archive paths from a server-authoritative registry; validate any override as a permitted selection only, reject duplicates/omissions that violate required lineage, and enforce normalized relative paths with no `..`, absolute paths, or separators outside expected prefixes.

## HIGH

- [analysis-snapshot-release-repository.R:62](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release-repository.R:62), [analysis-snapshot-release-service.R:177](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/services/analysis-snapshot-release-service.R:177), [analysis-snapshot-release-service.R:191](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/services/analysis-snapshot-release-service.R:191): public list/detail/latest responses expose `created_by_user_id` and `last_error_message`. Scenario: an Administrator builds a published release; unauthenticated `GET /api/analysis/releases` discloses their internal user ID. Any stored error message would also become a public internal-error leak. Fix: use an explicit public head projection/serializer allowlist; retain these fields only in admin responses.

- [analysis-snapshot-release.R:252](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:252), [analysis-snapshot-release.R:296](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:296): the builder checks only that a reproducibility hash is present, then stores the decompressed bytes without asserting they hash to that value. Scenario: a corrupt/restored `analysis_snapshot_reproducibility` row has bundle `B` and hash `H != sha256(B)`; the build publishes a release whose `reproducibility.json` violates the locked equality. Fix: decode raw bytes once, compare `analysis_release_sha256(repro_bytes)` to `repro_hash`, and reject with the release reproducibility gate on mismatch.

- [analysis-snapshot-release.R:189](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:189), [analysis-snapshot-release.R:321](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:321), [analysis-snapshot-release.R:437](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:437): idempotency is race-prone. A failed 5-second advisory-lock acquisition is ignored; two identical builds can both observe no release, then one loses the primary-key insert with a raw 500 rather than receiving the required idempotent 200. The same path fails to distinguish a genuine 64-bit ID collision. Fix: do not proceed unlocked, and additionally handle duplicate-key insertion atomically: reread by `release_id`, return it only if full `content_digest` matches, otherwise fail loudly.

## MEDIUM

- [analysis-snapshot-release.R:361](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:361), [analysis-snapshot-release.R:399](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:399): DB release version/commit are neither added to the manifest nor passed into the release head, despite migration support and the design’s provenance contract. Every newly built release stores these columns as `NULL`, losing the code/DB-release context needed to reproduce or audit it. Fix: extract the release values from the pinned manifests, include them in `source`/generator metadata, and persist them on the head.

## LOW

- [analysis_endpoints.R:398](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/endpoints/analysis_endpoints.R:398), [analysis-snapshot-release-repository.R:258](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release-repository.R:258): public pagination has no positive/max bound. `limit=-1` can produce a DB error; a very large limit can return every permanent release, including text fields and member summaries. Fix: clamp/reject to a small bounded range and require non-negative offset.

Checked — OK: public file lookup is an exact bound `(release_id, file_path)` query; public reads filter `published` in SQL; admin routes are Administrator-gated; SQL value inputs are bound with `unname()`; migration manifest is correctly `045` / `43L`; raw byte serving avoids duplicate `Content-Type`; pool checkout and acquired advisory locks have `on.exit` cleanup.

DO-NOT-SHIP until the blocker and high-severity issues are fixed.
tokens used
162,826
## BLOCKER

- [admin_analysis_snapshot_endpoints.R:176](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/endpoints/admin_analysis_snapshot_endpoints.R:176), [analysis-snapshot-release.R:238](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:238), [analysis-snapshot-release-manifest.R:191](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release-manifest.R:191): caller-supplied `layers` controls `has_reproducibility` and `files_prefix`, which are release-policy fields, not input data. An Administrator can submit a functional layer with `"has_reproducibility": false`; this skips both the hard coherence and reproducibility gates and can publish an incoherent/non-reproducible snapshot. The same request can set `"files_prefix":"../../target"`; tar materialization writes `file.path(src_dir, path)` without containment validation, escaping its temporary directory and leaving the external file behind. Fix: derive gate policy and archive paths from a server-authoritative registry; validate any override as a permitted selection only, reject duplicates/omissions that violate required lineage, and enforce normalized relative paths with no `..`, absolute paths, or separators outside expected prefixes.

## HIGH

- [analysis-snapshot-release-repository.R:62](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release-repository.R:62), [analysis-snapshot-release-service.R:177](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/services/analysis-snapshot-release-service.R:177), [analysis-snapshot-release-service.R:191](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/services/analysis-snapshot-release-service.R:191): public list/detail/latest responses expose `created_by_user_id` and `last_error_message`. Scenario: an Administrator builds a published release; unauthenticated `GET /api/analysis/releases` discloses their internal user ID. Any stored error message would also become a public internal-error leak. Fix: use an explicit public head projection/serializer allowlist; retain these fields only in admin responses.

- [analysis-snapshot-release.R:252](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:252), [analysis-snapshot-release.R:296](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:296): the builder checks only that a reproducibility hash is present, then stores the decompressed bytes without asserting they hash to that value. Scenario: a corrupt/restored `analysis_snapshot_reproducibility` row has bundle `B` and hash `H != sha256(B)`; the build publishes a release whose `reproducibility.json` violates the locked equality. Fix: decode raw bytes once, compare `analysis_release_sha256(repro_bytes)` to `repro_hash`, and reject with the release reproducibility gate on mismatch.

- [analysis-snapshot-release.R:189](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:189), [analysis-snapshot-release.R:321](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:321), [analysis-snapshot-release.R:437](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:437): idempotency is race-prone. A failed 5-second advisory-lock acquisition is ignored; two identical builds can both observe no release, then one loses the primary-key insert with a raw 500 rather than receiving the required idempotent 200. The same path fails to distinguish a genuine 64-bit ID collision. Fix: do not proceed unlocked, and additionally handle duplicate-key insertion atomically: reread by `release_id`, return it only if full `content_digest` matches, otherwise fail loudly.

## MEDIUM

- [analysis-snapshot-release.R:361](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:361), [analysis-snapshot-release.R:399](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release.R:399): DB release version/commit are neither added to the manifest nor passed into the release head, despite migration support and the design’s provenance contract. Every newly built release stores these columns as `NULL`, losing the code/DB-release context needed to reproduce or audit it. Fix: extract the release values from the pinned manifests, include them in `source`/generator metadata, and persist them on the head.

## LOW

- [analysis_endpoints.R:398](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/endpoints/analysis_endpoints.R:398), [analysis-snapshot-release-repository.R:258](/home/bernt-popp/development/sysndd/.claude/worktrees/analysis-snapshot-releases-573-slice-a/api/functions/analysis-snapshot-release-repository.R:258): public pagination has no positive/max bound. `limit=-1` can produce a DB error; a very large limit can return every permanent release, including text fields and member summaries. Fix: clamp/reject to a small bounded range and require non-negative offset.

Checked — OK: public file lookup is an exact bound `(release_id, file_path)` query; public reads filter `published` in SQL; admin routes are Administrator-gated; SQL value inputs are bound with `unname()`; migration manifest is correctly `045` / `43L`; raw byte serving avoids duplicate `Content-Type`; pool checkout and acquired advisory locks have `on.exit` cleanup.

DO-NOT-SHIP until the blocker and high-severity issues are fixed.
