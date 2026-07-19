Reading additional input from stdin...
OpenAI Codex v0.144.5
--------
workdir: /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
model: gpt-5.6-terra
provider: openai
approval: never
sandbox: read-only
reasoning effort: high
reasoning summaries: none
session id: 019f79ed-1185-7643-bfec-4659e4a8e7bf
--------
user
# Adversarial diff review ROUND 2 — #573 Slice C (Zenodo operator scripts)

You reviewed this branch in round 1 and returned NO-SHIP (1 BLOCKER, 2 HIGH, 3 MEDIUM). Those are now
addressed in commit `e19fcd26`. Fresh independent re-review of the CURRENT full branch diff:

1. **Verify each round-1 finding is genuinely resolved** (not papered over):
   - BLOCKER (unguarded staging-dir rmtree): now guarded by an ownership sentinel
     (`.analysis-release-zenodo-staging`) — a pre-existing dir without it is NOT deleted (the function
     stops). Confirm no bypass.
   - HIGH (release_id injection): now validated `^asr_[0-9a-f]{16}$` on both the request arg (allowing
     `latest`) and the resolved head id, before it touches any path/filename/marker; the Makefile parses
     `latest.env` with `sed` instead of shell-`source`. Confirm a `../`/newline/`;`-bearing id is rejected
     and the marker can't inject shell.
   - HIGH (validator gaps): now case-INSENSITIVE forbidden-name/dir matching + a file-type ALLOWLIST
     (`.md/.json/.sha256/.cff/.txt/.sql`) that rejects binary/unexpected-suffix/extensionless files +
     symlink rejection. Confirm `.ENV`, `.pem`, `.csv`, an extensionless file, and a symlink are all
     caught, and it runs before tarring.
   - MEDIUM (checksum coverage): `extract_and_verify` now requires every extracted regular file to be
     checksummed (no unstamped files, no dupes) and rejects `..`/absolute paths. Confirm a dropped
     checksum line or a traversal path fails closed.
   - MEDIUM (nondeterministic tarball): staged mtimes normalized to a fixed epoch (R internal tar zeroes
     the gzip timestamp) — a determinism test asserts byte-identical rebuilds. Confirm.
   - MEDIUM (--token leak): the `--token` CLI flag is removed; `ZENODO_TOKEN` env only.
   The logic now lives across `analysis-snapshot-release-zenodo-{package,verify,docs}.R` (the validator +
   extract-verify moved to `-verify.R`), tests in `test-unit-analysis-release-zenodo-{package,verify,upload}.R`.

2. **Hunt for any NEW or adjacent issues** the fixes introduced — same adversarial rigor (the extraction/
   refactor could have broken a call site; the new validator/checksum logic could have an off-by-one or a
   regex gap; the mtime normalization could miss a file; the sed marker-parse could mis-handle a path with
   spaces).

## The diff to review
```
git diff origin/master...HEAD -- ':(exclude).planning/**'
```
Context: `AGENTS.md` "Analysis-snapshot releases (#573)"; sibling `/home/bernt-popp/development/nddscore/`;
DOI endpoint `api/endpoints/admin_analysis_snapshot_endpoints.R`.

## Locked decisions (do NOT flag; flag violations)
Public-API read only (host-run, DI seams). Publish DOUBLE-gated (`require_publish_confirmation`, Makefile
never passes `--publish`). DOI record-back OPT-IN (`--record-doi` + `SYSNDD_ADMIN_TOKEN`, published-only,
only-supplied-non-empty-fields incl. the `nzchar(NA)` fix, JSON body, manual-command placeholder). Safety
validator runs last before tarring. Content-addressed ids (`asr_<16hex>`). No manuscript references. Every
handwritten `.R` < 600 lines. Operator scripts exempt from the external-budget guard.

## Output
Findings grouped by **BLOCKER / HIGH / MEDIUM / LOW** with file:line + failure scenario + fix direction.
End with `VERDICT: SHIP` or `VERDICT: NO-SHIP`. If the round-1 findings are resolved and nothing new is
ship-blocking, say `VERDICT: SHIP` plainly.
codex
I’m doing a fresh adversarial review of the current branch diff, including a direct regression check against every prior finding. I’ll use the repository’s security and code-quality review guides because this touches archive extraction, path validation, credentials, and operator-facing shell integration.
exec
/bin/bash -lc "sed -n '1,240p' /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md && sed -n '1,260p' .agents/skills/sysndd-security-bug-scan/SKILL.md && sed -n '1,240p' .agents/skills/sysndd-code-quality/SKILL.md" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
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

exec
/bin/bash -lc "git status --short && git diff --check origin/master...HEAD -- ':(exclude).planning/**' && git diff --stat origin/master...HEAD -- ':(exclude).planning/**' && git diff --name-only origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt-round2.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review-round2.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review.md
 .gitignore                                         |   4 +
 AGENTS.md                                          |   1 +
 CHANGELOG.md                                       |  11 +
 Makefile                                           |  33 +-
 .../analysis-snapshot-release-zenodo-docs.R        | 163 +++++++
 .../analysis-snapshot-release-zenodo-package.R     | 422 ++++++++++++++++++
 .../analysis-snapshot-release-zenodo-upload.R      | 316 +++++++++++++
 .../analysis-snapshot-release-zenodo-verify.R      | 487 +++++++++++++++++++++
 api/scripts/package-analysis-release-zenodo.R      | 157 +++++++
 api/scripts/upload-analysis-release-zenodo.R       | 218 +++++++++
 .../test-unit-analysis-release-zenodo-package.R    | 417 ++++++++++++++++++
 .../test-unit-analysis-release-zenodo-upload.R     | 444 +++++++++++++++++++
 .../test-unit-analysis-release-zenodo-verify.R     | 386 ++++++++++++++++
 api/version_spec.json                              |   2 +-
 app/package-lock.json                              |   4 +-
 app/package.json                                   |   2 +-
 documentation/09-deployment.qmd                    |  41 +-
 17 files changed, 3102 insertions(+), 6 deletions(-)
.gitignore
AGENTS.md
CHANGELOG.md
Makefile
api/functions/analysis-snapshot-release-zenodo-docs.R
api/functions/analysis-snapshot-release-zenodo-package.R
api/functions/analysis-snapshot-release-zenodo-upload.R
api/functions/analysis-snapshot-release-zenodo-verify.R
api/scripts/package-analysis-release-zenodo.R
api/scripts/upload-analysis-release-zenodo.R
api/tests/testthat/test-unit-analysis-release-zenodo-package.R
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R
api/version_spec.json
app/package-lock.json
app/package.json
documentation/09-deployment.qmd

exec
/bin/bash -lc 'git diff origin/master...HEAD -- Makefile api/functions/analysis-snapshot-release-zenodo-verify.R api/functions/analysis-snapshot-release-zenodo-package.R api/functions/analysis-snapshot-release-zenodo-upload.R api/scripts/package-analysis-release-zenodo.R api/scripts/upload-analysis-release-zenodo.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
diff --git a/Makefile b/Makefile
index f6a2865c..4e563781 100644
--- a/Makefile
+++ b/Makefile
@@ -41,7 +41,7 @@ RESET := \033[0m
 # =============================================================================
 # PHONY Declarations
 # =============================================================================
-.PHONY: help check-r check-npm check-docker install-api install-app dev serve-app build-app verify-app-bundle-budget watch-app test-api test-api-fast test-api-full mcp-transport-spike test-mcp-smoke coverage lint-api lint-app format-api format-app verify-seo-app code-quality-audit pre-commit ci-local _ci-cleanup preflight docker-build docker-up docker-down docker-dev docker-dev-db docker-logs docker-status cache-clear refresh-analysis-snapshots install-dev doctor worktree-setup worktree-prune refresh-fixtures test-ci-scripts verify-gate playwright-stack playwright-stack-down playwright-stack-logs docs-screenshots docs-screenshots-down verify-doc-screenshots _playwright-seed-templates _playwright-seed-users _playwright-seed-docs-data
+.PHONY: help check-r check-npm check-docker install-api install-app dev serve-app build-app verify-app-bundle-budget watch-app test-api test-api-fast test-api-full mcp-transport-spike test-mcp-smoke coverage lint-api lint-app format-api format-app verify-seo-app code-quality-audit pre-commit ci-local _ci-cleanup preflight docker-build docker-up docker-down docker-dev docker-dev-db docker-logs docker-status cache-clear refresh-analysis-snapshots install-dev doctor worktree-setup worktree-prune refresh-fixtures test-ci-scripts verify-gate playwright-stack playwright-stack-down playwright-stack-logs docs-screenshots docs-screenshots-down verify-doc-screenshots _playwright-seed-templates _playwright-seed-users _playwright-seed-docs-data analysis-release-zenodo-package analysis-release-zenodo-upload-draft

 # =============================================================================
 # Help Target (Self-documenting)
@@ -375,6 +375,37 @@ preflight: check-docker ## [quality] Run production preflight validation
 	@printf "  - /api/health/ready returns 200\n"
 	@printf "  - Database connectivity verified\n"

+# ARGS/UPLOAD_ARGS are passed through to the analysis-release Zenodo operator
+# scripts below (e.g. ARGS="--release-id asr_..." or UPLOAD_ARGS="--sandbox");
+# default empty so --warn-undefined-variables stays quiet.
+ARGS ?=
+UPLOAD_ARGS ?=
+
+analysis-release-zenodo-package: check-r ## [quality] Package a published analysis-snapshot release into a Zenodo staging dir + tarball
+	@printf "$(CYAN)==> Packaging analysis-snapshot release for Zenodo...$(RESET)\n"
+	@cd $(ROOT_DIR) && $(HOST_RSCRIPT) api/scripts/package-analysis-release-zenodo.R $(ARGS) && \
+		printf "$(GREEN)✓ analysis-release-zenodo-package complete (see outputs/analysis-release-zenodo/latest.env)$(RESET)\n" || \
+		(printf "$(RED)✗ analysis-release-zenodo-package failed$(RESET)\n" && exit 1)
+
+analysis-release-zenodo-upload-draft: check-r ## [quality] Upload the last-packaged release to a Zenodo DRAFT (never publishes)
+	@if [ -z "$${ZENODO_TOKEN:-}" ]; then \
+		printf "$(RED)✗ ZENODO_TOKEN is not set (export it in your shell or .env before running this target)$(RESET)\n"; \
+		exit 1; \
+	fi
+	@if [ ! -f "$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env" ]; then \
+		printf "$(RED)✗ outputs/analysis-release-zenodo/latest.env not found -- run 'make analysis-release-zenodo-package' first$(RESET)\n"; \
+		exit 1; \
+	fi
+	@printf "$(CYAN)==> Uploading last-packaged analysis-snapshot release to a Zenodo DRAFT (never publishes)...$(RESET)\n"
+	@MARKER="$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env"; \
+		ARCHIVE_PATH="$$(sed -n 's/^ARCHIVE_PATH=//p' "$$MARKER" | tail -n1)"; \
+		METADATA_PATH="$$(sed -n 's/^METADATA_PATH=//p' "$$MARKER" | tail -n1)"; \
+		RELEASE_ID="$$(sed -n 's/^RELEASE_ID=//p' "$$MARKER" | tail -n1)"; \
+		cd $(ROOT_DIR) && $(HOST_RSCRIPT) api/scripts/upload-analysis-release-zenodo.R \
+			--archive "$$ARCHIVE_PATH" --metadata "$$METADATA_PATH" --release-id "$$RELEASE_ID" $(UPLOAD_ARGS) && \
+		printf "$(GREEN)✓ analysis-release-zenodo-upload-draft complete -- DRAFT only; publishing is a deliberate manual step (see documentation/09-deployment.qmd)$(RESET)\n" || \
+		(printf "$(RED)✗ analysis-release-zenodo-upload-draft failed$(RESET)\n" && exit 1)
+
 # =============================================================================
 # Docker Targets
 # =============================================================================
diff --git a/api/functions/analysis-snapshot-release-zenodo-package.R b/api/functions/analysis-snapshot-release-zenodo-package.R
new file mode 100644
index 00000000..d94c182e
--- /dev/null
+++ b/api/functions/analysis-snapshot-release-zenodo-package.R
@@ -0,0 +1,422 @@
+# api/functions/analysis-snapshot-release-zenodo-package.R
+#
+# Pure, host-runnable operator-script helper for packaging a PUBLISHED
+# analysis-snapshot release (#573) into a Zenodo-shaped dataset staging
+# directory + deterministic tar.gz archive. This is NOT API-runtime code: it
+# is not registered in `bootstrap/load_modules.R`. The C2 CLI wrapper
+# (`api/scripts/package-analysis-release-zenodo.R`) sources this file
+# directly; tests use `source_api_file(..., local = FALSE)`.
+#
+# Read path: the PUBLIC HTTP API only (no DB, no docker exec) --
+#   GET {api_base_url}/api/analysis/releases/{latest|<release_id>}
+#   GET {api_base_url}/api/analysis/releases/<release_id>/bundle
+# A release is already a complete, self-verifying, content-addressed export
+# (see AGENTS.md "Analysis-snapshot releases (#573)"), so the packager's job
+# is narrow: download + verify the bundle, re-stage its files UNMODIFIED
+# under `analysis_snapshot_release/`, add Zenodo-facing docs/metadata, write
+# a staging-wide checksums.sha256, run the safety validator, then tar.
+#
+# Mirrors the sibling `../nddscore/src/models/sysndd_export.py` builders
+# (translated Python -> R) and reuses the fetch/extract/verify idioms from
+# `functions/nddscore-release-source.R` -- except the release bundle's own
+# checksum is SHA-256 (`bundle_sha256` on the release head), not the MD5
+# Zenodo's OWN file listing uses for the (unrelated) inbound nddscore fetch.
+#
+# Every HTTP/file-IO boundary is an injectable parameter with a real default
+# (the `.analysis_release_zenodo_http_*` seams below), so unit tests inject
+# plain stub closures -- no mocking library, no real network. Per AGENTS.md
+# ("External-budget guard: Slice C scripts ARE EXEMPT" in the scout, and the
+# documented `publication-functions.R`/`nddscore-release-source.R`
+# precedent), one-shot operator scripts are outside
+# `external_proxy_budget()` -- plain `httr2::req_timeout()`/`req_retry()`
+# literals are used directly.
+#
+# Doc-string builders live in the sibling
+# `analysis-snapshot-release-zenodo-docs.R` (guard-sourced below); the
+# fetch/download/extract-verify helpers and the safety validator live in the
+# sibling `analysis-snapshot-release-zenodo-verify.R` (also guard-sourced
+# below) -- both splits keep every file under the repo's 600-line soft
+# ceiling.
+
+`%||%` <- function(a, b) {
+  if (is.null(a) || length(a) == 0) {
+    b
+  } else {
+    a
+  }
+}
+
+if (!exists(".analysis_release_zenodo_docs_loaded", mode = "logical")) {
+  # Resolve this file's own directory from the active source() frame (the
+  # proven `helper-functions.R` / `async-job-repository.R` idiom) so the
+  # sibling docs file loads regardless of cwd or how this file was sourced.
+  .analysis_release_zenodo_self_dir <- local({
+    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
+    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
+  })
+  .analysis_release_zenodo_docs_candidates <- c(
+    if (!is.null(.analysis_release_zenodo_self_dir)) {
+      file.path(.analysis_release_zenodo_self_dir, "analysis-snapshot-release-zenodo-docs.R")
+    },
+    "functions/analysis-snapshot-release-zenodo-docs.R",
+    "/app/functions/analysis-snapshot-release-zenodo-docs.R"
+  )
+  for (.analysis_release_zenodo_docs_path in .analysis_release_zenodo_docs_candidates) {
+    if (file.exists(.analysis_release_zenodo_docs_path)) {
+      # local = TRUE (not FALSE): evaluate into THIS call's parent frame, i.e.
+      # the same environment this main file is itself being sourced into
+      # (mirrors the working `async-job-repository.R` guard-source precedent).
+      # `local = FALSE` would instead always target globalenv() regardless of
+      # caller, splitting the two files' symbols across different
+      # environments whenever `source_api_file(local = FALSE)` sources this
+      # file into a non-global test environment.
+      source(.analysis_release_zenodo_docs_path, local = TRUE)
+      break
+    }
+  }
+  rm(.analysis_release_zenodo_self_dir, .analysis_release_zenodo_docs_candidates, .analysis_release_zenodo_docs_path)
+}
+
+if (!exists(".analysis_release_zenodo_verify_loaded", mode = "logical")) {
+  # Same guard-source idiom as the docs block above, targeting the sibling
+  # fetch/extract-verify + safety-validator file instead.
+  .analysis_release_zenodo_self_dir <- local({
+    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
+    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
+  })
+  .analysis_release_zenodo_verify_candidates <- c(
+    if (!is.null(.analysis_release_zenodo_self_dir)) {
+      file.path(.analysis_release_zenodo_self_dir, "analysis-snapshot-release-zenodo-verify.R")
+    },
+    "functions/analysis-snapshot-release-zenodo-verify.R",
+    "/app/functions/analysis-snapshot-release-zenodo-verify.R"
+  )
+  for (.analysis_release_zenodo_verify_path in .analysis_release_zenodo_verify_candidates) {
+    if (file.exists(.analysis_release_zenodo_verify_path)) {
+      # local = TRUE for the same reason as the docs block above.
+      source(.analysis_release_zenodo_verify_path, local = TRUE)
+      break
+    }
+  }
+  rm(
+    .analysis_release_zenodo_self_dir, .analysis_release_zenodo_verify_candidates,
+    .analysis_release_zenodo_verify_path
+  )
+}
+
+# --------------------------------------------------------------------------- #
+# Builders (pure)
+# --------------------------------------------------------------------------- #
+
+.analysis_release_zenodo_created_at_date <- function(created_at) {
+  value <- as.character(created_at %||% "")[[1]]
+  if (!nzchar(value)) {
+    return("")
+  }
+  candidate <- substr(value, 1, 10)
+  if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", candidate)) candidate else value
+}
+
+#' Build the Zenodo metadata list -- becomes `zenodo_metadata.json` AND the
+#' body `set_metadata()` PUTs (C2). Never includes a `doi` key: Zenodo mints
+#' the DOI on deposition creation.
+#'
+#' @param head The release head (from `analysis_release_zenodo_fetch_head()`).
+#' @param version Optional override; default `head$source_data_version` or
+#'   `head$release_id`.
+#' @param license_id Optional override; default `head$license` or `"cc-by-4.0"`.
+analysis_release_zenodo_build_metadata <- function(head, version = NULL, license_id = NULL) {
+  release_id <- as.character(head$release_id %||% "")[[1]]
+  release_date <- .analysis_release_zenodo_created_at_date(head$created_at)
+  title <- if (nzchar(release_date)) {
+    sprintf("SysNDD analysis-snapshot release %s, %s", release_id, release_date)
+  } else {
+    sprintf("SysNDD analysis-snapshot release %s", release_id)
+  }
+
+  resolved_license <- license_id %||% head$license %||% "cc-by-4.0"
+  resolved_version <- as.character((version %||% head$source_data_version %||% release_id))[[1]]
+
+  description <- paste0(
+    "<p>Immutable, content-addressed public export of a SysNDD analysis-snapshot ",
+    "release: the functional (STRING/Leiden) clusters, the phenotype (MCA/HCPC) ",
+    "clusters, and the phenotype-functional correlation layer, each derived from ",
+    "approved public SysNDD curation data.</p>",
+    "<p>Every layer and file is independently verifiable via the bundled ",
+    "manifest.json and checksums.sha256. This is a derived analysis product, not a ",
+    "copy of the primary curated evidence.</p>"
+  )
+
+  list(
+    title = title,
+    upload_type = "dataset",
+    description = description,
+    creators = list(list(name = "Popp, Bernt", orcid = "0000-0002-3679-1081")),
+    keywords = list(
+      "SysNDD", "neurodevelopmental disorders", "gene-disease", "clustering",
+      "analysis snapshot"
+    ),
+    access_right = "open",
+    license = as.character(resolved_license)[[1]],
+    version = resolved_version,
+    language = "eng"
+  )
+}
+
+#' Build a Frictionless Data Package describing the WHOLE staging tree.
+#'
+#' @param staging_dir Root of the staging directory (already populated).
+#' @param name Dataset machine name.
+#' @param version Dataset version string.
+#' @param release_id The release id (becomes the datapackage `id`).
+analysis_release_zenodo_build_datapackage <- function(staging_dir, name, version, release_id) {
+  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
+  rel_paths <- base::setdiff(rel_paths, c("checksums.sha256", "datapackage.json"))
+
+  resources <- lapply(rel_paths, function(rel_path) {
+    full_path <- file.path(staging_dir, rel_path)
+    list(
+      name = gsub("\\.", "-", gsub("/", "-", rel_path)),
+      path = rel_path,
+      bytes = as.numeric(file.info(full_path)$size),
+      hash = digest::digest(file = full_path, algo = "sha256"),
+      mediatype = "application/octet-stream"
+    )
+  })
+
+  list(
+    profile = "data-package",
+    name = as.character(name)[[1]],
+    title = "SysNDD analysis-snapshot release",
+    version = as.character(version)[[1]],
+    id = as.character(release_id)[[1]],
+    licenses = list(list(name = "CC-BY-4.0", path = "https://creativecommons.org/licenses/by/4.0/")),
+    resources = resources
+  )
+}
+
+# --------------------------------------------------------------------------- #
+# Staging + checksums + tarball
+# --------------------------------------------------------------------------- #
+
+.analysis_release_zenodo_write_text <- function(path, content) {
+  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
+  cat(content, file = path)
+  invisible(path)
+}
+
+#' Write `checksums.sha256` at the staging root, covering every iterated file
+#' (excluding itself). Byte-identical format to
+#' `analysis_release_checksums_text()`: `"<sha256>  <path>\n"` lines.
+#'
+#' @return The written path.
+analysis_release_zenodo_write_checksums <- function(staging_dir) {
+  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
+  rel_paths <- rel_paths[rel_paths != "checksums.sha256"]
+
+  content <- if (length(rel_paths) == 0L) {
+    ""
+  } else {
+    lines <- vapply(rel_paths, function(rel_path) {
+      full_path <- file.path(staging_dir, rel_path)
+      paste0(digest::digest(file = full_path, algo = "sha256"), "  ", rel_path)
+    }, character(1))
+    paste0(paste(lines, collapse = "\n"), "\n")
+  }
+
+  out_path <- file.path(staging_dir, "checksums.sha256")
+  .analysis_release_zenodo_write_text(out_path, content)
+  out_path
+}
+
+# A fixed, arbitrary epoch every staged file/dir's mtime is normalized to
+# before tarring (item 5). R's internal tar writer already zeroes the gzip
+# container's own embedded timestamp, so per-file mtimes are the ONLY
+# remaining source of non-determinism between two builds of the same staged
+# content; normalizing them makes the resulting `.tar.gz` byte-identical
+# across runs (proved by
+# `test-unit-analysis-release-zenodo-package.R`'s "packaging the SAME staged
+# content twice" determinism test).
+.ANALYSIS_RELEASE_ZENODO_TAR_FIXED_TIME <- as.POSIXct("2020-01-01", tz = "UTC")
+
+#' Set every file's and directory's mtime under `staging_dir` (INCLUDING
+#' `staging_dir` itself) to a fixed epoch, deepest-first, so a rebuild of the
+#' identical content never differs by mtime alone.
+.analysis_release_zenodo_normalize_mtimes <- function(staging_dir) {
+  entries <- list.files(
+    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE,
+    full.names = TRUE, include.dirs = TRUE
+  )
+  # Deepest-first: a directory's own mtime is set only after every entry
+  # nested inside it, so nothing touched later in this loop bumps it again.
+  depth <- lengths(strsplit(entries, "/", fixed = TRUE))
+  entries <- entries[order(-depth)]
+  for (path in entries) {
+    Sys.setFileTime(path, .ANALYSIS_RELEASE_ZENODO_TAR_FIXED_TIME)
+  }
+  Sys.setFileTime(staging_dir, .ANALYSIS_RELEASE_ZENODO_TAR_FIXED_TIME)
+  invisible(TRUE)
+}
+
+#' Deterministic gzip tarball with ONE top-level dir (`basename(staging_dir)`).
+#' Also writes `<archive_path>.sha256` (`"<sha256>  <basename>\n"`).
+#'
+#' @return list(archive_path, archive_sha256_path).
+analysis_release_zenodo_make_tarball <- function(staging_dir, archive_path) {
+  archive_dir <- dirname(archive_path)
+  dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
+  archive_path <- normalizePath(file.path(archive_dir, basename(archive_path)), mustWork = FALSE)
+
+  staging_dir <- normalizePath(staging_dir, mustWork = TRUE)
+  parent_dir <- dirname(staging_dir)
+  base_name <- basename(staging_dir)
+
+  .analysis_release_zenodo_normalize_mtimes(staging_dir)
+
+  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
+  entries <- sort(file.path(base_name, rel_paths))
+
+  previous_wd <- setwd(parent_dir)
+  on.exit(setwd(previous_wd), add = TRUE)
+  # tar = "internal" forces R's built-in (pure-R) tar writer so the archive
+  # never depends on a system `tar` binary being present/compatible.
+  utils::tar(tarfile = archive_path, files = entries, compression = "gzip", tar = "internal")
+
+  sha256 <- digest::digest(file = archive_path, algo = "sha256")
+  sha_path <- paste0(archive_path, ".sha256")
+  cat(paste0(sha256, "  ", basename(archive_path), "\n"), file = sha_path)
+
+  list(archive_path = archive_path, archive_sha256_path = sha_path)
+}
+
+# --------------------------------------------------------------------------- #
+# Orchestrator
+# --------------------------------------------------------------------------- #
+
+#' Recursively sort a named list's keys alphabetically (objects only --
+#' unnamed lists/arrays are recursed into without reordering). Used for
+#' `zenodo_metadata.json`'s "pretty JSON, sorted keys" contract, mirroring
+#' Python's `json.dumps(..., sort_keys=True)`.
+.analysis_release_zenodo_sort_keys <- function(x) {
+  if (is.list(x)) {
+    nms <- names(x)
+    if (!is.null(nms) && all(nzchar(nms))) {
+      x <- x[order(nms)]
+    }
+    x <- lapply(x, .analysis_release_zenodo_sort_keys)
+  }
+  x
+}
+
+.analysis_release_zenodo_copy_tree <- function(src_dir, dest_dir) {
+  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
+  rel_paths <- list.files(src_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
+  for (rel_path in rel_paths) {
+    dest_path <- file.path(dest_dir, rel_path)
+    dir.create(dirname(dest_path), recursive = TRUE, showWarnings = FALSE)
+    file.copy(file.path(src_dir, rel_path), dest_path, overwrite = TRUE, copy.date = TRUE)
+  }
+  invisible(dest_dir)
+}
+
+#' Fetch a published release over the public HTTP API and assemble a Zenodo
+#' staging directory + deterministic tarball. Mirrors nddscore's
+#' `build_zenodo_dataset_package()` top-to-bottom.
+#'
+#' @return list(staging_dir, archive_path, archive_sha256_path,
+#'   zenodo_metadata_path, release_id).
+analysis_release_zenodo_package <- function(
+    api_base_url,
+    release_id = "latest",
+    staging_dir,
+    archive_dir,
+    version = NULL,
+    doi = NULL,
+    http_get_json = .analysis_release_zenodo_http_get_json,
+    http_download = .analysis_release_zenodo_http_download) {
+  head <- analysis_release_zenodo_fetch_head(api_base_url, release_id, http_get_json = http_get_json)
+  resolved_release_id <- as.character(head$release_id)[[1]]
+  # Defense-in-depth (item 2): re-validate the RESOLVED id even though the
+  # REQUEST arg was already validated inside fetch_head() -- this is the
+  # value that actually becomes `<release_id>.tar.gz` and the `RELEASE_ID=`
+  # marker line, so a compromised/misbehaving API response can never smuggle
+  # a path/marker-injection payload through.
+  .analysis_release_zenodo_assert_valid_release_id(resolved_release_id, allow_latest = FALSE)
+
+  bundle_path <- tempfile(fileext = ".tar.gz")
+  on.exit(unlink(bundle_path, force = TRUE), add = TRUE)
+  analysis_release_zenodo_download_bundle(
+    api_base_url, resolved_release_id, bundle_path, http_download = http_download
+  )
+  extracted_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, head$bundle_sha256)
+  on.exit(unlink(extracted_dir, recursive = TRUE, force = TRUE), add = TRUE)
+
+  # BLOCKER guard (item 1): refuse to recursively delete a pre-existing
+  # `--staging-dir` unless this tool itself created it (empty, absent, or
+  # carrying the ownership sentinel) -- an operator typo must never
+  # irreversibly rmtree an unrelated directory.
+  .analysis_release_zenodo_assert_staging_deletable(staging_dir)
+  if (dir.exists(staging_dir)) {
+    unlink(staging_dir, recursive = TRUE, force = TRUE)
+  }
+  dir.create(staging_dir, recursive = TRUE)
+  .analysis_release_zenodo_write_staging_sentinel(staging_dir)
+
+  nested_dir <- file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_NESTED_DIR)
+  .analysis_release_zenodo_copy_tree(extracted_dir, nested_dir)
+
+  resolved_version <- as.character(
+    (version %||% head$source_data_version %||% resolved_release_id)
+  )[[1]]
+
+  .analysis_release_zenodo_write_text(
+    file.path(staging_dir, "README.md"), analysis_release_zenodo_build_readme(head, doi)
+  )
+  .analysis_release_zenodo_write_text(
+    file.path(staging_dir, "DATA_CARD.md"), analysis_release_zenodo_build_data_card(head)
+  )
+  .analysis_release_zenodo_write_text(
+    file.path(staging_dir, "SCHEMA.md"), analysis_release_zenodo_build_schema_doc(head)
+  )
+  .analysis_release_zenodo_write_text(
+    file.path(staging_dir, "CHANGELOG.md"),
+    analysis_release_zenodo_build_changelog(head, resolved_version)
+  )
+  .analysis_release_zenodo_write_text(
+    file.path(staging_dir, "CITATION.cff"),
+    analysis_release_zenodo_build_citation_cff(head, resolved_version, doi)
+  )
+
+  metadata <- analysis_release_zenodo_build_metadata(head, version = resolved_version)
+  metadata_json <- jsonlite::toJSON(
+    .analysis_release_zenodo_sort_keys(metadata), auto_unbox = TRUE, pretty = TRUE, null = "null"
+  )
+  zenodo_metadata_path <- file.path(staging_dir, "zenodo_metadata.json")
+  .analysis_release_zenodo_write_text(zenodo_metadata_path, paste0(as.character(metadata_json), "\n"))
+
+  datapackage <- analysis_release_zenodo_build_datapackage(
+    staging_dir,
+    name = "sysndd-analysis-snapshot-release",
+    version = resolved_version,
+    release_id = resolved_release_id
+  )
+  datapackage_json <- jsonlite::toJSON(datapackage, auto_unbox = TRUE, pretty = TRUE, null = "null")
+  .analysis_release_zenodo_write_text(
+    file.path(staging_dir, "datapackage.json"), paste0(as.character(datapackage_json), "\n")
+  )
+
+  analysis_release_zenodo_write_checksums(staging_dir)
+
+  analysis_release_zenodo_validate_staging(staging_dir)
+
+  archive_path <- file.path(archive_dir, paste0(resolved_release_id, ".tar.gz"))
+  tar_result <- analysis_release_zenodo_make_tarball(staging_dir, archive_path)
+
+  list(
+    staging_dir = staging_dir,
+    archive_path = tar_result$archive_path,
+    archive_sha256_path = tar_result$archive_sha256_path,
+    zenodo_metadata_path = zenodo_metadata_path,
+    release_id = resolved_release_id
+  )
+}
diff --git a/api/functions/analysis-snapshot-release-zenodo-upload.R b/api/functions/analysis-snapshot-release-zenodo-upload.R
new file mode 100644
index 00000000..c89b4999
--- /dev/null
+++ b/api/functions/analysis-snapshot-release-zenodo-upload.R
@@ -0,0 +1,316 @@
+# api/functions/analysis-snapshot-release-zenodo-upload.R
+#
+# Pure, host-runnable operator-script helper (#573 Slice C / Task C2) for
+# uploading a Zenodo-staged analysis-snapshot release archive
+# (`api/functions/analysis-snapshot-release-zenodo-package.R`'s output) to a
+# Zenodo deposition, and (opt-in) recording the resulting DOI/record back
+# onto the SysNDD release head. NOT API-runtime code: it is not registered in
+# `bootstrap/load_modules.R`. The C2 CLI wrapper
+# (`api/scripts/upload-analysis-release-zenodo.R`) sources this file
+# directly; tests use `source_api_file(..., local = FALSE)`.
+#
+# Mirrors the sibling `../nddscore/scripts/upload_sysndd_zenodo_dataset.py`
+# flow (deposition get-or-create -> set metadata -> PUT archive to bucket ->
+# optional publish), translated Python -> R.
+#
+# Every HTTP boundary is an injectable seam parameter with a real `httr2`
+# default (the `.analysis_release_zenodo_http_*` functions below), so unit
+# tests inject plain stub closures -- no mocking library, no real network.
+# Per AGENTS.md ("External-budget guard: Slice C scripts ARE EXEMPT" in the
+# planning scout, and the documented `publication-functions.R`/
+# `nddscore-release-source.R` precedent), one-shot operator scripts are
+# outside `external_proxy_budget()` -- plain `httr2::req_timeout()` literals
+# are used directly.
+#
+# Publish is DOUBLE-gated: `analysis_release_zenodo_require_publish_confirmation()`
+# stops unless BOTH `publish` and `confirm_publish` are set -- the orchestrator
+# is draft-only by default. DOI record-back to the SysNDD admin API is OPT-IN
+# and lives OUTSIDE this pure orchestrator (it is invoked by the CLI script,
+# Deliverable 3), so this file stays free of SysNDD-admin coupling and easy to
+# test in isolation.
+
+`%||%` <- function(a, b) {
+  if (is.null(a) || length(a) == 0) {
+    b
+  } else {
+    a
+  }
+}
+
+# --------------------------------------------------------------------------- #
+# Zenodo API base URLs + publish safety interlock
+# --------------------------------------------------------------------------- #
+
+.ANALYSIS_RELEASE_ZENODO_API_PROD <- "https://zenodo.org/api"
+.ANALYSIS_RELEASE_ZENODO_API_SANDBOX <- "https://sandbox.zenodo.org/api"
+
+#' Resolve the Zenodo API base URL for the requested environment.
+analysis_release_zenodo_resolve_api <- function(sandbox = FALSE) {
+  if (isTRUE(sandbox)) {
+    .ANALYSIS_RELEASE_ZENODO_API_SANDBOX
+  } else {
+    .ANALYSIS_RELEASE_ZENODO_API_PROD
+  }
+}
+
+#' Stop unless BOTH `publish` and `confirm_publish` are set. A `publish`
+#' request without explicit confirmation is refused -- draft-only is the
+#' default, safe outcome. Mirrors the Python sibling's
+#' `require_publish_confirmation()` (there a `SystemExit`; here a `stop()`).
+analysis_release_zenodo_require_publish_confirmation <- function(publish, confirm_publish) {
+  if (isTRUE(publish) && !isTRUE(confirm_publish)) {
+    stop("--publish requires --confirm-publish", call. = FALSE)
+  }
+  invisible(NULL)
+}
+
+# --------------------------------------------------------------------------- #
+# DI seams: default httr2 implementations. Tests inject plain stub closures
+# with the SAME formal signature instead of mocking httr2/network calls.
+# --------------------------------------------------------------------------- #
+
+#' Default JSON request against the Zenodo deposit API. `token` is turned
+#' into a `Authorization: Bearer <token>` header; a non-NULL `body` is sent
+#' as a JSON object (Content-Type set by `httr2::req_body_json()`). The
+#' create-deposition call passes `body = list()`, which `jsonlite::toJSON()`
+#' would otherwise serialize as `[]` (an empty *array*) rather than the `{}`
+#' Zenodo's API expects for "create an empty deposition" -- special-cased via
+#' `req_body_raw()` so the wire format is the literal JSON object Zenodo
+#' documents.
+.analysis_release_zenodo_http_json <- function(method, url, token, body = NULL) {
+  req <- httr2::request(url) |>
+    httr2::req_method(method) |>
+    httr2::req_headers(Authorization = paste("Bearer", as.character(token)[[1]])) |>
+    httr2::req_timeout(60)
+
+  if (!is.null(body)) {
+    req <- if (is.list(body) && length(body) == 0) {
+      httr2::req_body_raw(req, "{}", type = "application/json")
+    } else {
+      httr2::req_body_json(req, body, auto_unbox = TRUE)
+    }
+  }
+
+  resp <- httr2::req_perform(req)
+  httr2::resp_body_json(resp, simplifyVector = FALSE)
+}
+
+#' Default streaming file PUT to a Zenodo bucket URL. Streams `archive_path`
+#' from disk as the raw request body (`httr2::req_body_file()`), Bearer auth,
+#' a long timeout (large archives, slow upload links).
+.analysis_release_zenodo_http_put_file <- function(url, token, archive_path) {
+  httr2::request(url) |>
+    httr2::req_method("PUT") |>
+    httr2::req_headers(Authorization = paste("Bearer", as.character(token)[[1]])) |>
+    httr2::req_timeout(3600) |>
+    httr2::req_body_file(archive_path) |>
+    httr2::req_perform()
+}
+
+# --------------------------------------------------------------------------- #
+# Deposition lifecycle
+# --------------------------------------------------------------------------- #
+
+#' Get-or-create a Zenodo deposition. `deposition_id = NULL` creates a fresh
+#' draft (`POST {api}/deposit/depositions` with an empty JSON object body);
+#' an explicit id reuses an existing draft (`GET
+#' {api}/deposit/depositions/{id}`). Returns the parsed deposition list.
+#'
+#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
+#'   Injectable seam; defaults to the real httr2 call.
+analysis_release_zenodo_get_or_create_deposition <- function(
+    api, token, deposition_id = NULL, http = .analysis_release_zenodo_http_json) {
+  api <- sub("/+$", "", as.character(api)[[1]])
+  if (is.null(deposition_id)) {
+    http("POST", paste0(api, "/deposit/depositions"), token, body = list())
+  } else {
+    deposition_id <- as.character(deposition_id)[[1]]
+    http("GET", paste0(api, "/deposit/depositions/", deposition_id), token)
+  }
+}
+
+#' Overwrite a deposition's metadata. `PUT {api}/deposit/depositions/{id}`
+#' with body `{"metadata": <metadata>}`.
+#'
+#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
+analysis_release_zenodo_set_metadata <- function(
+    api, token, deposition_id, metadata, http = .analysis_release_zenodo_http_json) {
+  api <- sub("/+$", "", as.character(api)[[1]])
+  deposition_id <- as.character(deposition_id)[[1]]
+  url <- paste0(api, "/deposit/depositions/", deposition_id)
+  http("PUT", url, token, body = list(metadata = metadata))
+}
+
+#' Stream the archive to the deposition's Zenodo bucket.
+#' `PUT {bucket_url}/{basename(archive_path)}`.
+#'
+#' @param put Function(url, token, archive_path). Injectable seam; defaults
+#'   to the real httr2 streaming PUT.
+#' @return The upload URL, invisibly.
+analysis_release_zenodo_upload_bucket <- function(
+    bucket_url, token, archive_path, put = .analysis_release_zenodo_http_put_file) {
+  bucket_url <- sub("/+$", "", as.character(bucket_url)[[1]])
+  url <- paste0(bucket_url, "/", basename(archive_path))
+  put(url, token, archive_path)
+  invisible(url)
+}
+
+#' Publish a draft deposition. `POST
+#' {api}/deposit/depositions/{id}/actions/publish`. Returns the published
+#' deposition (`{doi, conceptdoi, id, links: {html, ...}}`).
+#'
+#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
+analysis_release_zenodo_publish_deposition <- function(
+    api, token, deposition_id, http = .analysis_release_zenodo_http_json) {
+  api <- sub("/+$", "", as.character(api)[[1]])
+  deposition_id <- as.character(deposition_id)[[1]]
+  url <- paste0(api, "/deposit/depositions/", deposition_id, "/actions/publish")
+  http("POST", url, token)
+}
+
+# --------------------------------------------------------------------------- #
+# DOI record-back (OPT-IN, SysNDD-admin side) -- additive metadata, outside
+# any release content hash. Never called automatically; the CLI script only
+# invokes `analysis_release_zenodo_record_doi()` when the operator passes
+# `--record-doi` AND `SYSNDD_ADMIN_TOKEN` is set. Otherwise it prints
+# `analysis_release_zenodo_manual_doi_command()` so the operator can record
+# it by hand.
+# --------------------------------------------------------------------------- #
+
+.ANALYSIS_RELEASE_ZENODO_DOI_FIELD_NAMES <- c(
+  "zenodo_record_id", "zenodo_record_url", "version_doi", "concept_doi"
+)
+
+#' Keep only the four recognized DOI fields with a non-empty value. An
+#' omitted/NULL/NA/empty-string field is dropped, never forwarded as "",
+#' NULL, or NA -- the admin endpoint treats an omitted field as "leave
+#' unchanged", so a forwarded empty value would incorrectly clear it.
+#' `is.na()` is checked BEFORE `nzchar()` because `nzchar(NA_character_)` is
+#' TRUE in R -- without the guard an NA field survives the filter and is
+#' emitted as an explicit `null` instead of being omitted.
+.analysis_release_zenodo_doi_non_empty_fields <- function(doi_fields) {
+  doi_fields <- doi_fields[names(doi_fields) %in% .ANALYSIS_RELEASE_ZENODO_DOI_FIELD_NAMES]
+  Filter(function(value) {
+    if (is.null(value) || length(value) == 0) {
+      return(FALSE)
+    }
+    scalar <- value[[1]]
+    if (is.na(scalar)) {
+      return(FALSE)
+    }
+    nzchar(trimws(as.character(scalar)))
+  }, doi_fields)
+}
+
+#' PATCH the four Zenodo/DOI provenance fields onto a published release head.
+#' Additive-only: forwards ONLY the supplied non-empty fields, matching the
+#' admin endpoint's "an omitted field is left unchanged, never nulled out"
+#' contract (see AGENTS.md "Analysis-snapshot releases (#573)").
+#'
+#' @param sysndd_api_base_url Base URL of the SysNDD API.
+#' @param admin_token A pre-minted SysNDD Administrator bearer token
+#'   (`SYSNDD_ADMIN_TOKEN`). Distinct from the Zenodo `token` used elsewhere
+#'   in this file.
+#' @param patch Function(method, url, token, body = NULL) -> parsed JSON list.
+#'   Injectable seam; defaults to the real httr2 call.
+analysis_release_zenodo_record_doi <- function(
+    sysndd_api_base_url, admin_token, release_id, doi_fields,
+    patch = .analysis_release_zenodo_http_json) {
+  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
+  release_id <- as.character(release_id)[[1]]
+  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
+  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
+  patch("PATCH", url, admin_token, body = fields)
+}
+
+#' Build the exact `curl -X PATCH ...` command an operator can run by hand to
+#' record DOI/record provenance when `--record-doi` was not opted into (the
+#' default). Never executed automatically.
+analysis_release_zenodo_manual_doi_command <- function(sysndd_api_base_url, release_id, doi_fields) {
+  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
+  release_id <- as.character(release_id)[[1]]
+  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
+  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
+  body_json <- as.character(jsonlite::toJSON(fields, auto_unbox = TRUE))
+
+  paste0(
+    "curl -X PATCH '", url, "' ",
+    "-H 'Authorization: Bearer <SYSNDD_ADMIN_TOKEN>' ",
+    "-H 'Content-Type: application/json' ",
+    "-d '", body_json, "'"
+  )
+}
+
+# --------------------------------------------------------------------------- #
+# Orchestrator -- mirrors the Python sibling's `main()` flow. Pure w.r.t.
+# SysNDD: it never calls `analysis_release_zenodo_record_doi()` itself (the
+# CLI script does that, after this returns).
+# --------------------------------------------------------------------------- #
+
+#' Upload a packaged Zenodo archive: get-or-create deposition -> set metadata
+#' -> stream archive to bucket -> (if `publish`) publish. Draft-only unless
+#' BOTH `publish` and `confirm_publish` are set (enforced first, via
+#' `analysis_release_zenodo_require_publish_confirmation()`).
+#'
+#' @return list(deposition_id, reserved_doi, draft_url, published (bool),
+#'   version_doi, concept_doi, record_url). `version_doi`/`concept_doi`/
+#'   `record_url` are `NA_character_` unless `published` is TRUE.
+analysis_release_zenodo_upload <- function(
+    archive_path,
+    metadata_path,
+    token,
+    sandbox = FALSE,
+    deposition_id = NULL,
+    publish = FALSE,
+    confirm_publish = FALSE,
+    get_or_create_deposition = analysis_release_zenodo_get_or_create_deposition,
+    set_metadata = analysis_release_zenodo_set_metadata,
+    upload_bucket = analysis_release_zenodo_upload_bucket,
+    publish_deposition = analysis_release_zenodo_publish_deposition) {
+  analysis_release_zenodo_require_publish_confirmation(publish, confirm_publish)
+
+  if (is.null(token) || !nzchar(as.character(token)[[1]])) {
+    # No `--token` CLI flag exists (item 6, #573 Slice C hardening) -- a
+    # flag would leak the token into shell history/argv. The `token`
+    # parameter here is for programmatic/test callers only; the CLI wrapper
+    # always resolves it from `Sys.getenv("ZENODO_TOKEN")`.
+    stop("ZENODO_TOKEN not set (export it in your shell before running this script)", call. = FALSE)
+  }
+  if (!file.exists(archive_path)) {
+    stop(sprintf("Archive does not exist: %s", archive_path), call. = FALSE)
+  }
+  if (!file.exists(metadata_path)) {
+    stop(sprintf("Metadata does not exist: %s", metadata_path), call. = FALSE)
+  }
+
+  api <- analysis_release_zenodo_resolve_api(sandbox)
+  metadata <- jsonlite::fromJSON(metadata_path, simplifyVector = FALSE)
+
+  deposition <- get_or_create_deposition(api, token, deposition_id = deposition_id)
+  resolved_deposition_id <- deposition$id
+  bucket_url <- deposition$links$bucket
+  reserved_doi <- deposition$metadata$prereserve_doi$doi
+
+  set_metadata(api, token, resolved_deposition_id, metadata)
+  upload_bucket(bucket_url, token, archive_path)
+
+  result <- list(
+    deposition_id = resolved_deposition_id,
+    reserved_doi = reserved_doi %||% NA_character_,
+    draft_url = deposition$links$html %||% NA_character_,
+    published = FALSE,
+    version_doi = NA_character_,
+    concept_doi = NA_character_,
+    record_url = NA_character_
+  )
+
+  if (isTRUE(publish)) {
+    published_deposition <- publish_deposition(api, token, resolved_deposition_id)
+    result$published <- TRUE
+    result$version_doi <- published_deposition$doi %||% NA_character_
+    result$concept_doi <- published_deposition$conceptdoi %||% NA_character_
+    result$record_url <- published_deposition$links$html %||% NA_character_
+  }
+
+  result
+}
diff --git a/api/functions/analysis-snapshot-release-zenodo-verify.R b/api/functions/analysis-snapshot-release-zenodo-verify.R
new file mode 100644
index 00000000..43f03ecd
--- /dev/null
+++ b/api/functions/analysis-snapshot-release-zenodo-verify.R
@@ -0,0 +1,487 @@
+# api/functions/analysis-snapshot-release-zenodo-verify.R
+#
+# Fetch/download/extract-verify helpers AND the safety validator for the
+# analysis-snapshot RELEASE Zenodo packager (#573 Slice C). Extracted from
+# `analysis-snapshot-release-zenodo-package.R` (which guard-sources this
+# file) to keep both files under the repo's 600-line soft ceiling -- mirrors
+# the sibling `analysis-snapshot-release-zenodo-docs.R` split and the
+# `comparisons-functions.R` / `comparisons-parsers.R` precedent.
+#
+# This file is the hardening surface for a script that publishes public data
+# and moves an operator-supplied filesystem path: release-id validation
+# (path/filename/marker-injection guard), the extracted-bundle
+# coverage/traversal checks, and the staging-tree safety validator
+# (case-insensitive forbidden-name matching, a file-type allowlist, and a
+# symlink rejection) all live here.
+#
+# Depends on `%||%`, defined in the sibling `analysis-snapshot-release-
+# zenodo-package.R` (which always sources this file, never the other way
+# around) -- resolved lazily at CALL time via the shared sourcing
+# environment, not at source time, so definition order across the two files
+# does not matter (same idiom as the `-docs.R` sibling).
+
+.analysis_release_zenodo_verify_loaded <- TRUE
+
+# --------------------------------------------------------------------------- #
+# Shared constants (forbidden files/dirs, sensitive text, expected layout,
+# allowed file-type suffixes, the staging-ownership sentinel, the release-id
+# shape).
+# --------------------------------------------------------------------------- #
+
+.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES <- c(".env", ".env.local", ".envrc")
+.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS <- c(
+  ".git", ".planning", ".superpowers", ".venv", "__pycache__"
+)
+.ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS <- c(
+  "/home/", "/users/", "bernt-popp", "zenodo_token", "zenodo_access_token",
+  "bearer ", "development/sysndd", "development/nddscore", ".env", "git_sha"
+)
+# A well-formed analysis-release staging tree only ever contains these
+# suffixes (the release payload/docs). Doubles as both the file-type
+# ALLOWLIST (item 3: any staged regular file whose suffix is not in this set
+# fails validation, catching `.csv`/`.pem`/extensionless/binary secret files
+# without needing to scan binaries) and the set of suffixes the sensitive-
+# text content scan reads.
+.ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES <- c(".md", ".json", ".sql", ".cff", ".sha256", ".txt")
+.ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL <- c(
+  "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
+  "datapackage.json", "zenodo_metadata.json", "checksums.sha256"
+)
+.ANALYSIS_RELEASE_ZENODO_NESTED_DIR <- "analysis_snapshot_release"
+.ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED <- c("manifest.json", "checksums.sha256")
+
+# The ownership marker this tool writes at the staging root immediately
+# after creating it. `analysis_release_zenodo_package()` refuses to
+# recursively delete a pre-existing `--staging-dir` unless it is empty or
+# carries this sentinel -- see `.analysis_release_zenodo_staging_owned_by_tool()`.
+.ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL <- ".analysis-release-zenodo-staging"
+
+# A published release id is `"asr_" + 16 lowercase hex chars`
+# (`analysis_release_id()` in `analysis-snapshot-release-manifest.R`). This is
+# the ONLY shape ever allowed to become a filename, path component, or a
+# value written into the `latest.env` marker the Makefile `source`s.
+.ANALYSIS_RELEASE_ZENODO_ID_PATTERN <- "^asr_[0-9a-f]{16}$"
+
+# --------------------------------------------------------------------------- #
+# Release-id validation -- path/filename/marker-injection guard (item 2).
+# --------------------------------------------------------------------------- #
+
+#' Stop unless `release_id` is exactly `"latest"` (only when
+#' `allow_latest = TRUE`, i.e. the caller-supplied REQUEST arg) or a
+#' well-formed `asr_<16 lowercase hex>` id. Called on BOTH (a) the
+#' `--release-id` request argument (`allow_latest = TRUE`, in
+#' `analysis_release_zenodo_fetch_head()`) and (b) the RESOLVED id the API
+#' returns on the release head (`allow_latest = FALSE`, in
+#' `analysis_release_zenodo_package()`) -- defense-in-depth, since the
+#' resolved id is what actually becomes `<release_id>.tar.gz` and the
+#' `RELEASE_ID=` marker line. Any other value (`../evil`, an id containing a
+#' newline or shell metacharacters, ...) stops loudly here, before it is ever
+#' used as a path/filename/marker value.
+#'
+#' @return `release_id` (as a length-1 character), invisibly, on success.
+.analysis_release_zenodo_assert_valid_release_id <- function(release_id, allow_latest = FALSE) {
+  value <- as.character(release_id)[[1]]
+  if (isTRUE(allow_latest) && identical(value, "latest")) {
+    return(invisible(value))
+  }
+  if (!grepl(.ANALYSIS_RELEASE_ZENODO_ID_PATTERN, value)) {
+    stop(sprintf(
+      "Invalid analysis-snapshot release id %s: expected %s'asr_<16 lowercase hex>'",
+      shQuote(value), if (isTRUE(allow_latest)) "'latest' or " else ""
+    ), call. = FALSE)
+  }
+  invisible(value)
+}
+
+# --------------------------------------------------------------------------- #
+# Fetch (DI seams: http_get_json / http_download)
+# --------------------------------------------------------------------------- #
+
+#' Default JSON GET; tests inject a stub. Mirrors `.nddscore_http_get_json`.
+.analysis_release_zenodo_http_get_json <- function(url) {
+  resp <- httr2::request(url) |>
+    httr2::req_retry(
+      max_tries = 4,
+      is_transient = ~ httr2::resp_status(.x) %in% c(429, 503, 504)
+    ) |>
+    httr2::req_timeout(30) |>
+    httr2::req_perform()
+  httr2::resp_body_json(resp, simplifyVector = FALSE)
+}
+
+#' Default streamed binary GET; tests inject a stub. Mirrors `.nddscore_http_download`.
+.analysis_release_zenodo_http_download <- function(url, destfile) {
+  httr2::request(url) |>
+    httr2::req_retry(max_tries = 4) |>
+    httr2::req_timeout(300) |>
+    httr2::req_perform(path = destfile)
+  invisible(destfile)
+}
+
+#' Fetch a published release's head + parsed manifest over the public API.
+#'
+#' @param api_base_url Base URL of the SysNDD API (e.g. "http://localhost:7778").
+#' @param release_id "latest" (default) or an explicit `asr_<16 hex>` id.
+#'   Validated via `.analysis_release_zenodo_assert_valid_release_id()`
+#'   before it is ever placed into the request URL.
+#' @param http_get_json Function(url) -> parsed JSON list. Injectable seam.
+#' @return The parsed head list (release_id, created_at, license,
+#'   source_data_version, bundle_sha256, manifest, ...).
+analysis_release_zenodo_fetch_head <- function(
+    api_base_url,
+    release_id = "latest",
+    http_get_json = .analysis_release_zenodo_http_get_json) {
+  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
+  release_id <- as.character(release_id)[[1]]
+  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = TRUE)
+  url <- paste0(base_url, "/api/analysis/releases/", release_id)
+  http_get_json(url)
+}
+
+#' Download a published release's whole `bundle.tar.gz`, verbatim, to `destfile`.
+#'
+#' @param release_id An EXPLICIT `asr_<16 hex>` id (there is no
+#'   `/releases/latest/bundle` route -- callers must resolve the concrete id
+#'   via `analysis_release_zenodo_fetch_head()` first).
+#' @param http_download Function(url, destfile). Injectable seam.
+#' @return `destfile`, invisibly-compatible (returned for chaining).
+analysis_release_zenodo_download_bundle <- function(
+    api_base_url,
+    release_id,
+    destfile,
+    http_download = .analysis_release_zenodo_http_download) {
+  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
+  release_id <- as.character(release_id)[[1]]
+  url <- paste0(base_url, "/api/analysis/releases/", release_id, "/bundle")
+  http_download(url, destfile)
+  if (!file.exists(destfile) || file.size(destfile) == 0) {
+    stop("Analysis-snapshot release bundle download produced an empty file", call. = FALSE)
+  }
+  destfile
+}
+
+# --------------------------------------------------------------------------- #
+# Path-traversal guard, shared by both the tar-member listing and the inner
+# `checksums.sha256` entries (item 4).
+# --------------------------------------------------------------------------- #
+
+#' Stop if any `paths` entry is absolute (POSIX `/...` or a Windows drive
+#' letter) or contains a `..` path segment. Used on BOTH the tar member list
+#' (before extraction) and every `checksums.sha256` entry (before it is
+#' resolved to a file under `exdir`) -- a tampered bundle cannot escape the
+#' extraction directory via either vector.
+.analysis_release_zenodo_assert_no_traversal <- function(paths, context) {
+  offenders <- Filter(function(p) {
+    startsWith(p, "/") || grepl("^[A-Za-z]:", p) ||
+      any(strsplit(p, "/", fixed = TRUE)[[1]] == "..")
+  }, paths)
+  if (length(offenders) > 0) {
+    stop(sprintf(
+      "%s path traversal rejected: %s", context, paste(offenders, collapse = ", ")
+    ), call. = FALSE)
+  }
+  invisible(TRUE)
+}
+
+#' Verify a downloaded bundle against the release head's `bundle_sha256`,
+#' extract it, then verify the bundle's OWN inner `checksums.sha256` against
+#' every extracted file. Mirrors `nddscore_extract_and_verify()`'s verify
+#' loop, but the outer digest is SHA-256 (not MD5), and the release bundle's
+#' files sit directly at the archive root (no named top-level subdirectory
+#' to search for).
+#'
+#' Hardening (item 4): (1) every tar member path and every `checksums.sha256`
+#' entry is rejected if absolute or containing a `..` segment, BEFORE it is
+#' ever joined onto `exdir`; (2) after the existing per-line checksum
+#' verification, COVERAGE is asserted -- every extracted regular file except
+#' `checksums.sha256` itself must appear EXACTLY ONCE in the checksums list,
+#' so a tampered bundle that drops a checksum line for a present file (or
+#' lists the same path twice) fails loudly instead of silently passing.
+#'
+#' @param bundle_path Path to the downloaded `bundle.tar.gz`.
+#' @param expected_bundle_sha256 The release head's `bundle_sha256`.
+#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
+#' @return Path to the extraction directory (== `exdir`).
+analysis_release_zenodo_extract_and_verify <- function(
+    bundle_path, expected_bundle_sha256, exdir = NULL) {
+  if (!file.exists(bundle_path)) {
+    stop("Analysis-snapshot release bundle not found for verification", call. = FALSE)
+  }
+  actual_bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
+  expected <- tolower(as.character(expected_bundle_sha256 %||% "")[[1]])
+  if (!identical(tolower(actual_bundle_sha256), expected)) {
+    stop(sprintf(
+      "Analysis-snapshot release bundle checksum mismatch (expected %s, got %s)",
+      expected, actual_bundle_sha256
+    ), call. = FALSE)
+  }
+
+  tar_entries <- utils::untar(bundle_path, list = TRUE)
+  .analysis_release_zenodo_assert_no_traversal(tar_entries, context = "tar member")
+
+  if (is.null(exdir)) {
+    exdir <- file.path(
+      tempdir(), paste0("analysis_release_zenodo_extract_", as.integer(stats::runif(1, 1, 1e9)))
+    )
+  }
+  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
+  utils::untar(bundle_path, exdir = exdir)
+
+  sha_file <- file.path(exdir, "checksums.sha256")
+  if (!file.exists(sha_file)) {
+    stop("Extracted release bundle has no checksums.sha256", call. = FALSE)
+  }
+  sha_lines <- readLines(sha_file, warn = FALSE)
+  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
+
+  checksummed_paths <- character(0)
+  for (line in sha_lines) {
+    parts <- strsplit(trimws(line), "\\s+")[[1]]
+    expected_sha <- parts[[1]]
+    rel_name <- parts[[length(parts)]]
+    .analysis_release_zenodo_assert_no_traversal(rel_name, context = "checksums.sha256 entry")
+    target <- file.path(exdir, rel_name)
+    if (!file.exists(target)) {
+      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name), call. = FALSE)
+    }
+    actual_sha <- digest::digest(file = target, algo = "sha256")
+    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
+      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name), call. = FALSE)
+    }
+    checksummed_paths <- c(checksummed_paths, rel_name)
+  }
+
+  duplicate_entries <- unique(checksummed_paths[duplicated(checksummed_paths)])
+  if (length(duplicate_entries) > 0) {
+    stop(sprintf(
+      "checksums.sha256 lists duplicate entries: %s", paste(duplicate_entries, collapse = ", ")
+    ), call. = FALSE)
+  }
+
+  extracted_files <- list.files(exdir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
+  extracted_files <- extracted_files[extracted_files != "checksums.sha256"]
+  uncovered <- base::setdiff(extracted_files, checksummed_paths)
+  if (length(uncovered) > 0) {
+    stop(sprintf(
+      "Extracted release bundle contains file(s) not listed in checksums.sha256: %s",
+      paste(sort(uncovered), collapse = ", ")
+    ), call. = FALSE)
+  }
+
+  exdir
+}
+
+# --------------------------------------------------------------------------- #
+# Shared public-file iterator -- filter-at-source, reused by every
+# builder/checksums/validator step (belt half of belt-and-suspenders).
+# Case-insensitive (item 3) and excludes the staging-ownership sentinel
+# (item 1), which is an internal marker, never a shipped release file.
+# --------------------------------------------------------------------------- #
+
+#' Sorted, files-only, relative POSIX paths under `root_dir`, excluding
+#' forbidden filenames, any path with a forbidden dir-part segment, and the
+#' staging-ownership sentinel. Matching is case-insensitive.
+#'
+#' @return character vector of relative paths ("/"-separated).
+.analysis_release_zenodo_iter_public_files <- function(root_dir) {
+  all_files <- list.files(
+    root_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
+  )
+  keep <- vapply(all_files, function(rel_path) {
+    if (rel_path == .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL) {
+      return(FALSE)
+    }
+    base <- tolower(basename(rel_path))
+    if (base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES) {
+      return(FALSE)
+    }
+    segments <- tolower(strsplit(rel_path, "/", fixed = TRUE)[[1]])
+    !any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
+  }, logical(1))
+  sort(all_files[keep])
+}
+
+# --------------------------------------------------------------------------- #
+# Staging-directory delete guard (item 1, BLOCKER) -- refuse to
+# `unlink(recursive = TRUE)` any directory this tool did not itself create.
+# --------------------------------------------------------------------------- #
+
+#' TRUE when `staging_dir` is safe for this tool to recursively delete: it
+#' does not exist yet, is empty, or carries the ownership sentinel written by
+#' a prior run of this tool. A pre-existing, non-empty directory WITHOUT the
+#' sentinel is presumed to be an operator typo (e.g. `--staging-dir
+#' /important/dir`) and must never be silently rmtree'd.
+.analysis_release_zenodo_staging_owned_by_tool <- function(staging_dir) {
+  if (!dir.exists(staging_dir)) {
+    return(TRUE)
+  }
+  contents <- list.files(staging_dir, all.files = TRUE, no.. = TRUE)
+  if (length(contents) == 0L) {
+    return(TRUE)
+  }
+  file.exists(file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL))
+}
+
+#' Stop with a clear, actionable message unless `staging_dir` is safe to
+#' recursively delete (see `.analysis_release_zenodo_staging_owned_by_tool()`).
+.analysis_release_zenodo_assert_staging_deletable <- function(staging_dir) {
+  if (!.analysis_release_zenodo_staging_owned_by_tool(staging_dir)) {
+    stop(sprintf(
+      paste0(
+        "refusing to delete %s: not an analysis-release staging dir; ",
+        "remove it manually or choose another --staging-dir"
+      ),
+      staging_dir
+    ), call. = FALSE)
+  }
+  invisible(TRUE)
+}
+
+#' Write the ownership sentinel at the staging root. Called immediately after
+#' `dir.create(staging_dir)` (before any other staging content) so a later
+#' re-run recognizes this directory as the tool's own even if that later run
+#' is interrupted before completing.
+.analysis_release_zenodo_write_staging_sentinel <- function(staging_dir) {
+  writeLines(
+    paste0(
+      "This directory is owned by package-analysis-release-zenodo.R and is ",
+      "safe for it to recursively replace on the next run. Do not remove ",
+      "this file manually if you want that protection to keep applying."
+    ),
+    file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL)
+  )
+  invisible(TRUE)
+}
+
+# --------------------------------------------------------------------------- #
+# THE SAFETY VALIDATOR -- defense in depth, runs LAST before tarring.
+# Independent checks; each collects offending paths and stops loudly.
+# --------------------------------------------------------------------------- #
+
+.analysis_release_zenodo_validate_no_forbidden <- function(staging_dir) {
+  # Deliberately re-walks the tree directly (not via the shared iterator,
+  # which already excludes these) -- an independent re-check, not a
+  # tautology. Case-insensitive (item 3): both the forbidden filename and
+  # forbidden dir-part segments are matched lowercase, so `.ENV`,
+  # `.Git/config`, etc. no longer slip through.
+  all_files <- list.files(
+    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
+  )
+  offenders <- Filter(function(rel_path) {
+    base <- tolower(basename(rel_path))
+    segments <- tolower(strsplit(rel_path, "/", fixed = TRUE)[[1]])
+    base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES ||
+      any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
+  }, all_files)
+
+  if (length(offenders) > 0) {
+    stop(sprintf(
+      "Zenodo staging contains private files: %s",
+      paste(sort(offenders), collapse = ", ")
+    ), call. = FALSE)
+  }
+  invisible(TRUE)
+}
+
+#' Reject symlinks / non-regular files anywhere in the staging tree (item 3)
+#' -- a symlink could point outside the archive, or at a private file
+#' `utils::tar()` would then follow and embed verbatim. Checks BOTH files and
+#' directory entries (`include.dirs = TRUE`) so a symlinked directory is
+#' caught even if `list.files()` would otherwise silently walk through it.
+.analysis_release_zenodo_validate_no_symlinks <- function(staging_dir) {
+  rel_paths <- list.files(
+    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE,
+    full.names = FALSE, include.dirs = TRUE
+  )
+  offenders <- Filter(function(rel_path) {
+    full_path <- file.path(staging_dir, rel_path)
+    target <- suppressWarnings(Sys.readlink(full_path))
+    !is.na(target) && nzchar(target)
+  }, rel_paths)
+
+  if (length(offenders) > 0) {
+    stop(sprintf(
+      "Zenodo staging contains symlinks (not allowed): %s",
+      paste(sort(offenders), collapse = ", ")
+    ), call. = FALSE)
+  }
+  invisible(TRUE)
+}
+
+.analysis_release_zenodo_has_allowed_suffix <- function(rel_path) {
+  lower <- tolower(rel_path)
+  any(vapply(
+    .ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES,
+    function(suffix) endsWith(lower, suffix), logical(1)
+  ))
+}
+
+#' File-type ALLOWLIST (item 3): any staged regular file whose (lowercased)
+#' suffix is not in `.ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES` fails
+#' validation. This catches `.csv`/`.pem`/extensionless/binary secret files
+#' without needing to scan binary content -- a well-formed analysis-release
+#' staging tree only ever contains the release payload/docs suffixes.
+.analysis_release_zenodo_validate_allowed_suffix <- function(staging_dir) {
+  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
+  offenders <- Filter(
+    function(rel_path) !.analysis_release_zenodo_has_allowed_suffix(rel_path), rel_paths
+  )
+  if (length(offenders) > 0) {
+    stop(sprintf(
+      "Zenodo staging contains file(s) with an unexpected type/suffix: %s",
+      paste(offenders, collapse = ", ")
+    ), call. = FALSE)
+  }
+  invisible(TRUE)
+}
+
+.analysis_release_zenodo_validate_no_sensitive_text <- function(staging_dir) {
+  offenders <- character(0)
+  for (rel_path in .analysis_release_zenodo_iter_public_files(staging_dir)) {
+    if (!.analysis_release_zenodo_has_allowed_suffix(rel_path)) {
+      next
+    }
+    full_path <- file.path(staging_dir, rel_path)
+    text <- tolower(paste(readLines(full_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
+    hit <- Find(function(pattern) grepl(pattern, text, fixed = TRUE),
+                .ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS)
+    if (!is.null(hit)) {
+      offenders <- c(offenders, sprintf("%s (matched '%s')", rel_path, hit))
+    }
+  }
+  if (length(offenders) > 0) {
+    stop(sprintf(
+      "Zenodo staging contains sensitive public text: %s",
+      paste(offenders, collapse = "; ")
+    ), call. = FALSE)
+  }
+  invisible(TRUE)
+}
+
+.analysis_release_zenodo_validate_layout <- function(staging_dir) {
+  expected_top <- .ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL
+  expected_nested <- file.path(
+    .ANALYSIS_RELEASE_ZENODO_NESTED_DIR, .ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED
+  )
+  expected <- c(expected_top, expected_nested)
+
+  missing <- Filter(function(rel_path) !file.exists(file.path(staging_dir, rel_path)), expected)
+  if (length(missing) > 0) {
+    stop(sprintf(
+      "Zenodo staging is missing expected members: %s",
+      paste(missing, collapse = ", ")
+    ), call. = FALSE)
+  }
+  invisible(TRUE)
+}
+
+#' The safety validator. Independent checks, in order; stops with a clear
+#' message naming the offending relative paths on the first failing check.
+analysis_release_zenodo_validate_staging <- function(staging_dir) {
+  .analysis_release_zenodo_validate_no_forbidden(staging_dir)
+  .analysis_release_zenodo_validate_no_symlinks(staging_dir)
+  .analysis_release_zenodo_validate_allowed_suffix(staging_dir)
+  .analysis_release_zenodo_validate_no_sensitive_text(staging_dir)
+  .analysis_release_zenodo_validate_layout(staging_dir)
+  invisible(TRUE)
+}
diff --git a/api/scripts/package-analysis-release-zenodo.R b/api/scripts/package-analysis-release-zenodo.R
new file mode 100644
index 00000000..b9216f70
--- /dev/null
+++ b/api/scripts/package-analysis-release-zenodo.R
@@ -0,0 +1,157 @@
+#!/usr/bin/env Rscript
+# api/scripts/package-analysis-release-zenodo.R
+#
+# Thin operator CLI: fetch a PUBLISHED analysis-snapshot release (#573) over
+# the public SysNDD HTTP API and assemble a Zenodo-shaped dataset staging
+# directory + deterministic tar.gz archive, ready for
+# `upload-analysis-release-zenodo.R`.
+#
+# All packaging logic lives in
+# `api/functions/analysis-snapshot-release-zenodo-package.R`
+# (`analysis_release_zenodo_package()`, which itself guard-sources the
+# sibling `-docs.R` file); this script only parses flags, resolves + sources
+# that ONE file, calls the orchestrator, and prints the resulting paths --
+# mirroring the sibling
+# `../nddscore/scripts/package_sysndd_zenodo_dataset.py`.
+#
+# Usage (from the repo root, or from api/ -- CWD-independent, see below):
+#   Rscript api/scripts/package-analysis-release-zenodo.R \
+#     [--api-base-url http://localhost:7778] [--release-id latest] \
+#     [--staging-dir outputs/analysis-release-zenodo/staging] \
+#     [--archive-dir outputs/analysis-release-zenodo/archive] \
+#     [--version <override>]
+#
+# Requires: httr2, jsonlite, digest (all in api/renv.lock). No DB, no
+# bootstrap, no `external_proxy_budget()` -- a pure HTTP client, runnable on
+# any host with R (see AGENTS.md "Analysis-snapshot releases (#573)" and
+# `.superpowers/sdd/slice-c-scout.md` S3 for why the public API is the read
+# path, not the DB).
+#
+# CWD note: this script resolves
+# `api/functions/analysis-snapshot-release-zenodo-package.R` relative to ITS
+# OWN file location (via `sys.frame(1)$ofile`, falling back to Rscript's own
+# `--file=` argument -- the same idiom `capture-external-fixtures.R` uses),
+# so it may be invoked from any working directory; it does NOT assume CWD is
+# the repo root or `api/`.
+
+# --------------------------------------------------------------------------- #
+# Resolve this script's own directory, then source the packager (functions
+# only -- no top-level network calls in that file, so this is safe to do
+# unconditionally, even when this CLI script is itself only `source()`d).
+# --------------------------------------------------------------------------- #
+
+.package_analysis_release_zenodo_script_dir <- function() {
+  script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
+  if (is.null(script_file) || !nzchar(script_file)) {
+    full_args <- commandArgs(trailingOnly = FALSE)
+    file_arg <- grep("^--file=", full_args, value = TRUE)
+    script_file <- if (length(file_arg) >= 1) sub("^--file=", "", file_arg[1]) else "."
+  }
+  dirname(normalizePath(script_file, mustWork = FALSE))
+}
+
+.package_analysis_release_zenodo_script_dir_value <- .package_analysis_release_zenodo_script_dir()
+source(
+  file.path(
+    .package_analysis_release_zenodo_script_dir_value, "..", "functions",
+    "analysis-snapshot-release-zenodo-package.R"
+  ),
+  local = FALSE
+)
+
+# --------------------------------------------------------------------------- #
+# CLI arg parsing -- manual commandArgs() flag loop (repo convention; no
+# optparse dependency, see `verify-endpoints.R`).
+# --------------------------------------------------------------------------- #
+
+#' Parse + run the packaging CLI. Wrapped in a function (rather than bare
+#' top-level code) so the file can be `source()`d for its function
+#' definitions alone -- see the `sys.nframe() == 0L` main-guard at the
+#' bottom of this file, which only calls this when the script is run
+#' directly (`Rscript package-analysis-release-zenodo.R`), never when
+#' `source()`d (e.g. by a test).
+#' Write/overwrite the stable `outputs/analysis-release-zenodo/latest.env`
+#' pointer file the `analysis-release-zenodo-upload-draft` Make target reads
+#' to find this run's content-addressed archive (releases are `asr_<16
+#' hex>`-named, not date-versioned, so the Makefile cannot hardcode a
+#' filename). Fixed, CWD-relative location regardless of `--staging-dir`/
+#' `--archive-dir` overrides -- deliberately NOT under `staging_dir`/
+#' `archive_dir` so the marker's location never depends on those flags.
+#' Paths are written `normalizePath()`-resolved (absolute) so the marker is
+#' still correct if the upload step runs from a different CWD than the
+#' package step.
+.write_package_analysis_release_zenodo_marker <- function(result) {
+  marker_path <- "outputs/analysis-release-zenodo/latest.env"
+  dir.create(dirname(marker_path), recursive = TRUE, showWarnings = FALSE)
+  cat(
+    sprintf(
+      "ARCHIVE_PATH=%s\nMETADATA_PATH=%s\nRELEASE_ID=%s\n",
+      normalizePath(result$archive_path, mustWork = FALSE),
+      normalizePath(result$zenodo_metadata_path, mustWork = FALSE),
+      result$release_id
+    ),
+    file = marker_path
+  )
+  marker_path
+}
+
+run_package_analysis_release_zenodo_cli <- function() {
+  args <- commandArgs(trailingOnly = TRUE)
+
+  api_base_url <- Sys.getenv("SYSNDD_API_BASE_URL", "http://localhost:7778")
+  release_id <- "latest"
+  staging_dir <- "outputs/analysis-release-zenodo/staging"
+  archive_dir <- "outputs/analysis-release-zenodo/archive"
+  version <- NULL
+
+  if (length(args) > 0) {
+    for (i in seq_along(args)) {
+      if (args[i] == "--api-base-url" && i < length(args)) {
+        api_base_url <- args[i + 1]
+      } else if (args[i] == "--release-id" && i < length(args)) {
+        release_id <- args[i + 1]
+      } else if (args[i] == "--staging-dir" && i < length(args)) {
+        staging_dir <- args[i + 1]
+      } else if (args[i] == "--archive-dir" && i < length(args)) {
+        archive_dir <- args[i + 1]
+      } else if (args[i] == "--version" && i < length(args)) {
+        version <- args[i + 1]
+      }
+    }
+  }
+
+  message(sprintf(
+    "[package-analysis-release-zenodo] api_base_url=%s release_id=%s staging_dir=%s archive_dir=%s",
+    api_base_url, release_id, staging_dir, archive_dir
+  ))
+
+  result <- analysis_release_zenodo_package(
+    api_base_url = api_base_url,
+    release_id = release_id,
+    staging_dir = staging_dir,
+    archive_dir = archive_dir,
+    version = version
+  )
+
+  marker_path <- .write_package_analysis_release_zenodo_marker(result)
+
+  cat(sprintf("Release ID:           %s\n", result$release_id))
+  cat(sprintf("Staging dir:          %s\n", result$staging_dir))
+  cat(sprintf("Archive path:         %s\n", result$archive_path))
+  cat(sprintf("Archive sha256 path:  %s\n", result$archive_sha256_path))
+  cat(sprintf("Zenodo metadata path: %s\n", result$zenodo_metadata_path))
+  cat(sprintf("Marker file:          %s\n", marker_path))
+  cat(sprintf(
+    "\nNext: make analysis-release-zenodo-upload-draft (or: Rscript api/scripts/upload-analysis-release-zenodo.R --archive %s --metadata %s --release-id %s)\n",
+    result$archive_path, result$zenodo_metadata_path, result$release_id
+  ))
+
+  invisible(result)
+}
+
+# Main guard: `sys.nframe()` is 0 only at the true top level of a directly
+# `Rscript`-invoked file; a `source()`d file (e.g. from a test) always adds
+# at least one frame, so this line never fires under `source()`. This check
+# MUST stay at top level (not inside a function) -- see AGENTS.md-adjacent
+# `.superpowers/sdd/task-c2-report.md` for the empirical verification.
+if (sys.nframe() == 0L) run_package_analysis_release_zenodo_cli()
diff --git a/api/scripts/upload-analysis-release-zenodo.R b/api/scripts/upload-analysis-release-zenodo.R
new file mode 100644
index 00000000..0e28e331
--- /dev/null
+++ b/api/scripts/upload-analysis-release-zenodo.R
@@ -0,0 +1,218 @@
+#!/usr/bin/env Rscript
+# api/scripts/upload-analysis-release-zenodo.R
+#
+# Thin operator CLI: upload a packaged analysis-snapshot release archive
+# (#573; output of `package-analysis-release-zenodo.R`) to a Zenodo
+# deposition -- get-or-create -> set metadata -> stream archive to bucket ->
+# (optional, double-gated) publish -- then, opt-in, PATCH the resulting
+# DOI/record provenance back onto the SysNDD release head.
+#
+# All upload/record-back logic lives in
+# `api/functions/analysis-snapshot-release-zenodo-upload.R`; this script
+# only parses flags, sources that file, calls the orchestrator, and prints
+# results -- mirroring the sibling
+# `../nddscore/scripts/upload_sysndd_zenodo_dataset.py`.
+#
+# Usage (from the repo root, or from api/ -- CWD-independent, see below):
+#   Rscript api/scripts/upload-analysis-release-zenodo.R \
+#     --archive <path/to/archive.tar.gz> --metadata <path/to/zenodo_metadata.json> \
+#     [--sandbox] [--deposition-id <id>] [--publish --confirm-publish] \
+#     [--record-doi --release-id <asr_...>] [--api-base-url <SysNDD API base>]
+#
+# ZENODO_TOKEN is READ FROM THE ENVIRONMENT ONLY -- there is deliberately no
+# `--token` flag. A CLI flag would leak the token into shell history and
+# `ps`/`/proc/<pid>/cmdline` argv on any multi-user host; the underlying
+# `analysis_release_zenodo_upload()` function still accepts a `token`
+# parameter for tests/programmatic callers, but this CLI wrapper only ever
+# reads `Sys.getenv("ZENODO_TOKEN")`.
+#
+# Publish safety interlock: `--publish` alone is REFUSED -- both `--publish`
+# AND `--confirm-publish` must be passed, or the run stops before any HTTP
+# call is made (`analysis_release_zenodo_require_publish_confirmation()`).
+# Without `--publish`, the archive is uploaded to a Zenodo DRAFT only, for
+# manual review before publishing.
+#
+# DOI record-back is OPT-IN and requires BOTH `--record-doi` AND the
+# `SYSNDD_ADMIN_TOKEN` env var (a pre-minted SysNDD Administrator bearer
+# token) to be set, plus `--release-id` and a successfully PUBLISHED Zenodo
+# DOI. Absent any of those, this script NEVER calls the SysNDD admin PATCH
+# endpoint automatically -- it prints the exact manual `curl` command instead
+# so the operator can record it by hand.
+#
+# Requires: httr2, jsonlite (api/renv.lock). No DB, no bootstrap, no
+# `external_proxy_budget()` -- see AGENTS.md "Analysis-snapshot releases
+# (#573)" and `.superpowers/sdd/slice-c-scout.md`.
+#
+# CWD note: resolves `api/functions/analysis-snapshot-release-zenodo-
+# upload.R` relative to ITS OWN file location (same idiom as
+# `package-analysis-release-zenodo.R` / `capture-external-fixtures.R`), so it
+# may be invoked from any working directory.
+
+# --------------------------------------------------------------------------- #
+# Resolve this script's own directory, then source the upload/record-back
+# functions (function definitions only -- no top-level network calls in that
+# file, so this is safe to do unconditionally, even when this CLI script is
+# itself only `source()`d).
+# --------------------------------------------------------------------------- #
+
+.upload_analysis_release_zenodo_script_dir <- function() {
+  script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
+  if (is.null(script_file) || !nzchar(script_file)) {
+    full_args <- commandArgs(trailingOnly = FALSE)
+    file_arg <- grep("^--file=", full_args, value = TRUE)
+    script_file <- if (length(file_arg) >= 1) sub("^--file=", "", file_arg[1]) else "."
+  }
+  dirname(normalizePath(script_file, mustWork = FALSE))
+}
+
+.upload_analysis_release_zenodo_script_dir_value <- .upload_analysis_release_zenodo_script_dir()
+source(
+  file.path(
+    .upload_analysis_release_zenodo_script_dir_value, "..", "functions",
+    "analysis-snapshot-release-zenodo-upload.R"
+  ),
+  local = FALSE
+)
+
+# --------------------------------------------------------------------------- #
+# CLI arg parsing -- manual commandArgs() flag loop (repo convention; no
+# optparse dependency, see `verify-endpoints.R`).
+# --------------------------------------------------------------------------- #
+
+#' Parse + run the upload CLI. Wrapped in a function (rather than bare
+#' top-level code) so the file can be `source()`d for its function
+#' definitions alone -- see the `sys.nframe() == 0L` main-guard at the
+#' bottom of this file, which only calls this when the script is run
+#' directly (`Rscript upload-analysis-release-zenodo.R`), never when
+#' `source()`d (e.g. by a test).
+run_upload_analysis_release_zenodo_cli <- function() {
+  args <- commandArgs(trailingOnly = TRUE)
+
+  archive <- NULL
+  metadata <- NULL
+  # ZENODO_TOKEN is env-only -- see the "no --token flag" note in the file
+  # header. There is no CLI flag to set/override it.
+  token <- Sys.getenv("ZENODO_TOKEN", "")
+  sandbox <- FALSE
+  deposition_id <- NULL
+  publish <- FALSE
+  confirm_publish <- FALSE
+  record_doi <- FALSE
+  release_id <- NULL
+  api_base_url <- Sys.getenv("SYSNDD_API_BASE_URL", "http://localhost:7778")
+
+  if (length(args) > 0) {
+    for (i in seq_along(args)) {
+      if (args[i] == "--archive" && i < length(args)) {
+        archive <- args[i + 1]
+      } else if (args[i] == "--metadata" && i < length(args)) {
+        metadata <- args[i + 1]
+      } else if (args[i] == "--sandbox") {
+        sandbox <- TRUE
+      } else if (args[i] == "--deposition-id" && i < length(args)) {
+        deposition_id <- args[i + 1]
+      } else if (args[i] == "--publish") {
+        publish <- TRUE
+      } else if (args[i] == "--confirm-publish") {
+        confirm_publish <- TRUE
+      } else if (args[i] == "--record-doi") {
+        record_doi <- TRUE
+      } else if (args[i] == "--release-id" && i < length(args)) {
+        release_id <- args[i + 1]
+      } else if (args[i] == "--api-base-url" && i < length(args)) {
+        api_base_url <- args[i + 1]
+      }
+    }
+  }
+
+  if (is.null(archive) || !nzchar(archive)) {
+    stop("--archive is required", call. = FALSE)
+  }
+  if (is.null(metadata) || !nzchar(metadata)) {
+    stop("--metadata is required", call. = FALSE)
+  }
+
+  result <- analysis_release_zenodo_upload(
+    archive_path = archive,
+    metadata_path = metadata,
+    token = token,
+    sandbox = sandbox,
+    deposition_id = deposition_id,
+    publish = publish,
+    confirm_publish = confirm_publish
+  )
+
+  cat(sprintf("Zenodo deposition id: %s\n", result$deposition_id))
+  cat(sprintf(
+    "Zenodo reserved DOI:  %s\n",
+    if (is.na(result$reserved_doi)) "not returned" else result$reserved_doi
+  ))
+  cat(sprintf(
+    "Zenodo draft URL:     %s\n",
+    if (is.na(result$draft_url)) "not returned" else result$draft_url
+  ))
+
+  if (isTRUE(result$published)) {
+    cat(sprintf("Published Zenodo DOI: %s\n", result$version_doi))
+    cat(sprintf("Published Zenodo URL: %s\n", result$record_url))
+  } else {
+    cat("Draft uploaded only. Review in Zenodo before publishing.\n")
+  }
+
+  .print_doi_record_back(result, release_id, api_base_url, record_doi)
+
+  invisible(result)
+}
+
+#' The opt-in DOI record-back step. Never calls the SysNDD admin endpoint
+#' unless the operator explicitly asked for it (`--record-doi`) AND supplied
+#' credentials (`SYSNDD_ADMIN_TOKEN`) AND the run reached a real, published
+#' DOI -- a draft's "reserved" DOI is not final and is deliberately NOT
+#' recorded automatically. Otherwise prints the exact manual command.
+.print_doi_record_back <- function(result, release_id, api_base_url, record_doi) {
+  doi_fields <- list(
+    zenodo_record_id = as.character(result$deposition_id),
+    zenodo_record_url = if (isTRUE(result$published)) result$record_url else result$draft_url,
+    version_doi = if (isTRUE(result$published)) result$version_doi else NA_character_,
+    concept_doi = if (isTRUE(result$published)) result$concept_doi else NA_character_
+  )
+
+  have_release_id <- !is.null(release_id) && nzchar(release_id)
+  have_published_doi <- isTRUE(result$published) &&
+    !is.na(result$version_doi) && nzchar(as.character(result$version_doi))
+  admin_token <- Sys.getenv("SYSNDD_ADMIN_TOKEN", "")
+
+  if (!have_release_id) {
+    cat("\nNo --release-id supplied -- pass one to record or print a DOI record-back command.\n")
+    return(invisible(NULL))
+  }
+
+  if (isTRUE(record_doi) && nzchar(admin_token) && have_published_doi) {
+    updated <- analysis_release_zenodo_record_doi(
+      sysndd_api_base_url = api_base_url,
+      admin_token = admin_token,
+      release_id = release_id,
+      doi_fields = doi_fields
+    )
+    cat("\nDOI recorded on the SysNDD release head:\n")
+    cat(sprintf("  release_id:        %s\n", updated$release_id %||% release_id))
+    cat(sprintf("  version_doi:       %s\n", updated$version_doi %||% doi_fields$version_doi))
+    cat(sprintf("  zenodo_record_url: %s\n", updated$zenodo_record_url %||% doi_fields$zenodo_record_url))
+  } else {
+    cat(
+      "\nDOI not recorded automatically",
+      if (!have_published_doi) " (deposition not published yet)" else "",
+      ". Run with --record-doi and SYSNDD_ADMIN_TOKEN set after publishing, ",
+      "or record it by hand:\n",
+      sep = ""
+    )
+    cat(analysis_release_zenodo_manual_doi_command(api_base_url, release_id, doi_fields), "\n")
+  }
+  invisible(NULL)
+}
+
+# Main guard: `sys.nframe()` is 0 only at the true top level of a directly
+# `Rscript`-invoked file; a `source()`d file (e.g. from a test) always adds
+# at least one frame, so this line never fires under `source()`. This check
+# MUST stay at top level (not inside a function).
+if (sys.nframe() == 0L) run_upload_analysis_release_zenodo_cli()

exec
/bin/bash -lc 'nl -ba api/functions/analysis-snapshot-release-zenodo-verify.R && nl -ba api/functions/analysis-snapshot-release-zenodo-package.R && nl -ba api/functions/analysis-snapshot-release-zenodo-upload.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
     1	# api/functions/analysis-snapshot-release-zenodo-verify.R
     2	#
     3	# Fetch/download/extract-verify helpers AND the safety validator for the
     4	# analysis-snapshot RELEASE Zenodo packager (#573 Slice C). Extracted from
     5	# `analysis-snapshot-release-zenodo-package.R` (which guard-sources this
     6	# file) to keep both files under the repo's 600-line soft ceiling -- mirrors
     7	# the sibling `analysis-snapshot-release-zenodo-docs.R` split and the
     8	# `comparisons-functions.R` / `comparisons-parsers.R` precedent.
     9	#
    10	# This file is the hardening surface for a script that publishes public data
    11	# and moves an operator-supplied filesystem path: release-id validation
    12	# (path/filename/marker-injection guard), the extracted-bundle
    13	# coverage/traversal checks, and the staging-tree safety validator
    14	# (case-insensitive forbidden-name matching, a file-type allowlist, and a
    15	# symlink rejection) all live here.
    16	#
    17	# Depends on `%||%`, defined in the sibling `analysis-snapshot-release-
    18	# zenodo-package.R` (which always sources this file, never the other way
    19	# around) -- resolved lazily at CALL time via the shared sourcing
    20	# environment, not at source time, so definition order across the two files
    21	# does not matter (same idiom as the `-docs.R` sibling).
    22
    23	.analysis_release_zenodo_verify_loaded <- TRUE
    24
    25	# --------------------------------------------------------------------------- #
    26	# Shared constants (forbidden files/dirs, sensitive text, expected layout,
    27	# allowed file-type suffixes, the staging-ownership sentinel, the release-id
    28	# shape).
    29	# --------------------------------------------------------------------------- #
    30
    31	.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES <- c(".env", ".env.local", ".envrc")
    32	.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS <- c(
    33	  ".git", ".planning", ".superpowers", ".venv", "__pycache__"
    34	)
    35	.ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS <- c(
    36	  "/home/", "/users/", "bernt-popp", "zenodo_token", "zenodo_access_token",
    37	  "bearer ", "development/sysndd", "development/nddscore", ".env", "git_sha"
    38	)
    39	# A well-formed analysis-release staging tree only ever contains these
    40	# suffixes (the release payload/docs). Doubles as both the file-type
    41	# ALLOWLIST (item 3: any staged regular file whose suffix is not in this set
    42	# fails validation, catching `.csv`/`.pem`/extensionless/binary secret files
    43	# without needing to scan binaries) and the set of suffixes the sensitive-
    44	# text content scan reads.
    45	.ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES <- c(".md", ".json", ".sql", ".cff", ".sha256", ".txt")
    46	.ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL <- c(
    47	  "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
    48	  "datapackage.json", "zenodo_metadata.json", "checksums.sha256"
    49	)
    50	.ANALYSIS_RELEASE_ZENODO_NESTED_DIR <- "analysis_snapshot_release"
    51	.ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED <- c("manifest.json", "checksums.sha256")
    52
    53	# The ownership marker this tool writes at the staging root immediately
    54	# after creating it. `analysis_release_zenodo_package()` refuses to
    55	# recursively delete a pre-existing `--staging-dir` unless it is empty or
    56	# carries this sentinel -- see `.analysis_release_zenodo_staging_owned_by_tool()`.
    57	.ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL <- ".analysis-release-zenodo-staging"
    58
    59	# A published release id is `"asr_" + 16 lowercase hex chars`
    60	# (`analysis_release_id()` in `analysis-snapshot-release-manifest.R`). This is
    61	# the ONLY shape ever allowed to become a filename, path component, or a
    62	# value written into the `latest.env` marker the Makefile `source`s.
    63	.ANALYSIS_RELEASE_ZENODO_ID_PATTERN <- "^asr_[0-9a-f]{16}$"
    64
    65	# --------------------------------------------------------------------------- #
    66	# Release-id validation -- path/filename/marker-injection guard (item 2).
    67	# --------------------------------------------------------------------------- #
    68
    69	#' Stop unless `release_id` is exactly `"latest"` (only when
    70	#' `allow_latest = TRUE`, i.e. the caller-supplied REQUEST arg) or a
    71	#' well-formed `asr_<16 lowercase hex>` id. Called on BOTH (a) the
    72	#' `--release-id` request argument (`allow_latest = TRUE`, in
    73	#' `analysis_release_zenodo_fetch_head()`) and (b) the RESOLVED id the API
    74	#' returns on the release head (`allow_latest = FALSE`, in
    75	#' `analysis_release_zenodo_package()`) -- defense-in-depth, since the
    76	#' resolved id is what actually becomes `<release_id>.tar.gz` and the
    77	#' `RELEASE_ID=` marker line. Any other value (`../evil`, an id containing a
    78	#' newline or shell metacharacters, ...) stops loudly here, before it is ever
    79	#' used as a path/filename/marker value.
    80	#'
    81	#' @return `release_id` (as a length-1 character), invisibly, on success.
    82	.analysis_release_zenodo_assert_valid_release_id <- function(release_id, allow_latest = FALSE) {
    83	  value <- as.character(release_id)[[1]]
    84	  if (isTRUE(allow_latest) && identical(value, "latest")) {
    85	    return(invisible(value))
    86	  }
    87	  if (!grepl(.ANALYSIS_RELEASE_ZENODO_ID_PATTERN, value)) {
    88	    stop(sprintf(
    89	      "Invalid analysis-snapshot release id %s: expected %s'asr_<16 lowercase hex>'",
    90	      shQuote(value), if (isTRUE(allow_latest)) "'latest' or " else ""
    91	    ), call. = FALSE)
    92	  }
    93	  invisible(value)
    94	}
    95
    96	# --------------------------------------------------------------------------- #
    97	# Fetch (DI seams: http_get_json / http_download)
    98	# --------------------------------------------------------------------------- #
    99
   100	#' Default JSON GET; tests inject a stub. Mirrors `.nddscore_http_get_json`.
   101	.analysis_release_zenodo_http_get_json <- function(url) {
   102	  resp <- httr2::request(url) |>
   103	    httr2::req_retry(
   104	      max_tries = 4,
   105	      is_transient = ~ httr2::resp_status(.x) %in% c(429, 503, 504)
   106	    ) |>
   107	    httr2::req_timeout(30) |>
   108	    httr2::req_perform()
   109	  httr2::resp_body_json(resp, simplifyVector = FALSE)
   110	}
   111
   112	#' Default streamed binary GET; tests inject a stub. Mirrors `.nddscore_http_download`.
   113	.analysis_release_zenodo_http_download <- function(url, destfile) {
   114	  httr2::request(url) |>
   115	    httr2::req_retry(max_tries = 4) |>
   116	    httr2::req_timeout(300) |>
   117	    httr2::req_perform(path = destfile)
   118	  invisible(destfile)
   119	}
   120
   121	#' Fetch a published release's head + parsed manifest over the public API.
   122	#'
   123	#' @param api_base_url Base URL of the SysNDD API (e.g. "http://localhost:7778").
   124	#' @param release_id "latest" (default) or an explicit `asr_<16 hex>` id.
   125	#'   Validated via `.analysis_release_zenodo_assert_valid_release_id()`
   126	#'   before it is ever placed into the request URL.
   127	#' @param http_get_json Function(url) -> parsed JSON list. Injectable seam.
   128	#' @return The parsed head list (release_id, created_at, license,
   129	#'   source_data_version, bundle_sha256, manifest, ...).
   130	analysis_release_zenodo_fetch_head <- function(
   131	    api_base_url,
   132	    release_id = "latest",
   133	    http_get_json = .analysis_release_zenodo_http_get_json) {
   134	  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
   135	  release_id <- as.character(release_id)[[1]]
   136	  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = TRUE)
   137	  url <- paste0(base_url, "/api/analysis/releases/", release_id)
   138	  http_get_json(url)
   139	}
   140
   141	#' Download a published release's whole `bundle.tar.gz`, verbatim, to `destfile`.
   142	#'
   143	#' @param release_id An EXPLICIT `asr_<16 hex>` id (there is no
   144	#'   `/releases/latest/bundle` route -- callers must resolve the concrete id
   145	#'   via `analysis_release_zenodo_fetch_head()` first).
   146	#' @param http_download Function(url, destfile). Injectable seam.
   147	#' @return `destfile`, invisibly-compatible (returned for chaining).
   148	analysis_release_zenodo_download_bundle <- function(
   149	    api_base_url,
   150	    release_id,
   151	    destfile,
   152	    http_download = .analysis_release_zenodo_http_download) {
   153	  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
   154	  release_id <- as.character(release_id)[[1]]
   155	  url <- paste0(base_url, "/api/analysis/releases/", release_id, "/bundle")
   156	  http_download(url, destfile)
   157	  if (!file.exists(destfile) || file.size(destfile) == 0) {
   158	    stop("Analysis-snapshot release bundle download produced an empty file", call. = FALSE)
   159	  }
   160	  destfile
   161	}
   162
   163	# --------------------------------------------------------------------------- #
   164	# Path-traversal guard, shared by both the tar-member listing and the inner
   165	# `checksums.sha256` entries (item 4).
   166	# --------------------------------------------------------------------------- #
   167
   168	#' Stop if any `paths` entry is absolute (POSIX `/...` or a Windows drive
   169	#' letter) or contains a `..` path segment. Used on BOTH the tar member list
   170	#' (before extraction) and every `checksums.sha256` entry (before it is
   171	#' resolved to a file under `exdir`) -- a tampered bundle cannot escape the
   172	#' extraction directory via either vector.
   173	.analysis_release_zenodo_assert_no_traversal <- function(paths, context) {
   174	  offenders <- Filter(function(p) {
   175	    startsWith(p, "/") || grepl("^[A-Za-z]:", p) ||
   176	      any(strsplit(p, "/", fixed = TRUE)[[1]] == "..")
   177	  }, paths)
   178	  if (length(offenders) > 0) {
   179	    stop(sprintf(
   180	      "%s path traversal rejected: %s", context, paste(offenders, collapse = ", ")
   181	    ), call. = FALSE)
   182	  }
   183	  invisible(TRUE)
   184	}
   185
   186	#' Verify a downloaded bundle against the release head's `bundle_sha256`,
   187	#' extract it, then verify the bundle's OWN inner `checksums.sha256` against
   188	#' every extracted file. Mirrors `nddscore_extract_and_verify()`'s verify
   189	#' loop, but the outer digest is SHA-256 (not MD5), and the release bundle's
   190	#' files sit directly at the archive root (no named top-level subdirectory
   191	#' to search for).
   192	#'
   193	#' Hardening (item 4): (1) every tar member path and every `checksums.sha256`
   194	#' entry is rejected if absolute or containing a `..` segment, BEFORE it is
   195	#' ever joined onto `exdir`; (2) after the existing per-line checksum
   196	#' verification, COVERAGE is asserted -- every extracted regular file except
   197	#' `checksums.sha256` itself must appear EXACTLY ONCE in the checksums list,
   198	#' so a tampered bundle that drops a checksum line for a present file (or
   199	#' lists the same path twice) fails loudly instead of silently passing.
   200	#'
   201	#' @param bundle_path Path to the downloaded `bundle.tar.gz`.
   202	#' @param expected_bundle_sha256 The release head's `bundle_sha256`.
   203	#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
   204	#' @return Path to the extraction directory (== `exdir`).
   205	analysis_release_zenodo_extract_and_verify <- function(
   206	    bundle_path, expected_bundle_sha256, exdir = NULL) {
   207	  if (!file.exists(bundle_path)) {
   208	    stop("Analysis-snapshot release bundle not found for verification", call. = FALSE)
   209	  }
   210	  actual_bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
   211	  expected <- tolower(as.character(expected_bundle_sha256 %||% "")[[1]])
   212	  if (!identical(tolower(actual_bundle_sha256), expected)) {
   213	    stop(sprintf(
   214	      "Analysis-snapshot release bundle checksum mismatch (expected %s, got %s)",
   215	      expected, actual_bundle_sha256
   216	    ), call. = FALSE)
   217	  }
   218
   219	  tar_entries <- utils::untar(bundle_path, list = TRUE)
   220	  .analysis_release_zenodo_assert_no_traversal(tar_entries, context = "tar member")
   221
   222	  if (is.null(exdir)) {
   223	    exdir <- file.path(
   224	      tempdir(), paste0("analysis_release_zenodo_extract_", as.integer(stats::runif(1, 1, 1e9)))
   225	    )
   226	  }
   227	  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
   228	  utils::untar(bundle_path, exdir = exdir)
   229
   230	  sha_file <- file.path(exdir, "checksums.sha256")
   231	  if (!file.exists(sha_file)) {
   232	    stop("Extracted release bundle has no checksums.sha256", call. = FALSE)
   233	  }
   234	  sha_lines <- readLines(sha_file, warn = FALSE)
   235	  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
   236
   237	  checksummed_paths <- character(0)
   238	  for (line in sha_lines) {
   239	    parts <- strsplit(trimws(line), "\\s+")[[1]]
   240	    expected_sha <- parts[[1]]
   241	    rel_name <- parts[[length(parts)]]
   242	    .analysis_release_zenodo_assert_no_traversal(rel_name, context = "checksums.sha256 entry")
   243	    target <- file.path(exdir, rel_name)
   244	    if (!file.exists(target)) {
   245	      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name), call. = FALSE)
   246	    }
   247	    actual_sha <- digest::digest(file = target, algo = "sha256")
   248	    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
   249	      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name), call. = FALSE)
   250	    }
   251	    checksummed_paths <- c(checksummed_paths, rel_name)
   252	  }
   253
   254	  duplicate_entries <- unique(checksummed_paths[duplicated(checksummed_paths)])
   255	  if (length(duplicate_entries) > 0) {
   256	    stop(sprintf(
   257	      "checksums.sha256 lists duplicate entries: %s", paste(duplicate_entries, collapse = ", ")
   258	    ), call. = FALSE)
   259	  }
   260
   261	  extracted_files <- list.files(exdir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
   262	  extracted_files <- extracted_files[extracted_files != "checksums.sha256"]
   263	  uncovered <- base::setdiff(extracted_files, checksummed_paths)
   264	  if (length(uncovered) > 0) {
   265	    stop(sprintf(
   266	      "Extracted release bundle contains file(s) not listed in checksums.sha256: %s",
   267	      paste(sort(uncovered), collapse = ", ")
   268	    ), call. = FALSE)
   269	  }
   270
   271	  exdir
   272	}
   273
   274	# --------------------------------------------------------------------------- #
   275	# Shared public-file iterator -- filter-at-source, reused by every
   276	# builder/checksums/validator step (belt half of belt-and-suspenders).
   277	# Case-insensitive (item 3) and excludes the staging-ownership sentinel
   278	# (item 1), which is an internal marker, never a shipped release file.
   279	# --------------------------------------------------------------------------- #
   280
   281	#' Sorted, files-only, relative POSIX paths under `root_dir`, excluding
   282	#' forbidden filenames, any path with a forbidden dir-part segment, and the
   283	#' staging-ownership sentinel. Matching is case-insensitive.
   284	#'
   285	#' @return character vector of relative paths ("/"-separated).
   286	.analysis_release_zenodo_iter_public_files <- function(root_dir) {
   287	  all_files <- list.files(
   288	    root_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
   289	  )
   290	  keep <- vapply(all_files, function(rel_path) {
   291	    if (rel_path == .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL) {
   292	      return(FALSE)
   293	    }
   294	    base <- tolower(basename(rel_path))
   295	    if (base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES) {
   296	      return(FALSE)
   297	    }
   298	    segments <- tolower(strsplit(rel_path, "/", fixed = TRUE)[[1]])
   299	    !any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
   300	  }, logical(1))
   301	  sort(all_files[keep])
   302	}
   303
   304	# --------------------------------------------------------------------------- #
   305	# Staging-directory delete guard (item 1, BLOCKER) -- refuse to
   306	# `unlink(recursive = TRUE)` any directory this tool did not itself create.
   307	# --------------------------------------------------------------------------- #
   308
   309	#' TRUE when `staging_dir` is safe for this tool to recursively delete: it
   310	#' does not exist yet, is empty, or carries the ownership sentinel written by
   311	#' a prior run of this tool. A pre-existing, non-empty directory WITHOUT the
   312	#' sentinel is presumed to be an operator typo (e.g. `--staging-dir
   313	#' /important/dir`) and must never be silently rmtree'd.
   314	.analysis_release_zenodo_staging_owned_by_tool <- function(staging_dir) {
   315	  if (!dir.exists(staging_dir)) {
   316	    return(TRUE)
   317	  }
   318	  contents <- list.files(staging_dir, all.files = TRUE, no.. = TRUE)
   319	  if (length(contents) == 0L) {
   320	    return(TRUE)
   321	  }
   322	  file.exists(file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL))
   323	}
   324
   325	#' Stop with a clear, actionable message unless `staging_dir` is safe to
   326	#' recursively delete (see `.analysis_release_zenodo_staging_owned_by_tool()`).
   327	.analysis_release_zenodo_assert_staging_deletable <- function(staging_dir) {
   328	  if (!.analysis_release_zenodo_staging_owned_by_tool(staging_dir)) {
   329	    stop(sprintf(
   330	      paste0(
   331	        "refusing to delete %s: not an analysis-release staging dir; ",
   332	        "remove it manually or choose another --staging-dir"
   333	      ),
   334	      staging_dir
   335	    ), call. = FALSE)
   336	  }
   337	  invisible(TRUE)
   338	}
   339
   340	#' Write the ownership sentinel at the staging root. Called immediately after
   341	#' `dir.create(staging_dir)` (before any other staging content) so a later
   342	#' re-run recognizes this directory as the tool's own even if that later run
   343	#' is interrupted before completing.
   344	.analysis_release_zenodo_write_staging_sentinel <- function(staging_dir) {
   345	  writeLines(
   346	    paste0(
   347	      "This directory is owned by package-analysis-release-zenodo.R and is ",
   348	      "safe for it to recursively replace on the next run. Do not remove ",
   349	      "this file manually if you want that protection to keep applying."
   350	    ),
   351	    file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL)
   352	  )
   353	  invisible(TRUE)
   354	}
   355
   356	# --------------------------------------------------------------------------- #
   357	# THE SAFETY VALIDATOR -- defense in depth, runs LAST before tarring.
   358	# Independent checks; each collects offending paths and stops loudly.
   359	# --------------------------------------------------------------------------- #
   360
   361	.analysis_release_zenodo_validate_no_forbidden <- function(staging_dir) {
   362	  # Deliberately re-walks the tree directly (not via the shared iterator,
   363	  # which already excludes these) -- an independent re-check, not a
   364	  # tautology. Case-insensitive (item 3): both the forbidden filename and
   365	  # forbidden dir-part segments are matched lowercase, so `.ENV`,
   366	  # `.Git/config`, etc. no longer slip through.
   367	  all_files <- list.files(
   368	    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
   369	  )
   370	  offenders <- Filter(function(rel_path) {
   371	    base <- tolower(basename(rel_path))
   372	    segments <- tolower(strsplit(rel_path, "/", fixed = TRUE)[[1]])
   373	    base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES ||
   374	      any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
   375	  }, all_files)
   376
   377	  if (length(offenders) > 0) {
   378	    stop(sprintf(
   379	      "Zenodo staging contains private files: %s",
   380	      paste(sort(offenders), collapse = ", ")
   381	    ), call. = FALSE)
   382	  }
   383	  invisible(TRUE)
   384	}
   385
   386	#' Reject symlinks / non-regular files anywhere in the staging tree (item 3)
   387	#' -- a symlink could point outside the archive, or at a private file
   388	#' `utils::tar()` would then follow and embed verbatim. Checks BOTH files and
   389	#' directory entries (`include.dirs = TRUE`) so a symlinked directory is
   390	#' caught even if `list.files()` would otherwise silently walk through it.
   391	.analysis_release_zenodo_validate_no_symlinks <- function(staging_dir) {
   392	  rel_paths <- list.files(
   393	    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE,
   394	    full.names = FALSE, include.dirs = TRUE
   395	  )
   396	  offenders <- Filter(function(rel_path) {
   397	    full_path <- file.path(staging_dir, rel_path)
   398	    target <- suppressWarnings(Sys.readlink(full_path))
   399	    !is.na(target) && nzchar(target)
   400	  }, rel_paths)
   401
   402	  if (length(offenders) > 0) {
   403	    stop(sprintf(
   404	      "Zenodo staging contains symlinks (not allowed): %s",
   405	      paste(sort(offenders), collapse = ", ")
   406	    ), call. = FALSE)
   407	  }
   408	  invisible(TRUE)
   409	}
   410
   411	.analysis_release_zenodo_has_allowed_suffix <- function(rel_path) {
   412	  lower <- tolower(rel_path)
   413	  any(vapply(
   414	    .ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES,
   415	    function(suffix) endsWith(lower, suffix), logical(1)
   416	  ))
   417	}
   418
   419	#' File-type ALLOWLIST (item 3): any staged regular file whose (lowercased)
   420	#' suffix is not in `.ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES` fails
   421	#' validation. This catches `.csv`/`.pem`/extensionless/binary secret files
   422	#' without needing to scan binary content -- a well-formed analysis-release
   423	#' staging tree only ever contains the release payload/docs suffixes.
   424	.analysis_release_zenodo_validate_allowed_suffix <- function(staging_dir) {
   425	  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
   426	  offenders <- Filter(
   427	    function(rel_path) !.analysis_release_zenodo_has_allowed_suffix(rel_path), rel_paths
   428	  )
   429	  if (length(offenders) > 0) {
   430	    stop(sprintf(
   431	      "Zenodo staging contains file(s) with an unexpected type/suffix: %s",
   432	      paste(offenders, collapse = ", ")
   433	    ), call. = FALSE)
   434	  }
   435	  invisible(TRUE)
   436	}
   437
   438	.analysis_release_zenodo_validate_no_sensitive_text <- function(staging_dir) {
   439	  offenders <- character(0)
   440	  for (rel_path in .analysis_release_zenodo_iter_public_files(staging_dir)) {
   441	    if (!.analysis_release_zenodo_has_allowed_suffix(rel_path)) {
   442	      next
   443	    }
   444	    full_path <- file.path(staging_dir, rel_path)
   445	    text <- tolower(paste(readLines(full_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
   446	    hit <- Find(function(pattern) grepl(pattern, text, fixed = TRUE),
   447	                .ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS)
   448	    if (!is.null(hit)) {
   449	      offenders <- c(offenders, sprintf("%s (matched '%s')", rel_path, hit))
   450	    }
   451	  }
   452	  if (length(offenders) > 0) {
   453	    stop(sprintf(
   454	      "Zenodo staging contains sensitive public text: %s",
   455	      paste(offenders, collapse = "; ")
   456	    ), call. = FALSE)
   457	  }
   458	  invisible(TRUE)
   459	}
   460
   461	.analysis_release_zenodo_validate_layout <- function(staging_dir) {
   462	  expected_top <- .ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL
   463	  expected_nested <- file.path(
   464	    .ANALYSIS_RELEASE_ZENODO_NESTED_DIR, .ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED
   465	  )
   466	  expected <- c(expected_top, expected_nested)
   467
   468	  missing <- Filter(function(rel_path) !file.exists(file.path(staging_dir, rel_path)), expected)
   469	  if (length(missing) > 0) {
   470	    stop(sprintf(
   471	      "Zenodo staging is missing expected members: %s",
   472	      paste(missing, collapse = ", ")
   473	    ), call. = FALSE)
   474	  }
   475	  invisible(TRUE)
   476	}
   477
   478	#' The safety validator. Independent checks, in order; stops with a clear
   479	#' message naming the offending relative paths on the first failing check.
   480	analysis_release_zenodo_validate_staging <- function(staging_dir) {
   481	  .analysis_release_zenodo_validate_no_forbidden(staging_dir)
   482	  .analysis_release_zenodo_validate_no_symlinks(staging_dir)
   483	  .analysis_release_zenodo_validate_allowed_suffix(staging_dir)
   484	  .analysis_release_zenodo_validate_no_sensitive_text(staging_dir)
   485	  .analysis_release_zenodo_validate_layout(staging_dir)
   486	  invisible(TRUE)
   487	}
     1	# api/functions/analysis-snapshot-release-zenodo-package.R
     2	#
     3	# Pure, host-runnable operator-script helper for packaging a PUBLISHED
     4	# analysis-snapshot release (#573) into a Zenodo-shaped dataset staging
     5	# directory + deterministic tar.gz archive. This is NOT API-runtime code: it
     6	# is not registered in `bootstrap/load_modules.R`. The C2 CLI wrapper
     7	# (`api/scripts/package-analysis-release-zenodo.R`) sources this file
     8	# directly; tests use `source_api_file(..., local = FALSE)`.
     9	#
    10	# Read path: the PUBLIC HTTP API only (no DB, no docker exec) --
    11	#   GET {api_base_url}/api/analysis/releases/{latest|<release_id>}
    12	#   GET {api_base_url}/api/analysis/releases/<release_id>/bundle
    13	# A release is already a complete, self-verifying, content-addressed export
    14	# (see AGENTS.md "Analysis-snapshot releases (#573)"), so the packager's job
    15	# is narrow: download + verify the bundle, re-stage its files UNMODIFIED
    16	# under `analysis_snapshot_release/`, add Zenodo-facing docs/metadata, write
    17	# a staging-wide checksums.sha256, run the safety validator, then tar.
    18	#
    19	# Mirrors the sibling `../nddscore/src/models/sysndd_export.py` builders
    20	# (translated Python -> R) and reuses the fetch/extract/verify idioms from
    21	# `functions/nddscore-release-source.R` -- except the release bundle's own
    22	# checksum is SHA-256 (`bundle_sha256` on the release head), not the MD5
    23	# Zenodo's OWN file listing uses for the (unrelated) inbound nddscore fetch.
    24	#
    25	# Every HTTP/file-IO boundary is an injectable parameter with a real default
    26	# (the `.analysis_release_zenodo_http_*` seams below), so unit tests inject
    27	# plain stub closures -- no mocking library, no real network. Per AGENTS.md
    28	# ("External-budget guard: Slice C scripts ARE EXEMPT" in the scout, and the
    29	# documented `publication-functions.R`/`nddscore-release-source.R`
    30	# precedent), one-shot operator scripts are outside
    31	# `external_proxy_budget()` -- plain `httr2::req_timeout()`/`req_retry()`
    32	# literals are used directly.
    33	#
    34	# Doc-string builders live in the sibling
    35	# `analysis-snapshot-release-zenodo-docs.R` (guard-sourced below); the
    36	# fetch/download/extract-verify helpers and the safety validator live in the
    37	# sibling `analysis-snapshot-release-zenodo-verify.R` (also guard-sourced
    38	# below) -- both splits keep every file under the repo's 600-line soft
    39	# ceiling.
    40
    41	`%||%` <- function(a, b) {
    42	  if (is.null(a) || length(a) == 0) {
    43	    b
    44	  } else {
    45	    a
    46	  }
    47	}
    48
    49	if (!exists(".analysis_release_zenodo_docs_loaded", mode = "logical")) {
    50	  # Resolve this file's own directory from the active source() frame (the
    51	  # proven `helper-functions.R` / `async-job-repository.R` idiom) so the
    52	  # sibling docs file loads regardless of cwd or how this file was sourced.
    53	  .analysis_release_zenodo_self_dir <- local({
    54	    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
    55	    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
    56	  })
    57	  .analysis_release_zenodo_docs_candidates <- c(
    58	    if (!is.null(.analysis_release_zenodo_self_dir)) {
    59	      file.path(.analysis_release_zenodo_self_dir, "analysis-snapshot-release-zenodo-docs.R")
    60	    },
    61	    "functions/analysis-snapshot-release-zenodo-docs.R",
    62	    "/app/functions/analysis-snapshot-release-zenodo-docs.R"
    63	  )
    64	  for (.analysis_release_zenodo_docs_path in .analysis_release_zenodo_docs_candidates) {
    65	    if (file.exists(.analysis_release_zenodo_docs_path)) {
    66	      # local = TRUE (not FALSE): evaluate into THIS call's parent frame, i.e.
    67	      # the same environment this main file is itself being sourced into
    68	      # (mirrors the working `async-job-repository.R` guard-source precedent).
    69	      # `local = FALSE` would instead always target globalenv() regardless of
    70	      # caller, splitting the two files' symbols across different
    71	      # environments whenever `source_api_file(local = FALSE)` sources this
    72	      # file into a non-global test environment.
    73	      source(.analysis_release_zenodo_docs_path, local = TRUE)
    74	      break
    75	    }
    76	  }
    77	  rm(.analysis_release_zenodo_self_dir, .analysis_release_zenodo_docs_candidates, .analysis_release_zenodo_docs_path)
    78	}
    79
    80	if (!exists(".analysis_release_zenodo_verify_loaded", mode = "logical")) {
    81	  # Same guard-source idiom as the docs block above, targeting the sibling
    82	  # fetch/extract-verify + safety-validator file instead.
    83	  .analysis_release_zenodo_self_dir <- local({
    84	    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
    85	    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
    86	  })
    87	  .analysis_release_zenodo_verify_candidates <- c(
    88	    if (!is.null(.analysis_release_zenodo_self_dir)) {
    89	      file.path(.analysis_release_zenodo_self_dir, "analysis-snapshot-release-zenodo-verify.R")
    90	    },
    91	    "functions/analysis-snapshot-release-zenodo-verify.R",
    92	    "/app/functions/analysis-snapshot-release-zenodo-verify.R"
    93	  )
    94	  for (.analysis_release_zenodo_verify_path in .analysis_release_zenodo_verify_candidates) {
    95	    if (file.exists(.analysis_release_zenodo_verify_path)) {
    96	      # local = TRUE for the same reason as the docs block above.
    97	      source(.analysis_release_zenodo_verify_path, local = TRUE)
    98	      break
    99	    }
   100	  }
   101	  rm(
   102	    .analysis_release_zenodo_self_dir, .analysis_release_zenodo_verify_candidates,
   103	    .analysis_release_zenodo_verify_path
   104	  )
   105	}
   106
   107	# --------------------------------------------------------------------------- #
   108	# Builders (pure)
   109	# --------------------------------------------------------------------------- #
   110
   111	.analysis_release_zenodo_created_at_date <- function(created_at) {
   112	  value <- as.character(created_at %||% "")[[1]]
   113	  if (!nzchar(value)) {
   114	    return("")
   115	  }
   116	  candidate <- substr(value, 1, 10)
   117	  if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", candidate)) candidate else value
   118	}
   119
   120	#' Build the Zenodo metadata list -- becomes `zenodo_metadata.json` AND the
   121	#' body `set_metadata()` PUTs (C2). Never includes a `doi` key: Zenodo mints
   122	#' the DOI on deposition creation.
   123	#'
   124	#' @param head The release head (from `analysis_release_zenodo_fetch_head()`).
   125	#' @param version Optional override; default `head$source_data_version` or
   126	#'   `head$release_id`.
   127	#' @param license_id Optional override; default `head$license` or `"cc-by-4.0"`.
   128	analysis_release_zenodo_build_metadata <- function(head, version = NULL, license_id = NULL) {
   129	  release_id <- as.character(head$release_id %||% "")[[1]]
   130	  release_date <- .analysis_release_zenodo_created_at_date(head$created_at)
   131	  title <- if (nzchar(release_date)) {
   132	    sprintf("SysNDD analysis-snapshot release %s, %s", release_id, release_date)
   133	  } else {
   134	    sprintf("SysNDD analysis-snapshot release %s", release_id)
   135	  }
   136
   137	  resolved_license <- license_id %||% head$license %||% "cc-by-4.0"
   138	  resolved_version <- as.character((version %||% head$source_data_version %||% release_id))[[1]]
   139
   140	  description <- paste0(
   141	    "<p>Immutable, content-addressed public export of a SysNDD analysis-snapshot ",
   142	    "release: the functional (STRING/Leiden) clusters, the phenotype (MCA/HCPC) ",
   143	    "clusters, and the phenotype-functional correlation layer, each derived from ",
   144	    "approved public SysNDD curation data.</p>",
   145	    "<p>Every layer and file is independently verifiable via the bundled ",
   146	    "manifest.json and checksums.sha256. This is a derived analysis product, not a ",
   147	    "copy of the primary curated evidence.</p>"
   148	  )
   149
   150	  list(
   151	    title = title,
   152	    upload_type = "dataset",
   153	    description = description,
   154	    creators = list(list(name = "Popp, Bernt", orcid = "0000-0002-3679-1081")),
   155	    keywords = list(
   156	      "SysNDD", "neurodevelopmental disorders", "gene-disease", "clustering",
   157	      "analysis snapshot"
   158	    ),
   159	    access_right = "open",
   160	    license = as.character(resolved_license)[[1]],
   161	    version = resolved_version,
   162	    language = "eng"
   163	  )
   164	}
   165
   166	#' Build a Frictionless Data Package describing the WHOLE staging tree.
   167	#'
   168	#' @param staging_dir Root of the staging directory (already populated).
   169	#' @param name Dataset machine name.
   170	#' @param version Dataset version string.
   171	#' @param release_id The release id (becomes the datapackage `id`).
   172	analysis_release_zenodo_build_datapackage <- function(staging_dir, name, version, release_id) {
   173	  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
   174	  rel_paths <- base::setdiff(rel_paths, c("checksums.sha256", "datapackage.json"))
   175
   176	  resources <- lapply(rel_paths, function(rel_path) {
   177	    full_path <- file.path(staging_dir, rel_path)
   178	    list(
   179	      name = gsub("\\.", "-", gsub("/", "-", rel_path)),
   180	      path = rel_path,
   181	      bytes = as.numeric(file.info(full_path)$size),
   182	      hash = digest::digest(file = full_path, algo = "sha256"),
   183	      mediatype = "application/octet-stream"
   184	    )
   185	  })
   186
   187	  list(
   188	    profile = "data-package",
   189	    name = as.character(name)[[1]],
   190	    title = "SysNDD analysis-snapshot release",
   191	    version = as.character(version)[[1]],
   192	    id = as.character(release_id)[[1]],
   193	    licenses = list(list(name = "CC-BY-4.0", path = "https://creativecommons.org/licenses/by/4.0/")),
   194	    resources = resources
   195	  )
   196	}
   197
   198	# --------------------------------------------------------------------------- #
   199	# Staging + checksums + tarball
   200	# --------------------------------------------------------------------------- #
   201
   202	.analysis_release_zenodo_write_text <- function(path, content) {
   203	  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
   204	  cat(content, file = path)
   205	  invisible(path)
   206	}
   207
   208	#' Write `checksums.sha256` at the staging root, covering every iterated file
   209	#' (excluding itself). Byte-identical format to
   210	#' `analysis_release_checksums_text()`: `"<sha256>  <path>\n"` lines.
   211	#'
   212	#' @return The written path.
   213	analysis_release_zenodo_write_checksums <- function(staging_dir) {
   214	  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
   215	  rel_paths <- rel_paths[rel_paths != "checksums.sha256"]
   216
   217	  content <- if (length(rel_paths) == 0L) {
   218	    ""
   219	  } else {
   220	    lines <- vapply(rel_paths, function(rel_path) {
   221	      full_path <- file.path(staging_dir, rel_path)
   222	      paste0(digest::digest(file = full_path, algo = "sha256"), "  ", rel_path)
   223	    }, character(1))
   224	    paste0(paste(lines, collapse = "\n"), "\n")
   225	  }
   226
   227	  out_path <- file.path(staging_dir, "checksums.sha256")
   228	  .analysis_release_zenodo_write_text(out_path, content)
   229	  out_path
   230	}
   231
   232	# A fixed, arbitrary epoch every staged file/dir's mtime is normalized to
   233	# before tarring (item 5). R's internal tar writer already zeroes the gzip
   234	# container's own embedded timestamp, so per-file mtimes are the ONLY
   235	# remaining source of non-determinism between two builds of the same staged
   236	# content; normalizing them makes the resulting `.tar.gz` byte-identical
   237	# across runs (proved by
   238	# `test-unit-analysis-release-zenodo-package.R`'s "packaging the SAME staged
   239	# content twice" determinism test).
   240	.ANALYSIS_RELEASE_ZENODO_TAR_FIXED_TIME <- as.POSIXct("2020-01-01", tz = "UTC")
   241
   242	#' Set every file's and directory's mtime under `staging_dir` (INCLUDING
   243	#' `staging_dir` itself) to a fixed epoch, deepest-first, so a rebuild of the
   244	#' identical content never differs by mtime alone.
   245	.analysis_release_zenodo_normalize_mtimes <- function(staging_dir) {
   246	  entries <- list.files(
   247	    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE,
   248	    full.names = TRUE, include.dirs = TRUE
   249	  )
   250	  # Deepest-first: a directory's own mtime is set only after every entry
   251	  # nested inside it, so nothing touched later in this loop bumps it again.
   252	  depth <- lengths(strsplit(entries, "/", fixed = TRUE))
   253	  entries <- entries[order(-depth)]
   254	  for (path in entries) {
   255	    Sys.setFileTime(path, .ANALYSIS_RELEASE_ZENODO_TAR_FIXED_TIME)
   256	  }
   257	  Sys.setFileTime(staging_dir, .ANALYSIS_RELEASE_ZENODO_TAR_FIXED_TIME)
   258	  invisible(TRUE)
   259	}
   260
   261	#' Deterministic gzip tarball with ONE top-level dir (`basename(staging_dir)`).
   262	#' Also writes `<archive_path>.sha256` (`"<sha256>  <basename>\n"`).
   263	#'
   264	#' @return list(archive_path, archive_sha256_path).
   265	analysis_release_zenodo_make_tarball <- function(staging_dir, archive_path) {
   266	  archive_dir <- dirname(archive_path)
   267	  dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
   268	  archive_path <- normalizePath(file.path(archive_dir, basename(archive_path)), mustWork = FALSE)
   269
   270	  staging_dir <- normalizePath(staging_dir, mustWork = TRUE)
   271	  parent_dir <- dirname(staging_dir)
   272	  base_name <- basename(staging_dir)
   273
   274	  .analysis_release_zenodo_normalize_mtimes(staging_dir)
   275
   276	  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
   277	  entries <- sort(file.path(base_name, rel_paths))
   278
   279	  previous_wd <- setwd(parent_dir)
   280	  on.exit(setwd(previous_wd), add = TRUE)
   281	  # tar = "internal" forces R's built-in (pure-R) tar writer so the archive
   282	  # never depends on a system `tar` binary being present/compatible.
   283	  utils::tar(tarfile = archive_path, files = entries, compression = "gzip", tar = "internal")
   284
   285	  sha256 <- digest::digest(file = archive_path, algo = "sha256")
   286	  sha_path <- paste0(archive_path, ".sha256")
   287	  cat(paste0(sha256, "  ", basename(archive_path), "\n"), file = sha_path)
   288
   289	  list(archive_path = archive_path, archive_sha256_path = sha_path)
   290	}
   291
   292	# --------------------------------------------------------------------------- #
   293	# Orchestrator
   294	# --------------------------------------------------------------------------- #
   295
   296	#' Recursively sort a named list's keys alphabetically (objects only --
   297	#' unnamed lists/arrays are recursed into without reordering). Used for
   298	#' `zenodo_metadata.json`'s "pretty JSON, sorted keys" contract, mirroring
   299	#' Python's `json.dumps(..., sort_keys=True)`.
   300	.analysis_release_zenodo_sort_keys <- function(x) {
   301	  if (is.list(x)) {
   302	    nms <- names(x)
   303	    if (!is.null(nms) && all(nzchar(nms))) {
   304	      x <- x[order(nms)]
   305	    }
   306	    x <- lapply(x, .analysis_release_zenodo_sort_keys)
   307	  }
   308	  x
   309	}
   310
   311	.analysis_release_zenodo_copy_tree <- function(src_dir, dest_dir) {
   312	  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
   313	  rel_paths <- list.files(src_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
   314	  for (rel_path in rel_paths) {
   315	    dest_path <- file.path(dest_dir, rel_path)
   316	    dir.create(dirname(dest_path), recursive = TRUE, showWarnings = FALSE)
   317	    file.copy(file.path(src_dir, rel_path), dest_path, overwrite = TRUE, copy.date = TRUE)
   318	  }
   319	  invisible(dest_dir)
   320	}
   321
   322	#' Fetch a published release over the public HTTP API and assemble a Zenodo
   323	#' staging directory + deterministic tarball. Mirrors nddscore's
   324	#' `build_zenodo_dataset_package()` top-to-bottom.
   325	#'
   326	#' @return list(staging_dir, archive_path, archive_sha256_path,
   327	#'   zenodo_metadata_path, release_id).
   328	analysis_release_zenodo_package <- function(
   329	    api_base_url,
   330	    release_id = "latest",
   331	    staging_dir,
   332	    archive_dir,
   333	    version = NULL,
   334	    doi = NULL,
   335	    http_get_json = .analysis_release_zenodo_http_get_json,
   336	    http_download = .analysis_release_zenodo_http_download) {
   337	  head <- analysis_release_zenodo_fetch_head(api_base_url, release_id, http_get_json = http_get_json)
   338	  resolved_release_id <- as.character(head$release_id)[[1]]
   339	  # Defense-in-depth (item 2): re-validate the RESOLVED id even though the
   340	  # REQUEST arg was already validated inside fetch_head() -- this is the
   341	  # value that actually becomes `<release_id>.tar.gz` and the `RELEASE_ID=`
   342	  # marker line, so a compromised/misbehaving API response can never smuggle
   343	  # a path/marker-injection payload through.
   344	  .analysis_release_zenodo_assert_valid_release_id(resolved_release_id, allow_latest = FALSE)
   345
   346	  bundle_path <- tempfile(fileext = ".tar.gz")
   347	  on.exit(unlink(bundle_path, force = TRUE), add = TRUE)
   348	  analysis_release_zenodo_download_bundle(
   349	    api_base_url, resolved_release_id, bundle_path, http_download = http_download
   350	  )
   351	  extracted_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, head$bundle_sha256)
   352	  on.exit(unlink(extracted_dir, recursive = TRUE, force = TRUE), add = TRUE)
   353
   354	  # BLOCKER guard (item 1): refuse to recursively delete a pre-existing
   355	  # `--staging-dir` unless this tool itself created it (empty, absent, or
   356	  # carrying the ownership sentinel) -- an operator typo must never
   357	  # irreversibly rmtree an unrelated directory.
   358	  .analysis_release_zenodo_assert_staging_deletable(staging_dir)
   359	  if (dir.exists(staging_dir)) {
   360	    unlink(staging_dir, recursive = TRUE, force = TRUE)
   361	  }
   362	  dir.create(staging_dir, recursive = TRUE)
   363	  .analysis_release_zenodo_write_staging_sentinel(staging_dir)
   364
   365	  nested_dir <- file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_NESTED_DIR)
   366	  .analysis_release_zenodo_copy_tree(extracted_dir, nested_dir)
   367
   368	  resolved_version <- as.character(
   369	    (version %||% head$source_data_version %||% resolved_release_id)
   370	  )[[1]]
   371
   372	  .analysis_release_zenodo_write_text(
   373	    file.path(staging_dir, "README.md"), analysis_release_zenodo_build_readme(head, doi)
   374	  )
   375	  .analysis_release_zenodo_write_text(
   376	    file.path(staging_dir, "DATA_CARD.md"), analysis_release_zenodo_build_data_card(head)
   377	  )
   378	  .analysis_release_zenodo_write_text(
   379	    file.path(staging_dir, "SCHEMA.md"), analysis_release_zenodo_build_schema_doc(head)
   380	  )
   381	  .analysis_release_zenodo_write_text(
   382	    file.path(staging_dir, "CHANGELOG.md"),
   383	    analysis_release_zenodo_build_changelog(head, resolved_version)
   384	  )
   385	  .analysis_release_zenodo_write_text(
   386	    file.path(staging_dir, "CITATION.cff"),
   387	    analysis_release_zenodo_build_citation_cff(head, resolved_version, doi)
   388	  )
   389
   390	  metadata <- analysis_release_zenodo_build_metadata(head, version = resolved_version)
   391	  metadata_json <- jsonlite::toJSON(
   392	    .analysis_release_zenodo_sort_keys(metadata), auto_unbox = TRUE, pretty = TRUE, null = "null"
   393	  )
   394	  zenodo_metadata_path <- file.path(staging_dir, "zenodo_metadata.json")
   395	  .analysis_release_zenodo_write_text(zenodo_metadata_path, paste0(as.character(metadata_json), "\n"))
   396
   397	  datapackage <- analysis_release_zenodo_build_datapackage(
   398	    staging_dir,
   399	    name = "sysndd-analysis-snapshot-release",
   400	    version = resolved_version,
   401	    release_id = resolved_release_id
   402	  )
   403	  datapackage_json <- jsonlite::toJSON(datapackage, auto_unbox = TRUE, pretty = TRUE, null = "null")
   404	  .analysis_release_zenodo_write_text(
   405	    file.path(staging_dir, "datapackage.json"), paste0(as.character(datapackage_json), "\n")
   406	  )
   407
   408	  analysis_release_zenodo_write_checksums(staging_dir)
   409
   410	  analysis_release_zenodo_validate_staging(staging_dir)
   411
   412	  archive_path <- file.path(archive_dir, paste0(resolved_release_id, ".tar.gz"))
   413	  tar_result <- analysis_release_zenodo_make_tarball(staging_dir, archive_path)
   414
   415	  list(
   416	    staging_dir = staging_dir,
   417	    archive_path = tar_result$archive_path,
   418	    archive_sha256_path = tar_result$archive_sha256_path,
   419	    zenodo_metadata_path = zenodo_metadata_path,
   420	    release_id = resolved_release_id
   421	  )
   422	}
     1	# api/functions/analysis-snapshot-release-zenodo-upload.R
     2	#
     3	# Pure, host-runnable operator-script helper (#573 Slice C / Task C2) for
     4	# uploading a Zenodo-staged analysis-snapshot release archive
     5	# (`api/functions/analysis-snapshot-release-zenodo-package.R`'s output) to a
     6	# Zenodo deposition, and (opt-in) recording the resulting DOI/record back
     7	# onto the SysNDD release head. NOT API-runtime code: it is not registered in
     8	# `bootstrap/load_modules.R`. The C2 CLI wrapper
     9	# (`api/scripts/upload-analysis-release-zenodo.R`) sources this file
    10	# directly; tests use `source_api_file(..., local = FALSE)`.
    11	#
    12	# Mirrors the sibling `../nddscore/scripts/upload_sysndd_zenodo_dataset.py`
    13	# flow (deposition get-or-create -> set metadata -> PUT archive to bucket ->
    14	# optional publish), translated Python -> R.
    15	#
    16	# Every HTTP boundary is an injectable seam parameter with a real `httr2`
    17	# default (the `.analysis_release_zenodo_http_*` functions below), so unit
    18	# tests inject plain stub closures -- no mocking library, no real network.
    19	# Per AGENTS.md ("External-budget guard: Slice C scripts ARE EXEMPT" in the
    20	# planning scout, and the documented `publication-functions.R`/
    21	# `nddscore-release-source.R` precedent), one-shot operator scripts are
    22	# outside `external_proxy_budget()` -- plain `httr2::req_timeout()` literals
    23	# are used directly.
    24	#
    25	# Publish is DOUBLE-gated: `analysis_release_zenodo_require_publish_confirmation()`
    26	# stops unless BOTH `publish` and `confirm_publish` are set -- the orchestrator
    27	# is draft-only by default. DOI record-back to the SysNDD admin API is OPT-IN
    28	# and lives OUTSIDE this pure orchestrator (it is invoked by the CLI script,
    29	# Deliverable 3), so this file stays free of SysNDD-admin coupling and easy to
    30	# test in isolation.
    31
    32	`%||%` <- function(a, b) {
    33	  if (is.null(a) || length(a) == 0) {
    34	    b
    35	  } else {
    36	    a
    37	  }
    38	}
    39
    40	# --------------------------------------------------------------------------- #
    41	# Zenodo API base URLs + publish safety interlock
    42	# --------------------------------------------------------------------------- #
    43
    44	.ANALYSIS_RELEASE_ZENODO_API_PROD <- "https://zenodo.org/api"
    45	.ANALYSIS_RELEASE_ZENODO_API_SANDBOX <- "https://sandbox.zenodo.org/api"
    46
    47	#' Resolve the Zenodo API base URL for the requested environment.
    48	analysis_release_zenodo_resolve_api <- function(sandbox = FALSE) {
    49	  if (isTRUE(sandbox)) {
    50	    .ANALYSIS_RELEASE_ZENODO_API_SANDBOX
    51	  } else {
    52	    .ANALYSIS_RELEASE_ZENODO_API_PROD
    53	  }
    54	}
    55
    56	#' Stop unless BOTH `publish` and `confirm_publish` are set. A `publish`
    57	#' request without explicit confirmation is refused -- draft-only is the
    58	#' default, safe outcome. Mirrors the Python sibling's
    59	#' `require_publish_confirmation()` (there a `SystemExit`; here a `stop()`).
    60	analysis_release_zenodo_require_publish_confirmation <- function(publish, confirm_publish) {
    61	  if (isTRUE(publish) && !isTRUE(confirm_publish)) {
    62	    stop("--publish requires --confirm-publish", call. = FALSE)
    63	  }
    64	  invisible(NULL)
    65	}
    66
    67	# --------------------------------------------------------------------------- #
    68	# DI seams: default httr2 implementations. Tests inject plain stub closures
    69	# with the SAME formal signature instead of mocking httr2/network calls.
    70	# --------------------------------------------------------------------------- #
    71
    72	#' Default JSON request against the Zenodo deposit API. `token` is turned
    73	#' into a `Authorization: Bearer <token>` header; a non-NULL `body` is sent
    74	#' as a JSON object (Content-Type set by `httr2::req_body_json()`). The
    75	#' create-deposition call passes `body = list()`, which `jsonlite::toJSON()`
    76	#' would otherwise serialize as `[]` (an empty *array*) rather than the `{}`
    77	#' Zenodo's API expects for "create an empty deposition" -- special-cased via
    78	#' `req_body_raw()` so the wire format is the literal JSON object Zenodo
    79	#' documents.
    80	.analysis_release_zenodo_http_json <- function(method, url, token, body = NULL) {
    81	  req <- httr2::request(url) |>
    82	    httr2::req_method(method) |>
    83	    httr2::req_headers(Authorization = paste("Bearer", as.character(token)[[1]])) |>
    84	    httr2::req_timeout(60)
    85
    86	  if (!is.null(body)) {
    87	    req <- if (is.list(body) && length(body) == 0) {
    88	      httr2::req_body_raw(req, "{}", type = "application/json")
    89	    } else {
    90	      httr2::req_body_json(req, body, auto_unbox = TRUE)
    91	    }
    92	  }
    93
    94	  resp <- httr2::req_perform(req)
    95	  httr2::resp_body_json(resp, simplifyVector = FALSE)
    96	}
    97
    98	#' Default streaming file PUT to a Zenodo bucket URL. Streams `archive_path`
    99	#' from disk as the raw request body (`httr2::req_body_file()`), Bearer auth,
   100	#' a long timeout (large archives, slow upload links).
   101	.analysis_release_zenodo_http_put_file <- function(url, token, archive_path) {
   102	  httr2::request(url) |>
   103	    httr2::req_method("PUT") |>
   104	    httr2::req_headers(Authorization = paste("Bearer", as.character(token)[[1]])) |>
   105	    httr2::req_timeout(3600) |>
   106	    httr2::req_body_file(archive_path) |>
   107	    httr2::req_perform()
   108	}
   109
   110	# --------------------------------------------------------------------------- #
   111	# Deposition lifecycle
   112	# --------------------------------------------------------------------------- #
   113
   114	#' Get-or-create a Zenodo deposition. `deposition_id = NULL` creates a fresh
   115	#' draft (`POST {api}/deposit/depositions` with an empty JSON object body);
   116	#' an explicit id reuses an existing draft (`GET
   117	#' {api}/deposit/depositions/{id}`). Returns the parsed deposition list.
   118	#'
   119	#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
   120	#'   Injectable seam; defaults to the real httr2 call.
   121	analysis_release_zenodo_get_or_create_deposition <- function(
   122	    api, token, deposition_id = NULL, http = .analysis_release_zenodo_http_json) {
   123	  api <- sub("/+$", "", as.character(api)[[1]])
   124	  if (is.null(deposition_id)) {
   125	    http("POST", paste0(api, "/deposit/depositions"), token, body = list())
   126	  } else {
   127	    deposition_id <- as.character(deposition_id)[[1]]
   128	    http("GET", paste0(api, "/deposit/depositions/", deposition_id), token)
   129	  }
   130	}
   131
   132	#' Overwrite a deposition's metadata. `PUT {api}/deposit/depositions/{id}`
   133	#' with body `{"metadata": <metadata>}`.
   134	#'
   135	#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
   136	analysis_release_zenodo_set_metadata <- function(
   137	    api, token, deposition_id, metadata, http = .analysis_release_zenodo_http_json) {
   138	  api <- sub("/+$", "", as.character(api)[[1]])
   139	  deposition_id <- as.character(deposition_id)[[1]]
   140	  url <- paste0(api, "/deposit/depositions/", deposition_id)
   141	  http("PUT", url, token, body = list(metadata = metadata))
   142	}
   143
   144	#' Stream the archive to the deposition's Zenodo bucket.
   145	#' `PUT {bucket_url}/{basename(archive_path)}`.
   146	#'
   147	#' @param put Function(url, token, archive_path). Injectable seam; defaults
   148	#'   to the real httr2 streaming PUT.
   149	#' @return The upload URL, invisibly.
   150	analysis_release_zenodo_upload_bucket <- function(
   151	    bucket_url, token, archive_path, put = .analysis_release_zenodo_http_put_file) {
   152	  bucket_url <- sub("/+$", "", as.character(bucket_url)[[1]])
   153	  url <- paste0(bucket_url, "/", basename(archive_path))
   154	  put(url, token, archive_path)
   155	  invisible(url)
   156	}
   157
   158	#' Publish a draft deposition. `POST
   159	#' {api}/deposit/depositions/{id}/actions/publish`. Returns the published
   160	#' deposition (`{doi, conceptdoi, id, links: {html, ...}}`).
   161	#'
   162	#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
   163	analysis_release_zenodo_publish_deposition <- function(
   164	    api, token, deposition_id, http = .analysis_release_zenodo_http_json) {
   165	  api <- sub("/+$", "", as.character(api)[[1]])
   166	  deposition_id <- as.character(deposition_id)[[1]]
   167	  url <- paste0(api, "/deposit/depositions/", deposition_id, "/actions/publish")
   168	  http("POST", url, token)
   169	}
   170
   171	# --------------------------------------------------------------------------- #
   172	# DOI record-back (OPT-IN, SysNDD-admin side) -- additive metadata, outside
   173	# any release content hash. Never called automatically; the CLI script only
   174	# invokes `analysis_release_zenodo_record_doi()` when the operator passes
   175	# `--record-doi` AND `SYSNDD_ADMIN_TOKEN` is set. Otherwise it prints
   176	# `analysis_release_zenodo_manual_doi_command()` so the operator can record
   177	# it by hand.
   178	# --------------------------------------------------------------------------- #
   179
   180	.ANALYSIS_RELEASE_ZENODO_DOI_FIELD_NAMES <- c(
   181	  "zenodo_record_id", "zenodo_record_url", "version_doi", "concept_doi"
   182	)
   183
   184	#' Keep only the four recognized DOI fields with a non-empty value. An
   185	#' omitted/NULL/NA/empty-string field is dropped, never forwarded as "",
   186	#' NULL, or NA -- the admin endpoint treats an omitted field as "leave
   187	#' unchanged", so a forwarded empty value would incorrectly clear it.
   188	#' `is.na()` is checked BEFORE `nzchar()` because `nzchar(NA_character_)` is
   189	#' TRUE in R -- without the guard an NA field survives the filter and is
   190	#' emitted as an explicit `null` instead of being omitted.
   191	.analysis_release_zenodo_doi_non_empty_fields <- function(doi_fields) {
   192	  doi_fields <- doi_fields[names(doi_fields) %in% .ANALYSIS_RELEASE_ZENODO_DOI_FIELD_NAMES]
   193	  Filter(function(value) {
   194	    if (is.null(value) || length(value) == 0) {
   195	      return(FALSE)
   196	    }
   197	    scalar <- value[[1]]
   198	    if (is.na(scalar)) {
   199	      return(FALSE)
   200	    }
   201	    nzchar(trimws(as.character(scalar)))
   202	  }, doi_fields)
   203	}
   204
   205	#' PATCH the four Zenodo/DOI provenance fields onto a published release head.
   206	#' Additive-only: forwards ONLY the supplied non-empty fields, matching the
   207	#' admin endpoint's "an omitted field is left unchanged, never nulled out"
   208	#' contract (see AGENTS.md "Analysis-snapshot releases (#573)").
   209	#'
   210	#' @param sysndd_api_base_url Base URL of the SysNDD API.
   211	#' @param admin_token A pre-minted SysNDD Administrator bearer token
   212	#'   (`SYSNDD_ADMIN_TOKEN`). Distinct from the Zenodo `token` used elsewhere
   213	#'   in this file.
   214	#' @param patch Function(method, url, token, body = NULL) -> parsed JSON list.
   215	#'   Injectable seam; defaults to the real httr2 call.
   216	analysis_release_zenodo_record_doi <- function(
   217	    sysndd_api_base_url, admin_token, release_id, doi_fields,
   218	    patch = .analysis_release_zenodo_http_json) {
   219	  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
   220	  release_id <- as.character(release_id)[[1]]
   221	  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
   222	  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
   223	  patch("PATCH", url, admin_token, body = fields)
   224	}
   225
   226	#' Build the exact `curl -X PATCH ...` command an operator can run by hand to
   227	#' record DOI/record provenance when `--record-doi` was not opted into (the
   228	#' default). Never executed automatically.
   229	analysis_release_zenodo_manual_doi_command <- function(sysndd_api_base_url, release_id, doi_fields) {
   230	  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
   231	  release_id <- as.character(release_id)[[1]]
   232	  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
   233	  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
   234	  body_json <- as.character(jsonlite::toJSON(fields, auto_unbox = TRUE))
   235
   236	  paste0(
   237	    "curl -X PATCH '", url, "' ",
   238	    "-H 'Authorization: Bearer <SYSNDD_ADMIN_TOKEN>' ",
   239	    "-H 'Content-Type: application/json' ",
   240	    "-d '", body_json, "'"
   241	  )
   242	}
   243
   244	# --------------------------------------------------------------------------- #
   245	# Orchestrator -- mirrors the Python sibling's `main()` flow. Pure w.r.t.
   246	# SysNDD: it never calls `analysis_release_zenodo_record_doi()` itself (the
   247	# CLI script does that, after this returns).
   248	# --------------------------------------------------------------------------- #
   249
   250	#' Upload a packaged Zenodo archive: get-or-create deposition -> set metadata
   251	#' -> stream archive to bucket -> (if `publish`) publish. Draft-only unless
   252	#' BOTH `publish` and `confirm_publish` are set (enforced first, via
   253	#' `analysis_release_zenodo_require_publish_confirmation()`).
   254	#'
   255	#' @return list(deposition_id, reserved_doi, draft_url, published (bool),
   256	#'   version_doi, concept_doi, record_url). `version_doi`/`concept_doi`/
   257	#'   `record_url` are `NA_character_` unless `published` is TRUE.
   258	analysis_release_zenodo_upload <- function(
   259	    archive_path,
   260	    metadata_path,
   261	    token,
   262	    sandbox = FALSE,
   263	    deposition_id = NULL,
   264	    publish = FALSE,
   265	    confirm_publish = FALSE,
   266	    get_or_create_deposition = analysis_release_zenodo_get_or_create_deposition,
   267	    set_metadata = analysis_release_zenodo_set_metadata,
   268	    upload_bucket = analysis_release_zenodo_upload_bucket,
   269	    publish_deposition = analysis_release_zenodo_publish_deposition) {
   270	  analysis_release_zenodo_require_publish_confirmation(publish, confirm_publish)
   271
   272	  if (is.null(token) || !nzchar(as.character(token)[[1]])) {
   273	    # No `--token` CLI flag exists (item 6, #573 Slice C hardening) -- a
   274	    # flag would leak the token into shell history/argv. The `token`
   275	    # parameter here is for programmatic/test callers only; the CLI wrapper
   276	    # always resolves it from `Sys.getenv("ZENODO_TOKEN")`.
   277	    stop("ZENODO_TOKEN not set (export it in your shell before running this script)", call. = FALSE)
   278	  }
   279	  if (!file.exists(archive_path)) {
   280	    stop(sprintf("Archive does not exist: %s", archive_path), call. = FALSE)
   281	  }
   282	  if (!file.exists(metadata_path)) {
   283	    stop(sprintf("Metadata does not exist: %s", metadata_path), call. = FALSE)
   284	  }
   285
   286	  api <- analysis_release_zenodo_resolve_api(sandbox)
   287	  metadata <- jsonlite::fromJSON(metadata_path, simplifyVector = FALSE)
   288
   289	  deposition <- get_or_create_deposition(api, token, deposition_id = deposition_id)
   290	  resolved_deposition_id <- deposition$id
   291	  bucket_url <- deposition$links$bucket
   292	  reserved_doi <- deposition$metadata$prereserve_doi$doi
   293
   294	  set_metadata(api, token, resolved_deposition_id, metadata)
   295	  upload_bucket(bucket_url, token, archive_path)
   296
   297	  result <- list(
   298	    deposition_id = resolved_deposition_id,
   299	    reserved_doi = reserved_doi %||% NA_character_,
   300	    draft_url = deposition$links$html %||% NA_character_,
   301	    published = FALSE,
   302	    version_doi = NA_character_,
   303	    concept_doi = NA_character_,
   304	    record_url = NA_character_
   305	  )
   306
   307	  if (isTRUE(publish)) {
   308	    published_deposition <- publish_deposition(api, token, resolved_deposition_id)
   309	    result$published <- TRUE
   310	    result$version_doi <- published_deposition$doi %||% NA_character_
   311	    result$concept_doi <- published_deposition$conceptdoi %||% NA_character_
   312	    result$record_url <- published_deposition$links$html %||% NA_character_
   313	  }
   314
   315	  result
   316	}

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-zenodo-verify.R | sed -n '350,520p'
nl -ba api/functions/analysis-snapshot-release-zenodo-package.R | sed -n '240,440p'
nl -ba api/functions/analysis-snapshot-release-zenodo-docs.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
   350	    ),
   351	    file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL)
   352	  )
   353	  invisible(TRUE)
   354	}
   355
   356	# --------------------------------------------------------------------------- #
   357	# THE SAFETY VALIDATOR -- defense in depth, runs LAST before tarring.
   358	# Independent checks; each collects offending paths and stops loudly.
   359	# --------------------------------------------------------------------------- #
   360
   361	.analysis_release_zenodo_validate_no_forbidden <- function(staging_dir) {
   362	  # Deliberately re-walks the tree directly (not via the shared iterator,
   363	  # which already excludes these) -- an independent re-check, not a
   364	  # tautology. Case-insensitive (item 3): both the forbidden filename and
   365	  # forbidden dir-part segments are matched lowercase, so `.ENV`,
   366	  # `.Git/config`, etc. no longer slip through.
   367	  all_files <- list.files(
   368	    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
   369	  )
   370	  offenders <- Filter(function(rel_path) {
   371	    base <- tolower(basename(rel_path))
   372	    segments <- tolower(strsplit(rel_path, "/", fixed = TRUE)[[1]])
   373	    base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES ||
   374	      any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
   375	  }, all_files)
   376
   377	  if (length(offenders) > 0) {
   378	    stop(sprintf(
   379	      "Zenodo staging contains private files: %s",
   380	      paste(sort(offenders), collapse = ", ")
   381	    ), call. = FALSE)
   382	  }
   383	  invisible(TRUE)
   384	}
   385
   386	#' Reject symlinks / non-regular files anywhere in the staging tree (item 3)
   387	#' -- a symlink could point outside the archive, or at a private file
   388	#' `utils::tar()` would then follow and embed verbatim. Checks BOTH files and
   389	#' directory entries (`include.dirs = TRUE`) so a symlinked directory is
   390	#' caught even if `list.files()` would otherwise silently walk through it.
   391	.analysis_release_zenodo_validate_no_symlinks <- function(staging_dir) {
   392	  rel_paths <- list.files(
   393	    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE,
   394	    full.names = FALSE, include.dirs = TRUE
   395	  )
   396	  offenders <- Filter(function(rel_path) {
   397	    full_path <- file.path(staging_dir, rel_path)
   398	    target <- suppressWarnings(Sys.readlink(full_path))
   399	    !is.na(target) && nzchar(target)
   400	  }, rel_paths)
   401
   402	  if (length(offenders) > 0) {
   403	    stop(sprintf(
   404	      "Zenodo staging contains symlinks (not allowed): %s",
   405	      paste(sort(offenders), collapse = ", ")
   406	    ), call. = FALSE)
   407	  }
   408	  invisible(TRUE)
   409	}
   410
   411	.analysis_release_zenodo_has_allowed_suffix <- function(rel_path) {
   412	  lower <- tolower(rel_path)
   413	  any(vapply(
   414	    .ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES,
   415	    function(suffix) endsWith(lower, suffix), logical(1)
   416	  ))
   417	}
   418
   419	#' File-type ALLOWLIST (item 3): any staged regular file whose (lowercased)
   420	#' suffix is not in `.ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES` fails
   421	#' validation. This catches `.csv`/`.pem`/extensionless/binary secret files
   422	#' without needing to scan binary content -- a well-formed analysis-release
   423	#' staging tree only ever contains the release payload/docs suffixes.
   424	.analysis_release_zenodo_validate_allowed_suffix <- function(staging_dir) {
   425	  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
   426	  offenders <- Filter(
   427	    function(rel_path) !.analysis_release_zenodo_has_allowed_suffix(rel_path), rel_paths
   428	  )
   429	  if (length(offenders) > 0) {
   430	    stop(sprintf(
   431	      "Zenodo staging contains file(s) with an unexpected type/suffix: %s",
   432	      paste(offenders, collapse = ", ")
   433	    ), call. = FALSE)
   434	  }
   435	  invisible(TRUE)
   436	}
   437
   438	.analysis_release_zenodo_validate_no_sensitive_text <- function(staging_dir) {
   439	  offenders <- character(0)
   440	  for (rel_path in .analysis_release_zenodo_iter_public_files(staging_dir)) {
   441	    if (!.analysis_release_zenodo_has_allowed_suffix(rel_path)) {
   442	      next
   443	    }
   444	    full_path <- file.path(staging_dir, rel_path)
   445	    text <- tolower(paste(readLines(full_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
   446	    hit <- Find(function(pattern) grepl(pattern, text, fixed = TRUE),
   447	                .ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS)
   448	    if (!is.null(hit)) {
   449	      offenders <- c(offenders, sprintf("%s (matched '%s')", rel_path, hit))
   450	    }
   451	  }
   452	  if (length(offenders) > 0) {
   453	    stop(sprintf(
   454	      "Zenodo staging contains sensitive public text: %s",
   455	      paste(offenders, collapse = "; ")
   456	    ), call. = FALSE)
   457	  }
   458	  invisible(TRUE)
   459	}
   460
   461	.analysis_release_zenodo_validate_layout <- function(staging_dir) {
   462	  expected_top <- .ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL
   463	  expected_nested <- file.path(
   464	    .ANALYSIS_RELEASE_ZENODO_NESTED_DIR, .ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED
   465	  )
   466	  expected <- c(expected_top, expected_nested)
   467
   468	  missing <- Filter(function(rel_path) !file.exists(file.path(staging_dir, rel_path)), expected)
   469	  if (length(missing) > 0) {
   470	    stop(sprintf(
   471	      "Zenodo staging is missing expected members: %s",
   472	      paste(missing, collapse = ", ")
   473	    ), call. = FALSE)
   474	  }
   475	  invisible(TRUE)
   476	}
   477
   478	#' The safety validator. Independent checks, in order; stops with a clear
   479	#' message naming the offending relative paths on the first failing check.
   480	analysis_release_zenodo_validate_staging <- function(staging_dir) {
   481	  .analysis_release_zenodo_validate_no_forbidden(staging_dir)
   482	  .analysis_release_zenodo_validate_no_symlinks(staging_dir)
   483	  .analysis_release_zenodo_validate_allowed_suffix(staging_dir)
   484	  .analysis_release_zenodo_validate_no_sensitive_text(staging_dir)
   485	  .analysis_release_zenodo_validate_layout(staging_dir)
   486	  invisible(TRUE)
   487	}
   240	.ANALYSIS_RELEASE_ZENODO_TAR_FIXED_TIME <- as.POSIXct("2020-01-01", tz = "UTC")
   241
   242	#' Set every file's and directory's mtime under `staging_dir` (INCLUDING
   243	#' `staging_dir` itself) to a fixed epoch, deepest-first, so a rebuild of the
   244	#' identical content never differs by mtime alone.
   245	.analysis_release_zenodo_normalize_mtimes <- function(staging_dir) {
   246	  entries <- list.files(
   247	    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE,
   248	    full.names = TRUE, include.dirs = TRUE
   249	  )
   250	  # Deepest-first: a directory's own mtime is set only after every entry
   251	  # nested inside it, so nothing touched later in this loop bumps it again.
   252	  depth <- lengths(strsplit(entries, "/", fixed = TRUE))
   253	  entries <- entries[order(-depth)]
   254	  for (path in entries) {
   255	    Sys.setFileTime(path, .ANALYSIS_RELEASE_ZENODO_TAR_FIXED_TIME)
   256	  }
   257	  Sys.setFileTime(staging_dir, .ANALYSIS_RELEASE_ZENODO_TAR_FIXED_TIME)
   258	  invisible(TRUE)
   259	}
   260
   261	#' Deterministic gzip tarball with ONE top-level dir (`basename(staging_dir)`).
   262	#' Also writes `<archive_path>.sha256` (`"<sha256>  <basename>\n"`).
   263	#'
   264	#' @return list(archive_path, archive_sha256_path).
   265	analysis_release_zenodo_make_tarball <- function(staging_dir, archive_path) {
   266	  archive_dir <- dirname(archive_path)
   267	  dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
   268	  archive_path <- normalizePath(file.path(archive_dir, basename(archive_path)), mustWork = FALSE)
   269
   270	  staging_dir <- normalizePath(staging_dir, mustWork = TRUE)
   271	  parent_dir <- dirname(staging_dir)
   272	  base_name <- basename(staging_dir)
   273
   274	  .analysis_release_zenodo_normalize_mtimes(staging_dir)
   275
   276	  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
   277	  entries <- sort(file.path(base_name, rel_paths))
   278
   279	  previous_wd <- setwd(parent_dir)
   280	  on.exit(setwd(previous_wd), add = TRUE)
   281	  # tar = "internal" forces R's built-in (pure-R) tar writer so the archive
   282	  # never depends on a system `tar` binary being present/compatible.
   283	  utils::tar(tarfile = archive_path, files = entries, compression = "gzip", tar = "internal")
   284
   285	  sha256 <- digest::digest(file = archive_path, algo = "sha256")
   286	  sha_path <- paste0(archive_path, ".sha256")
   287	  cat(paste0(sha256, "  ", basename(archive_path), "\n"), file = sha_path)
   288
   289	  list(archive_path = archive_path, archive_sha256_path = sha_path)
   290	}
   291
   292	# --------------------------------------------------------------------------- #
   293	# Orchestrator
   294	# --------------------------------------------------------------------------- #
   295
   296	#' Recursively sort a named list's keys alphabetically (objects only --
   297	#' unnamed lists/arrays are recursed into without reordering). Used for
   298	#' `zenodo_metadata.json`'s "pretty JSON, sorted keys" contract, mirroring
   299	#' Python's `json.dumps(..., sort_keys=True)`.
   300	.analysis_release_zenodo_sort_keys <- function(x) {
   301	  if (is.list(x)) {
   302	    nms <- names(x)
   303	    if (!is.null(nms) && all(nzchar(nms))) {
   304	      x <- x[order(nms)]
   305	    }
   306	    x <- lapply(x, .analysis_release_zenodo_sort_keys)
   307	  }
   308	  x
   309	}
   310
   311	.analysis_release_zenodo_copy_tree <- function(src_dir, dest_dir) {
   312	  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
   313	  rel_paths <- list.files(src_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
   314	  for (rel_path in rel_paths) {
   315	    dest_path <- file.path(dest_dir, rel_path)
   316	    dir.create(dirname(dest_path), recursive = TRUE, showWarnings = FALSE)
   317	    file.copy(file.path(src_dir, rel_path), dest_path, overwrite = TRUE, copy.date = TRUE)
   318	  }
   319	  invisible(dest_dir)
   320	}
   321
   322	#' Fetch a published release over the public HTTP API and assemble a Zenodo
   323	#' staging directory + deterministic tarball. Mirrors nddscore's
   324	#' `build_zenodo_dataset_package()` top-to-bottom.
   325	#'
   326	#' @return list(staging_dir, archive_path, archive_sha256_path,
   327	#'   zenodo_metadata_path, release_id).
   328	analysis_release_zenodo_package <- function(
   329	    api_base_url,
   330	    release_id = "latest",
   331	    staging_dir,
   332	    archive_dir,
   333	    version = NULL,
   334	    doi = NULL,
   335	    http_get_json = .analysis_release_zenodo_http_get_json,
   336	    http_download = .analysis_release_zenodo_http_download) {
   337	  head <- analysis_release_zenodo_fetch_head(api_base_url, release_id, http_get_json = http_get_json)
   338	  resolved_release_id <- as.character(head$release_id)[[1]]
   339	  # Defense-in-depth (item 2): re-validate the RESOLVED id even though the
   340	  # REQUEST arg was already validated inside fetch_head() -- this is the
   341	  # value that actually becomes `<release_id>.tar.gz` and the `RELEASE_ID=`
   342	  # marker line, so a compromised/misbehaving API response can never smuggle
   343	  # a path/marker-injection payload through.
   344	  .analysis_release_zenodo_assert_valid_release_id(resolved_release_id, allow_latest = FALSE)
   345
   346	  bundle_path <- tempfile(fileext = ".tar.gz")
   347	  on.exit(unlink(bundle_path, force = TRUE), add = TRUE)
   348	  analysis_release_zenodo_download_bundle(
   349	    api_base_url, resolved_release_id, bundle_path, http_download = http_download
   350	  )
   351	  extracted_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, head$bundle_sha256)
   352	  on.exit(unlink(extracted_dir, recursive = TRUE, force = TRUE), add = TRUE)
   353
   354	  # BLOCKER guard (item 1): refuse to recursively delete a pre-existing
   355	  # `--staging-dir` unless this tool itself created it (empty, absent, or
   356	  # carrying the ownership sentinel) -- an operator typo must never
   357	  # irreversibly rmtree an unrelated directory.
   358	  .analysis_release_zenodo_assert_staging_deletable(staging_dir)
   359	  if (dir.exists(staging_dir)) {
   360	    unlink(staging_dir, recursive = TRUE, force = TRUE)
   361	  }
   362	  dir.create(staging_dir, recursive = TRUE)
   363	  .analysis_release_zenodo_write_staging_sentinel(staging_dir)
   364
   365	  nested_dir <- file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_NESTED_DIR)
   366	  .analysis_release_zenodo_copy_tree(extracted_dir, nested_dir)
   367
   368	  resolved_version <- as.character(
   369	    (version %||% head$source_data_version %||% resolved_release_id)
   370	  )[[1]]
   371
   372	  .analysis_release_zenodo_write_text(
   373	    file.path(staging_dir, "README.md"), analysis_release_zenodo_build_readme(head, doi)
   374	  )
   375	  .analysis_release_zenodo_write_text(
   376	    file.path(staging_dir, "DATA_CARD.md"), analysis_release_zenodo_build_data_card(head)
   377	  )
   378	  .analysis_release_zenodo_write_text(
   379	    file.path(staging_dir, "SCHEMA.md"), analysis_release_zenodo_build_schema_doc(head)
   380	  )
   381	  .analysis_release_zenodo_write_text(
   382	    file.path(staging_dir, "CHANGELOG.md"),
   383	    analysis_release_zenodo_build_changelog(head, resolved_version)
   384	  )
   385	  .analysis_release_zenodo_write_text(
   386	    file.path(staging_dir, "CITATION.cff"),
   387	    analysis_release_zenodo_build_citation_cff(head, resolved_version, doi)
   388	  )
   389
   390	  metadata <- analysis_release_zenodo_build_metadata(head, version = resolved_version)
   391	  metadata_json <- jsonlite::toJSON(
   392	    .analysis_release_zenodo_sort_keys(metadata), auto_unbox = TRUE, pretty = TRUE, null = "null"
   393	  )
   394	  zenodo_metadata_path <- file.path(staging_dir, "zenodo_metadata.json")
   395	  .analysis_release_zenodo_write_text(zenodo_metadata_path, paste0(as.character(metadata_json), "\n"))
   396
   397	  datapackage <- analysis_release_zenodo_build_datapackage(
   398	    staging_dir,
   399	    name = "sysndd-analysis-snapshot-release",
   400	    version = resolved_version,
   401	    release_id = resolved_release_id
   402	  )
   403	  datapackage_json <- jsonlite::toJSON(datapackage, auto_unbox = TRUE, pretty = TRUE, null = "null")
   404	  .analysis_release_zenodo_write_text(
   405	    file.path(staging_dir, "datapackage.json"), paste0(as.character(datapackage_json), "\n")
   406	  )
   407
   408	  analysis_release_zenodo_write_checksums(staging_dir)
   409
   410	  analysis_release_zenodo_validate_staging(staging_dir)
   411
   412	  archive_path <- file.path(archive_dir, paste0(resolved_release_id, ".tar.gz"))
   413	  tar_result <- analysis_release_zenodo_make_tarball(staging_dir, archive_path)
   414
   415	  list(
   416	    staging_dir = staging_dir,
   417	    archive_path = tar_result$archive_path,
   418	    archive_sha256_path = tar_result$archive_sha256_path,
   419	    zenodo_metadata_path = zenodo_metadata_path,
   420	    release_id = resolved_release_id
   421	  )
   422	}
     1	# api/functions/analysis-snapshot-release-zenodo-docs.R
     2	#
     3	# Doc-string builders for the analysis-snapshot RELEASE Zenodo packager
     4	# (#573 Slice C / Task C1). Extracted from
     5	# `analysis-snapshot-release-zenodo-package.R` (which guard-sources this
     6	# file) to keep both files under the repo's 600-line soft ceiling -- mirrors
     7	# the `comparisons-functions.R` / `comparisons-parsers.R` split.
     8	#
     9	# Every function here is pure (`str` in, `str` out) and mirrors one of the
    10	# sibling `../nddscore/src/models/sysndd_export.py` doc builders
    11	# (`_build_readme` / `_build_ingestion_notes` / `_build_schema_doc` /
    12	# `_build_changelog` / `_build_citation_cff`), adapted to analysis-release
    13	# content (no model performance metrics, no morbidscore/mantis scrubbing --
    14	# analysis releases carry no private git-sha/model fields to begin with).
    15	#
    16	# Depends on `%||%` and `.analysis_release_zenodo_created_at_date()`, both
    17	# defined in the sibling `analysis-snapshot-release-zenodo-package.R` (which
    18	# always sources this file, never the other way around) -- resolved lazily
    19	# at CALL time via the shared global sourcing environment, not at source
    20	# time, so definition order across the two files does not matter.
    21
    22	.analysis_release_zenodo_docs_loaded <- TRUE
    23
    24	#' `README.md`: version/id/DOI header + a 4-step "Use" walkthrough.
    25	analysis_release_zenodo_build_readme <- function(head, doi = NULL) {
    26	  release_id <- as.character(head$release_id %||% "")[[1]]
    27	  version <- as.character((head$source_data_version %||% head$release_version %||% release_id))[[1]]
    28	  doi_text <- doi %||% "reserved Zenodo DOI to be added before publication"
    29
    30	  paste0(
    31	    "# SysNDD analysis-snapshot release\n\n",
    32	    sprintf("- Release ID: `%s`\n", release_id),
    33	    sprintf("- Source data version: `%s`\n", version),
    34	    sprintf("- DOI: %s\n\n", doi_text),
    35	    "This dataset is an immutable, content-addressed export of a SysNDD public ",
    36	    "analysis-snapshot release. It is a derived analysis product, not a copy of ",
    37	    "the primary curated SysNDD evidence.\n\n",
    38	    "## Use\n\n",
    39	    "1. Extract the archive.\n",
    40	    "2. Verify `checksums.sha256` at the archive root (and the nested ",
    41	    "`analysis_snapshot_release/checksums.sha256`).\n",
    42	    "3. Read `DATA_CARD.md` and `SCHEMA.md`.\n",
    43	    "4. Import files from `analysis_snapshot_release/` using its own ",
    44	    "`manifest.json` as the file index.\n"
    45	  )
    46	}
    47
    48	#' `DATA_CARD.md`: what each bundled file is, the layer set, how to verify.
    49	#' Folds the intent of nddscore's `_build_ingestion_notes` since there is no
    50	#' model to card here.
    51	analysis_release_zenodo_build_data_card <- function(head) {
    52	  release_id <- as.character(head$release_id %||% "")[[1]]
    53	  layers <- head$manifest$layers %||% head$layers %||% list()
    54
    55	  layer_block <- if (length(layers) > 0) {
    56	    layer_names <- vapply(layers, function(layer) {
    57	      as.character(layer$analysis_type %||% "unknown")[[1]]
    58	    }, character(1))
    59	    paste(sprintf("- `%s`", layer_names), collapse = "\n")
    60	  } else {
    61	    paste(
    62	      "- `functional_clusters`", "- `phenotype_clusters`",
    63	      "- `phenotype_functional_correlations`",
    64	      sep = "\n"
    65	    )
    66	  }
    67
    68	  paste0(
    69	    "# Data Card\n\n",
    70	    sprintf(
    71	      "Release `%s` bundles the following analysis layers under ",
    72	      release_id
    73	    ),
    74	    "`analysis_snapshot_release/`:\n\n",
    75	    layer_block, "\n\n",
    76	    "Each cluster layer directory contains `payload.json` (the served cluster ",
    77	    "membership + validation) and, where applicable, `reproducibility.json` (the ",
    78	    "raw artifact needed to independently recompute modularity/silhouette). The ",
    79	    "phenotype-functional correlation layer has a `payload.json` only.\n\n",
    80	    "`analysis_snapshot_release/manifest.json` lists every bundled file with its ",
    81	    "size and sha256; `checksums.sha256` (both at the archive root and inside ",
    82	    "`analysis_snapshot_release/`) lets any consumer verify byte-for-byte ",
    83	    "integrity with `sha256sum -c`.\n\n",
    84	    "Scope: derived cluster analysis over approved public SysNDD curation data. ",
    85	    "This is not raw curated evidence and not a clinical diagnostic product.\n"
    86	  )
    87	}
    88
    89	#' `SCHEMA.md`: the manifest/layers structure and the lineage-anchor vs
    90	#' reproducibility-hash distinction, stated correctly (payload_hash/
    91	#' input_hash/snapshot_id are lineage anchors, NOT a hash of payload.json).
    92	analysis_release_zenodo_build_schema_doc <- function(head) {
    93	  paste0(
    94	    "# Schema\n\n",
    95	    "`analysis_snapshot_release/manifest.json` is the authoritative file index. ",
    96	    "For each layer it records `analysis_type`, `input_hash`, `payload_hash`, ",
    97	    "`reproducibility_hash` (when the layer has a reproducibility bundle), and ",
    98	    "`dependencies`. For each bundled file it records `path`, `bytes`, and ",
    99	    "`sha256`.\n\n",
   100	    "## Lineage anchors vs the reproducibility hash\n\n",
   101	    "`payload_hash`, `input_hash`, and `snapshot_id` are cross-checkable lineage ",
   102	    "anchors against the live `meta.snapshot.{payload_hash,input_hash,snapshot_id}` ",
   103	    "on the corresponding `/api/analysis/*` endpoint. They are NOT a hash of this ",
   104	    "release's own `payload.json` file -- the served payload round-trips through ",
   105	    "fixed-precision database columns before the release freezes it, so a ",
   106	    "byte-for-byte reconstruction is neither guaranteed nor attempted.\n\n",
   107	    "By contrast, for each cluster layer with a reproducibility bundle, ",
   108	    "`sha256(reproducibility.json) == reproducibility_hash` exactly.\n"
   109	  )
   110	}
   111
   112	#' `CHANGELOG.md`: one `## {version} - {date}` section (no accumulation --
   113	#' each package rebuild overwrites the file with a single-entry changelog,
   114	#' mirroring nddscore's `_build_changelog`).
   115	analysis_release_zenodo_build_changelog <- function(head, version) {
   116	  release_id <- as.character(head$release_id %||% "")[[1]]
   117	  resolved_version <- as.character((version %||% head$source_data_version %||% release_id))[[1]]
   118	  release_date <- .analysis_release_zenodo_created_at_date(head$created_at)
   119	  date_suffix <- if (nzchar(release_date)) sprintf(" - %s", release_date) else ""
   120
   121	  paste0(
   122	    "# Changelog\n\n",
   123	    sprintf("## %s%s\n\n", resolved_version, date_suffix),
   124	    sprintf("- Initial Zenodo dataset package for analysis-snapshot release `%s`.\n", release_id),
   125	    "- Bundles the functional clusters, phenotype clusters, and ",
   126	    "phenotype-functional correlation layers, plus their manifest and ",
   127	    "checksums.\n"
   128	  )
   129	}
   130
   131	#' `CITATION.cff`: CFF 1.2.0, `type: dataset`, optional `doi:`, single author
   132	#' block with ORCID, `license: CC-BY-4.0`.
   133	analysis_release_zenodo_build_citation_cff <- function(head, version, doi = NULL) {
   134	  release_id <- as.character(head$release_id %||% "")[[1]]
   135	  resolved_version <- as.character((version %||% head$source_data_version %||% release_id))[[1]]
   136	  release_date <- .analysis_release_zenodo_created_at_date(head$created_at)
   137	  date_line <- if (nzchar(release_date)) release_date else format(Sys.Date())
   138	  doi_block <- if (!is.null(doi) && nzchar(as.character(doi)[[1]])) {
   139	    sprintf("doi: \"%s\"\n", as.character(doi)[[1]])
   140	  } else {
   141	    ""
   142	  }
   143
   144	  paste0(
   145	    "cff-version: 1.2.0\n",
   146	    "message: \"If you use this SysNDD analysis-snapshot release, please cite it ",
   147	    "as below.\"\n",
   148	    "type: dataset\n",
   149	    sprintf("title: \"SysNDD analysis-snapshot release %s\"\n", release_id),
   150	    sprintf("version: \"%s\"\n", resolved_version),
   151	    sprintf("date-released: \"%s\"\n", date_line),
   152	    doi_block,
   153	    "authors:\n",
   154	    "  - family-names: Popp\n",
   155	    "    given-names: Bernt\n",
   156	    "    orcid: \"https://orcid.org/0000-0002-3679-1081\"\n",
   157	    "keywords:\n",
   158	    "  - SysNDD\n",
   159	    "  - neurodevelopmental disorders\n",
   160	    "  - clustering\n",
   161	    "license: CC-BY-4.0\n"
   162	  )
   163	}

codex
The round-one protections are present in the code paths I’ve inspected. I’m now probing the seams around extraction/copying and the Makefile handoff—those are the places where a fix can look correct locally but lose its protection before validation.
exec
/bin/bash -lc "rg -n -C 3 \"(symlink|travers|coverage|checksum|sentinel|staging|determin|release.id|marker|latest.env|token|record.doi|manual)\" api/tests/testthat/test-unit-analysis-release-zenodo-{package,verify,upload}.R && nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-verify.R | sed -n '1,430p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-45-# upload_bucket -- direct analog of the sibling's test #3
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-46-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-47-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:48:test_that("upload_bucket: PUTs to {bucket}/{basename(archive)}, Bearer token, body is the archive file", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-49-  archive <- withr::local_tempfile()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-50-  writeBin(charToRaw("abc"), archive)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-51-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-52-  captured <- new.env()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:53:  stub_put <- function(url, token, archive_path) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-54-    assign("url", url, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:55:    assign("token", token, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-56-    assign("bytes", readBin(archive_path, "raw", file.info(archive_path)$size), envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-57-  }
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-58-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-59-  result <- analysis_release_zenodo_upload_bucket(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:60:    "https://zenodo.example/bucket", "token", archive, put = stub_put
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-61-  )
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-62-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-63-  expect_identical(get("url", envir = captured), paste0("https://zenodo.example/bucket/", basename(archive)))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:64:  expect_identical(get("token", envir = captured), "token")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-65-  expect_identical(get("bytes", envir = captured), charToRaw("abc"))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-66-  expect_identical(result, paste0("https://zenodo.example/bucket/", basename(archive)))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-67-})
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-70-  archive <- withr::local_tempfile()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-71-  writeBin(charToRaw("xyz"), archive)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-72-  captured_url <- NULL
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:73:  stub_put <- function(url, token, archive_path) captured_url <<- url
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-74-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:75:  analysis_release_zenodo_upload_bucket("https://zenodo.example/bucket/", "token", archive, put = stub_put)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-76-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-77-  expect_identical(captured_url, paste0("https://zenodo.example/bucket/", basename(archive)))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-78-})
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-83-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-84-test_that("get_or_create_deposition: NULL deposition_id -> POST .../deposit/depositions", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-85-  captured <- new.env()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:86:  stub_http <- function(method, url, token, body = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-87-    assign("method", method, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-88-    assign("url", url, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:89:    assign("token", token, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-90-    assign("body", body, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-91-    list(id = 999, links = list(bucket = "https://bucket.example"))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-92-  }
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-97-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-98-  expect_identical(get("method", envir = captured), "POST")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-99-  expect_identical(get("url", envir = captured), "https://zenodo.org/api/deposit/depositions")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:100:  expect_identical(get("token", envir = captured), "tok")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-101-  expect_identical(get("body", envir = captured), list())
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-102-  expect_identical(result$id, 999)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-103-})
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-104-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-105-test_that("get_or_create_deposition: explicit deposition_id -> GET .../deposit/depositions/{id}", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-106-  captured <- new.env()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:107:  stub_http <- function(method, url, token, body = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-108-    assign("method", method, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-109-    assign("url", url, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-110-    assign("body", body, envir = captured)
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-127-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-128-test_that("set_metadata: PUTs to .../deposit/depositions/{id} with body {\"metadata\": ...}", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-129-  captured <- new.env()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:130:  stub_http <- function(method, url, token, body = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-131-    assign("method", method, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-132-    assign("url", url, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-133-    assign("body", body, envir = captured)
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-150-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-151-test_that("publish_deposition: POSTs to .../deposit/depositions/{id}/actions/publish", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-152-  captured <- new.env()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:153:  stub_http <- function(method, url, token, body = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-154-    assign("method", method, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-155-    assign("url", url, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-156-    list(doi = "10.5281/zenodo.999", conceptdoi = "10.5281/zenodo.998", links = list(html = "https://zenodo.org/record/999"))
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-168-})
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-169-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-170-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:171:# record_doi -- PATCH to the SysNDD admin endpoint, only non-empty fields
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-172-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-173-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:174:test_that("record_doi: PATCH .../releases/<id>/doi, admin Bearer token, body has ONLY supplied non-empty fields", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-175-  captured <- new.env()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:176:  stub_patch <- function(method, url, token, body = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-177-    assign("method", method, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-178-    assign("url", url, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:179:    assign("token", token, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-180-    assign("body", body, envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:181:    list(release_id = "asr_test")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-182-  }
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-183-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:184:  result <- analysis_release_zenodo_record_doi(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-185-    "http://localhost:7778",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:186:    "admin-token",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-187-    "asr_deadbeefcafebabe",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-188-    doi_fields = list(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-189-      zenodo_record_id = "999",
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-199-    get("url", envir = captured),
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-200-    "http://localhost:7778/api/admin/analysis/releases/asr_deadbeefcafebabe/doi"
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-201-  )
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:202:  expect_identical(get("token", envir = captured), "admin-token")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-203-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-204-  body <- get("body", envir = captured)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-205-  expect_setequal(names(body), c("zenodo_record_id", "zenodo_record_url", "version_doi"))
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-207-  expect_identical(body$zenodo_record_url, "https://zenodo.org/record/999")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-208-  expect_identical(body$version_doi, "10.5281/zenodo.999")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-209-  expect_false("concept_doi" %in% names(body))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:210:  expect_identical(result$release_id, "asr_test")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-211-})
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-212-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:213:test_that("record_doi: an empty-string field is also dropped (never forwarded as an empty value)", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-214-  captured_body <- NULL
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:215:  stub_patch <- function(method, url, token, body = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-216-    captured_body <<- body
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-217-    list()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-218-  }
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-219-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:220:  analysis_release_zenodo_record_doi(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:221:    "http://localhost:7778", "admin-token", "asr_x",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-222-    doi_fields = list(zenodo_record_id = "1", concept_doi = ""),
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-223-    patch = stub_patch
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-224-  )
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-226-  expect_setequal(names(captured_body), "zenodo_record_id")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-227-})
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-228-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:229:test_that("record_doi: an NA_character_ field is dropped, not forwarded as null (nzchar(NA) gotcha)", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-230-  captured_body <- NULL
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:231:  stub_patch <- function(method, url, token, body = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-232-    captured_body <<- body
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-233-    list()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-234-  }
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-235-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:236:  analysis_release_zenodo_record_doi(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:237:    "http://localhost:7778", "admin-token", "asr_x",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-238-    doi_fields = list(version_doi = "10.5281/zenodo.1", concept_doi = NA_character_),
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-239-    patch = stub_patch
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-240-  )
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-244-})
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-245-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-246-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:247:# manual_doi_command -- the printed fallback when --record-doi is not opted into
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-248-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-249-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:250:test_that("manual_doi_command: contains the endpoint path, release id, and all 4 supplied fields", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:251:  command <- analysis_release_zenodo_manual_doi_command(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-252-    "http://localhost:7778",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-253-    "asr_deadbeefcafebabe",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-254-    doi_fields = list(
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-271-  expect_true(grepl("concept_doi", command, fixed = TRUE))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-272-})
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-273-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:274:test_that("manual_doi_command: never auto-executes -- it only returns a string", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:275:  command <- analysis_release_zenodo_manual_doi_command(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-276-    "http://localhost:7778", "asr_x", doi_fields = list(zenodo_record_id = "1")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-277-  )
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-278-  expect_true(is.character(command))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-279-  expect_length(command, 1L)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-280-})
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-281-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:282:test_that("manual_doi_command: an NA_character_ field is omitted, not printed as null/NA (nzchar(NA) gotcha)", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:283:  command <- analysis_release_zenodo_manual_doi_command(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-284-    "http://localhost:7778",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-285-    "asr_deadbeefcafebabe",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-286-    doi_fields = list(
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-305-# function's own (short-lived) call frame, not the calling `test_that()`
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-306-# block -- so the files would be deleted the instant this helper returns,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-307-# before the caller can use them (same trap documented in
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:308:# `test-unit-analysis-release-zenodo-package.R`'s `make_well_formed_staging()`
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-309-# comment). Session tempdir cleanup at process exit is sufficient here.
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-310-.zenodo_upload_test_files <- function() {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-311-  archive <- file.path(tempdir(), paste0("zenodo_upload_test_", as.integer(stats::runif(1, 1, 1e9)), ".tar.gz"))
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-319-  files <- .zenodo_upload_test_files()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-320-  publish_called <- FALSE
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-321-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:322:  fake_get_or_create <- function(api, token, deposition_id = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-323-    list(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-324-      id = 111,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-325-      links = list(bucket = "https://bucket.example/111", html = "https://zenodo.org/deposit/111"),
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-326-      metadata = list(prereserve_doi = list(doi = "10.5281/zenodo.111"))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-327-    )
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-328-  }
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:329:  fake_set_metadata <- function(api, token, deposition_id, metadata) NULL
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:330:  fake_upload_bucket <- function(bucket_url, token, archive_path) invisible(NULL)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:331:  fake_publish <- function(api, token, deposition_id) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-332-    publish_called <<- TRUE
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-333-    list()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-334-  }
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-336-  result <- analysis_release_zenodo_upload(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-337-    archive_path = files$archive,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-338-    metadata_path = files$metadata_path,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:339:    token = "tok",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-340-    publish = FALSE,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-341-    confirm_publish = FALSE,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-342-    get_or_create_deposition = fake_get_or_create,
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-356-test_that("upload(): publish=TRUE + confirm_publish=TRUE publishes and fills version/concept DOI + record_url", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-357-  files <- .zenodo_upload_test_files()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-358-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:359:  fake_get_or_create <- function(api, token, deposition_id = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-360-    list(id = 222, links = list(bucket = "https://bucket.example/222", html = "https://zenodo.org/deposit/222"))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-361-  }
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:362:  fake_set_metadata <- function(api, token, deposition_id, metadata) NULL
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:363:  fake_upload_bucket <- function(bucket_url, token, archive_path) invisible(NULL)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:364:  fake_publish <- function(api, token, deposition_id) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-365-    list(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-366-      doi = "10.5281/zenodo.222",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-367-      conceptdoi = "10.5281/zenodo.221",
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-372-  result <- analysis_release_zenodo_upload(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-373-    archive_path = files$archive,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-374-    metadata_path = files$metadata_path,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:375:    token = "tok",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-376-    publish = TRUE,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-377-    confirm_publish = TRUE,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-378-    get_or_create_deposition = fake_get_or_create,
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-399-    analysis_release_zenodo_upload(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-400-      archive_path = files$archive,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-401-      metadata_path = files$metadata_path,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:402:      token = "tok",
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-403-      publish = TRUE,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-404-      confirm_publish = FALSE,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-405-      get_or_create_deposition = fake_get_or_create
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-409-  expect_false(called)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-410-})
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-411-
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:412:test_that("upload(): missing token stops with a clear message", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-413-  files <- .zenodo_upload_test_files()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-414-  expect_error(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-415-    analysis_release_zenodo_upload(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:416:      archive_path = files$archive, metadata_path = files$metadata_path, token = ""
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-417-    ),
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-418-    "ZENODO_TOKEN"
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-419-  )
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-425-    analysis_release_zenodo_upload(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-426-      archive_path = file.path(tempdir(), "does-not-exist.tar.gz"),
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-427-      metadata_path = files$metadata_path,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:428:      token = "tok"
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-429-    ),
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-430-    "Archive does not exist"
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-431-  )
--
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-437-    analysis_release_zenodo_upload(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-438-      archive_path = files$archive,
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-439-      metadata_path = file.path(tempdir(), "does-not-exist.json"),
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:440:      token = "tok"
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-441-    ),
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-442-    "Metadata does not exist"
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R-443-  )
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-10-# `-verify.R` into the same target environment -- mirrors
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-11-# `test-unit-analysis-release-zenodo-package.R`'s sourcing.
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-12-#
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:13:# Covers: release-id shape validation (path/filename/marker-injection guard),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-14-# `fetch_head`/`download_bundle` URL-building, `extract_and_verify`
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:15:# (checksum coverage + path-traversal rejection), and the safety validator
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:16:# `validate_staging` (case-insensitive forbidden-name matching, the file-type
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:17:# allowlist, and symlink rejection).
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-18-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-19-library(testthat)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-20-
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-24-# Shared fixture helpers
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-25-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-26-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:27:# A well-formed Zenodo staging directory: the expected top-level docs plus the
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:28:# nested analysis_snapshot_release/ subdir with its own manifest+checksums.
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-29-#
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-30-# Deliberately uses plain `tempfile()`, NOT `withr::local_tempdir()`: the
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-31-# latter schedules cleanup via `withr::defer(..., envir = parent.frame())`,
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-34-# block -- so the directory would be deleted the instant this helper
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-35-# returns, before the caller can use it. Session tempdir cleanup at process
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-36-# exit is sufficient for a short-lived test run.
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:37:make_well_formed_staging <- function() {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:38:  staging <- file.path(tempdir(), paste0("zenodo_staging_", as.integer(stats::runif(1, 1, 1e9))))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:39:  dir.create(staging, recursive = TRUE)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-40-  for (name in c(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-41-    "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:42:    "datapackage.json", "zenodo_metadata.json", "checksums.sha256"
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-43-  )) {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:44:    writeLines("placeholder content", file.path(staging, name))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-45-  }
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:46:  dir.create(file.path(staging, "analysis_snapshot_release"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:47:  writeLines('{"release_id":"asr_test"}', file.path(staging, "analysis_snapshot_release", "manifest.json"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:48:  writeLines("deadbeef  manifest.json", file.path(staging, "analysis_snapshot_release", "checksums.sha256"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:49:  staging
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-50-}
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-51-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-52-# Builds a tiny tar.gz with two files + a matching (or deliberately wrong,
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:53:# omitted, duplicated, or traversal-shaped) inner checksums.sha256, mirroring
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-54-# the shape of a real release bundle (files directly at the archive root --
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-55-# NOT nested under a named subdirectory, unlike the sibling nddscore
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-56-# archive).
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-57-#
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:58:# @param omit_checksum_for character vector of "a.txt"/"b.txt" to leave OUT
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:59:#   of checksums.sha256 while still including the file in the tar (proves
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:60:#   the coverage gap check, item 4).
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:61:# @param extra_checksum_lines extra raw lines appended verbatim to
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:62:#   checksums.sha256 (proves the path-traversal + duplicate-entry checks,
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-63-#   item 4).
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-64-build_fixture_bundle <- function(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-65-    dir, a_sha_override = NULL, b_sha_override = NULL,
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:66:    omit_checksum_for = character(0), extra_checksum_lines = character(0)) {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-67-  src <- file.path(dir, paste0("src_", as.integer(stats::runif(1, 1, 1e9))))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-68-  dir.create(src, recursive = TRUE)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-69-  writeLines("file A content", file.path(src, "a.txt"))
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-72-  b_sha <- b_sha_override %||% digest::digest(file = file.path(src, "b.txt"), algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-73-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-74-  lines <- character(0)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:75:  if (!("a.txt" %in% omit_checksum_for)) lines <- c(lines, paste0(a_sha, "  a.txt"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:76:  if (!("b.txt" %in% omit_checksum_for)) lines <- c(lines, paste0(b_sha, "  b.txt"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:77:  lines <- c(lines, extra_checksum_lines)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:78:  cat(paste0(paste(lines, collapse = "\n"), "\n"), file = file.path(src, "checksums.sha256"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-79-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-80-  bundle_path <- file.path(dir, paste0("bundle_", basename(src), ".tar.gz"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-81-  withr::with_dir(src, {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-82-    utils::tar(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:83:      tarfile = bundle_path, files = c("a.txt", "b.txt", "checksums.sha256"),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-84-      compression = "gzip", tar = "internal"
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-85-    )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-86-  })
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-92-# public entry point for the REQUEST-arg validation.
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-93-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-94-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:95:test_that("fetch_head: rejects a release_id containing '..' (path traversal shape) before calling http_get_json", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-96-  called <- FALSE
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-97-  stub_get_json <- function(url) {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-98-    called <<- TRUE
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-100-  }
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-101-  expect_error(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-102-    analysis_release_zenodo_fetch_head("http://localhost:7778", "../evil", http_get_json = stub_get_json),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:103:    "Invalid analysis-snapshot release id"
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-104-  )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-105-  expect_false(called)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-106-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-107-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:108:test_that("fetch_head: rejects a release_id containing an embedded newline before calling http_get_json", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-109-  called <- FALSE
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-110-  stub_get_json <- function(url) {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-111-    called <<- TRUE
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-115-    analysis_release_zenodo_fetch_head(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-116-      "http://localhost:7778", "asr_1234567890abcd\nrm -rf /", http_get_json = stub_get_json
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-117-    ),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:118:    "Invalid analysis-snapshot release id"
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-119-  )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-120-  expect_false(called)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-121-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-122-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:123:test_that("fetch_head: rejects a release_id containing shell metacharacters before calling http_get_json", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-124-  called <- FALSE
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-125-  stub_get_json <- function(url) {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-126-    called <<- TRUE
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-130-    analysis_release_zenodo_fetch_head(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-131-      "http://localhost:7778", "asr_1234567890abcd;rm -rf /", http_get_json = stub_get_json
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-132-    ),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:133:    "Invalid analysis-snapshot release id"
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-134-  )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-135-  expect_false(called)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-136-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-137-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:138:test_that("fetch_head: rejects an uppercase / wrong-length release_id", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-139-  stub_get_json <- function(url) list()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-140-  expect_error(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-141-    analysis_release_zenodo_fetch_head("http://localhost:7778", "ASR_DEADBEEFCAFEBABE", http_get_json = stub_get_json),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:142:    "Invalid analysis-snapshot release id"
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-143-  )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-144-  expect_error(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-145-    analysis_release_zenodo_fetch_head("http://localhost:7778", "asr_short", http_get_json = stub_get_json),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:146:    "Invalid analysis-snapshot release id"
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-147-  )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-148-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-149-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-150-test_that("fetch_head: accepts 'latest' and a well-formed asr_<16 hex> id", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:151:  stub_get_json <- function(url) list(release_id = "ok")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-152-  expect_no_error(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-153-    analysis_release_zenodo_fetch_head("http://localhost:7778", "latest", http_get_json = stub_get_json)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-154-  )
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-167-  captured_url <- NULL
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-168-  stub_get_json <- function(url) {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-169-    captured_url <<- url
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:170:    list(release_id = "asr_abcdef0123456789", bundle_sha256 = "deadbeef")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-171-  }
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-172-  head <- analysis_release_zenodo_fetch_head("http://localhost:7778", "latest", http_get_json = stub_get_json)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-173-  expect_identical(captured_url, "http://localhost:7778/api/analysis/releases/latest")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:174:  expect_identical(head$release_id, "asr_abcdef0123456789")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-175-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-176-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:177:test_that("fetch_head: builds the /releases/<id> URL for an explicit release_id (trailing slash tolerated)", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-178-  captured_url <- NULL
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-179-  stub_get_json <- function(url) {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-180-    captured_url <<- url
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:181:    list(release_id = "asr_0000000000000000")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-182-  }
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-183-  head <- analysis_release_zenodo_fetch_head(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-184-    "http://localhost:7778/", "asr_0000000000000000", http_get_json = stub_get_json
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-185-  )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-186-  expect_identical(captured_url, "http://localhost:7778/api/analysis/releases/asr_0000000000000000")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:187:  expect_identical(head$release_id, "asr_0000000000000000")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-188-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-189-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-190-test_that("download_bundle: builds the /releases/<id>/bundle URL and streams the stub's content through", {
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-223-# extract_and_verify
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-224-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-225-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:226:test_that("extract_and_verify: passes with a matching bundle_sha256 and matching inner checksums", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-227-  work_dir <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-228-  bundle_path <- build_fixture_bundle(work_dir)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-229-  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-236-  expect_true(file.exists(file.path(result_dir, "b.txt")))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-237-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-238-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:239:test_that("extract_and_verify: FAILS when the inner checksums.sha256 doesn't match file content", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-240-  work_dir <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-241-  bad_sha <- strrep("0", 64L)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-242-  bundle_path <- build_fixture_bundle(work_dir, a_sha_override = bad_sha)
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-258-    analysis_release_zenodo_extract_and_verify(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-259-      bundle_path, strrep("f", 64L), exdir = file.path(work_dir, "extracted_bad_outer")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-260-    ),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:261:    "checksum mismatch"
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-262-  )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-263-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-264-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:265:test_that("extract_and_verify: FAILS when checksums.sha256 omits a line for a present file (coverage gap, item 4)", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-266-  work_dir <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:267:  bundle_path <- build_fixture_bundle(work_dir, omit_checksum_for = "b.txt")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-268-  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-269-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-270-  expect_error(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-271-    analysis_release_zenodo_extract_and_verify(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:272:      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_coverage_gap")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-273-    ),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:274:    "not listed in checksums.sha256"
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-275-  )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-276-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-277-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:278:test_that("extract_and_verify: FAILS when a checksums.sha256 entry contains a '../' path (traversal, item 4)", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-279-  work_dir <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-280-  bundle_path <- build_fixture_bundle(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:281:    work_dir, extra_checksum_lines = paste0(strrep("0", 64L), "  ../evil.txt")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-282-  )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-283-  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-284-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-285-  expect_error(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-286-    analysis_release_zenodo_extract_and_verify(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:287:      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_traversal")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-288-    ),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:289:    "path traversal rejected"
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-290-  )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-291-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-292-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:293:test_that("extract_and_verify: FAILS when checksums.sha256 lists the same file twice (duplicate entry, item 4)", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-294-  work_dir <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-295-  known_a_content_file <- tempfile()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-296-  writeLines("file A content", known_a_content_file)
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-298-  unlink(known_a_content_file)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-299-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-300-  bundle_path <- build_fixture_bundle(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:301:    work_dir, extra_checksum_lines = paste0(known_a_sha, "  a.txt")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-302-  )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-303-  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-304-
--
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-311-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-312-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-313-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:314:# validate_staging -- THE SAFETY VALIDATOR
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-315-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-316-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:317:test_that("validate_staging: passes on a well-formed staging dir", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:318:  staging <- make_well_formed_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:319:  expect_no_error(analysis_release_zenodo_validate_staging(staging))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-320-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-321-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:322:test_that("validate_staging: FAILS when a .env file is planted", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:323:  staging <- make_well_formed_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:324:  writeLines("SECRET=1", file.path(staging, "analysis_snapshot_release", ".env"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:325:  expect_error(analysis_release_zenodo_validate_staging(staging), "private files")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-326-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-327-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:328:test_that("validate_staging: FAILS when an UPPERCASE .ENV file is planted (item 3, case-insensitivity)", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:329:  staging <- make_well_formed_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:330:  writeLines("SECRET=1", file.path(staging, "analysis_snapshot_release", ".ENV"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:331:  expect_error(analysis_release_zenodo_validate_staging(staging), "private files")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-332-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-333-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:334:test_that("validate_staging: FAILS when a doc contains an absolute host path + dev username", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:335:  staging <- make_well_formed_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:336:  writeLines("built at /home/bernt-popp/development/sysndd on this host", file.path(staging, "README.md"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:337:  expect_error(analysis_release_zenodo_validate_staging(staging), "sensitive")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-338-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-339-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:340:test_that("validate_staging: FAILS when a doc contains a token-shaped string", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:341:  staging <- make_well_formed_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:342:  writeLines("ZENODO_TOKEN=abc123", file.path(staging, "DATA_CARD.md"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:343:  expect_error(analysis_release_zenodo_validate_staging(staging), "sensitive")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-344-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-345-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:346:test_that("validate_staging: FAILS when an expected top-level doc is missing", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:347:  staging <- make_well_formed_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:348:  file.remove(file.path(staging, "SCHEMA.md"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:349:  expect_error(analysis_release_zenodo_validate_staging(staging), "missing")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-350-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-351-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:352:test_that("validate_staging: FAILS when the nested manifest.json is missing", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:353:  staging <- make_well_formed_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:354:  file.remove(file.path(staging, "analysis_snapshot_release", "manifest.json"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:355:  expect_error(analysis_release_zenodo_validate_staging(staging), "missing")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-356-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-357-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:358:test_that("validate_staging: FAILS when a .pem file is planted (item 3, file-type allowlist)", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:359:  staging <- make_well_formed_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:360:  writeLines("-----BEGIN PRIVATE KEY-----", file.path(staging, "analysis_snapshot_release", "key.pem"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:361:  expect_error(analysis_release_zenodo_validate_staging(staging), "unexpected type/suffix")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-362-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-363-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:364:test_that("validate_staging: FAILS when a .csv file is planted (item 3, file-type allowlist)", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:365:  staging <- make_well_formed_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:366:  writeLines("a,b,c", file.path(staging, "secret.csv"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:367:  expect_error(analysis_release_zenodo_validate_staging(staging), "unexpected type/suffix")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-368-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-369-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:370:test_that("validate_staging: FAILS when an extensionless file is planted (item 3, file-type allowlist)", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:371:  staging <- make_well_formed_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:372:  writeLines("token-shaped-secret", file.path(staging, "analysis_snapshot_release", "credentials"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:373:  expect_error(analysis_release_zenodo_validate_staging(staging), "unexpected type/suffix")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-374-})
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-375-
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:376:test_that("validate_staging: FAILS when a symlink is planted (item 3, symlink rejection)", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:377:  staging <- make_well_formed_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-378-  target <- tempfile()
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:379:  writeLines("outside the staging tree", target)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:380:  link <- file.path(staging, "escape.md")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-381-  skip_if_not(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:382:    isTRUE(file.symlink(target, link)),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:383:    "host does not support creating symlinks (e.g. some restricted CI runners)"
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-384-  )
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:385:  expect_error(analysis_release_zenodo_validate_staging(staging), "symlinks")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R-386-})
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-11-#
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-12-# The fetch/download/extract-verify helpers and the safety validator
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-13-# (`analysis_release_zenodo_fetch_head`, `_download_bundle`,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:14:# `_extract_and_verify`, `_validate_staging`, plus release-id-shape
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-15-# validation) live in the sibling
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-16-# `analysis-snapshot-release-zenodo-verify.R` and are covered by
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-17-# `test-unit-analysis-release-zenodo-verify.R`; this file covers the
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:18:# builders, checksums/tarball, and the `analysis_release_zenodo_package()`
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:19:# orchestrator (including the staging-directory delete guard, which is
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-20-# exercised only through the orchestrator).
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-21-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-22-library(testthat)
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-25-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-26-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-27-# Shared fixture helper -- a valid stubbed published release (README.md +
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:28:# manifest.json + checksums.sha256, tarred), for orchestrator-level tests
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:29:# that need `analysis_release_zenodo_package()` to reach its staging/tar
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-30-# steps. Deliberately uses plain `tempfile()`-rooted names, NOT
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-31-# `withr::local_tempdir()`, inside the returned closures where relevant --
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-32-# see the shared cleanup-timing note in `test-unit-analysis-release-zenodo-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:33:# verify.R`'s `make_well_formed_staging()` comment.
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-34-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-35-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:36:build_fake_release_stubs <- function(work_dir, release_id = "asr_deadbeefcafebabe", bundle_sha256_override = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-37-  bundle_src <- file.path(work_dir, paste0("bundle_src_", as.integer(stats::runif(1, 1, 1e9))))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-38-  dir.create(bundle_src)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-39-  writeLines("# SysNDD analysis-snapshot release", file.path(bundle_src, "README.md"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:40:  writeLines(sprintf('{"release_id":"%s"}', release_id), file.path(bundle_src, "manifest.json"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-41-  readme_sha <- digest::digest(file = file.path(bundle_src, "README.md"), algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-42-  manifest_sha <- digest::digest(file = file.path(bundle_src, "manifest.json"), algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-43-  cat(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-44-    paste0(readme_sha, "  README.md\n", manifest_sha, "  manifest.json\n"),
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:45:    file = file.path(bundle_src, "checksums.sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-46-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-47-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-48-  bundle_path <- file.path(work_dir, paste0("bundle_", basename(bundle_src), ".tar.gz"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-49-  withr::with_dir(bundle_src, {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-50-    utils::tar(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:51:      tarfile = bundle_path, files = c("README.md", "manifest.json", "checksums.sha256"),
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-52-      compression = "gzip", tar = "internal"
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-53-    )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-54-  })
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-55-  bundle_sha256 <- bundle_sha256_override %||% digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-56-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-57-  fake_head <- list(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:58:    release_id = release_id,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-59-    created_at = "2026-07-15T10:00:00Z",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-60-    license = "CC-BY-4.0",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-61-    source_data_version = "v42",
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-74-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-75-test_that("build_metadata: exact keys/values for a fully-populated head", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-76-  head <- list(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:77:    release_id = "asr_abc1234567890abc",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-78-    created_at = "2026-07-15T10:00:00Z",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-79-    license = "CC-BY-4.0",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-80-    source_data_version = "v42"
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-95-})
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-96-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-97-test_that("build_metadata: a non-default head license carries through, not hardcoded", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:98:  head <- list(release_id = "asr_deadbeefdeadbeef", created_at = "2026-01-01T00:00:00Z", license = "mit")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-99-  metadata <- analysis_release_zenodo_build_metadata(head)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-100-  expect_identical(metadata$license, "mit")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-101-})
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-102-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:103:test_that("build_metadata: falls back to cc-by-4.0 license and release_id version when head omits both", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:104:  head <- list(release_id = "asr_0000000000000000", created_at = "2026-02-02T00:00:00Z")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-105-  metadata <- analysis_release_zenodo_build_metadata(head)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-106-  expect_identical(metadata$license, "cc-by-4.0")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-107-  expect_identical(metadata$version, "asr_0000000000000000")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-108-})
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-109-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-110-test_that("build_metadata: explicit version/license_id args override head values", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:111:  head <- list(release_id = "asr_1111111111111111", created_at = "2026-03-03T00:00:00Z", license = "mit")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-112-  metadata <- analysis_release_zenodo_build_metadata(head, version = "9.9.9", license_id = "cc0-1.0")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-113-  expect_identical(metadata$version, "9.9.9")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-114-  expect_identical(metadata$license, "cc0-1.0")
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-118-# build_datapackage
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-119-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-120-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:121:test_that("build_datapackage excludes checksums.sha256/datapackage.json and reports correct resource fields", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:122:  staging <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:123:  dir.create(file.path(staging, "analysis_snapshot_release"), recursive = TRUE)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:124:  writeLines("hello", file.path(staging, "README.md"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:125:  writeLines('{"a":1}', file.path(staging, "analysis_snapshot_release", "manifest.json"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:126:  cat("deadbeef  README.md\n", file = file.path(staging, "checksums.sha256"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:127:  writeLines("{}", file.path(staging, "datapackage.json"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-128-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-129-  dp <- analysis_release_zenodo_build_datapackage(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:130:    staging, name = "test-pkg", version = "v1", release_id = "asr_test"
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-131-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-132-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-133-  expect_identical(dp$profile, "data-package")
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-140-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-141-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-142-  resource_paths <- vapply(dp$resources, function(r) r$path, character(1))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:143:  expect_false("checksums.sha256" %in% resource_paths)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-144-  expect_false("datapackage.json" %in% resource_paths)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-145-  expect_true("README.md" %in% resource_paths)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-146-  expect_true("analysis_snapshot_release/manifest.json" %in% resource_paths)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-147-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-148-  readme_resource <- dp$resources[[which(resource_paths == "README.md")]]
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:149:  expect_identical(readme_resource$bytes, as.numeric(file.info(file.path(staging, "README.md"))$size))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-150-  expect_identical(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-151-    readme_resource$hash,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:152:    digest::digest(file = file.path(staging, "README.md"), algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-153-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-154-  expect_identical(readme_resource$mediatype, "application/octet-stream")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-155-  expect_identical(readme_resource$name, "README-md")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-156-})
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-157-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-158-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:159:# write_checksums
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-160-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-161-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:162:test_that("write_checksums: classic sha256sum format, excludes itself, deterministic sorted order", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:163:  staging <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:164:  writeLines("a", file.path(staging, "b.txt"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:165:  writeLines("b", file.path(staging, "a.txt"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:166:  out_path <- analysis_release_zenodo_write_checksums(staging)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-167-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:168:  expect_identical(out_path, file.path(staging, "checksums.sha256"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-169-  lines <- readLines(out_path)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-170-  expect_length(lines, 2L)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-171-  expect_true(grepl("  a\\.txt$", lines[[1]]))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-172-  expect_true(grepl("  b\\.txt$", lines[[2]]))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-173-  expect_identical(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-174-    lines[[1]],
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:175:    paste0(digest::digest(file = file.path(staging, "a.txt"), algo = "sha256"), "  a.txt")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-176-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-177-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-178-  raw_content <- readChar(out_path, file.info(out_path)$size, useBytes = TRUE)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-179-  expect_true(endsWith(raw_content, "\n"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-180-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:181:  # Re-running never emits a self-referential line for checksums.sha256 itself.
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:182:  analysis_release_zenodo_write_checksums(staging)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:183:  lines2 <- readLines(file.path(staging, "checksums.sha256"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:184:  expect_false(any(grepl("checksums\\.sha256", lines2)))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-185-})
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-186-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-187-# --------------------------------------------------------------------------- #
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-189-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-190-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-191-test_that("make_tarball: single top-level dir, plus a sibling .sha256 file with the correct digest", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:192:  staging <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:193:  writeLines("hello", file.path(staging, "README.md"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-194-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-195-  archive_dir <- file.path(withr::local_tempdir(), "archive")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-196-  archive_path <- file.path(archive_dir, "asr_test.tar.gz")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:197:  result <- analysis_release_zenodo_make_tarball(staging, archive_path)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-198-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-199-  expect_true(file.exists(result$archive_path))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-200-  expect_true(file.exists(result$archive_sha256_path))
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-208-  # utils::untar(list = TRUE) reports entries with a trailing "/" for dirs.
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-209-  top_level_dirs <- unique(sub("^([^/]+)/.*$", "\\1", entries))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-210-  expect_length(top_level_dirs, 1L)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:211:  expect_identical(top_level_dirs, basename(staging))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-212-})
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-213-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-214-test_that("make_tarball: packaging the SAME staged content twice produces a byte-identical archive (item 5)", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:215:  # A FIXED staging directory name (not withr::local_tempdir()'s randomized
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-216-  # basename) is essential here: the tar entry names are
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:217:  # `basename(staging_dir)/...`, so two DIFFERENT staging dirs would embed
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-218-  # two different names into the archive and legitimately produce different
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:219:  # bytes. Reusing the SAME staging_dir across two build passes mirrors the
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:220:  # real operator flow (a fixed `--staging-dir` rebuilt on every run).
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:221:  root <- file.path(tempdir(), paste0("zenodo_determinism_", as.integer(stats::runif(1, 1, 1e9))))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:222:  rebuild_staging <- function() {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-223-    unlink(root, recursive = TRUE, force = TRUE)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-224-    dir.create(root, recursive = TRUE)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-225-    writeLines("hello", file.path(root, "README.md"))
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-230-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-231-  archive_dir <- file.path(withr::local_tempdir(), "archive")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-232-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:233:  rebuild_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-234-  result1 <- analysis_release_zenodo_make_tarball(root, file.path(archive_dir, "run1.tar.gz"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-235-  sha1 <- digest::digest(file = result1$archive_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-236-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-237-  Sys.sleep(1.2) # ensure real wall-clock time actually advances between builds
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-238-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:239:  rebuild_staging()
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-240-  result2 <- analysis_release_zenodo_make_tarball(root, file.path(archive_dir, "run2.tar.gz"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-241-  sha2 <- digest::digest(file = result2$archive_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-242-
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-252-  work_dir <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-253-  stubs <- build_fake_release_stubs(work_dir)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-254-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:255:  staging_dir <- file.path(work_dir, "staging")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-256-  archive_dir <- file.path(work_dir, "archive")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-257-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-258-  result <- analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-259-    api_base_url = "http://localhost:7778",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:260:    release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:261:    staging_dir = staging_dir,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-262-    archive_dir = archive_dir,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-263-    http_get_json = stubs$stub_get_json,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-264-    http_download = stubs$stub_download
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-265-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-266-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:267:  expect_identical(result$release_id, "asr_deadbeefcafebabe")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:268:  expect_identical(result$staging_dir, staging_dir)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-269-  expect_true(file.exists(result$archive_path))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-270-  expect_true(file.exists(result$archive_sha256_path))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-271-  expect_true(file.exists(result$zenodo_metadata_path))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-272-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:273:  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "README.md")))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:274:  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "manifest.json")))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:275:  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "checksums.sha256")))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:276:  expect_true(file.exists(file.path(staging_dir, "checksums.sha256")))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:277:  expect_true(file.exists(file.path(staging_dir, "datapackage.json")))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-278-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-279-  metadata <- jsonlite::fromJSON(result$zenodo_metadata_path, simplifyVector = TRUE)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-280-  expect_identical(metadata$license, "CC-BY-4.0")
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-286-  expect_identical(recorded_sha_line, paste0(actual_sha, "  ", basename(result$archive_path)))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-287-})
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-288-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:289:test_that("package(): rejects when the downloaded bundle fails checksum verification", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-290-  work_dir <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-291-  stubs <- build_fake_release_stubs(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:292:    work_dir, release_id = "asr_baadf00dbaadf00d", bundle_sha256_override = strrep("f", 64L)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-293-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-294-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-295-  expect_error(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-296-    analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-297-      api_base_url = "http://localhost:7778",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:298:      release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:299:      staging_dir = file.path(work_dir, "staging2"),
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-300-      archive_dir = file.path(work_dir, "archive2"),
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-301-      http_get_json = stubs$stub_get_json,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-302-      http_download = stubs$stub_download
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-303-    ),
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:304:    "checksum mismatch"
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-305-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-306-})
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-307-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:308:test_that("package(): rejects a malformed RESOLVED release_id from the head before downloading (item 2, defense-in-depth)", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-309-  work_dir <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-310-  download_called <- FALSE
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:311:  fake_head <- list(release_id = "asr_not-a-valid-id!!", bundle_sha256 = strrep("0", 64L))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-312-  stub_get_json <- function(url) fake_head
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-313-  stub_download <- function(url, destfile) {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-314-    download_called <<- TRUE
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-315-  }
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-316-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:317:  staging_dir <- file.path(work_dir, "staging_bad_resolved_id")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-318-  expect_error(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-319-    analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-320-      api_base_url = "http://localhost:7778",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:321:      release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:322:      staging_dir = staging_dir,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-323-      archive_dir = file.path(work_dir, "archive_bad_resolved_id"),
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-324-      http_get_json = stub_get_json,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-325-      http_download = stub_download
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-326-    ),
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:327:    "Invalid analysis-snapshot release id"
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-328-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-329-  expect_false(download_called)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:330:  expect_false(dir.exists(staging_dir))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-331-})
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-332-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-333-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:334:# package(): staging-directory delete guard (item 1, BLOCKER)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-335-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-336-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:337:test_that("package(): refuses to delete a pre-existing non-empty staging dir without the ownership sentinel", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-338-  work_dir <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:339:  stubs <- build_fake_release_stubs(work_dir, release_id = "asr_ffffffffffffffff")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-340-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:341:  staging_dir <- file.path(work_dir, "staging_important")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:342:  dir.create(staging_dir, recursive = TRUE)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:343:  writeLines("do not delete me", file.path(staging_dir, "keep.txt"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-344-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-345-  expect_error(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-346-    analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-347-      api_base_url = "http://localhost:7778",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:348:      release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:349:      staging_dir = staging_dir,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-350-      archive_dir = file.path(work_dir, "archive_guard"),
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-351-      http_get_json = stubs$stub_get_json,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-352-      http_download = stubs$stub_download
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-355-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-356-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-357-  # The pre-existing directory and its content are untouched.
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:358:  expect_true(dir.exists(staging_dir))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:359:  expect_true(file.exists(file.path(staging_dir, "keep.txt")))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:360:  expect_identical(readLines(file.path(staging_dir, "keep.txt")), "do not delete me")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-361-})
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-362-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:363:test_that("package(): an EMPTY pre-existing staging dir (no sentinel needed) is accepted and populated", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-364-  work_dir <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:365:  stubs <- build_fake_release_stubs(work_dir, release_id = "asr_1234567890abcdef")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-366-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:367:  staging_dir <- file.path(work_dir, "staging_empty")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:368:  dir.create(staging_dir, recursive = TRUE)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-369-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-370-  result <- analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-371-    api_base_url = "http://localhost:7778",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:372:    release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:373:    staging_dir = staging_dir,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-374-    archive_dir = file.path(work_dir, "archive_empty"),
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-375-    http_get_json = stubs$stub_get_json,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-376-    http_download = stubs$stub_download
--
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-379-  expect_true(file.exists(result$zenodo_metadata_path))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-380-})
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-381-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:382:test_that("package(): re-running against a staging dir it previously created (has the sentinel) succeeds and replaces it", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-383-  work_dir <- withr::local_tempdir()
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:384:  staging_dir <- file.path(work_dir, "staging_reuse")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-385-  archive_dir <- file.path(work_dir, "archive_reuse")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-386-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:387:  stubs1 <- build_fake_release_stubs(work_dir, release_id = "asr_1111111111111111")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-388-  result1 <- analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-389-    api_base_url = "http://localhost:7778",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:390:    release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:391:    staging_dir = staging_dir,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-392-    archive_dir = archive_dir,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-393-    http_get_json = stubs1$stub_get_json,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-394-    http_download = stubs1$stub_download
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-395-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:396:  expect_identical(result1$release_id, "asr_1111111111111111")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-397-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:398:  # Second run against the SAME staging_dir (now sentinel-marked by the
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-399-  # first run) must succeed -- the delete guard only blocks a dir it did NOT
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-400-  # create, not a re-run against its own prior output.
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:401:  stubs2 <- build_fake_release_stubs(work_dir, release_id = "asr_2222222222222222")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-402-  result2 <- analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-403-    api_base_url = "http://localhost:7778",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:404:    release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:405:    staging_dir = staging_dir,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-406-    archive_dir = archive_dir,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-407-    http_get_json = stubs2$stub_get_json,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-408-    http_download = stubs2$stub_download
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-409-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:410:  expect_identical(result2$release_id, "asr_2222222222222222")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-411-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-412-  # The second run's content replaced the first's.
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-413-  manifest <- jsonlite::fromJSON(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:414:    file.path(staging_dir, "analysis_snapshot_release", "manifest.json"), simplifyVector = TRUE
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-415-  )
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:416:  expect_identical(manifest$release_id, "asr_2222222222222222")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R-417-})
     1	# Unit tests for the analysis-snapshot RELEASE Zenodo fetch/extract-verify
     2	# helpers and safety validator (#573 Slice C, Codex round-1 hardening):
     3	# api/functions/analysis-snapshot-release-zenodo-verify.R.
     4	#
     5	# Pure, DB-free, NO NETWORK: every HTTP boundary is an injectable seam
     6	# (`http_get_json`/`http_download`) so tests supply plain stub closures
     7	# instead of a mocking library. This file sources the MAIN
     8	# `analysis-snapshot-release-zenodo-package.R` (not `-verify.R` directly)
     9	# because that file defines `%||%` and guard-sources BOTH `-docs.R` and
    10	# `-verify.R` into the same target environment -- mirrors
    11	# `test-unit-analysis-release-zenodo-package.R`'s sourcing.
    12	#
    13	# Covers: release-id shape validation (path/filename/marker-injection guard),
    14	# `fetch_head`/`download_bundle` URL-building, `extract_and_verify`
    15	# (checksum coverage + path-traversal rejection), and the safety validator
    16	# `validate_staging` (case-insensitive forbidden-name matching, the file-type
    17	# allowlist, and symlink rejection).
    18
    19	library(testthat)
    20
    21	source_api_file("functions/analysis-snapshot-release-zenodo-package.R", local = FALSE)
    22
    23	# --------------------------------------------------------------------------- #
    24	# Shared fixture helpers
    25	# --------------------------------------------------------------------------- #
    26
    27	# A well-formed Zenodo staging directory: the expected top-level docs plus the
    28	# nested analysis_snapshot_release/ subdir with its own manifest+checksums.
    29	#
    30	# Deliberately uses plain `tempfile()`, NOT `withr::local_tempdir()`: the
    31	# latter schedules cleanup via `withr::defer(..., envir = parent.frame())`,
    32	# and `parent.frame()` evaluated INSIDE this helper resolves to this
    33	# function's own (short-lived) call frame, not the calling `test_that()`
    34	# block -- so the directory would be deleted the instant this helper
    35	# returns, before the caller can use it. Session tempdir cleanup at process
    36	# exit is sufficient for a short-lived test run.
    37	make_well_formed_staging <- function() {
    38	  staging <- file.path(tempdir(), paste0("zenodo_staging_", as.integer(stats::runif(1, 1, 1e9))))
    39	  dir.create(staging, recursive = TRUE)
    40	  for (name in c(
    41	    "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
    42	    "datapackage.json", "zenodo_metadata.json", "checksums.sha256"
    43	  )) {
    44	    writeLines("placeholder content", file.path(staging, name))
    45	  }
    46	  dir.create(file.path(staging, "analysis_snapshot_release"))
    47	  writeLines('{"release_id":"asr_test"}', file.path(staging, "analysis_snapshot_release", "manifest.json"))
    48	  writeLines("deadbeef  manifest.json", file.path(staging, "analysis_snapshot_release", "checksums.sha256"))
    49	  staging
    50	}
    51
    52	# Builds a tiny tar.gz with two files + a matching (or deliberately wrong,
    53	# omitted, duplicated, or traversal-shaped) inner checksums.sha256, mirroring
    54	# the shape of a real release bundle (files directly at the archive root --
    55	# NOT nested under a named subdirectory, unlike the sibling nddscore
    56	# archive).
    57	#
    58	# @param omit_checksum_for character vector of "a.txt"/"b.txt" to leave OUT
    59	#   of checksums.sha256 while still including the file in the tar (proves
    60	#   the coverage gap check, item 4).
    61	# @param extra_checksum_lines extra raw lines appended verbatim to
    62	#   checksums.sha256 (proves the path-traversal + duplicate-entry checks,
    63	#   item 4).
    64	build_fixture_bundle <- function(
    65	    dir, a_sha_override = NULL, b_sha_override = NULL,
    66	    omit_checksum_for = character(0), extra_checksum_lines = character(0)) {
    67	  src <- file.path(dir, paste0("src_", as.integer(stats::runif(1, 1, 1e9))))
    68	  dir.create(src, recursive = TRUE)
    69	  writeLines("file A content", file.path(src, "a.txt"))
    70	  writeLines("file B content", file.path(src, "b.txt"))
    71	  a_sha <- a_sha_override %||% digest::digest(file = file.path(src, "a.txt"), algo = "sha256")
    72	  b_sha <- b_sha_override %||% digest::digest(file = file.path(src, "b.txt"), algo = "sha256")
    73
    74	  lines <- character(0)
    75	  if (!("a.txt" %in% omit_checksum_for)) lines <- c(lines, paste0(a_sha, "  a.txt"))
    76	  if (!("b.txt" %in% omit_checksum_for)) lines <- c(lines, paste0(b_sha, "  b.txt"))
    77	  lines <- c(lines, extra_checksum_lines)
    78	  cat(paste0(paste(lines, collapse = "\n"), "\n"), file = file.path(src, "checksums.sha256"))
    79
    80	  bundle_path <- file.path(dir, paste0("bundle_", basename(src), ".tar.gz"))
    81	  withr::with_dir(src, {
    82	    utils::tar(
    83	      tarfile = bundle_path, files = c("a.txt", "b.txt", "checksums.sha256"),
    84	      compression = "gzip", tar = "internal"
    85	    )
    86	  })
    87	  bundle_path
    88	}
    89
    90	# --------------------------------------------------------------------------- #
    91	# Release-id shape validation (item 2) -- exercised via fetch_head(), the
    92	# public entry point for the REQUEST-arg validation.
    93	# --------------------------------------------------------------------------- #
    94
    95	test_that("fetch_head: rejects a release_id containing '..' (path traversal shape) before calling http_get_json", {
    96	  called <- FALSE
    97	  stub_get_json <- function(url) {
    98	    called <<- TRUE
    99	    list()
   100	  }
   101	  expect_error(
   102	    analysis_release_zenodo_fetch_head("http://localhost:7778", "../evil", http_get_json = stub_get_json),
   103	    "Invalid analysis-snapshot release id"
   104	  )
   105	  expect_false(called)
   106	})
   107
   108	test_that("fetch_head: rejects a release_id containing an embedded newline before calling http_get_json", {
   109	  called <- FALSE
   110	  stub_get_json <- function(url) {
   111	    called <<- TRUE
   112	    list()
   113	  }
   114	  expect_error(
   115	    analysis_release_zenodo_fetch_head(
   116	      "http://localhost:7778", "asr_1234567890abcd\nrm -rf /", http_get_json = stub_get_json
   117	    ),
   118	    "Invalid analysis-snapshot release id"
   119	  )
   120	  expect_false(called)
   121	})
   122
   123	test_that("fetch_head: rejects a release_id containing shell metacharacters before calling http_get_json", {
   124	  called <- FALSE
   125	  stub_get_json <- function(url) {
   126	    called <<- TRUE
   127	    list()
   128	  }
   129	  expect_error(
   130	    analysis_release_zenodo_fetch_head(
   131	      "http://localhost:7778", "asr_1234567890abcd;rm -rf /", http_get_json = stub_get_json
   132	    ),
   133	    "Invalid analysis-snapshot release id"
   134	  )
   135	  expect_false(called)
   136	})
   137
   138	test_that("fetch_head: rejects an uppercase / wrong-length release_id", {
   139	  stub_get_json <- function(url) list()
   140	  expect_error(
   141	    analysis_release_zenodo_fetch_head("http://localhost:7778", "ASR_DEADBEEFCAFEBABE", http_get_json = stub_get_json),
   142	    "Invalid analysis-snapshot release id"
   143	  )
   144	  expect_error(
   145	    analysis_release_zenodo_fetch_head("http://localhost:7778", "asr_short", http_get_json = stub_get_json),
   146	    "Invalid analysis-snapshot release id"
   147	  )
   148	})
   149
   150	test_that("fetch_head: accepts 'latest' and a well-formed asr_<16 hex> id", {
   151	  stub_get_json <- function(url) list(release_id = "ok")
   152	  expect_no_error(
   153	    analysis_release_zenodo_fetch_head("http://localhost:7778", "latest", http_get_json = stub_get_json)
   154	  )
   155	  expect_no_error(
   156	    analysis_release_zenodo_fetch_head(
   157	      "http://localhost:7778", "asr_deadbeefcafebabe", http_get_json = stub_get_json
   158	    )
   159	  )
   160	})
   161
   162	# --------------------------------------------------------------------------- #
   163	# fetch_head / download_bundle -- DI seams, no real network
   164	# --------------------------------------------------------------------------- #
   165
   166	test_that("fetch_head: builds the /releases/latest URL and passes the stub's JSON through", {
   167	  captured_url <- NULL
   168	  stub_get_json <- function(url) {
   169	    captured_url <<- url
   170	    list(release_id = "asr_abcdef0123456789", bundle_sha256 = "deadbeef")
   171	  }
   172	  head <- analysis_release_zenodo_fetch_head("http://localhost:7778", "latest", http_get_json = stub_get_json)
   173	  expect_identical(captured_url, "http://localhost:7778/api/analysis/releases/latest")
   174	  expect_identical(head$release_id, "asr_abcdef0123456789")
   175	})
   176
   177	test_that("fetch_head: builds the /releases/<id> URL for an explicit release_id (trailing slash tolerated)", {
   178	  captured_url <- NULL
   179	  stub_get_json <- function(url) {
   180	    captured_url <<- url
   181	    list(release_id = "asr_0000000000000000")
   182	  }
   183	  head <- analysis_release_zenodo_fetch_head(
   184	    "http://localhost:7778/", "asr_0000000000000000", http_get_json = stub_get_json
   185	  )
   186	  expect_identical(captured_url, "http://localhost:7778/api/analysis/releases/asr_0000000000000000")
   187	  expect_identical(head$release_id, "asr_0000000000000000")
   188	})
   189
   190	test_that("download_bundle: builds the /releases/<id>/bundle URL and streams the stub's content through", {
   191	  captured <- new.env()
   192	  work_dir <- withr::local_tempdir()
   193	  dest <- file.path(work_dir, "bundle.tar.gz")
   194	  stub_download <- function(url, destfile) {
   195	    assign("url", url, envir = captured)
   196	    assign("destfile", destfile, envir = captured)
   197	    writeBin(as.raw(c(1, 2, 3)), destfile)
   198	  }
   199	  result <- analysis_release_zenodo_download_bundle(
   200	    "http://localhost:7778", "asr_0000000000000000", dest, http_download = stub_download
   201	  )
   202	  expect_identical(get("url", envir = captured), "http://localhost:7778/api/analysis/releases/asr_0000000000000000/bundle")
   203	  expect_identical(get("destfile", envir = captured), dest)
   204	  expect_identical(result, dest)
   205	  expect_true(file.exists(dest))
   206	})
   207
   208	test_that("download_bundle: errors when the injected downloader produces an empty file", {
   209	  work_dir <- withr::local_tempdir()
   210	  dest <- file.path(work_dir, "empty.tar.gz")
   211	  stub_download <- function(url, destfile) {
   212	    file.create(destfile)
   213	  }
   214	  expect_error(
   215	    analysis_release_zenodo_download_bundle(
   216	      "http://localhost:7778", "asr_x", dest, http_download = stub_download
   217	    ),
   218	    "empty"
   219	  )
   220	})
   221
   222	# --------------------------------------------------------------------------- #
   223	# extract_and_verify
   224	# --------------------------------------------------------------------------- #
   225
   226	test_that("extract_and_verify: passes with a matching bundle_sha256 and matching inner checksums", {
   227	  work_dir <- withr::local_tempdir()
   228	  bundle_path <- build_fixture_bundle(work_dir)
   229	  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
   230
   231	  exdir <- file.path(work_dir, "extracted")
   232	  result_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, expected_sha, exdir = exdir)
   233
   234	  expect_identical(normalizePath(result_dir), normalizePath(exdir))
   235	  expect_true(file.exists(file.path(result_dir, "a.txt")))
   236	  expect_true(file.exists(file.path(result_dir, "b.txt")))
   237	})
   238
   239	test_that("extract_and_verify: FAILS when the inner checksums.sha256 doesn't match file content", {
   240	  work_dir <- withr::local_tempdir()
   241	  bad_sha <- strrep("0", 64L)
   242	  bundle_path <- build_fixture_bundle(work_dir, a_sha_override = bad_sha)
   243	  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
   244
   245	  expect_error(
   246	    analysis_release_zenodo_extract_and_verify(
   247	      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_bad_inner")
   248	    ),
   249	    "mismatch"
   250	  )
   251	})
   252
   253	test_that("extract_and_verify: FAILS with a wrong expected_bundle_sha256 (outer verification)", {
   254	  work_dir <- withr::local_tempdir()
   255	  bundle_path <- build_fixture_bundle(work_dir)
   256
   257	  expect_error(
   258	    analysis_release_zenodo_extract_and_verify(
   259	      bundle_path, strrep("f", 64L), exdir = file.path(work_dir, "extracted_bad_outer")
   260	    ),
   261	    "checksum mismatch"
   262	  )
   263	})
   264
   265	test_that("extract_and_verify: FAILS when checksums.sha256 omits a line for a present file (coverage gap, item 4)", {
   266	  work_dir <- withr::local_tempdir()
   267	  bundle_path <- build_fixture_bundle(work_dir, omit_checksum_for = "b.txt")
   268	  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
   269
   270	  expect_error(
   271	    analysis_release_zenodo_extract_and_verify(
   272	      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_coverage_gap")
   273	    ),
   274	    "not listed in checksums.sha256"
   275	  )
   276	})
   277
   278	test_that("extract_and_verify: FAILS when a checksums.sha256 entry contains a '../' path (traversal, item 4)", {
   279	  work_dir <- withr::local_tempdir()
   280	  bundle_path <- build_fixture_bundle(
   281	    work_dir, extra_checksum_lines = paste0(strrep("0", 64L), "  ../evil.txt")
   282	  )
   283	  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
   284
   285	  expect_error(
   286	    analysis_release_zenodo_extract_and_verify(
   287	      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_traversal")
   288	    ),
   289	    "path traversal rejected"
   290	  )
   291	})
   292
   293	test_that("extract_and_verify: FAILS when checksums.sha256 lists the same file twice (duplicate entry, item 4)", {
   294	  work_dir <- withr::local_tempdir()
   295	  known_a_content_file <- tempfile()
   296	  writeLines("file A content", known_a_content_file)
   297	  known_a_sha <- digest::digest(file = known_a_content_file, algo = "sha256")
   298	  unlink(known_a_content_file)
   299
   300	  bundle_path <- build_fixture_bundle(
   301	    work_dir, extra_checksum_lines = paste0(known_a_sha, "  a.txt")
   302	  )
   303	  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
   304
   305	  expect_error(
   306	    analysis_release_zenodo_extract_and_verify(
   307	      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_duplicate")
   308	    ),
   309	    "duplicate entries"
   310	  )
   311	})
   312
   313	# --------------------------------------------------------------------------- #
   314	# validate_staging -- THE SAFETY VALIDATOR
   315	# --------------------------------------------------------------------------- #
   316
   317	test_that("validate_staging: passes on a well-formed staging dir", {
   318	  staging <- make_well_formed_staging()
   319	  expect_no_error(analysis_release_zenodo_validate_staging(staging))
   320	})
   321
   322	test_that("validate_staging: FAILS when a .env file is planted", {
   323	  staging <- make_well_formed_staging()
   324	  writeLines("SECRET=1", file.path(staging, "analysis_snapshot_release", ".env"))
   325	  expect_error(analysis_release_zenodo_validate_staging(staging), "private files")
   326	})
   327
   328	test_that("validate_staging: FAILS when an UPPERCASE .ENV file is planted (item 3, case-insensitivity)", {
   329	  staging <- make_well_formed_staging()
   330	  writeLines("SECRET=1", file.path(staging, "analysis_snapshot_release", ".ENV"))
   331	  expect_error(analysis_release_zenodo_validate_staging(staging), "private files")
   332	})
   333
   334	test_that("validate_staging: FAILS when a doc contains an absolute host path + dev username", {
   335	  staging <- make_well_formed_staging()
   336	  writeLines("built at /home/bernt-popp/development/sysndd on this host", file.path(staging, "README.md"))
   337	  expect_error(analysis_release_zenodo_validate_staging(staging), "sensitive")
   338	})
   339
   340	test_that("validate_staging: FAILS when a doc contains a token-shaped string", {
   341	  staging <- make_well_formed_staging()
   342	  writeLines("ZENODO_TOKEN=abc123", file.path(staging, "DATA_CARD.md"))
   343	  expect_error(analysis_release_zenodo_validate_staging(staging), "sensitive")
   344	})
   345
   346	test_that("validate_staging: FAILS when an expected top-level doc is missing", {
   347	  staging <- make_well_formed_staging()
   348	  file.remove(file.path(staging, "SCHEMA.md"))
   349	  expect_error(analysis_release_zenodo_validate_staging(staging), "missing")
   350	})
   351
   352	test_that("validate_staging: FAILS when the nested manifest.json is missing", {
   353	  staging <- make_well_formed_staging()
   354	  file.remove(file.path(staging, "analysis_snapshot_release", "manifest.json"))
   355	  expect_error(analysis_release_zenodo_validate_staging(staging), "missing")
   356	})
   357
   358	test_that("validate_staging: FAILS when a .pem file is planted (item 3, file-type allowlist)", {
   359	  staging <- make_well_formed_staging()
   360	  writeLines("-----BEGIN PRIVATE KEY-----", file.path(staging, "analysis_snapshot_release", "key.pem"))
   361	  expect_error(analysis_release_zenodo_validate_staging(staging), "unexpected type/suffix")
   362	})
   363
   364	test_that("validate_staging: FAILS when a .csv file is planted (item 3, file-type allowlist)", {
   365	  staging <- make_well_formed_staging()
   366	  writeLines("a,b,c", file.path(staging, "secret.csv"))
   367	  expect_error(analysis_release_zenodo_validate_staging(staging), "unexpected type/suffix")
   368	})
   369
   370	test_that("validate_staging: FAILS when an extensionless file is planted (item 3, file-type allowlist)", {
   371	  staging <- make_well_formed_staging()
   372	  writeLines("token-shaped-secret", file.path(staging, "analysis_snapshot_release", "credentials"))
   373	  expect_error(analysis_release_zenodo_validate_staging(staging), "unexpected type/suffix")
   374	})
   375
   376	test_that("validate_staging: FAILS when a symlink is planted (item 3, symlink rejection)", {
   377	  staging <- make_well_formed_staging()
   378	  target <- tempfile()
   379	  writeLines("outside the staging tree", target)
   380	  link <- file.path(staging, "escape.md")
   381	  skip_if_not(
   382	    isTRUE(file.symlink(target, link)),
   383	    "host does not support creating symlinks (e.g. some restricted CI runners)"
   384	  )
   385	  expect_error(analysis_release_zenodo_validate_staging(staging), "symlinks")
   386	})

exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-package.R | sed -n '1,460p'
nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-upload.R | sed -n '160,470p'
nl -ba api/endpoints/admin_analysis_snapshot_endpoints.R | sed -n '1,260p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
     1	# Unit tests for the analysis-snapshot RELEASE Zenodo packager (#573 Slice C
     2	# / Task C1): api/functions/analysis-snapshot-release-zenodo-package.R.
     3	#
     4	# Pure, DB-free, NO NETWORK: every HTTP boundary is an injectable seam
     5	# (`http_get_json`/`http_download`) so tests supply plain stub closures
     6	# instead of a mocking library, mirroring the `nddscore_download_archive(...,
     7	# http_download = .nddscore_http_download)` DI pattern already used by
     8	# `functions/nddscore-release-source.R`. Fixture tarballs are built inline
     9	# with `utils::tar()` -- no dependency on a real published release or a
    10	# running API.
    11	#
    12	# The fetch/download/extract-verify helpers and the safety validator
    13	# (`analysis_release_zenodo_fetch_head`, `_download_bundle`,
    14	# `_extract_and_verify`, `_validate_staging`, plus release-id-shape
    15	# validation) live in the sibling
    16	# `analysis-snapshot-release-zenodo-verify.R` and are covered by
    17	# `test-unit-analysis-release-zenodo-verify.R`; this file covers the
    18	# builders, checksums/tarball, and the `analysis_release_zenodo_package()`
    19	# orchestrator (including the staging-directory delete guard, which is
    20	# exercised only through the orchestrator).
    21
    22	library(testthat)
    23
    24	source_api_file("functions/analysis-snapshot-release-zenodo-package.R", local = FALSE)
    25
    26	# --------------------------------------------------------------------------- #
    27	# Shared fixture helper -- a valid stubbed published release (README.md +
    28	# manifest.json + checksums.sha256, tarred), for orchestrator-level tests
    29	# that need `analysis_release_zenodo_package()` to reach its staging/tar
    30	# steps. Deliberately uses plain `tempfile()`-rooted names, NOT
    31	# `withr::local_tempdir()`, inside the returned closures where relevant --
    32	# see the shared cleanup-timing note in `test-unit-analysis-release-zenodo-
    33	# verify.R`'s `make_well_formed_staging()` comment.
    34	# --------------------------------------------------------------------------- #
    35
    36	build_fake_release_stubs <- function(work_dir, release_id = "asr_deadbeefcafebabe", bundle_sha256_override = NULL) {
    37	  bundle_src <- file.path(work_dir, paste0("bundle_src_", as.integer(stats::runif(1, 1, 1e9))))
    38	  dir.create(bundle_src)
    39	  writeLines("# SysNDD analysis-snapshot release", file.path(bundle_src, "README.md"))
    40	  writeLines(sprintf('{"release_id":"%s"}', release_id), file.path(bundle_src, "manifest.json"))
    41	  readme_sha <- digest::digest(file = file.path(bundle_src, "README.md"), algo = "sha256")
    42	  manifest_sha <- digest::digest(file = file.path(bundle_src, "manifest.json"), algo = "sha256")
    43	  cat(
    44	    paste0(readme_sha, "  README.md\n", manifest_sha, "  manifest.json\n"),
    45	    file = file.path(bundle_src, "checksums.sha256")
    46	  )
    47
    48	  bundle_path <- file.path(work_dir, paste0("bundle_", basename(bundle_src), ".tar.gz"))
    49	  withr::with_dir(bundle_src, {
    50	    utils::tar(
    51	      tarfile = bundle_path, files = c("README.md", "manifest.json", "checksums.sha256"),
    52	      compression = "gzip", tar = "internal"
    53	    )
    54	  })
    55	  bundle_sha256 <- bundle_sha256_override %||% digest::digest(file = bundle_path, algo = "sha256")
    56
    57	  fake_head <- list(
    58	    release_id = release_id,
    59	    created_at = "2026-07-15T10:00:00Z",
    60	    license = "CC-BY-4.0",
    61	    source_data_version = "v42",
    62	    bundle_sha256 = bundle_sha256
    63	  )
    64	  list(
    65	    stub_get_json = function(url) fake_head,
    66	    stub_download = function(url, destfile) file.copy(bundle_path, destfile, overwrite = TRUE),
    67	    fake_head = fake_head
    68	  )
    69	}
    70
    71	# --------------------------------------------------------------------------- #
    72	# build_metadata
    73	# --------------------------------------------------------------------------- #
    74
    75	test_that("build_metadata: exact keys/values for a fully-populated head", {
    76	  head <- list(
    77	    release_id = "asr_abc1234567890abc",
    78	    created_at = "2026-07-15T10:00:00Z",
    79	    license = "CC-BY-4.0",
    80	    source_data_version = "v42"
    81	  )
    82	  metadata <- analysis_release_zenodo_build_metadata(head)
    83
    84	  expect_identical(metadata$title, "SysNDD analysis-snapshot release asr_abc1234567890abc, 2026-07-15")
    85	  expect_identical(metadata$upload_type, "dataset")
    86	  expect_true(is.character(metadata$description) && length(metadata$description) == 1L)
    87	  expect_true(grepl("<p>", metadata$description, fixed = TRUE))
    88	  expect_identical(metadata$creators, list(list(name = "Popp, Bernt", orcid = "0000-0002-3679-1081")))
    89	  expect_true("SysNDD" %in% unlist(metadata$keywords))
    90	  expect_identical(metadata$access_right, "open")
    91	  expect_identical(metadata$license, "CC-BY-4.0")
    92	  expect_identical(metadata$version, "v42")
    93	  expect_identical(metadata$language, "eng")
    94	  expect_false("doi" %in% names(metadata))
    95	})
    96
    97	test_that("build_metadata: a non-default head license carries through, not hardcoded", {
    98	  head <- list(release_id = "asr_deadbeefdeadbeef", created_at = "2026-01-01T00:00:00Z", license = "mit")
    99	  metadata <- analysis_release_zenodo_build_metadata(head)
   100	  expect_identical(metadata$license, "mit")
   101	})
   102
   103	test_that("build_metadata: falls back to cc-by-4.0 license and release_id version when head omits both", {
   104	  head <- list(release_id = "asr_0000000000000000", created_at = "2026-02-02T00:00:00Z")
   105	  metadata <- analysis_release_zenodo_build_metadata(head)
   106	  expect_identical(metadata$license, "cc-by-4.0")
   107	  expect_identical(metadata$version, "asr_0000000000000000")
   108	})
   109
   110	test_that("build_metadata: explicit version/license_id args override head values", {
   111	  head <- list(release_id = "asr_1111111111111111", created_at = "2026-03-03T00:00:00Z", license = "mit")
   112	  metadata <- analysis_release_zenodo_build_metadata(head, version = "9.9.9", license_id = "cc0-1.0")
   113	  expect_identical(metadata$version, "9.9.9")
   114	  expect_identical(metadata$license, "cc0-1.0")
   115	})
   116
   117	# --------------------------------------------------------------------------- #
   118	# build_datapackage
   119	# --------------------------------------------------------------------------- #
   120
   121	test_that("build_datapackage excludes checksums.sha256/datapackage.json and reports correct resource fields", {
   122	  staging <- withr::local_tempdir()
   123	  dir.create(file.path(staging, "analysis_snapshot_release"), recursive = TRUE)
   124	  writeLines("hello", file.path(staging, "README.md"))
   125	  writeLines('{"a":1}', file.path(staging, "analysis_snapshot_release", "manifest.json"))
   126	  cat("deadbeef  README.md\n", file = file.path(staging, "checksums.sha256"))
   127	  writeLines("{}", file.path(staging, "datapackage.json"))
   128
   129	  dp <- analysis_release_zenodo_build_datapackage(
   130	    staging, name = "test-pkg", version = "v1", release_id = "asr_test"
   131	  )
   132
   133	  expect_identical(dp$profile, "data-package")
   134	  expect_identical(dp$name, "test-pkg")
   135	  expect_identical(dp$id, "asr_test")
   136	  expect_identical(dp$version, "v1")
   137	  expect_identical(
   138	    dp$licenses,
   139	    list(list(name = "CC-BY-4.0", path = "https://creativecommons.org/licenses/by/4.0/"))
   140	  )
   141
   142	  resource_paths <- vapply(dp$resources, function(r) r$path, character(1))
   143	  expect_false("checksums.sha256" %in% resource_paths)
   144	  expect_false("datapackage.json" %in% resource_paths)
   145	  expect_true("README.md" %in% resource_paths)
   146	  expect_true("analysis_snapshot_release/manifest.json" %in% resource_paths)
   147
   148	  readme_resource <- dp$resources[[which(resource_paths == "README.md")]]
   149	  expect_identical(readme_resource$bytes, as.numeric(file.info(file.path(staging, "README.md"))$size))
   150	  expect_identical(
   151	    readme_resource$hash,
   152	    digest::digest(file = file.path(staging, "README.md"), algo = "sha256")
   153	  )
   154	  expect_identical(readme_resource$mediatype, "application/octet-stream")
   155	  expect_identical(readme_resource$name, "README-md")
   156	})
   157
   158	# --------------------------------------------------------------------------- #
   159	# write_checksums
   160	# --------------------------------------------------------------------------- #
   161
   162	test_that("write_checksums: classic sha256sum format, excludes itself, deterministic sorted order", {
   163	  staging <- withr::local_tempdir()
   164	  writeLines("a", file.path(staging, "b.txt"))
   165	  writeLines("b", file.path(staging, "a.txt"))
   166	  out_path <- analysis_release_zenodo_write_checksums(staging)
   167
   168	  expect_identical(out_path, file.path(staging, "checksums.sha256"))
   169	  lines <- readLines(out_path)
   170	  expect_length(lines, 2L)
   171	  expect_true(grepl("  a\\.txt$", lines[[1]]))
   172	  expect_true(grepl("  b\\.txt$", lines[[2]]))
   173	  expect_identical(
   174	    lines[[1]],
   175	    paste0(digest::digest(file = file.path(staging, "a.txt"), algo = "sha256"), "  a.txt")
   176	  )
   177
   178	  raw_content <- readChar(out_path, file.info(out_path)$size, useBytes = TRUE)
   179	  expect_true(endsWith(raw_content, "\n"))
   180
   181	  # Re-running never emits a self-referential line for checksums.sha256 itself.
   182	  analysis_release_zenodo_write_checksums(staging)
   183	  lines2 <- readLines(file.path(staging, "checksums.sha256"))
   184	  expect_false(any(grepl("checksums\\.sha256", lines2)))
   185	})
   186
   187	# --------------------------------------------------------------------------- #
   188	# make_tarball
   189	# --------------------------------------------------------------------------- #
   190
   191	test_that("make_tarball: single top-level dir, plus a sibling .sha256 file with the correct digest", {
   192	  staging <- withr::local_tempdir()
   193	  writeLines("hello", file.path(staging, "README.md"))
   194
   195	  archive_dir <- file.path(withr::local_tempdir(), "archive")
   196	  archive_path <- file.path(archive_dir, "asr_test.tar.gz")
   197	  result <- analysis_release_zenodo_make_tarball(staging, archive_path)
   198
   199	  expect_true(file.exists(result$archive_path))
   200	  expect_true(file.exists(result$archive_sha256_path))
   201	  expect_identical(result$archive_sha256_path, paste0(result$archive_path, ".sha256"))
   202
   203	  sha_line <- readLines(result$archive_sha256_path)
   204	  actual_sha <- digest::digest(file = result$archive_path, algo = "sha256")
   205	  expect_identical(sha_line, paste0(actual_sha, "  ", basename(result$archive_path)))
   206
   207	  entries <- utils::untar(result$archive_path, list = TRUE)
   208	  # utils::untar(list = TRUE) reports entries with a trailing "/" for dirs.
   209	  top_level_dirs <- unique(sub("^([^/]+)/.*$", "\\1", entries))
   210	  expect_length(top_level_dirs, 1L)
   211	  expect_identical(top_level_dirs, basename(staging))
   212	})
   213
   214	test_that("make_tarball: packaging the SAME staged content twice produces a byte-identical archive (item 5)", {
   215	  # A FIXED staging directory name (not withr::local_tempdir()'s randomized
   216	  # basename) is essential here: the tar entry names are
   217	  # `basename(staging_dir)/...`, so two DIFFERENT staging dirs would embed
   218	  # two different names into the archive and legitimately produce different
   219	  # bytes. Reusing the SAME staging_dir across two build passes mirrors the
   220	  # real operator flow (a fixed `--staging-dir` rebuilt on every run).
   221	  root <- file.path(tempdir(), paste0("zenodo_determinism_", as.integer(stats::runif(1, 1, 1e9))))
   222	  rebuild_staging <- function() {
   223	    unlink(root, recursive = TRUE, force = TRUE)
   224	    dir.create(root, recursive = TRUE)
   225	    writeLines("hello", file.path(root, "README.md"))
   226	    dir.create(file.path(root, "sub"))
   227	    writeLines("nested content", file.path(root, "sub", "b.txt"))
   228	    root
   229	  }
   230
   231	  archive_dir <- file.path(withr::local_tempdir(), "archive")
   232
   233	  rebuild_staging()
   234	  result1 <- analysis_release_zenodo_make_tarball(root, file.path(archive_dir, "run1.tar.gz"))
   235	  sha1 <- digest::digest(file = result1$archive_path, algo = "sha256")
   236
   237	  Sys.sleep(1.2) # ensure real wall-clock time actually advances between builds
   238
   239	  rebuild_staging()
   240	  result2 <- analysis_release_zenodo_make_tarball(root, file.path(archive_dir, "run2.tar.gz"))
   241	  sha2 <- digest::digest(file = result2$archive_path, algo = "sha256")
   242
   243	  expect_identical(sha1, sha2)
   244	  unlink(root, recursive = TRUE, force = TRUE)
   245	})
   246
   247	# --------------------------------------------------------------------------- #
   248	# package(): full orchestration with stubbed HTTP
   249	# --------------------------------------------------------------------------- #
   250
   251	test_that("package(): fetches, verifies, re-stages, validates, and tars a fake published release", {
   252	  work_dir <- withr::local_tempdir()
   253	  stubs <- build_fake_release_stubs(work_dir)
   254
   255	  staging_dir <- file.path(work_dir, "staging")
   256	  archive_dir <- file.path(work_dir, "archive")
   257
   258	  result <- analysis_release_zenodo_package(
   259	    api_base_url = "http://localhost:7778",
   260	    release_id = "latest",
   261	    staging_dir = staging_dir,
   262	    archive_dir = archive_dir,
   263	    http_get_json = stubs$stub_get_json,
   264	    http_download = stubs$stub_download
   265	  )
   266
   267	  expect_identical(result$release_id, "asr_deadbeefcafebabe")
   268	  expect_identical(result$staging_dir, staging_dir)
   269	  expect_true(file.exists(result$archive_path))
   270	  expect_true(file.exists(result$archive_sha256_path))
   271	  expect_true(file.exists(result$zenodo_metadata_path))
   272
   273	  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "README.md")))
   274	  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "manifest.json")))
   275	  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "checksums.sha256")))
   276	  expect_true(file.exists(file.path(staging_dir, "checksums.sha256")))
   277	  expect_true(file.exists(file.path(staging_dir, "datapackage.json")))
   278
   279	  metadata <- jsonlite::fromJSON(result$zenodo_metadata_path, simplifyVector = TRUE)
   280	  expect_identical(metadata$license, "CC-BY-4.0")
   281	  expect_identical(metadata$version, "v42")
   282	  expect_false("doi" %in% names(metadata))
   283
   284	  recorded_sha_line <- readLines(result$archive_sha256_path)
   285	  actual_sha <- digest::digest(file = result$archive_path, algo = "sha256")
   286	  expect_identical(recorded_sha_line, paste0(actual_sha, "  ", basename(result$archive_path)))
   287	})
   288
   289	test_that("package(): rejects when the downloaded bundle fails checksum verification", {
   290	  work_dir <- withr::local_tempdir()
   291	  stubs <- build_fake_release_stubs(
   292	    work_dir, release_id = "asr_baadf00dbaadf00d", bundle_sha256_override = strrep("f", 64L)
   293	  )
   294
   295	  expect_error(
   296	    analysis_release_zenodo_package(
   297	      api_base_url = "http://localhost:7778",
   298	      release_id = "latest",
   299	      staging_dir = file.path(work_dir, "staging2"),
   300	      archive_dir = file.path(work_dir, "archive2"),
   301	      http_get_json = stubs$stub_get_json,
   302	      http_download = stubs$stub_download
   303	    ),
   304	    "checksum mismatch"
   305	  )
   306	})
   307
   308	test_that("package(): rejects a malformed RESOLVED release_id from the head before downloading (item 2, defense-in-depth)", {
   309	  work_dir <- withr::local_tempdir()
   310	  download_called <- FALSE
   311	  fake_head <- list(release_id = "asr_not-a-valid-id!!", bundle_sha256 = strrep("0", 64L))
   312	  stub_get_json <- function(url) fake_head
   313	  stub_download <- function(url, destfile) {
   314	    download_called <<- TRUE
   315	  }
   316
   317	  staging_dir <- file.path(work_dir, "staging_bad_resolved_id")
   318	  expect_error(
   319	    analysis_release_zenodo_package(
   320	      api_base_url = "http://localhost:7778",
   321	      release_id = "latest",
   322	      staging_dir = staging_dir,
   323	      archive_dir = file.path(work_dir, "archive_bad_resolved_id"),
   324	      http_get_json = stub_get_json,
   325	      http_download = stub_download
   326	    ),
   327	    "Invalid analysis-snapshot release id"
   328	  )
   329	  expect_false(download_called)
   330	  expect_false(dir.exists(staging_dir))
   331	})
   332
   333	# --------------------------------------------------------------------------- #
   334	# package(): staging-directory delete guard (item 1, BLOCKER)
   335	# --------------------------------------------------------------------------- #
   336
   337	test_that("package(): refuses to delete a pre-existing non-empty staging dir without the ownership sentinel", {
   338	  work_dir <- withr::local_tempdir()
   339	  stubs <- build_fake_release_stubs(work_dir, release_id = "asr_ffffffffffffffff")
   340
   341	  staging_dir <- file.path(work_dir, "staging_important")
   342	  dir.create(staging_dir, recursive = TRUE)
   343	  writeLines("do not delete me", file.path(staging_dir, "keep.txt"))
   344
   345	  expect_error(
   346	    analysis_release_zenodo_package(
   347	      api_base_url = "http://localhost:7778",
   348	      release_id = "latest",
   349	      staging_dir = staging_dir,
   350	      archive_dir = file.path(work_dir, "archive_guard"),
   351	      http_get_json = stubs$stub_get_json,
   352	      http_download = stubs$stub_download
   353	    ),
   354	    "refusing to delete"
   355	  )
   356
   357	  # The pre-existing directory and its content are untouched.
   358	  expect_true(dir.exists(staging_dir))
   359	  expect_true(file.exists(file.path(staging_dir, "keep.txt")))
   360	  expect_identical(readLines(file.path(staging_dir, "keep.txt")), "do not delete me")
   361	})
   362
   363	test_that("package(): an EMPTY pre-existing staging dir (no sentinel needed) is accepted and populated", {
   364	  work_dir <- withr::local_tempdir()
   365	  stubs <- build_fake_release_stubs(work_dir, release_id = "asr_1234567890abcdef")
   366
   367	  staging_dir <- file.path(work_dir, "staging_empty")
   368	  dir.create(staging_dir, recursive = TRUE)
   369
   370	  result <- analysis_release_zenodo_package(
   371	    api_base_url = "http://localhost:7778",
   372	    release_id = "latest",
   373	    staging_dir = staging_dir,
   374	    archive_dir = file.path(work_dir, "archive_empty"),
   375	    http_get_json = stubs$stub_get_json,
   376	    http_download = stubs$stub_download
   377	  )
   378
   379	  expect_true(file.exists(result$zenodo_metadata_path))
   380	})
   381
   382	test_that("package(): re-running against a staging dir it previously created (has the sentinel) succeeds and replaces it", {
   383	  work_dir <- withr::local_tempdir()
   384	  staging_dir <- file.path(work_dir, "staging_reuse")
   385	  archive_dir <- file.path(work_dir, "archive_reuse")
   386
   387	  stubs1 <- build_fake_release_stubs(work_dir, release_id = "asr_1111111111111111")
   388	  result1 <- analysis_release_zenodo_package(
   389	    api_base_url = "http://localhost:7778",
   390	    release_id = "latest",
   391	    staging_dir = staging_dir,
   392	    archive_dir = archive_dir,
   393	    http_get_json = stubs1$stub_get_json,
   394	    http_download = stubs1$stub_download
   395	  )
   396	  expect_identical(result1$release_id, "asr_1111111111111111")
   397
   398	  # Second run against the SAME staging_dir (now sentinel-marked by the
   399	  # first run) must succeed -- the delete guard only blocks a dir it did NOT
   400	  # create, not a re-run against its own prior output.
   401	  stubs2 <- build_fake_release_stubs(work_dir, release_id = "asr_2222222222222222")
   402	  result2 <- analysis_release_zenodo_package(
   403	    api_base_url = "http://localhost:7778",
   404	    release_id = "latest",
   405	    staging_dir = staging_dir,
   406	    archive_dir = archive_dir,
   407	    http_get_json = stubs2$stub_get_json,
   408	    http_download = stubs2$stub_download
   409	  )
   410	  expect_identical(result2$release_id, "asr_2222222222222222")
   411
   412	  # The second run's content replaced the first's.
   413	  manifest <- jsonlite::fromJSON(
   414	    file.path(staging_dir, "analysis_snapshot_release", "manifest.json"), simplifyVector = TRUE
   415	  )
   416	  expect_identical(manifest$release_id, "asr_2222222222222222")
   417	})
   160	    "https://zenodo.org/api", "tok", 999, http = stub_http
   161	  )
   162
   163	  expect_identical(get("method", envir = captured), "POST")
   164	  expect_identical(
   165	    get("url", envir = captured), "https://zenodo.org/api/deposit/depositions/999/actions/publish"
   166	  )
   167	  expect_identical(result$doi, "10.5281/zenodo.999")
   168	})
   169
   170	# --------------------------------------------------------------------------- #
   171	# record_doi -- PATCH to the SysNDD admin endpoint, only non-empty fields
   172	# --------------------------------------------------------------------------- #
   173
   174	test_that("record_doi: PATCH .../releases/<id>/doi, admin Bearer token, body has ONLY supplied non-empty fields", {
   175	  captured <- new.env()
   176	  stub_patch <- function(method, url, token, body = NULL) {
   177	    assign("method", method, envir = captured)
   178	    assign("url", url, envir = captured)
   179	    assign("token", token, envir = captured)
   180	    assign("body", body, envir = captured)
   181	    list(release_id = "asr_test")
   182	  }
   183
   184	  result <- analysis_release_zenodo_record_doi(
   185	    "http://localhost:7778",
   186	    "admin-token",
   187	    "asr_deadbeefcafebabe",
   188	    doi_fields = list(
   189	      zenodo_record_id = "999",
   190	      zenodo_record_url = "https://zenodo.org/record/999",
   191	      version_doi = "10.5281/zenodo.999",
   192	      concept_doi = NULL
   193	    ),
   194	    patch = stub_patch
   195	  )
   196
   197	  expect_identical(get("method", envir = captured), "PATCH")
   198	  expect_identical(
   199	    get("url", envir = captured),
   200	    "http://localhost:7778/api/admin/analysis/releases/asr_deadbeefcafebabe/doi"
   201	  )
   202	  expect_identical(get("token", envir = captured), "admin-token")
   203
   204	  body <- get("body", envir = captured)
   205	  expect_setequal(names(body), c("zenodo_record_id", "zenodo_record_url", "version_doi"))
   206	  expect_identical(body$zenodo_record_id, "999")
   207	  expect_identical(body$zenodo_record_url, "https://zenodo.org/record/999")
   208	  expect_identical(body$version_doi, "10.5281/zenodo.999")
   209	  expect_false("concept_doi" %in% names(body))
   210	  expect_identical(result$release_id, "asr_test")
   211	})
   212
   213	test_that("record_doi: an empty-string field is also dropped (never forwarded as an empty value)", {
   214	  captured_body <- NULL
   215	  stub_patch <- function(method, url, token, body = NULL) {
   216	    captured_body <<- body
   217	    list()
   218	  }
   219
   220	  analysis_release_zenodo_record_doi(
   221	    "http://localhost:7778", "admin-token", "asr_x",
   222	    doi_fields = list(zenodo_record_id = "1", concept_doi = ""),
   223	    patch = stub_patch
   224	  )
   225
   226	  expect_setequal(names(captured_body), "zenodo_record_id")
   227	})
   228
   229	test_that("record_doi: an NA_character_ field is dropped, not forwarded as null (nzchar(NA) gotcha)", {
   230	  captured_body <- NULL
   231	  stub_patch <- function(method, url, token, body = NULL) {
   232	    captured_body <<- body
   233	    list()
   234	  }
   235
   236	  analysis_release_zenodo_record_doi(
   237	    "http://localhost:7778", "admin-token", "asr_x",
   238	    doi_fields = list(version_doi = "10.5281/zenodo.1", concept_doi = NA_character_),
   239	    patch = stub_patch
   240	  )
   241
   242	  expect_setequal(names(captured_body), "version_doi")
   243	  expect_false("concept_doi" %in% names(captured_body))
   244	})
   245
   246	# --------------------------------------------------------------------------- #
   247	# manual_doi_command -- the printed fallback when --record-doi is not opted into
   248	# --------------------------------------------------------------------------- #
   249
   250	test_that("manual_doi_command: contains the endpoint path, release id, and all 4 supplied fields", {
   251	  command <- analysis_release_zenodo_manual_doi_command(
   252	    "http://localhost:7778",
   253	    "asr_deadbeefcafebabe",
   254	    doi_fields = list(
   255	      zenodo_record_id = "999",
   256	      zenodo_record_url = "https://zenodo.org/record/999",
   257	      version_doi = "10.5281/zenodo.999",
   258	      concept_doi = "10.5281/zenodo.998"
   259	    )
   260	  )
   261
   262	  expect_true(grepl("/api/admin/analysis/releases/asr_deadbeefcafebabe/doi", command, fixed = TRUE))
   263	  expect_true(grepl("curl -X PATCH", command, fixed = TRUE))
   264	  expect_true(grepl("999", command, fixed = TRUE))
   265	  expect_true(grepl("https://zenodo.org/record/999", command, fixed = TRUE))
   266	  expect_true(grepl("10.5281/zenodo.999", command, fixed = TRUE))
   267	  expect_true(grepl("10.5281/zenodo.998", command, fixed = TRUE))
   268	  expect_true(grepl("zenodo_record_id", command, fixed = TRUE))
   269	  expect_true(grepl("zenodo_record_url", command, fixed = TRUE))
   270	  expect_true(grepl("version_doi", command, fixed = TRUE))
   271	  expect_true(grepl("concept_doi", command, fixed = TRUE))
   272	})
   273
   274	test_that("manual_doi_command: never auto-executes -- it only returns a string", {
   275	  command <- analysis_release_zenodo_manual_doi_command(
   276	    "http://localhost:7778", "asr_x", doi_fields = list(zenodo_record_id = "1")
   277	  )
   278	  expect_true(is.character(command))
   279	  expect_length(command, 1L)
   280	})
   281
   282	test_that("manual_doi_command: an NA_character_ field is omitted, not printed as null/NA (nzchar(NA) gotcha)", {
   283	  command <- analysis_release_zenodo_manual_doi_command(
   284	    "http://localhost:7778",
   285	    "asr_deadbeefcafebabe",
   286	    doi_fields = list(
   287	      zenodo_record_id = "999",
   288	      concept_doi = NA_character_
   289	    )
   290	  )
   291
   292	  expect_true(grepl("zenodo_record_id", command, fixed = TRUE))
   293	  expect_false(grepl("concept_doi", command, fixed = TRUE))
   294	  expect_false(grepl("null", command, fixed = TRUE))
   295	  expect_false(grepl("\"NA\"", command, fixed = TRUE))
   296	})
   297
   298	# --------------------------------------------------------------------------- #
   299	# upload(): full orchestration with stubbed HTTP -- draft-only and publish
   300	# --------------------------------------------------------------------------- #
   301
   302	# Deliberately uses plain `tempfile()`, NOT `withr::local_tempfile()`: the
   303	# latter schedules cleanup via `withr::defer(..., envir = parent.frame())`,
   304	# and `parent.frame()` evaluated INSIDE this helper resolves to this
   305	# function's own (short-lived) call frame, not the calling `test_that()`
   306	# block -- so the files would be deleted the instant this helper returns,
   307	# before the caller can use them (same trap documented in
   308	# `test-unit-analysis-release-zenodo-package.R`'s `make_well_formed_staging()`
   309	# comment). Session tempdir cleanup at process exit is sufficient here.
   310	.zenodo_upload_test_files <- function() {
   311	  archive <- file.path(tempdir(), paste0("zenodo_upload_test_", as.integer(stats::runif(1, 1, 1e9)), ".tar.gz"))
   312	  writeBin(charToRaw("archive bytes"), archive)
   313	  metadata_path <- file.path(tempdir(), paste0("zenodo_upload_test_", as.integer(stats::runif(1, 1, 1e9)), ".json"))
   314	  writeLines('{"title": "Test", "upload_type": "dataset"}', metadata_path)
   315	  list(archive = archive, metadata_path = metadata_path)
   316	}
   317
   318	test_that("upload(): draft-only flow (publish=FALSE) never calls publish_deposition", {
   319	  files <- .zenodo_upload_test_files()
   320	  publish_called <- FALSE
   321
   322	  fake_get_or_create <- function(api, token, deposition_id = NULL) {
   323	    list(
   324	      id = 111,
   325	      links = list(bucket = "https://bucket.example/111", html = "https://zenodo.org/deposit/111"),
   326	      metadata = list(prereserve_doi = list(doi = "10.5281/zenodo.111"))
   327	    )
   328	  }
   329	  fake_set_metadata <- function(api, token, deposition_id, metadata) NULL
   330	  fake_upload_bucket <- function(bucket_url, token, archive_path) invisible(NULL)
   331	  fake_publish <- function(api, token, deposition_id) {
   332	    publish_called <<- TRUE
   333	    list()
   334	  }
   335
   336	  result <- analysis_release_zenodo_upload(
   337	    archive_path = files$archive,
   338	    metadata_path = files$metadata_path,
   339	    token = "tok",
   340	    publish = FALSE,
   341	    confirm_publish = FALSE,
   342	    get_or_create_deposition = fake_get_or_create,
   343	    set_metadata = fake_set_metadata,
   344	    upload_bucket = fake_upload_bucket,
   345	    publish_deposition = fake_publish
   346	  )
   347
   348	  expect_false(publish_called)
   349	  expect_identical(result$deposition_id, 111)
   350	  expect_identical(result$reserved_doi, "10.5281/zenodo.111")
   351	  expect_identical(result$draft_url, "https://zenodo.org/deposit/111")
   352	  expect_false(result$published)
   353	  expect_true(is.na(result$version_doi))
   354	})
   355
   356	test_that("upload(): publish=TRUE + confirm_publish=TRUE publishes and fills version/concept DOI + record_url", {
   357	  files <- .zenodo_upload_test_files()
   358
   359	  fake_get_or_create <- function(api, token, deposition_id = NULL) {
   360	    list(id = 222, links = list(bucket = "https://bucket.example/222", html = "https://zenodo.org/deposit/222"))
   361	  }
   362	  fake_set_metadata <- function(api, token, deposition_id, metadata) NULL
   363	  fake_upload_bucket <- function(bucket_url, token, archive_path) invisible(NULL)
   364	  fake_publish <- function(api, token, deposition_id) {
   365	    list(
   366	      doi = "10.5281/zenodo.222",
   367	      conceptdoi = "10.5281/zenodo.221",
   368	      links = list(html = "https://zenodo.org/record/222")
   369	    )
   370	  }
   371
   372	  result <- analysis_release_zenodo_upload(
   373	    archive_path = files$archive,
   374	    metadata_path = files$metadata_path,
   375	    token = "tok",
   376	    publish = TRUE,
   377	    confirm_publish = TRUE,
   378	    get_or_create_deposition = fake_get_or_create,
   379	    set_metadata = fake_set_metadata,
   380	    upload_bucket = fake_upload_bucket,
   381	    publish_deposition = fake_publish
   382	  )
   383
   384	  expect_true(result$published)
   385	  expect_identical(result$version_doi, "10.5281/zenodo.222")
   386	  expect_identical(result$concept_doi, "10.5281/zenodo.221")
   387	  expect_identical(result$record_url, "https://zenodo.org/record/222")
   388	})
   389
   390	test_that("upload(): publish=TRUE without confirm_publish stops before any HTTP seam is invoked", {
   391	  files <- .zenodo_upload_test_files()
   392	  called <- FALSE
   393	  fake_get_or_create <- function(...) {
   394	    called <<- TRUE
   395	    list(id = 1, links = list(bucket = "https://bucket.example"))
   396	  }
   397
   398	  expect_error(
   399	    analysis_release_zenodo_upload(
   400	      archive_path = files$archive,
   401	      metadata_path = files$metadata_path,
   402	      token = "tok",
   403	      publish = TRUE,
   404	      confirm_publish = FALSE,
   405	      get_or_create_deposition = fake_get_or_create
   406	    ),
   407	    "--publish requires --confirm-publish"
   408	  )
   409	  expect_false(called)
   410	})
   411
   412	test_that("upload(): missing token stops with a clear message", {
   413	  files <- .zenodo_upload_test_files()
   414	  expect_error(
   415	    analysis_release_zenodo_upload(
   416	      archive_path = files$archive, metadata_path = files$metadata_path, token = ""
   417	    ),
   418	    "ZENODO_TOKEN"
   419	  )
   420	})
   421
   422	test_that("upload(): missing archive file stops with a clear message", {
   423	  files <- .zenodo_upload_test_files()
   424	  expect_error(
   425	    analysis_release_zenodo_upload(
   426	      archive_path = file.path(tempdir(), "does-not-exist.tar.gz"),
   427	      metadata_path = files$metadata_path,
   428	      token = "tok"
   429	    ),
   430	    "Archive does not exist"
   431	  )
   432	})
   433
   434	test_that("upload(): missing metadata file stops with a clear message", {
   435	  files <- .zenodo_upload_test_files()
   436	  expect_error(
   437	    analysis_release_zenodo_upload(
   438	      archive_path = files$archive,
   439	      metadata_path = file.path(tempdir(), "does-not-exist.json"),
   440	      token = "tok"
   441	    ),
   442	    "Metadata does not exist"
   443	  )
   444	})
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

exec
/bin/bash -lc "cd api && Rscript -e \"testthat::test_file('tests/testthat/test-unit-analysis-release-zenodo-verify.R'); testthat::test_file('tests/testthat/test-unit-analysis-release-zenodo-package.R'); testthat::test_file('tests/testthat/test-unit-analysis-release-zenodo-upload.R')\"" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 exited 2 in 0ms:
Fatal error: creating temporary file for '-e' failed

exec
/bin/bash -lc 'git diff origin/master...HEAD -- .gitignore AGENTS.md CHANGELOG.md documentation/09-deployment.qmd api/version_spec.json app/package.json app/package-lock.json && rg -n "analysis_release_zenodo|package-analysis-release|upload-analysis-release|analysis-release-zenodo" Makefile api/functions api/scripts documentation api/tests/testthat | head -n 260' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
diff --git a/.gitignore b/.gitignore
index c3aedec2..c7f0f765 100644
--- a/.gitignore
+++ b/.gitignore
@@ -87,3 +87,7 @@ secrets/

 # Superpowers SDD scratch (ledger, task briefs, review packages)
 .superpowers/
+
+# Analysis-snapshot release Zenodo packaging output (#573 Slice C): staging
+# trees + archives generated by `make analysis-release-zenodo-package`.
+outputs/analysis-release-zenodo/
diff --git a/AGENTS.md b/AGENTS.md
index 7aa9b3e1..6199501a 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -122,6 +122,7 @@ Analysis-snapshot **releases** are immutable, content-addressed, frozen exports
 - **Never pruned.** A published release is permanent; `DELETE /api/admin/analysis/releases/<id>` only works on a `draft`. `analysis_snapshot_prune()` (`analysis-snapshot-repository.R`) now skips any `snapshot_id` still referenced by an `analysis_snapshot_release_member` row (`analysis_release_referenced_snapshot_ids()`), so a snapshot pinned by a release keeps serving its live reproducibility endpoint too — even though release integrity never depends on the source snapshot surviving (each release is self-contained).
 - **Build is synchronous, admin, DB-only — the worker is NOT required.** Unlike snapshot refresh, `POST /api/admin/analysis/releases` runs inline on the API request (`analysis_snapshot_release_build()` is called directly from the endpoint, not submitted as an async job): no clustering recompute, no external calls, no LLM, no cache writes. A release can be built even if the worker is down, as long as public-ready snapshots already exist.
 - **`GET .../releases/<release_id>/file?path=<file_path>` uses a query param, not a nested path segment**, because Plumber 1.3.2 has no `<path:.*>` wildcard — only named, typed, single-segment path params (`<id>`, `<id:int>`) exist, so a nested archive path (e.g. `functional_clusters/payload.json`) cannot be expressed as a URL path segment. The manifest's `files[].path` values are the caller's index into this route.
+- **Zenodo operator scripts (#573 Slice C).** `api/scripts/{package,upload}-analysis-release-zenodo.R` (+ helpers `api/functions/analysis-snapshot-release-zenodo-{package,verify,docs,upload}.R`) archive a published release to Zenodo. They are HOST-RUN, HTTP-only (read a published release via the public API only — no DB/worker involvement), draft-only by default behind a `--publish --confirm-publish` double-gate, and support an opt-in `--record-doi` record-back to the additive DOI PATCH endpoint above. `make analysis-release-zenodo-package` / `make analysis-release-zenodo-upload-draft` wrap them for local operator use (the package step also writes a `outputs/analysis-release-zenodo/latest.env` pointer file so the upload step can find the content-addressed archive without a hardcoded filename, and the Makefile reads that file back with a safe `sed` field-extract, not a `source`, so a marker-format change can never inject shell); the Makefile never passes `--publish`. These scripts are operator-only — NOT sourced by `bootstrap/load_modules.R` — and are exempt from the external-budget guard (one-shot scripts, not request-path code), covered by `test-unit-analysis-release-zenodo-{package,upload}.R`. Hardening (post-Codex-review, #573 Slice C round 1): the resolved/requested `release_id` is validated against `^asr_[0-9a-f]{16}$` (`.analysis_release_zenodo_assert_valid_release_id()`, sibling `-verify.R`) before it can become a filename/path/marker value; `analysis_release_zenodo_package()` refuses to `unlink(recursive = TRUE)` a pre-existing `--staging-dir` unless it is empty or carries an ownership sentinel (`.analysis-release-zenodo-staging`) this tool itself wrote on a prior run — a non-empty, non-sentinel dir stops the build instead of being silently rmtree'd; the safety validator matches forbidden names/dir-parts case-insensitively, enforces a file-type allowlist (`.md`/`.json`/`.sha256`/`.cff`/`.txt`/`.sql` only), and rejects symlinks; `analysis_release_zenodo_extract_and_verify()` requires full checksum COVERAGE (every extracted file, no unstamped extras) and rejects absolute/`..` paths in both tar members and checksum entries; the tarball is made byte-identical across rebuilds of the same staged content by normalizing every staged file/dir's mtime to a fixed epoch before tarring (R's internal tar writer already zeroes the gzip container timestamp); and the upload CLI reads `ZENODO_TOKEN` from the environment ONLY — there is no `--token` flag, to avoid leaking the token into shell history/argv.

 ### Cluster-analysis statistical soundness (#508–#512)

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 48651d8b..10996e09 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -6,6 +6,17 @@ The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),

 ## [Unreleased]

+## [0.30.3] — 2026-07-19
+
+Zenodo archival operator scripts for analysis-snapshot releases (#573, Slice C). A published analysis-snapshot release (Slice A) can now be archived to Zenodo with two host-run, HTTP-only scripts — no DB, no worker, no docker exec. Note: 0.30.1 (#574 category clustering) and 0.30.2 (#573 Slice B UI) are reserved for those PRs, which this assumes land first.
+
+### Added
+
+- **`api/scripts/package-analysis-release-zenodo.R`**: fetches a published release over the public `/api/analysis/releases/*` API, verifies its bundle checksum, re-stages the files under `analysis_snapshot_release/`, adds Zenodo-facing docs/metadata (`README.md`, `DATA_CARD.md`, `SCHEMA.md`, `CHANGELOG.md`, `CITATION.cff`, `zenodo_metadata.json`, `datapackage.json`), runs a packaging safety validator, and produces a deterministic `<release_id>.tar.gz` + checksum. Writes a `outputs/analysis-release-zenodo/latest.env` pointer file so downstream tooling can find the content-addressed archive without a hardcoded filename.
+- **`api/scripts/upload-analysis-release-zenodo.R`**: uploads a packaged archive to a Zenodo deposition (get-or-create, set metadata, stream file to bucket), with an optional, doubly-gated `--publish --confirm-publish` step and an opt-in `--record-doi` record-back to the additive `PATCH /api/admin/analysis/releases/<id>/doi` endpoint. Draft-only by default; publishing is always a deliberate, explicit action.
+- Two Make targets, `analysis-release-zenodo-package` and `analysis-release-zenodo-upload-draft`, wrap the scripts for local operator use; the Makefile itself never passes `--publish`.
+- Operator runbook documented in `documentation/09-deployment.qmd` under "Zenodo archival (operator scripts, #573 Slice C)".
+
 ## [0.30.0] — 2026-07-18

 Immutable public analysis-snapshot releases (#573, Slice A). SysNDD's derived
diff --git a/api/version_spec.json b/api/version_spec.json
index 86e2b6e6..3e5cbe9a 100644
--- a/api/version_spec.json
+++ b/api/version_spec.json
@@ -1,7 +1,7 @@
 {
   "title": "SysNDD API",
   "description": "This is the API powering the SysNDD website, allowing programmatic access to the database contents.",
-  "version": "0.30.0",
+  "version": "0.30.3",
   "contact": {
     "name": "API Support",
     "url": "https://berntpopp.github.io/sysndd/api.html",
diff --git a/app/package-lock.json b/app/package-lock.json
index bcc638de..37dfd6d3 100644
--- a/app/package-lock.json
+++ b/app/package-lock.json
@@ -1,12 +1,12 @@
 {
   "name": "sysndd",
-  "version": "0.30.0",
+  "version": "0.30.3",
   "lockfileVersion": 3,
   "requires": true,
   "packages": {
     "": {
       "name": "sysndd",
-      "version": "0.30.0",
+      "version": "0.30.3",
       "dependencies": {
         "@popperjs/core": "^2.11.8",
         "@unhead/vue": "^3.1.8",
diff --git a/app/package.json b/app/package.json
index ea8dbd91..21ff6092 100644
--- a/app/package.json
+++ b/app/package.json
@@ -1,6 +1,6 @@
 {
   "name": "sysndd",
-  "version": "0.30.0",
+  "version": "0.30.3",
   "private": true,
   "type": "module",
   "scripts": {
diff --git a/documentation/09-deployment.qmd b/documentation/09-deployment.qmd
index ff2dc9b5..a90b67d0 100644
--- a/documentation/09-deployment.qmd
+++ b/documentation/09-deployment.qmd
@@ -313,7 +313,46 @@ curl -sS -X PATCH https://<host>/api/admin/analysis/releases/<release_id>/doi \

 **Public download surface** (no auth): `GET /api/analysis/releases/<release_id>/manifest.json` returns the exact stored manifest bytes (`sha256(bytes) == manifest_sha256` on the release head); `GET /api/analysis/releases/<release_id>/file?path=<file_path>` returns one content-addressed file by its exact manifest path (e.g. `path=functional_clusters/payload.json`); `GET /api/analysis/releases/<release_id>/bundle` streams the whole frozen `bundle.tar.gz`.

-**Zenodo packaging/upload.** The operator-run archival flow that packages a published release into a Zenodo-ready dataset (mirroring the existing NDDScore Zenodo release scripts) is planned for a later slice of this program; it is not part of this deploy. Until then, `PATCH .../doi` accepts a manually-recorded DOI once an operator has archived a release through any equivalent process.
+#### Zenodo archival (operator scripts, #573 Slice C)
+
+Once a release is published (above), an operator can archive it to Zenodo with two host-run scripts (`api/scripts/package-analysis-release-zenodo.R` + `api/scripts/upload-analysis-release-zenodo.R`, mirroring the existing NDDScore/Zenodo release scripts in `../nddscore`). Both are plain HTTP clients: the packager reads the release only through the public `/api/analysis/releases/*` routes above (no DB, no `docker exec`), and the uploader only talks to the Zenodo REST API and (optionally) the admin DOI PATCH endpoint. Neither is wired into `docker-compose.yml`, `bootstrap/load_modules.R`, or the worker — run them on the host (or CI) where a published release is reachable over HTTP.
+
+**Prerequisites:**
+
+- Host R with `httr2`, `jsonlite`, and `digest` (all already in `api/renv.lock`).
+- `ZENODO_TOKEN` — a Zenodo personal access token (`https://zenodo.org/account/settings/applications/tokens/new/`, scope `deposit:write` + `deposit:actions`). Set it in your shell or a git-ignored `.env`; it is **never** committed and the Makefile never bakes it in as a literal.
+- `SYSNDD_API_BASE_URL` (optional) — the public API base to read the release from; defaults to `http://localhost:7778`.
+- `SYSNDD_ADMIN_TOKEN` (optional) — a pre-minted SysNDD Administrator bearer token, only needed for the automated DOI record-back in step 6.
+
+**Flow:**
+
+1. **Package.**
+   ```bash
+   make analysis-release-zenodo-package
+   # or, for an explicit release rather than the current `latest`:
+   ARGS="--release-id asr_<16 hex>" make analysis-release-zenodo-package
+   ```
+   Downloads the release's `bundle.tar.gz`, verifies its checksum, re-stages the files under `analysis_snapshot_release/`, adds Zenodo-facing `README.md`/`DATA_CARD.md`/`SCHEMA.md`/`CHANGELOG.md`/`CITATION.cff`/`zenodo_metadata.json`/`datapackage.json`, runs the packaging safety validator (case-insensitive `.env`/`.git`/sensitive-text rejection, a file-type allowlist, and a symlink rejection — defense-in-depth; a release payload has no such content by construction), and writes `outputs/analysis-release-zenodo/archive/<release_id>.tar.gz` + `.sha256` plus a `outputs/analysis-release-zenodo/latest.env` pointer file (`ARCHIVE_PATH`/`METADATA_PATH`/`RELEASE_ID`) so the next step can find the content-addressed archive without a hardcoded, drift-prone filename.
+2. **Review** the staging directory (`outputs/analysis-release-zenodo/staging/`) by eye before uploading anything — the validator is a safety net, not a substitute for a human look.
+3. **Upload a draft.**
+   ```bash
+   make analysis-release-zenodo-upload-draft
+   # against the Zenodo sandbox instead of production, for a dry run:
+   UPLOAD_ARGS="--sandbox" make analysis-release-zenodo-upload-draft
+   ```
+   Requires `ZENODO_TOKEN` (the target fails fast with a clear message if it is unset) and `outputs/analysis-release-zenodo/latest.env` (fails fast with "run analysis-release-zenodo-package first" if absent). Creates (or reuses, via `--deposition-id`) a Zenodo deposition, sets its metadata, and streams the archive to the deposition bucket — **always a DRAFT**, never published. Prints the reserved DOI and the draft's Zenodo web URL.
+4. **Review the draft** in the Zenodo web UI (metadata, file listing, reserved DOI) before publishing.
+5. **Publish — deliberately, by hand.** There is no Make target for this on purpose: publishing is a one-way action, so it stays a manual `Rscript` invocation behind a double gate (`analysis_release_zenodo_require_publish_confirmation()` refuses to make any HTTP call unless **both** flags are present). `ZENODO_TOKEN` must already be exported in the shell — there is no `--token` flag (a CLI flag would leak the token into shell history and process argv):
+   ```bash
+   Rscript api/scripts/upload-analysis-release-zenodo.R \
+     --archive outputs/analysis-release-zenodo/archive/<release_id>.tar.gz \
+     --metadata outputs/analysis-release-zenodo/staging/zenodo_metadata.json \
+     --release-id <release_id> \
+     --deposition-id <id-from-step-3> --publish --confirm-publish
+   ```
+6. **Record the DOI** back onto the SysNDD release head — additive only; it never touches `content_digest`/`manifest_sha256`, so the bytes a consumer already downloaded stay valid. Either automatically, by adding `--record-doi` (with `SYSNDD_ADMIN_TOKEN` set) to the publish command in step 5, or by running the manual `curl` command the script prints when `--record-doi` is omitted (equivalent to the `PATCH .../releases/<release_id>/doi` call documented above).
+
+**Defaults and safety.** Every upload is a DRAFT unless step 5's double gate is satisfied explicitly. The archive itself is a self-contained, independently-verifiable copy (its own `manifest.json`, `checksums.sha256`, and — for the two cluster layers — reproducibility bundles), so a Zenodo consumer never depends on SysNDD staying reachable. No manuscript or paper references appear anywhere in the packaged output.

 ### Disease cross-ontology mapping refresh (`ontology-mapping-cron`)

Makefile:44:.PHONY: help check-r check-npm check-docker install-api install-app dev serve-app build-app verify-app-bundle-budget watch-app test-api test-api-fast test-api-full mcp-transport-spike test-mcp-smoke coverage lint-api lint-app format-api format-app verify-seo-app code-quality-audit pre-commit ci-local _ci-cleanup preflight docker-build docker-up docker-down docker-dev docker-dev-db docker-logs docker-status cache-clear refresh-analysis-snapshots install-dev doctor worktree-setup worktree-prune refresh-fixtures test-ci-scripts verify-gate playwright-stack playwright-stack-down playwright-stack-logs docs-screenshots docs-screenshots-down verify-doc-screenshots _playwright-seed-templates _playwright-seed-users _playwright-seed-docs-data analysis-release-zenodo-package analysis-release-zenodo-upload-draft
Makefile:384:analysis-release-zenodo-package: check-r ## [quality] Package a published analysis-snapshot release into a Zenodo staging dir + tarball
Makefile:386:	@cd $(ROOT_DIR) && $(HOST_RSCRIPT) api/scripts/package-analysis-release-zenodo.R $(ARGS) && \
Makefile:387:		printf "$(GREEN)✓ analysis-release-zenodo-package complete (see outputs/analysis-release-zenodo/latest.env)$(RESET)\n" || \
Makefile:388:		(printf "$(RED)✗ analysis-release-zenodo-package failed$(RESET)\n" && exit 1)
Makefile:390:analysis-release-zenodo-upload-draft: check-r ## [quality] Upload the last-packaged release to a Zenodo DRAFT (never publishes)
Makefile:395:	@if [ ! -f "$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env" ]; then \
Makefile:396:		printf "$(RED)✗ outputs/analysis-release-zenodo/latest.env not found -- run 'make analysis-release-zenodo-package' first$(RESET)\n"; \
Makefile:400:	@MARKER="$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env"; \
Makefile:404:		cd $(ROOT_DIR) && $(HOST_RSCRIPT) api/scripts/upload-analysis-release-zenodo.R \
Makefile:406:		printf "$(GREEN)✓ analysis-release-zenodo-upload-draft complete -- DRAFT only; publishing is a deliberate manual step (see documentation/09-deployment.qmd)$(RESET)\n" || \
Makefile:407:		(printf "$(RED)✗ analysis-release-zenodo-upload-draft failed$(RESET)\n" && exit 1)
api/scripts/package-analysis-release-zenodo.R:2:# api/scripts/package-analysis-release-zenodo.R
api/scripts/package-analysis-release-zenodo.R:7:# `upload-analysis-release-zenodo.R`.
api/scripts/package-analysis-release-zenodo.R:11:# (`analysis_release_zenodo_package()`, which itself guard-sources the
api/scripts/package-analysis-release-zenodo.R:18:#   Rscript api/scripts/package-analysis-release-zenodo.R \
api/scripts/package-analysis-release-zenodo.R:20:#     [--staging-dir outputs/analysis-release-zenodo/staging] \
api/scripts/package-analysis-release-zenodo.R:21:#     [--archive-dir outputs/analysis-release-zenodo/archive] \
api/scripts/package-analysis-release-zenodo.R:43:.package_analysis_release_zenodo_script_dir <- function() {
api/scripts/package-analysis-release-zenodo.R:53:.package_analysis_release_zenodo_script_dir_value <- .package_analysis_release_zenodo_script_dir()
api/scripts/package-analysis-release-zenodo.R:56:    .package_analysis_release_zenodo_script_dir_value, "..", "functions",
api/scripts/package-analysis-release-zenodo.R:71:#' directly (`Rscript package-analysis-release-zenodo.R`), never when
api/scripts/package-analysis-release-zenodo.R:73:#' Write/overwrite the stable `outputs/analysis-release-zenodo/latest.env`
api/scripts/package-analysis-release-zenodo.R:74:#' pointer file the `analysis-release-zenodo-upload-draft` Make target reads
api/scripts/package-analysis-release-zenodo.R:83:.write_package_analysis_release_zenodo_marker <- function(result) {
api/scripts/package-analysis-release-zenodo.R:84:  marker_path <- "outputs/analysis-release-zenodo/latest.env"
api/scripts/package-analysis-release-zenodo.R:98:run_package_analysis_release_zenodo_cli <- function() {
api/scripts/package-analysis-release-zenodo.R:103:  staging_dir <- "outputs/analysis-release-zenodo/staging"
api/scripts/package-analysis-release-zenodo.R:104:  archive_dir <- "outputs/analysis-release-zenodo/archive"
api/scripts/package-analysis-release-zenodo.R:124:    "[package-analysis-release-zenodo] api_base_url=%s release_id=%s staging_dir=%s archive_dir=%s",
api/scripts/package-analysis-release-zenodo.R:128:  result <- analysis_release_zenodo_package(
api/scripts/package-analysis-release-zenodo.R:136:  marker_path <- .write_package_analysis_release_zenodo_marker(result)
api/scripts/package-analysis-release-zenodo.R:145:    "\nNext: make analysis-release-zenodo-upload-draft (or: Rscript api/scripts/upload-analysis-release-zenodo.R --archive %s --metadata %s --release-id %s)\n",
api/scripts/package-analysis-release-zenodo.R:157:if (sys.nframe() == 0L) run_package_analysis_release_zenodo_cli()
api/scripts/upload-analysis-release-zenodo.R:2:# api/scripts/upload-analysis-release-zenodo.R
api/scripts/upload-analysis-release-zenodo.R:5:# (#573; output of `package-analysis-release-zenodo.R`) to a Zenodo
api/scripts/upload-analysis-release-zenodo.R:17:#   Rscript api/scripts/upload-analysis-release-zenodo.R \
api/scripts/upload-analysis-release-zenodo.R:25:# `analysis_release_zenodo_upload()` function still accepts a `token`
api/scripts/upload-analysis-release-zenodo.R:31:# call is made (`analysis_release_zenodo_require_publish_confirmation()`).
api/scripts/upload-analysis-release-zenodo.R:48:# `package-analysis-release-zenodo.R` / `capture-external-fixtures.R`), so it
api/scripts/upload-analysis-release-zenodo.R:58:.upload_analysis_release_zenodo_script_dir <- function() {
api/scripts/upload-analysis-release-zenodo.R:68:.upload_analysis_release_zenodo_script_dir_value <- .upload_analysis_release_zenodo_script_dir()
api/scripts/upload-analysis-release-zenodo.R:71:    .upload_analysis_release_zenodo_script_dir_value, "..", "functions",
api/scripts/upload-analysis-release-zenodo.R:86:#' directly (`Rscript upload-analysis-release-zenodo.R`), never when
api/scripts/upload-analysis-release-zenodo.R:88:run_upload_analysis_release_zenodo_cli <- function() {
api/scripts/upload-analysis-release-zenodo.R:135:  result <- analysis_release_zenodo_upload(
api/scripts/upload-analysis-release-zenodo.R:191:    updated <- analysis_release_zenodo_record_doi(
api/scripts/upload-analysis-release-zenodo.R:209:    cat(analysis_release_zenodo_manual_doi_command(api_base_url, release_id, doi_fields), "\n")
api/scripts/upload-analysis-release-zenodo.R:218:if (sys.nframe() == 0L) run_upload_analysis_release_zenodo_cli()
api/functions/analysis-snapshot-release-zenodo-package.R:7:# (`api/scripts/package-analysis-release-zenodo.R`) sources this file
api/functions/analysis-snapshot-release-zenodo-package.R:26:# (the `.analysis_release_zenodo_http_*` seams below), so unit tests inject
api/functions/analysis-snapshot-release-zenodo-package.R:49:if (!exists(".analysis_release_zenodo_docs_loaded", mode = "logical")) {
api/functions/analysis-snapshot-release-zenodo-package.R:53:  .analysis_release_zenodo_self_dir <- local({
api/functions/analysis-snapshot-release-zenodo-package.R:57:  .analysis_release_zenodo_docs_candidates <- c(
api/functions/analysis-snapshot-release-zenodo-package.R:58:    if (!is.null(.analysis_release_zenodo_self_dir)) {
api/functions/analysis-snapshot-release-zenodo-package.R:59:      file.path(.analysis_release_zenodo_self_dir, "analysis-snapshot-release-zenodo-docs.R")
api/functions/analysis-snapshot-release-zenodo-package.R:64:  for (.analysis_release_zenodo_docs_path in .analysis_release_zenodo_docs_candidates) {
api/functions/analysis-snapshot-release-zenodo-package.R:65:    if (file.exists(.analysis_release_zenodo_docs_path)) {
api/functions/analysis-snapshot-release-zenodo-package.R:73:      source(.analysis_release_zenodo_docs_path, local = TRUE)
api/functions/analysis-snapshot-release-zenodo-package.R:77:  rm(.analysis_release_zenodo_self_dir, .analysis_release_zenodo_docs_candidates, .analysis_release_zenodo_docs_path)
api/functions/analysis-snapshot-release-zenodo-package.R:80:if (!exists(".analysis_release_zenodo_verify_loaded", mode = "logical")) {
api/functions/analysis-snapshot-release-zenodo-package.R:83:  .analysis_release_zenodo_self_dir <- local({
api/functions/analysis-snapshot-release-zenodo-package.R:87:  .analysis_release_zenodo_verify_candidates <- c(
api/functions/analysis-snapshot-release-zenodo-package.R:88:    if (!is.null(.analysis_release_zenodo_self_dir)) {
api/functions/analysis-snapshot-release-zenodo-package.R:89:      file.path(.analysis_release_zenodo_self_dir, "analysis-snapshot-release-zenodo-verify.R")
api/functions/analysis-snapshot-release-zenodo-package.R:94:  for (.analysis_release_zenodo_verify_path in .analysis_release_zenodo_verify_candidates) {
api/functions/analysis-snapshot-release-zenodo-package.R:95:    if (file.exists(.analysis_release_zenodo_verify_path)) {
api/functions/analysis-snapshot-release-zenodo-package.R:97:      source(.analysis_release_zenodo_verify_path, local = TRUE)
api/functions/analysis-snapshot-release-zenodo-package.R:102:    .analysis_release_zenodo_self_dir, .analysis_release_zenodo_verify_candidates,
api/functions/analysis-snapshot-release-zenodo-package.R:103:    .analysis_release_zenodo_verify_path
api/functions/analysis-snapshot-release-zenodo-package.R:111:.analysis_release_zenodo_created_at_date <- function(created_at) {
api/functions/analysis-snapshot-release-zenodo-package.R:124:#' @param head The release head (from `analysis_release_zenodo_fetch_head()`).
api/functions/analysis-snapshot-release-zenodo-package.R:128:analysis_release_zenodo_build_metadata <- function(head, version = NULL, license_id = NULL) {
api/functions/analysis-snapshot-release-zenodo-package.R:130:  release_date <- .analysis_release_zenodo_created_at_date(head$created_at)
api/functions/analysis-snapshot-release-zenodo-package.R:172:analysis_release_zenodo_build_datapackage <- function(staging_dir, name, version, release_id) {
api/functions/analysis-snapshot-release-zenodo-package.R:173:  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R:202:.analysis_release_zenodo_write_text <- function(path, content) {
api/functions/analysis-snapshot-release-zenodo-package.R:213:analysis_release_zenodo_write_checksums <- function(staging_dir) {
api/functions/analysis-snapshot-release-zenodo-package.R:214:  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R:228:  .analysis_release_zenodo_write_text(out_path, content)
api/functions/analysis-snapshot-release-zenodo-package.R:238:# `test-unit-analysis-release-zenodo-package.R`'s "packaging the SAME staged
api/functions/analysis-snapshot-release-zenodo-package.R:245:.analysis_release_zenodo_normalize_mtimes <- function(staging_dir) {
api/functions/analysis-snapshot-release-zenodo-package.R:265:analysis_release_zenodo_make_tarball <- function(staging_dir, archive_path) {
api/functions/analysis-snapshot-release-zenodo-package.R:274:  .analysis_release_zenodo_normalize_mtimes(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R:276:  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R:300:.analysis_release_zenodo_sort_keys <- function(x) {
api/functions/analysis-snapshot-release-zenodo-package.R:306:    x <- lapply(x, .analysis_release_zenodo_sort_keys)
api/functions/analysis-snapshot-release-zenodo-package.R:311:.analysis_release_zenodo_copy_tree <- function(src_dir, dest_dir) {
api/functions/analysis-snapshot-release-zenodo-package.R:328:analysis_release_zenodo_package <- function(
api/functions/analysis-snapshot-release-zenodo-package.R:335:    http_get_json = .analysis_release_zenodo_http_get_json,
api/functions/analysis-snapshot-release-zenodo-package.R:336:    http_download = .analysis_release_zenodo_http_download) {
api/functions/analysis-snapshot-release-zenodo-package.R:337:  head <- analysis_release_zenodo_fetch_head(api_base_url, release_id, http_get_json = http_get_json)
api/functions/analysis-snapshot-release-zenodo-package.R:344:  .analysis_release_zenodo_assert_valid_release_id(resolved_release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-package.R:348:  analysis_release_zenodo_download_bundle(
api/functions/analysis-snapshot-release-zenodo-package.R:351:  extracted_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, head$bundle_sha256)
api/functions/analysis-snapshot-release-zenodo-package.R:358:  .analysis_release_zenodo_assert_staging_deletable(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R:363:  .analysis_release_zenodo_write_staging_sentinel(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R:366:  .analysis_release_zenodo_copy_tree(extracted_dir, nested_dir)
api/functions/analysis-snapshot-release-zenodo-package.R:372:  .analysis_release_zenodo_write_text(
api/functions/analysis-snapshot-release-zenodo-package.R:373:    file.path(staging_dir, "README.md"), analysis_release_zenodo_build_readme(head, doi)
api/functions/analysis-snapshot-release-zenodo-package.R:375:  .analysis_release_zenodo_write_text(
api/functions/analysis-snapshot-release-zenodo-package.R:376:    file.path(staging_dir, "DATA_CARD.md"), analysis_release_zenodo_build_data_card(head)
api/functions/analysis-snapshot-release-zenodo-package.R:378:  .analysis_release_zenodo_write_text(
api/functions/analysis-snapshot-release-zenodo-package.R:379:    file.path(staging_dir, "SCHEMA.md"), analysis_release_zenodo_build_schema_doc(head)
api/functions/analysis-snapshot-release-zenodo-package.R:381:  .analysis_release_zenodo_write_text(
api/functions/analysis-snapshot-release-zenodo-package.R:383:    analysis_release_zenodo_build_changelog(head, resolved_version)
api/functions/analysis-snapshot-release-zenodo-package.R:385:  .analysis_release_zenodo_write_text(
api/functions/analysis-snapshot-release-zenodo-package.R:387:    analysis_release_zenodo_build_citation_cff(head, resolved_version, doi)
api/functions/analysis-snapshot-release-zenodo-package.R:390:  metadata <- analysis_release_zenodo_build_metadata(head, version = resolved_version)
api/functions/analysis-snapshot-release-zenodo-package.R:392:    .analysis_release_zenodo_sort_keys(metadata), auto_unbox = TRUE, pretty = TRUE, null = "null"
api/functions/analysis-snapshot-release-zenodo-package.R:395:  .analysis_release_zenodo_write_text(zenodo_metadata_path, paste0(as.character(metadata_json), "\n"))
api/functions/analysis-snapshot-release-zenodo-package.R:397:  datapackage <- analysis_release_zenodo_build_datapackage(
api/functions/analysis-snapshot-release-zenodo-package.R:404:  .analysis_release_zenodo_write_text(
api/functions/analysis-snapshot-release-zenodo-package.R:408:  analysis_release_zenodo_write_checksums(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R:410:  analysis_release_zenodo_validate_staging(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R:413:  tar_result <- analysis_release_zenodo_make_tarball(staging_dir, archive_path)
api/functions/analysis-snapshot-release-zenodo-verify.R:23:.analysis_release_zenodo_verify_loaded <- TRUE
api/functions/analysis-snapshot-release-zenodo-verify.R:54:# after creating it. `analysis_release_zenodo_package()` refuses to
api/functions/analysis-snapshot-release-zenodo-verify.R:56:# carries this sentinel -- see `.analysis_release_zenodo_staging_owned_by_tool()`.
api/functions/analysis-snapshot-release-zenodo-verify.R:57:.ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL <- ".analysis-release-zenodo-staging"
api/functions/analysis-snapshot-release-zenodo-verify.R:73:#' `analysis_release_zenodo_fetch_head()`) and (b) the RESOLVED id the API
api/functions/analysis-snapshot-release-zenodo-verify.R:75:#' `analysis_release_zenodo_package()`) -- defense-in-depth, since the
api/functions/analysis-snapshot-release-zenodo-verify.R:82:.analysis_release_zenodo_assert_valid_release_id <- function(release_id, allow_latest = FALSE) {
api/functions/analysis-snapshot-release-zenodo-verify.R:101:.analysis_release_zenodo_http_get_json <- function(url) {
api/functions/analysis-snapshot-release-zenodo-verify.R:113:.analysis_release_zenodo_http_download <- function(url, destfile) {
api/functions/analysis-snapshot-release-zenodo-verify.R:125:#'   Validated via `.analysis_release_zenodo_assert_valid_release_id()`
api/functions/analysis-snapshot-release-zenodo-verify.R:130:analysis_release_zenodo_fetch_head <- function(
api/functions/analysis-snapshot-release-zenodo-verify.R:133:    http_get_json = .analysis_release_zenodo_http_get_json) {
api/functions/analysis-snapshot-release-zenodo-verify.R:136:  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = TRUE)
api/functions/analysis-snapshot-release-zenodo-verify.R:145:#'   via `analysis_release_zenodo_fetch_head()` first).
api/functions/analysis-snapshot-release-zenodo-verify.R:148:analysis_release_zenodo_download_bundle <- function(
api/functions/analysis-snapshot-release-zenodo-verify.R:152:    http_download = .analysis_release_zenodo_http_download) {
api/functions/analysis-snapshot-release-zenodo-verify.R:173:.analysis_release_zenodo_assert_no_traversal <- function(paths, context) {
api/functions/analysis-snapshot-release-zenodo-verify.R:205:analysis_release_zenodo_extract_and_verify <- function(
api/functions/analysis-snapshot-release-zenodo-verify.R:220:  .analysis_release_zenodo_assert_no_traversal(tar_entries, context = "tar member")
api/functions/analysis-snapshot-release-zenodo-verify.R:224:      tempdir(), paste0("analysis_release_zenodo_extract_", as.integer(stats::runif(1, 1, 1e9)))
api/functions/analysis-snapshot-release-zenodo-verify.R:242:    .analysis_release_zenodo_assert_no_traversal(rel_name, context = "checksums.sha256 entry")
api/functions/analysis-snapshot-release-zenodo-verify.R:286:.analysis_release_zenodo_iter_public_files <- function(root_dir) {
api/functions/analysis-snapshot-release-zenodo-verify.R:314:.analysis_release_zenodo_staging_owned_by_tool <- function(staging_dir) {
api/functions/analysis-snapshot-release-zenodo-verify.R:326:#' recursively delete (see `.analysis_release_zenodo_staging_owned_by_tool()`).
api/functions/analysis-snapshot-release-zenodo-verify.R:327:.analysis_release_zenodo_assert_staging_deletable <- function(staging_dir) {
api/functions/analysis-snapshot-release-zenodo-verify.R:328:  if (!.analysis_release_zenodo_staging_owned_by_tool(staging_dir)) {
api/functions/analysis-snapshot-release-zenodo-verify.R:344:.analysis_release_zenodo_write_staging_sentinel <- function(staging_dir) {
api/functions/analysis-snapshot-release-zenodo-verify.R:347:      "This directory is owned by package-analysis-release-zenodo.R and is ",
api/functions/analysis-snapshot-release-zenodo-verify.R:361:.analysis_release_zenodo_validate_no_forbidden <- function(staging_dir) {
api/functions/analysis-snapshot-release-zenodo-verify.R:391:.analysis_release_zenodo_validate_no_symlinks <- function(staging_dir) {
api/functions/analysis-snapshot-release-zenodo-verify.R:411:.analysis_release_zenodo_has_allowed_suffix <- function(rel_path) {
api/functions/analysis-snapshot-release-zenodo-verify.R:424:.analysis_release_zenodo_validate_allowed_suffix <- function(staging_dir) {
api/functions/analysis-snapshot-release-zenodo-verify.R:425:  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
api/functions/analysis-snapshot-release-zenodo-verify.R:427:    function(rel_path) !.analysis_release_zenodo_has_allowed_suffix(rel_path), rel_paths
api/functions/analysis-snapshot-release-zenodo-verify.R:438:.analysis_release_zenodo_validate_no_sensitive_text <- function(staging_dir) {
api/functions/analysis-snapshot-release-zenodo-verify.R:440:  for (rel_path in .analysis_release_zenodo_iter_public_files(staging_dir)) {
api/functions/analysis-snapshot-release-zenodo-verify.R:441:    if (!.analysis_release_zenodo_has_allowed_suffix(rel_path)) {
api/functions/analysis-snapshot-release-zenodo-verify.R:461:.analysis_release_zenodo_validate_layout <- function(staging_dir) {
api/functions/analysis-snapshot-release-zenodo-verify.R:480:analysis_release_zenodo_validate_staging <- function(staging_dir) {
api/functions/analysis-snapshot-release-zenodo-verify.R:481:  .analysis_release_zenodo_validate_no_forbidden(staging_dir)
api/functions/analysis-snapshot-release-zenodo-verify.R:482:  .analysis_release_zenodo_validate_no_symlinks(staging_dir)
api/functions/analysis-snapshot-release-zenodo-verify.R:483:  .analysis_release_zenodo_validate_allowed_suffix(staging_dir)
api/functions/analysis-snapshot-release-zenodo-verify.R:484:  .analysis_release_zenodo_validate_no_sensitive_text(staging_dir)
api/functions/analysis-snapshot-release-zenodo-verify.R:485:  .analysis_release_zenodo_validate_layout(staging_dir)
api/functions/analysis-snapshot-release-zenodo-upload.R:9:# (`api/scripts/upload-analysis-release-zenodo.R`) sources this file
api/functions/analysis-snapshot-release-zenodo-upload.R:17:# default (the `.analysis_release_zenodo_http_*` functions below), so unit
api/functions/analysis-snapshot-release-zenodo-upload.R:25:# Publish is DOUBLE-gated: `analysis_release_zenodo_require_publish_confirmation()`
api/functions/analysis-snapshot-release-zenodo-upload.R:48:analysis_release_zenodo_resolve_api <- function(sandbox = FALSE) {
api/functions/analysis-snapshot-release-zenodo-upload.R:60:analysis_release_zenodo_require_publish_confirmation <- function(publish, confirm_publish) {
api/functions/analysis-snapshot-release-zenodo-upload.R:80:.analysis_release_zenodo_http_json <- function(method, url, token, body = NULL) {
api/functions/analysis-snapshot-release-zenodo-upload.R:101:.analysis_release_zenodo_http_put_file <- function(url, token, archive_path) {
api/functions/analysis-snapshot-release-zenodo-upload.R:121:analysis_release_zenodo_get_or_create_deposition <- function(
api/functions/analysis-snapshot-release-zenodo-upload.R:122:    api, token, deposition_id = NULL, http = .analysis_release_zenodo_http_json) {
api/functions/analysis-snapshot-release-zenodo-upload.R:136:analysis_release_zenodo_set_metadata <- function(
api/functions/analysis-snapshot-release-zenodo-upload.R:137:    api, token, deposition_id, metadata, http = .analysis_release_zenodo_http_json) {
api/functions/analysis-snapshot-release-zenodo-upload.R:150:analysis_release_zenodo_upload_bucket <- function(
api/functions/analysis-snapshot-release-zenodo-upload.R:151:    bucket_url, token, archive_path, put = .analysis_release_zenodo_http_put_file) {
api/functions/analysis-snapshot-release-zenodo-upload.R:163:analysis_release_zenodo_publish_deposition <- function(
api/functions/analysis-snapshot-release-zenodo-upload.R:164:    api, token, deposition_id, http = .analysis_release_zenodo_http_json) {
api/functions/analysis-snapshot-release-zenodo-upload.R:174:# invokes `analysis_release_zenodo_record_doi()` when the operator passes
api/functions/analysis-snapshot-release-zenodo-upload.R:176:# `analysis_release_zenodo_manual_doi_command()` so the operator can record
api/functions/analysis-snapshot-release-zenodo-upload.R:191:.analysis_release_zenodo_doi_non_empty_fields <- function(doi_fields) {
api/functions/analysis-snapshot-release-zenodo-upload.R:216:analysis_release_zenodo_record_doi <- function(
api/functions/analysis-snapshot-release-zenodo-upload.R:218:    patch = .analysis_release_zenodo_http_json) {
api/functions/analysis-snapshot-release-zenodo-upload.R:222:  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
api/functions/analysis-snapshot-release-zenodo-upload.R:229:analysis_release_zenodo_manual_doi_command <- function(sysndd_api_base_url, release_id, doi_fields) {
api/functions/analysis-snapshot-release-zenodo-upload.R:233:  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
api/functions/analysis-snapshot-release-zenodo-upload.R:246:# SysNDD: it never calls `analysis_release_zenodo_record_doi()` itself (the
api/functions/analysis-snapshot-release-zenodo-upload.R:253:#' `analysis_release_zenodo_require_publish_confirmation()`).
api/functions/analysis-snapshot-release-zenodo-upload.R:258:analysis_release_zenodo_upload <- function(
api/functions/analysis-snapshot-release-zenodo-upload.R:266:    get_or_create_deposition = analysis_release_zenodo_get_or_create_deposition,
api/functions/analysis-snapshot-release-zenodo-upload.R:267:    set_metadata = analysis_release_zenodo_set_metadata,
api/functions/analysis-snapshot-release-zenodo-upload.R:268:    upload_bucket = analysis_release_zenodo_upload_bucket,
api/functions/analysis-snapshot-release-zenodo-upload.R:269:    publish_deposition = analysis_release_zenodo_publish_deposition) {
api/functions/analysis-snapshot-release-zenodo-upload.R:270:  analysis_release_zenodo_require_publish_confirmation(publish, confirm_publish)
api/functions/analysis-snapshot-release-zenodo-upload.R:286:  api <- analysis_release_zenodo_resolve_api(sandbox)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:11:# `test-unit-analysis-release-zenodo-package.R`'s sourcing.
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:102:    analysis_release_zenodo_fetch_head("http://localhost:7778", "../evil", http_get_json = stub_get_json),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:115:    analysis_release_zenodo_fetch_head(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:130:    analysis_release_zenodo_fetch_head(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:141:    analysis_release_zenodo_fetch_head("http://localhost:7778", "ASR_DEADBEEFCAFEBABE", http_get_json = stub_get_json),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:145:    analysis_release_zenodo_fetch_head("http://localhost:7778", "asr_short", http_get_json = stub_get_json),
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:153:    analysis_release_zenodo_fetch_head("http://localhost:7778", "latest", http_get_json = stub_get_json)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:156:    analysis_release_zenodo_fetch_head(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:172:  head <- analysis_release_zenodo_fetch_head("http://localhost:7778", "latest", http_get_json = stub_get_json)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:183:  head <- analysis_release_zenodo_fetch_head(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:199:  result <- analysis_release_zenodo_download_bundle(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:215:    analysis_release_zenodo_download_bundle(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:232:  result_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, expected_sha, exdir = exdir)
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:246:    analysis_release_zenodo_extract_and_verify(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:258:    analysis_release_zenodo_extract_and_verify(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:271:    analysis_release_zenodo_extract_and_verify(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:286:    analysis_release_zenodo_extract_and_verify(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:306:    analysis_release_zenodo_extract_and_verify(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:319:  expect_no_error(analysis_release_zenodo_validate_staging(staging))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:325:  expect_error(analysis_release_zenodo_validate_staging(staging), "private files")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:331:  expect_error(analysis_release_zenodo_validate_staging(staging), "private files")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:337:  expect_error(analysis_release_zenodo_validate_staging(staging), "sensitive")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:343:  expect_error(analysis_release_zenodo_validate_staging(staging), "sensitive")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:349:  expect_error(analysis_release_zenodo_validate_staging(staging), "missing")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:355:  expect_error(analysis_release_zenodo_validate_staging(staging), "missing")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:361:  expect_error(analysis_release_zenodo_validate_staging(staging), "unexpected type/suffix")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:367:  expect_error(analysis_release_zenodo_validate_staging(staging), "unexpected type/suffix")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:373:  expect_error(analysis_release_zenodo_validate_staging(staging), "unexpected type/suffix")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:385:  expect_error(analysis_release_zenodo_validate_staging(staging), "symlinks")
api/functions/analysis-snapshot-release-zenodo-docs.R:16:# Depends on `%||%` and `.analysis_release_zenodo_created_at_date()`, both
api/functions/analysis-snapshot-release-zenodo-docs.R:22:.analysis_release_zenodo_docs_loaded <- TRUE
api/functions/analysis-snapshot-release-zenodo-docs.R:25:analysis_release_zenodo_build_readme <- function(head, doi = NULL) {
api/functions/analysis-snapshot-release-zenodo-docs.R:51:analysis_release_zenodo_build_data_card <- function(head) {
api/functions/analysis-snapshot-release-zenodo-docs.R:92:analysis_release_zenodo_build_schema_doc <- function(head) {
api/functions/analysis-snapshot-release-zenodo-docs.R:115:analysis_release_zenodo_build_changelog <- function(head, version) {
api/functions/analysis-snapshot-release-zenodo-docs.R:118:  release_date <- .analysis_release_zenodo_created_at_date(head$created_at)
api/functions/analysis-snapshot-release-zenodo-docs.R:133:analysis_release_zenodo_build_citation_cff <- function(head, version, doi = NULL) {
api/functions/analysis-snapshot-release-zenodo-docs.R:136:  release_date <- .analysis_release_zenodo_created_at_date(head$created_at)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:13:# (`analysis_release_zenodo_fetch_head`, `_download_bundle`,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:17:# `test-unit-analysis-release-zenodo-verify.R`; this file covers the
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:18:# builders, checksums/tarball, and the `analysis_release_zenodo_package()`
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:29:# that need `analysis_release_zenodo_package()` to reach its staging/tar
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:32:# see the shared cleanup-timing note in `test-unit-analysis-release-zenodo-
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:82:  metadata <- analysis_release_zenodo_build_metadata(head)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:99:  metadata <- analysis_release_zenodo_build_metadata(head)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:105:  metadata <- analysis_release_zenodo_build_metadata(head)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:112:  metadata <- analysis_release_zenodo_build_metadata(head, version = "9.9.9", license_id = "cc0-1.0")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:129:  dp <- analysis_release_zenodo_build_datapackage(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:166:  out_path <- analysis_release_zenodo_write_checksums(staging)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:182:  analysis_release_zenodo_write_checksums(staging)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:197:  result <- analysis_release_zenodo_make_tarball(staging, archive_path)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:234:  result1 <- analysis_release_zenodo_make_tarball(root, file.path(archive_dir, "run1.tar.gz"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:240:  result2 <- analysis_release_zenodo_make_tarball(root, file.path(archive_dir, "run2.tar.gz"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:258:  result <- analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:296:    analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:319:    analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:346:    analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:370:  result <- analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:388:  result1 <- analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:402:  result2 <- analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:21:    analysis_release_zenodo_require_publish_confirmation(TRUE, FALSE),
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:27:  expect_no_error(analysis_release_zenodo_require_publish_confirmation(FALSE, FALSE))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:31:  expect_no_error(analysis_release_zenodo_require_publish_confirmation(TRUE, TRUE))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:39:  expect_identical(analysis_release_zenodo_resolve_api(TRUE), "https://sandbox.zenodo.org/api")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:40:  expect_identical(analysis_release_zenodo_resolve_api(FALSE), "https://zenodo.org/api")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:41:  expect_identical(analysis_release_zenodo_resolve_api(), "https://zenodo.org/api")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:59:  result <- analysis_release_zenodo_upload_bucket(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:75:  analysis_release_zenodo_upload_bucket("https://zenodo.example/bucket/", "token", archive, put = stub_put)

codex
I found two end-to-end gaps that the focused unit tests do not cover: an input-bundle symlink can be dereferenced before the staging validator sees it, and the separate upload/DOI path accepts an unvalidated release ID when it prints its manual command. I’m finishing the severity pass and checking the locked publish/record-back semantics.
exec
/bin/bash -lc "nl -ba api/endpoints/admin_analysis_snapshot_endpoints.R | sed -n '240,355p'
nl -ba api/scripts/upload-analysis-release-zenodo.R | sed -n '145,220p'
nl -ba Makefile | sed -n '378,412p'
nl -ba api/functions/analysis-snapshot-release-zenodo-verify.R | sed -n '163,272p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
   145	  cat(sprintf("Zenodo deposition id: %s\n", result$deposition_id))
   146	  cat(sprintf(
   147	    "Zenodo reserved DOI:  %s\n",
   148	    if (is.na(result$reserved_doi)) "not returned" else result$reserved_doi
   149	  ))
   150	  cat(sprintf(
   151	    "Zenodo draft URL:     %s\n",
   152	    if (is.na(result$draft_url)) "not returned" else result$draft_url
   153	  ))
   154
   155	  if (isTRUE(result$published)) {
   156	    cat(sprintf("Published Zenodo DOI: %s\n", result$version_doi))
   157	    cat(sprintf("Published Zenodo URL: %s\n", result$record_url))
   158	  } else {
   159	    cat("Draft uploaded only. Review in Zenodo before publishing.\n")
   160	  }
   161
   162	  .print_doi_record_back(result, release_id, api_base_url, record_doi)
   163
   164	  invisible(result)
   165	}
   166
   167	#' The opt-in DOI record-back step. Never calls the SysNDD admin endpoint
   168	#' unless the operator explicitly asked for it (`--record-doi`) AND supplied
   169	#' credentials (`SYSNDD_ADMIN_TOKEN`) AND the run reached a real, published
   170	#' DOI -- a draft's "reserved" DOI is not final and is deliberately NOT
   171	#' recorded automatically. Otherwise prints the exact manual command.
   172	.print_doi_record_back <- function(result, release_id, api_base_url, record_doi) {
   173	  doi_fields <- list(
   174	    zenodo_record_id = as.character(result$deposition_id),
   175	    zenodo_record_url = if (isTRUE(result$published)) result$record_url else result$draft_url,
   176	    version_doi = if (isTRUE(result$published)) result$version_doi else NA_character_,
   177	    concept_doi = if (isTRUE(result$published)) result$concept_doi else NA_character_
   178	  )
   179
   180	  have_release_id <- !is.null(release_id) && nzchar(release_id)
   181	  have_published_doi <- isTRUE(result$published) &&
   182	    !is.na(result$version_doi) && nzchar(as.character(result$version_doi))
   183	  admin_token <- Sys.getenv("SYSNDD_ADMIN_TOKEN", "")
   184
   185	  if (!have_release_id) {
   186	    cat("\nNo --release-id supplied -- pass one to record or print a DOI record-back command.\n")
   187	    return(invisible(NULL))
   188	  }
   189
   190	  if (isTRUE(record_doi) && nzchar(admin_token) && have_published_doi) {
   191	    updated <- analysis_release_zenodo_record_doi(
   192	      sysndd_api_base_url = api_base_url,
   193	      admin_token = admin_token,
   194	      release_id = release_id,
   195	      doi_fields = doi_fields
   196	    )
   197	    cat("\nDOI recorded on the SysNDD release head:\n")
   198	    cat(sprintf("  release_id:        %s\n", updated$release_id %||% release_id))
   199	    cat(sprintf("  version_doi:       %s\n", updated$version_doi %||% doi_fields$version_doi))
   200	    cat(sprintf("  zenodo_record_url: %s\n", updated$zenodo_record_url %||% doi_fields$zenodo_record_url))
   201	  } else {
   202	    cat(
   203	      "\nDOI not recorded automatically",
   204	      if (!have_published_doi) " (deposition not published yet)" else "",
   205	      ". Run with --record-doi and SYSNDD_ADMIN_TOKEN set after publishing, ",
   206	      "or record it by hand:\n",
   207	      sep = ""
   208	    )
   209	    cat(analysis_release_zenodo_manual_doi_command(api_base_url, release_id, doi_fields), "\n")
   210	  }
   211	  invisible(NULL)
   212	}
   213
   214	# Main guard: `sys.nframe()` is 0 only at the true top level of a directly
   215	# `Rscript`-invoked file; a `source()`d file (e.g. from a test) always adds
   216	# at least one frame, so this line never fires under `source()`. This check
   217	# MUST stay at top level (not inside a function).
   218	if (sys.nframe() == 0L) run_upload_analysis_release_zenodo_cli()
   378	# ARGS/UPLOAD_ARGS are passed through to the analysis-release Zenodo operator
   379	# scripts below (e.g. ARGS="--release-id asr_..." or UPLOAD_ARGS="--sandbox");
   380	# default empty so --warn-undefined-variables stays quiet.
   381	ARGS ?=
   382	UPLOAD_ARGS ?=
   383
   384	analysis-release-zenodo-package: check-r ## [quality] Package a published analysis-snapshot release into a Zenodo staging dir + tarball
   385		@printf "$(CYAN)==> Packaging analysis-snapshot release for Zenodo...$(RESET)\n"
   386		@cd $(ROOT_DIR) && $(HOST_RSCRIPT) api/scripts/package-analysis-release-zenodo.R $(ARGS) && \
   387			printf "$(GREEN)✓ analysis-release-zenodo-package complete (see outputs/analysis-release-zenodo/latest.env)$(RESET)\n" || \
   388			(printf "$(RED)✗ analysis-release-zenodo-package failed$(RESET)\n" && exit 1)
   389
   390	analysis-release-zenodo-upload-draft: check-r ## [quality] Upload the last-packaged release to a Zenodo DRAFT (never publishes)
   391		@if [ -z "$${ZENODO_TOKEN:-}" ]; then \
   392			printf "$(RED)✗ ZENODO_TOKEN is not set (export it in your shell or .env before running this target)$(RESET)\n"; \
   393			exit 1; \
   394		fi
   395		@if [ ! -f "$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env" ]; then \
   396			printf "$(RED)✗ outputs/analysis-release-zenodo/latest.env not found -- run 'make analysis-release-zenodo-package' first$(RESET)\n"; \
   397			exit 1; \
   398		fi
   399		@printf "$(CYAN)==> Uploading last-packaged analysis-snapshot release to a Zenodo DRAFT (never publishes)...$(RESET)\n"
   400		@MARKER="$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env"; \
   401			ARCHIVE_PATH="$$(sed -n 's/^ARCHIVE_PATH=//p' "$$MARKER" | tail -n1)"; \
   402			METADATA_PATH="$$(sed -n 's/^METADATA_PATH=//p' "$$MARKER" | tail -n1)"; \
   403			RELEASE_ID="$$(sed -n 's/^RELEASE_ID=//p' "$$MARKER" | tail -n1)"; \
   404			cd $(ROOT_DIR) && $(HOST_RSCRIPT) api/scripts/upload-analysis-release-zenodo.R \
   405				--archive "$$ARCHIVE_PATH" --metadata "$$METADATA_PATH" --release-id "$$RELEASE_ID" $(UPLOAD_ARGS) && \
   406			printf "$(GREEN)✓ analysis-release-zenodo-upload-draft complete -- DRAFT only; publishing is a deliberate manual step (see documentation/09-deployment.qmd)$(RESET)\n" || \
   407			(printf "$(RED)✗ analysis-release-zenodo-upload-draft failed$(RESET)\n" && exit 1)
   408
   409	# =============================================================================
   410	# Docker Targets
   411	# =============================================================================
   412	# Compose file sets:
   163	# --------------------------------------------------------------------------- #
   164	# Path-traversal guard, shared by both the tar-member listing and the inner
   165	# `checksums.sha256` entries (item 4).
   166	# --------------------------------------------------------------------------- #
   167
   168	#' Stop if any `paths` entry is absolute (POSIX `/...` or a Windows drive
   169	#' letter) or contains a `..` path segment. Used on BOTH the tar member list
   170	#' (before extraction) and every `checksums.sha256` entry (before it is
   171	#' resolved to a file under `exdir`) -- a tampered bundle cannot escape the
   172	#' extraction directory via either vector.
   173	.analysis_release_zenodo_assert_no_traversal <- function(paths, context) {
   174	  offenders <- Filter(function(p) {
   175	    startsWith(p, "/") || grepl("^[A-Za-z]:", p) ||
   176	      any(strsplit(p, "/", fixed = TRUE)[[1]] == "..")
   177	  }, paths)
   178	  if (length(offenders) > 0) {
   179	    stop(sprintf(
   180	      "%s path traversal rejected: %s", context, paste(offenders, collapse = ", ")
   181	    ), call. = FALSE)
   182	  }
   183	  invisible(TRUE)
   184	}
   185
   186	#' Verify a downloaded bundle against the release head's `bundle_sha256`,
   187	#' extract it, then verify the bundle's OWN inner `checksums.sha256` against
   188	#' every extracted file. Mirrors `nddscore_extract_and_verify()`'s verify
   189	#' loop, but the outer digest is SHA-256 (not MD5), and the release bundle's
   190	#' files sit directly at the archive root (no named top-level subdirectory
   191	#' to search for).
   192	#'
   193	#' Hardening (item 4): (1) every tar member path and every `checksums.sha256`
   194	#' entry is rejected if absolute or containing a `..` segment, BEFORE it is
   195	#' ever joined onto `exdir`; (2) after the existing per-line checksum
   196	#' verification, COVERAGE is asserted -- every extracted regular file except
   197	#' `checksums.sha256` itself must appear EXACTLY ONCE in the checksums list,
   198	#' so a tampered bundle that drops a checksum line for a present file (or
   199	#' lists the same path twice) fails loudly instead of silently passing.
   200	#'
   201	#' @param bundle_path Path to the downloaded `bundle.tar.gz`.
   202	#' @param expected_bundle_sha256 The release head's `bundle_sha256`.
   203	#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
   204	#' @return Path to the extraction directory (== `exdir`).
   205	analysis_release_zenodo_extract_and_verify <- function(
   206	    bundle_path, expected_bundle_sha256, exdir = NULL) {
   207	  if (!file.exists(bundle_path)) {
   208	    stop("Analysis-snapshot release bundle not found for verification", call. = FALSE)
   209	  }
   210	  actual_bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
   211	  expected <- tolower(as.character(expected_bundle_sha256 %||% "")[[1]])
   212	  if (!identical(tolower(actual_bundle_sha256), expected)) {
   213	    stop(sprintf(
   214	      "Analysis-snapshot release bundle checksum mismatch (expected %s, got %s)",
   215	      expected, actual_bundle_sha256
   216	    ), call. = FALSE)
   217	  }
   218
   219	  tar_entries <- utils::untar(bundle_path, list = TRUE)
   220	  .analysis_release_zenodo_assert_no_traversal(tar_entries, context = "tar member")
   221
   222	  if (is.null(exdir)) {
   223	    exdir <- file.path(
   224	      tempdir(), paste0("analysis_release_zenodo_extract_", as.integer(stats::runif(1, 1, 1e9)))
   225	    )
   226	  }
   227	  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
   228	  utils::untar(bundle_path, exdir = exdir)
   229
   230	  sha_file <- file.path(exdir, "checksums.sha256")
   231	  if (!file.exists(sha_file)) {
   232	    stop("Extracted release bundle has no checksums.sha256", call. = FALSE)
   233	  }
   234	  sha_lines <- readLines(sha_file, warn = FALSE)
   235	  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
   236
   237	  checksummed_paths <- character(0)
   238	  for (line in sha_lines) {
   239	    parts <- strsplit(trimws(line), "\\s+")[[1]]
   240	    expected_sha <- parts[[1]]
   241	    rel_name <- parts[[length(parts)]]
   242	    .analysis_release_zenodo_assert_no_traversal(rel_name, context = "checksums.sha256 entry")
   243	    target <- file.path(exdir, rel_name)
   244	    if (!file.exists(target)) {
   245	      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name), call. = FALSE)
   246	    }
   247	    actual_sha <- digest::digest(file = target, algo = "sha256")
   248	    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
   249	      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name), call. = FALSE)
   250	    }
   251	    checksummed_paths <- c(checksummed_paths, rel_name)
   252	  }
   253
   254	  duplicate_entries <- unique(checksummed_paths[duplicated(checksummed_paths)])
   255	  if (length(duplicate_entries) > 0) {
   256	    stop(sprintf(
   257	      "checksums.sha256 lists duplicate entries: %s", paste(duplicate_entries, collapse = ", ")
   258	    ), call. = FALSE)
   259	  }
   260
   261	  extracted_files <- list.files(exdir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
   262	  extracted_files <- extracted_files[extracted_files != "checksums.sha256"]
   263	  uncovered <- base::setdiff(extracted_files, checksummed_paths)
   264	  if (length(uncovered) > 0) {
   265	    stop(sprintf(
   266	      "Extracted release bundle contains file(s) not listed in checksums.sha256: %s",
   267	      paste(sort(uncovered), collapse = ", ")
   268	    ), call. = FALSE)
   269	  }
   270
   271	  exdir
   272	}

exec
/bin/bash -lc "rg -n -C 4 \"svc_release_set_doi|set_doi\" api/services/analysis-snapshot-release-service.R api/functions/analysis-snapshot-release-repository.R api/tests/testthat | head -n 180 && git diff --check origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
api/functions/analysis-snapshot-release-repository.R-448-#' @param doi_fields Named list, any subset of `zenodo_record_id`,
api/functions/analysis-snapshot-release-repository.R-449-#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
api/functions/analysis-snapshot-release-repository.R-450-#' @return logical(1), TRUE iff a row was updated.
api/functions/analysis-snapshot-release-repository.R-451-#' @export
api/functions/analysis-snapshot-release-repository.R:452:analysis_release_set_doi <- function(release_id, doi_fields = list(), conn) {
api/functions/analysis-snapshot-release-repository.R-453-  allowed <- c("zenodo_record_id", "zenodo_record_url", "version_doi", "concept_doi")
api/functions/analysis-snapshot-release-repository.R-454-  present <- intersect(names(doi_fields), allowed)
api/functions/analysis-snapshot-release-repository.R-455-  if (length(present) == 0L) {
api/functions/analysis-snapshot-release-repository.R-456-    return(FALSE)
--
api/services/analysis-snapshot-release-service.R-33-# unknown release id, or an unknown archive file path) is indistinguishable
api/services/analysis-snapshot-release-service.R-34-# from the caller's point of view — both resolve to a plain 404. Drafts are
api/services/analysis-snapshot-release-service.R-35-# NEVER returned publicly.
api/services/analysis-snapshot-release-service.R-36-#
api/services/analysis-snapshot-release-service.R:37:# ADMIN SURFACE. `svc_release_build/publish/set_doi/delete_draft()` are
api/services/analysis-snapshot-release-service.R-38-# admin-only from the caller's perspective (the endpoint layer is expected to
api/services/analysis-snapshot-release-service.R-39-# gate with `require_role(req, res, "Administrator")` before calling in, the
api/services/analysis-snapshot-release-service.R-40-# same pattern as the other `svc_*` admin services in this directory); this
api/services/analysis-snapshot-release-service.R-41-# file does not itself check roles.
--
api/services/analysis-snapshot-release-service.R-147-#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
api/services/analysis-snapshot-release-service.R-148-#' @param conn A real DBIConnection.
api/services/analysis-snapshot-release-service.R-149-#' @return The updated release head.
api/services/analysis-snapshot-release-service.R-150-#' @export
api/services/analysis-snapshot-release-service.R:151:svc_release_set_doi <- function(release_id, doi_fields, conn = NULL) {
api/services/analysis-snapshot-release-service.R:152:  analysis_release_set_doi(release_id, doi_fields = doi_fields, conn = conn)
api/services/analysis-snapshot-release-service.R-153-  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/services/analysis-snapshot-release-service.R-154-  if (is.null(head)) {
api/services/analysis-snapshot-release-service.R-155-    stop_for_not_found(sprintf("Release '%s' not found", release_id))
api/services/analysis-snapshot-release-service.R-156-  }
--
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-4-# Task A5): api/services/analysis-snapshot-release-service.R.
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-5-#
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-6-# Pure unit tests, NO DATABASE. The A4 build orchestrator
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-7-# (`analysis_snapshot_release_build`) and the A3 repository functions
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:8:# (`analysis_release_list/get/get_file/get_bundle/publish/set_doi/
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-9-# delete_draft`) are entirely STUBBED: this file never sources
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-10-# `functions/analysis-snapshot-release.R` or
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-11-# `functions/analysis-snapshot-release-repository.R`, it only defines
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-12-# minimal stand-ins for the names the service calls, then reassigns them
--
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-29-analysis_release_get <- function(...) stop("stub: analysis_release_get not mocked")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-30-analysis_release_get_file <- function(...) stop("stub: analysis_release_get_file not mocked")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-31-analysis_release_get_bundle <- function(...) stop("stub: analysis_release_get_bundle not mocked")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-32-analysis_release_publish <- function(...) stop("stub: analysis_release_publish not mocked")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:33:analysis_release_set_doi <- function(...) stop("stub: analysis_release_set_doi not mocked")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-34-analysis_release_delete_draft <- function(...) stop("stub: analysis_release_delete_draft not mocked")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-35-# Identity stand-in for the PUBLIC projection: the REAL allowlist behaviour is
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-36-# covered against the real function in the repository integration test; here the
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-37-# service tests only verify svc_release_list/get ROUTE through it.
--
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-280-  )
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-281-})
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-282-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-283-# =============================================================================
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:284:# svc_release_set_doi
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-285-# =============================================================================
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-286-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:287:test_that("set_doi: unknown id -> 404", {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-288-  with_release_mocks(
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-289-    list(
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:290:      analysis_release_set_doi = function(...) FALSE,
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-291-      analysis_release_get = function(...) NULL
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-292-    ),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-293-    {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-294-      expect_error(
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:295:        svc_release_set_doi("asr_missing", list(version_doi = "10.5281/zenodo.1")),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-296-        class = "error_404"
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-297-      )
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-298-    }
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-299-  )
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-300-})
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-301-
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:302:test_that("set_doi: success returns the updated head and forwards doi_fields verbatim", {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-303-  head <- list(release_id = "asr_doi1", version_doi = "10.5281/zenodo.1")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-304-  captured <- NULL
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-305-  with_release_mocks(
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-306-    list(
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:307:      analysis_release_set_doi = function(release_id, doi_fields, conn = NULL) {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-308-        captured <<- doi_fields
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-309-        TRUE
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-310-      },
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-311-      analysis_release_get = function(...) head
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-312-    ),
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-313-    {
api/tests/testthat/test-unit-analysis-snapshot-release-service.R:314:      out <- svc_release_set_doi("asr_doi1", list(version_doi = "10.5281/zenodo.1"))
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-315-      expect_identical(out, head)
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-316-      expect_equal(captured$version_doi, "10.5281/zenodo.1")
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-317-    }
api/tests/testthat/test-unit-analysis-snapshot-release-service.R-318-  )
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-1-# tests/testthat/test-integration-analysis-snapshot-release-repository.R
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-2-#
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-3-# Integration tests for the analysis-snapshot RELEASE repository (#573 Slice
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-4-# A / Task A3): insert / get / list / get_file / get_bundle / publish /
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:5:# set_doi / delete_draft / exists / referenced_snapshot_ids, against the real
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-6-# test database (sysndd_db_test).
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-7-#
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-8-# IMPORTANT (verified live against RMariaDB, not just inferred from
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-9-# comments): analysis_release_insert() wraps its writes in ONE
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-105-    license = "CC-BY-4.0"
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-106-  )
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-107-}
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-108-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:109:test_that("analysis-snapshot release repository round-trips insert/get/list/get_file/get_bundle/publish/set_doi", {
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-110-  skip_if_no_test_db()
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-111-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-112-  schema_conn <- get_test_db_connection()
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-113-  ensure_test_release_schema(schema_conn)
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-198-    vapply(entry$layers, function(l) as.integer(l$snapshot_id), integer(1)),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-199-    c(101L, 202L)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-200-  )
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-201-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:202:  # --- set_doi: additive, never touches content_digest/manifest_sha256 -------
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-203-  before_digest <- published$content_digest
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-204-  before_manifest_sha <- published$manifest_sha256
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:205:  ok <- analysis_release_set_doi(
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-206-    TEST_RELEASE_ID,
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-207-    list(zenodo_record_id = "123456", version_doi = "10.5281/zenodo.123456"),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-208-    conn = conn
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-209-  )
--
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-215-  expect_true(is.na(with_doi$concept_doi)) # untouched (not provided)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-216-  expect_equal(with_doi$content_digest, before_digest)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-217-  expect_equal(with_doi$manifest_sha256, before_manifest_sha)
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-218-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:219:  # set_doi on an unrelated/nonexistent id is a no-op
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:220:  expect_false(analysis_release_set_doi(
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-221-    "asr_does_not_exist",
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-222-    list(zenodo_record_id = "999"),
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-223-    conn = conn
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-224-  ))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-225-  # empty doi_fields is a no-op
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R:226:  expect_false(analysis_release_set_doi(TEST_RELEASE_ID, list(), conn = conn))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-227-
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-228-  # --- delete_draft refuses a published row -----------------------------------
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-229-  expect_false(analysis_release_delete_draft(TEST_RELEASE_ID, conn = conn))
api/tests/testthat/test-integration-analysis-snapshot-release-repository.R-230-  expect_true(analysis_release_exists(TEST_RELEASE_ID, conn = conn))

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-repository.R | sed -n '440,490p'
nl -ba api/services/analysis-snapshot-release-service.R | sed -n '130,165p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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

exec
/bin/bash -lc 'rg -n -i -C 3 "symbolic links|symbolic link|symlink" /usr/share/R/doc /usr/lib/R/doc 2>/dev/null | head -n 100' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
codex
## BLOCKER

None.

## HIGH

- `api/functions/analysis-snapshot-release-zenodo-verify.R:219-228`, `api/functions/analysis-snapshot-release-zenodo-package.R:311-318` — Input-bundle symlinks are not rejected before copying. A malicious/misconfigured API response can provide a symlinked release member with a matching bundle hash; extraction and checksum calculation follow it, and `file.copy()` can dereference it into the new staging tree. The later staging symlink validator then sees an ordinary copied file, allowing host-readable content to be tarred and uploaded.
  Fix: validate the extracted bundle immediately after `untar()`—reject symlinks and non-regular files, including `checksums.sha256`, before reading hashes or calling `copy_tree()`. Add an end-to-end fixture containing a symlink to an external test file and assert packaging fails.

- `api/functions/analysis-snapshot-release-zenodo-upload.R:216-241`, `api/scripts/upload-analysis-release-zenodo.R:180-209` — The upload/DOI-record-back path does not apply the content-addressed release-ID validation. A crafted `--release-id` is concatenated into the admin URL and, worse, interpolated inside the displayed single-quoted `curl` command. For example, a value containing `' ; <command> ; #` produces a copy/paste command-injection payload. This bypasses the otherwise-correct packager-side ID guard.
  Fix: share and invoke the strict `^asr_[0-9a-f]{16}$` validator before any DOI URL/command construction; shell-quote the generated URL and JSON payload with `shQuote()` as defense in depth. Add quote/newline/traversal rejection tests for both automatic and manual DOI paths.

## MEDIUM

- `api/scripts/upload-analysis-release-zenodo.R:201-209` — The locked “published-only” DOI record-back rule is bypassable through the manual fallback. After a draft upload, the script prints an executable PATCH command containing the draft record ID/URL and explicitly says “or record it by hand”; the endpoint accepts it because it does not enforce Zenodo publication state.
  Fix: when `result$published` is false, print only post-publication instructions—no populated PATCH command. Emit the command only after a published result, and add a draft-path test.

- `api/functions/analysis-snapshot-release-zenodo-verify.R:173-177` — Traversal validation splits only on `/`. On Windows-capable host runs, `..\\escape` and UNC-style `\\host\\share` paths are not rejected before extraction/checksum resolution.
  Fix: normalize/check both slash styles and reject UNC/leading backslash paths; test backslash traversal in tar members and checksum entries.

## LOW

None.

Round-one check: the staging rmtree guard, packager request/resolved-ID validation, `sed` marker handoff (including space-safe quoting), case-insensitive filename checks, suffix allowlist, ordinary checksum coverage, deterministic mtime normalization, and environment-only Zenodo token are all present. The symlink protection is not complete end-to-end because validation occurs after the unsafe extraction/copy boundary.

`git diff --check` passed. Targeted R tests and `make code-quality-audit` could not run because this review sandbox cannot create `/tmp` files.

VERDICT: NO-SHIP
tokens used
113,331
## BLOCKER

None.

## HIGH

- `api/functions/analysis-snapshot-release-zenodo-verify.R:219-228`, `api/functions/analysis-snapshot-release-zenodo-package.R:311-318` — Input-bundle symlinks are not rejected before copying. A malicious/misconfigured API response can provide a symlinked release member with a matching bundle hash; extraction and checksum calculation follow it, and `file.copy()` can dereference it into the new staging tree. The later staging symlink validator then sees an ordinary copied file, allowing host-readable content to be tarred and uploaded.
  Fix: validate the extracted bundle immediately after `untar()`—reject symlinks and non-regular files, including `checksums.sha256`, before reading hashes or calling `copy_tree()`. Add an end-to-end fixture containing a symlink to an external test file and assert packaging fails.

- `api/functions/analysis-snapshot-release-zenodo-upload.R:216-241`, `api/scripts/upload-analysis-release-zenodo.R:180-209` — The upload/DOI-record-back path does not apply the content-addressed release-ID validation. A crafted `--release-id` is concatenated into the admin URL and, worse, interpolated inside the displayed single-quoted `curl` command. For example, a value containing `' ; <command> ; #` produces a copy/paste command-injection payload. This bypasses the otherwise-correct packager-side ID guard.
  Fix: share and invoke the strict `^asr_[0-9a-f]{16}$` validator before any DOI URL/command construction; shell-quote the generated URL and JSON payload with `shQuote()` as defense in depth. Add quote/newline/traversal rejection tests for both automatic and manual DOI paths.

## MEDIUM

- `api/scripts/upload-analysis-release-zenodo.R:201-209` — The locked “published-only” DOI record-back rule is bypassable through the manual fallback. After a draft upload, the script prints an executable PATCH command containing the draft record ID/URL and explicitly says “or record it by hand”; the endpoint accepts it because it does not enforce Zenodo publication state.
  Fix: when `result$published` is false, print only post-publication instructions—no populated PATCH command. Emit the command only after a published result, and add a draft-path test.

- `api/functions/analysis-snapshot-release-zenodo-verify.R:173-177` — Traversal validation splits only on `/`. On Windows-capable host runs, `..\\escape` and UNC-style `\\host\\share` paths are not rejected before extraction/checksum resolution.
  Fix: normalize/check both slash styles and reject UNC/leading backslash paths; test backslash traversal in tar members and checksum entries.

## LOW

None.

Round-one check: the staging rmtree guard, packager request/resolved-ID validation, `sed` marker handoff (including space-safe quoting), case-insensitive filename checks, suffix allowlist, ordinary checksum coverage, deterministic mtime normalization, and environment-only Zenodo token are all present. The symlink protection is not complete end-to-end because validation occurs after the unsafe extraction/copy boundary.

`git diff --check` passed. Targeted R tests and `make code-quality-audit` could not run because this review sandbox cannot create `/tmp` files.

VERDICT: NO-SHIP
