Reading additional input from stdin...
OpenAI Codex v0.144.6
--------
workdir: /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
model: gpt-5.6-terra
provider: openai
approval: never
sandbox: read-only
reasoning effort: high
reasoning summaries: none
session id: 019f7a21-fe9f-77e3-a952-c53c476f16f9
--------
user
# Adversarial diff review ROUND 4 — #573 Slice C (Zenodo operator scripts)

Rounds 1-3 returned NO-SHIP; findings have converged (6 → 4 → 2). Round-3 fixes are in commit
`46b5c48f`. Fresh independent re-review of the CURRENT full branch diff.

1. **Verify the two round-3 findings are genuinely resolved:**
   - HIGH (non-regular files): the post-`untar()` guard (`analysis-snapshot-release-zenodo-verify.R`,
     `.analysis_release_zenodo_reject_unsafe_files`) now rejects symlinks AND any non-regular file (via
     `fs::file_info()$type == "file"`, which stats without opening — so a FIFO can't hang it), before
     any `digest` read. Confirm a FIFO/socket/device bundle member fails closed, not by hanging.
   - MEDIUM (download_bundle): `analysis_release_zenodo_download_bundle()` now validates `release_id`
     (`^asr_[0-9a-f]{16}$`, `allow_latest = FALSE`) before interpolating it into the URL. Confirm a
     `../`/quote/newline id is rejected before any HTTP call.

2. **Final adjacent sweep** — any remaining or newly-introduced issue. Same rigor as prior rounds. Note
   the fixer used `fs::file_info()$type` rather than `file_test("-f")` (correct: `file_test("-f")` is
   `!isdir` and returns TRUE for a FIFO) — confirm the chosen check is sound.

## The diff to review
```
git diff origin/master...HEAD -- ':(exclude).planning/**'
```
Files: `analysis-snapshot-release-zenodo-{common,package,verify,docs,upload}.R`, the two CLI scripts,
and `test-unit-analysis-release-zenodo-{package,verify,verify-round3,upload,upload-doi-safety}.R` (+ a
shared `analysis-release-zenodo-verify-fixtures.R`), plus Makefile/.gitignore/docs/AGENTS/version.
Context: `AGENTS.md`, sibling `/home/bernt-popp/development/nddscore/`, DOI endpoint
`api/endpoints/admin_analysis_snapshot_endpoints.R`.

## Locked decisions (do NOT flag; flag violations)
Public-API read only, host-run, DI seams. Publish DOUBLE-gated; Makefile never publishes. DOI
record-back OPT-IN, PUBLISHED-only (auto + printed manual command), only-supplied-non-empty fields, JSON
body, placeholder token in printed commands. Safety validator (case-insensitive, file-type allowlist,
symlink + non-regular-file + traversal rejection) runs before tarring; bundle extraction fails closed.
Staging rmtree sentinel-guarded. release_id `^asr_[0-9a-f]{16}$` everywhere it touches a
path/URL/command/marker (including `download_bundle`). Content-addressed ids. No manuscript refs. Every
handwritten `.R` < 600. Operator scripts exempt from the external-budget guard.

## Output
Findings by **BLOCKER / HIGH / MEDIUM / LOW** with file:line + failure scenario + fix. End with
`VERDICT: SHIP` or `VERDICT: NO-SHIP`. If the round-3 findings are resolved and nothing new is
ship-blocking, say `VERDICT: SHIP` plainly — do not manufacture issues to avoid a clean pass.
codex
I’ll perform a read-only adversarial review of the current branch diff, including targeted checks for FIFO behavior and release-id validation before any HTTP seam. I’m using the repository’s security/code-quality review guidance because this is a security-sensitive operator-tool sweep.
exec
/bin/bash -lc "sed -n '1,240p' .agents/skills/sysndd-security-bug-scan/SKILL.md && sed -n '1,200p' .agents/skills/sysndd-code-quality/SKILL.md && git status --short && git diff --stat origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
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
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt-round2.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt-round3.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt-round4.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review-round2.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review-round3.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review-round4.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review.md
?? .planning/reviews/2026-07-19-573-slice-c-reconciliation.md
 .gitignore                                         |   4 +
 AGENTS.md                                          |   1 +
 CHANGELOG.md                                       |  11 +
 Makefile                                           |  33 +-
 .../analysis-snapshot-release-zenodo-common.R      |  75 +++
 .../analysis-snapshot-release-zenodo-docs.R        | 163 ++++++
 .../analysis-snapshot-release-zenodo-package.R     | 422 +++++++++++++++
 .../analysis-snapshot-release-zenodo-upload.R      | 459 ++++++++++++++++
 .../analysis-snapshot-release-zenodo-verify.R      | 587 +++++++++++++++++++++
 api/scripts/package-analysis-release-zenodo.R      | 157 ++++++
 api/scripts/upload-analysis-release-zenodo.R       | 180 +++++++
 .../analysis-release-zenodo-verify-fixtures.R      |  53 ++
 .../test-unit-analysis-release-zenodo-package.R    | 417 +++++++++++++++
 ...nit-analysis-release-zenodo-upload-doi-safety.R | 239 +++++++++
 .../test-unit-analysis-release-zenodo-upload.R     | 450 ++++++++++++++++
 ...st-unit-analysis-release-zenodo-verify-round3.R |  86 +++
 .../test-unit-analysis-release-zenodo-verify.R     | 543 +++++++++++++++++++
 api/version_spec.json                              |   2 +-
 app/package-lock.json                              |   4 +-
 app/package.json                                   |   2 +-
 documentation/09-deployment.qmd                    |  41 +-
 21 files changed, 3923 insertions(+), 6 deletions(-)

exec
/bin/bash -lc "sed -n '1,220p' /home/bernt-popp/.codex/superpowers/skills/using-superpowers/SKILL.md
rg -n \"download_bundle|reject_unsafe|reject_symlink|untar|digest\\(|assert_valid_release|URL|curl|system|tar\\(|file_info|release_id\" api/functions/analysis-snapshot-release-zenodo-{common,package,verify,docs,upload}.R api/scripts/{package,upload}-analysis-release-zenodo.R api/tests/testthat/{test-unit-analysis-release-zenodo-package,test-unit-analysis-release-zenodo-verify,test-unit-analysis-release-zenodo-verify-round3,test-unit-analysis-release-zenodo-upload,test-unit-analysis-release-zenodo-upload-doi-safety,analysis-release-zenodo-verify-fixtures}.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
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
api/functions/analysis-snapshot-release-zenodo-common.R:6:# (`.analysis_release_zenodo_assert_valid_release_id()`).
api/functions/analysis-snapshot-release-zenodo-common.R:14:# URL or a printed shell command.
api/functions/analysis-snapshot-release-zenodo-common.R:19:# flag) built an admin PATCH URL AND a printed `curl` command straight from
api/functions/analysis-snapshot-release-zenodo-common.R:22:# single-quoted shell command, and a `../` value alters the URL path.
api/functions/analysis-snapshot-release-zenodo-common.R:39:# (`analysis_release_id()` in `analysis-snapshot-release-manifest.R`). This is
api/functions/analysis-snapshot-release-zenodo-common.R:40:# the ONLY shape ever allowed to become a filename, path component, URL
api/functions/analysis-snapshot-release-zenodo-common.R:44:#' Stop unless `release_id` is exactly `"latest"` (only when
api/functions/analysis-snapshot-release-zenodo-common.R:52:#'   becomes `<release_id>.tar.gz` and the `RELEASE_ID=` marker line;
api/functions/analysis-snapshot-release-zenodo-common.R:55:#'   builds the admin PATCH URL or the printed `curl` command from the
api/functions/analysis-snapshot-release-zenodo-common.R:60:#' as a path/filename/marker/URL segment or interpolated into a command.
api/functions/analysis-snapshot-release-zenodo-common.R:62:#' @return `release_id` (as a length-1 character), invisibly, on success.
api/functions/analysis-snapshot-release-zenodo-common.R:63:.analysis_release_zenodo_assert_valid_release_id <- function(release_id, allow_latest = FALSE) {
api/functions/analysis-snapshot-release-zenodo-common.R:64:  value <- as.character(release_id)[[1]]
api/tests/testthat/analysis-release-zenodo-verify-fixtures.R:36:  a_sha <- a_sha_override %||% digest::digest(file = file.path(src, "a.txt"), algo = "sha256")
api/tests/testthat/analysis-release-zenodo-verify-fixtures.R:37:  b_sha <- b_sha_override %||% digest::digest(file = file.path(src, "b.txt"), algo = "sha256")
api/tests/testthat/analysis-release-zenodo-verify-fixtures.R:47:    utils::tar(
api/tests/testthat/test-unit-analysis-release-zenodo-verify-round3.R:13:# Covers item 1 (HIGH): `.analysis_release_zenodo_reject_unsafe_files()`
api/tests/testthat/test-unit-analysis-release-zenodo-verify-round3.R:14:# (renamed from `.analysis_release_zenodo_reject_symlinks()`) rejects ANY
api/tests/testthat/test-unit-analysis-release-zenodo-verify-round3.R:16:# so a FIFO/pipe can never reach `digest::digest(file = ...)`, which would
api/tests/testthat/test-unit-analysis-release-zenodo-verify-round3.R:31:  # (which only checked `Sys.readlink()`), and `digest::digest(file = ...)`
api/tests/testthat/test-unit-analysis-release-zenodo-verify-round3.R:38:  # reach `digest::digest(file = <the fifo path>)` and hang forever. This
api/tests/testthat/test-unit-analysis-release-zenodo-verify-round3.R:47:  # not packed into the tar.gz itself -- because taring/untaring a FIFO node
api/tests/testthat/test-unit-analysis-release-zenodo-verify-round3.R:49:  # exact same post-untar guard call site with no risk of the archive step
api/tests/testthat/test-unit-analysis-release-zenodo-verify-round3.R:56:  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify-round3.R:62:    base::system2("mkfifo", shQuote(fifo_path), stdout = FALSE, stderr = FALSE), 0L
api/tests/testthat/test-unit-analysis-release-zenodo-verify-round3.R:79:  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:19:#   admin PATCH URL or printed shell command from it.
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:21:#   URL and JSON body it prints.
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:33:# builds the admin PATCH URL or the printed shell command from it.
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:36:.invalid_release_ids_round2 <- list(
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:43:for (.label in names(.invalid_release_ids_round2)) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:46:    bad_id <- .invalid_release_ids_round2[[label]]
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:48:    test_that(paste0("record_doi: rejects a release_id containing ", label, " before calling patch"), {
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:64:    test_that(paste0("manual_doi_command: rejects a release_id containing ", label, " before building any command"), {
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:75:test_that("record_doi: accepts a well-formed asr_<16 hex> release_id", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:88:test_that("manual_doi_command: shQuote()s the URL and JSON body (defense in depth, Codex round-2 item 2)", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:89:  # A well-formed release_id can never itself carry shell metacharacters (the
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:92:  # field value cannot break out of the printed `curl` command's arguments.
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:111:# item 2 (HIGH, release-id validation before ANY URL/command is built) and
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:151:  expect_false(grepl("curl -X PATCH", output, fixed = TRUE))
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:168:  expect_false(grepl("curl -X PATCH", output, fixed = TRUE))
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:180:  expect_true(grepl("curl -X PATCH", output, fixed = TRUE))
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:188:  stub_record_doi_fn <- function(sysndd_api_base_url, admin_token, release_id, doi_fields) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:189:    assign("release_id", release_id, envir = captured_call)
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:191:    list(release_id = release_id, version_doi = doi_fields$version_doi, zenodo_record_url = doi_fields$zenodo_record_url)
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:200:  expect_false(grepl("curl -X PATCH", output, fixed = TRUE))
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:202:  expect_identical(get("release_id", envir = captured_call), "asr_deadbeefcafebabe")
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:206:for (.label in names(.invalid_release_ids_round2)) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:209:    bad_id <- .invalid_release_ids_round2[[label]]
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:212:      "print_doi_record_back: rejects a release_id containing ", label,
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:213:      " before building any URL/command (Codex round-2 item 2, HIGH)"
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:223:      # Nothing (no manual command, no partial URL) was ever printed before
api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R:225:      expect_false(grepl("curl", captured$get(), fixed = TRUE))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:69:test_that("upload_bucket: strips a trailing slash from bucket_url before building the target URL", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:181:    list(release_id = "asr_test")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:210:  expect_identical(result$release_id, "asr_test")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:269:  expect_true(grepl("curl -X PATCH", command, fixed = TRUE))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:14:# including `download_bundle`'s own defense-in-depth check, Codex round-3
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:15:# item 2, MEDIUM), `fetch_head`/`download_bundle` URL-building,
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:55:  writeLines('{"release_id":"asr_test"}', file.path(staging, "analysis_snapshot_release", "manifest.json"))
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:72:test_that("fetch_head: rejects a release_id containing '..' (path traversal shape) before calling http_get_json", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:85:test_that("fetch_head: rejects a release_id containing an embedded newline before calling http_get_json", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:100:test_that("fetch_head: rejects a release_id containing shell metacharacters before calling http_get_json", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:115:test_that("fetch_head: rejects an uppercase / wrong-length release_id", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:128:  stub_get_json <- function(url) list(release_id = "ok")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:140:# fetch_head / download_bundle -- DI seams, no real network
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:143:test_that("fetch_head: builds the /releases/latest URL and passes the stub's JSON through", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:147:    list(release_id = "asr_abcdef0123456789", bundle_sha256 = "deadbeef")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:151:  expect_identical(head$release_id, "asr_abcdef0123456789")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:154:test_that("fetch_head: builds the /releases/<id> URL for an explicit release_id (trailing slash tolerated)", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:158:    list(release_id = "asr_0000000000000000")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:164:  expect_identical(head$release_id, "asr_0000000000000000")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:167:test_that("download_bundle: builds the /releases/<id>/bundle URL and streams the stub's content through", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:176:  result <- analysis_release_zenodo_download_bundle(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:185:test_that("download_bundle: errors when the injected downloader produces an empty file", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:192:    analysis_release_zenodo_download_bundle(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:200:# download_bundle: release_id shape validation (Codex round-3 item 2,
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:202:# before calling download_bundle(), but this exported helper can be called
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:204:# interpolated into the bundle URL and before http_download is invoked.
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:207:test_that("download_bundle: rejects a malformed release_id ('asr_x') before calling http_download", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:216:    analysis_release_zenodo_download_bundle(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:225:test_that("download_bundle: rejects a release_id containing '..' (path traversal shape) before calling http_download", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:234:    analysis_release_zenodo_download_bundle(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:242:test_that("download_bundle: rejects a release_id containing a quote before calling http_download", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:251:    analysis_release_zenodo_download_bundle(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:259:test_that("download_bundle: rejects 'latest' (a bundle URL always targets a concrete id)", {
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:268:    analysis_release_zenodo_download_bundle(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:283:  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:297:  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:322:  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:337:  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:352:  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:367:  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:387:  weird_sha <- digest::digest(file = file.path(src, weird_name), algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:392:    utils::tar(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:397:  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:409:  # EXTRACTED tree, before `digest::digest(file = ...)` (which follows
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:427:  a_sha <- digest::digest(file = file.path(src, "a.txt"), algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:435:    utils::tar(
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:440:  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:454:  known_a_sha <- digest::digest(file = known_a_content_file, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-verify.R:460:  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
api/scripts/package-analysis-release-zenodo.R:91:      result$release_id
api/scripts/package-analysis-release-zenodo.R:101:  api_base_url <- Sys.getenv("SYSNDD_API_BASE_URL", "http://localhost:7778")
api/scripts/package-analysis-release-zenodo.R:102:  release_id <- "latest"
api/scripts/package-analysis-release-zenodo.R:112:        release_id <- args[i + 1]
api/scripts/package-analysis-release-zenodo.R:124:    "[package-analysis-release-zenodo] api_base_url=%s release_id=%s staging_dir=%s archive_dir=%s",
api/scripts/package-analysis-release-zenodo.R:125:    api_base_url, release_id, staging_dir, archive_dir
api/scripts/package-analysis-release-zenodo.R:130:    release_id = release_id,
api/scripts/package-analysis-release-zenodo.R:138:  cat(sprintf("Release ID:           %s\n", result$release_id))
api/scripts/package-analysis-release-zenodo.R:146:    result$archive_path, result$zenodo_metadata_path, result$release_id
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:9:# with `utils::tar()` -- no dependency on a real published release or a
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:13:# (`analysis_release_zenodo_fetch_head`, `_download_bundle`,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:36:build_fake_release_stubs <- function(work_dir, release_id = "asr_deadbeefcafebabe", bundle_sha256_override = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:40:  writeLines(sprintf('{"release_id":"%s"}', release_id), file.path(bundle_src, "manifest.json"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:41:  readme_sha <- digest::digest(file = file.path(bundle_src, "README.md"), algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:42:  manifest_sha <- digest::digest(file = file.path(bundle_src, "manifest.json"), algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:50:    utils::tar(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:55:  bundle_sha256 <- bundle_sha256_override %||% digest::digest(file = bundle_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:58:    release_id = release_id,
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:77:    release_id = "asr_abc1234567890abc",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:98:  head <- list(release_id = "asr_deadbeefdeadbeef", created_at = "2026-01-01T00:00:00Z", license = "mit")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:103:test_that("build_metadata: falls back to cc-by-4.0 license and release_id version when head omits both", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:104:  head <- list(release_id = "asr_0000000000000000", created_at = "2026-02-02T00:00:00Z")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:111:  head <- list(release_id = "asr_1111111111111111", created_at = "2026-03-03T00:00:00Z", license = "mit")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:130:    staging, name = "test-pkg", version = "v1", release_id = "asr_test"
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:152:    digest::digest(file = file.path(staging, "README.md"), algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:175:    paste0(digest::digest(file = file.path(staging, "a.txt"), algo = "sha256"), "  a.txt")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:204:  actual_sha <- digest::digest(file = result$archive_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:207:  entries <- utils::untar(result$archive_path, list = TRUE)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:208:  # utils::untar(list = TRUE) reports entries with a trailing "/" for dirs.
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:235:  sha1 <- digest::digest(file = result1$archive_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:241:  sha2 <- digest::digest(file = result2$archive_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:260:    release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:267:  expect_identical(result$release_id, "asr_deadbeefcafebabe")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:285:  actual_sha <- digest::digest(file = result$archive_path, algo = "sha256")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:292:    work_dir, release_id = "asr_baadf00dbaadf00d", bundle_sha256_override = strrep("f", 64L)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:298:      release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:308:test_that("package(): rejects a malformed RESOLVED release_id from the head before downloading (item 2, defense-in-depth)", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:311:  fake_head <- list(release_id = "asr_not-a-valid-id!!", bundle_sha256 = strrep("0", 64L))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:321:      release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:339:  stubs <- build_fake_release_stubs(work_dir, release_id = "asr_ffffffffffffffff")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:348:      release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:365:  stubs <- build_fake_release_stubs(work_dir, release_id = "asr_1234567890abcdef")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:372:    release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:387:  stubs1 <- build_fake_release_stubs(work_dir, release_id = "asr_1111111111111111")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:390:    release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:396:  expect_identical(result1$release_id, "asr_1111111111111111")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:401:  stubs2 <- build_fake_release_stubs(work_dir, release_id = "asr_2222222222222222")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:404:    release_id = "latest",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:410:  expect_identical(result2$release_id, "asr_2222222222222222")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:416:  expect_identical(manifest$release_id, "asr_2222222222222222")
api/scripts/upload-analysis-release-zenodo.R:39:# endpoint automatically -- it prints the exact manual `curl` command instead
api/scripts/upload-analysis-release-zenodo.R:46:# into the admin URL or the printed command.
api/scripts/upload-analysis-release-zenodo.R:107:  release_id <- NULL
api/scripts/upload-analysis-release-zenodo.R:108:  api_base_url <- Sys.getenv("SYSNDD_API_BASE_URL", "http://localhost:7778")
api/scripts/upload-analysis-release-zenodo.R:127:        release_id <- args[i + 1]
api/scripts/upload-analysis-release-zenodo.R:157:    "Zenodo draft URL:     %s\n",
api/scripts/upload-analysis-release-zenodo.R:163:    cat(sprintf("Published Zenodo URL: %s\n", result$record_url))
api/scripts/upload-analysis-release-zenodo.R:171:  analysis_release_zenodo_print_doi_record_back(result, release_id, api_base_url, record_doi)
api/functions/analysis-snapshot-release-zenodo-upload.R:35:# operator-supplied `--release-id` and both builds an admin PATCH URL from it
api/functions/analysis-snapshot-release-zenodo-upload.R:36:# AND interpolates it into a printed single-quoted `curl` command -- so an
api/functions/analysis-snapshot-release-zenodo-upload.R:37:# unvalidated value is a path/URL-injection AND a copy/paste
api/functions/analysis-snapshot-release-zenodo-upload.R:38:# command-injection vector. Every DOI URL/command builder below calls the
api/functions/analysis-snapshot-release-zenodo-upload.R:39:# shared `.analysis_release_zenodo_assert_valid_release_id()` (guard-sourced
api/functions/analysis-snapshot-release-zenodo-upload.R:77:# Zenodo API base URLs + publish safety interlock
api/functions/analysis-snapshot-release-zenodo-upload.R:83:#' Resolve the Zenodo API base URL for the requested environment.
api/functions/analysis-snapshot-release-zenodo-upload.R:134:#' Default streaming file PUT to a Zenodo bucket URL. Streams `archive_path`
api/functions/analysis-snapshot-release-zenodo-upload.R:185:#' @return The upload URL, invisibly.
api/functions/analysis-snapshot-release-zenodo-upload.R:246:#' @param sysndd_api_base_url Base URL of the SysNDD API.
api/functions/analysis-snapshot-release-zenodo-upload.R:250:#' @param release_id Validated via
api/functions/analysis-snapshot-release-zenodo-upload.R:251:#'   `.analysis_release_zenodo_assert_valid_release_id()` BEFORE the admin
api/functions/analysis-snapshot-release-zenodo-upload.R:252:#'   PATCH URL is built (Codex round-2 item 2, HIGH) -- an invalid id
api/functions/analysis-snapshot-release-zenodo-upload.R:254:#'   is ever placed into the URL.
api/functions/analysis-snapshot-release-zenodo-upload.R:258:    sysndd_api_base_url, admin_token, release_id, doi_fields,
api/functions/analysis-snapshot-release-zenodo-upload.R:261:  release_id <- as.character(release_id)[[1]]
api/functions/analysis-snapshot-release-zenodo-upload.R:262:  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-upload.R:263:  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
api/functions/analysis-snapshot-release-zenodo-upload.R:268:#' Build the exact `curl -X PATCH ...` command an operator can run by hand to
api/functions/analysis-snapshot-release-zenodo-upload.R:272:#' Codex round-2 item 2 (HIGH): `release_id` is validated via
api/functions/analysis-snapshot-release-zenodo-upload.R:273:#' `.analysis_release_zenodo_assert_valid_release_id()` BEFORE the URL or
api/functions/analysis-snapshot-release-zenodo-upload.R:275:#' path-altering URL segment or a copy/paste command-injection payload once
api/functions/analysis-snapshot-release-zenodo-upload.R:276:#' printed. Defense in depth: the resolved URL and the JSON body are each
api/functions/analysis-snapshot-release-zenodo-upload.R:279:#' `;`, or a newline cannot break out of the single-quoted `curl` arguments.
api/functions/analysis-snapshot-release-zenodo-upload.R:280:analysis_release_zenodo_manual_doi_command <- function(sysndd_api_base_url, release_id, doi_fields) {
api/functions/analysis-snapshot-release-zenodo-upload.R:282:  release_id <- as.character(release_id)[[1]]
api/functions/analysis-snapshot-release-zenodo-upload.R:283:  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-upload.R:284:  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
api/functions/analysis-snapshot-release-zenodo-upload.R:289:    "curl -X PATCH ", shQuote(url), " ",
api/functions/analysis-snapshot-release-zenodo-upload.R:309:#' - item 2 (HIGH): `release_id` is validated via
api/functions/analysis-snapshot-release-zenodo-upload.R:310:#'   `.analysis_release_zenodo_assert_valid_release_id()` immediately after
api/functions/analysis-snapshot-release-zenodo-upload.R:311:#'   the "no id supplied" short-circuit and BEFORE any URL or command is
api/functions/analysis-snapshot-release-zenodo-upload.R:322:#' @param release_id Operator-supplied `--release-id` (or `NULL`).
api/functions/analysis-snapshot-release-zenodo-upload.R:323:#' @param api_base_url Base URL of the SysNDD API.
api/functions/analysis-snapshot-release-zenodo-upload.R:332:    result, release_id, api_base_url, record_doi, printer = cat,
api/functions/analysis-snapshot-release-zenodo-upload.R:334:  have_release_id <- !is.null(release_id) && nzchar(as.character(release_id)[[1]])
api/functions/analysis-snapshot-release-zenodo-upload.R:335:  if (!have_release_id) {
api/functions/analysis-snapshot-release-zenodo-upload.R:340:  release_id <- as.character(release_id)[[1]]
api/functions/analysis-snapshot-release-zenodo-upload.R:341:  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-upload.R:367:      release_id = release_id,
api/functions/analysis-snapshot-release-zenodo-upload.R:371:    printer(sprintf("  release_id:        %s\n", updated$release_id %||% release_id))
api/functions/analysis-snapshot-release-zenodo-upload.R:382:    printer(analysis_release_zenodo_manual_doi_command(api_base_url, release_id, doi_fields), "\n")
api/functions/analysis-snapshot-release-zenodo-package.R:11:#   GET {api_base_url}/api/analysis/releases/{latest|<release_id>}
api/functions/analysis-snapshot-release-zenodo-package.R:12:#   GET {api_base_url}/api/analysis/releases/<release_id>/bundle
api/functions/analysis-snapshot-release-zenodo-package.R:126:#'   `head$release_id`.
api/functions/analysis-snapshot-release-zenodo-package.R:129:  release_id <- as.character(head$release_id %||% "")[[1]]
api/functions/analysis-snapshot-release-zenodo-package.R:132:    sprintf("SysNDD analysis-snapshot release %s, %s", release_id, release_date)
api/functions/analysis-snapshot-release-zenodo-package.R:134:    sprintf("SysNDD analysis-snapshot release %s", release_id)
api/functions/analysis-snapshot-release-zenodo-package.R:138:  resolved_version <- as.character((version %||% head$source_data_version %||% release_id))[[1]]
api/functions/analysis-snapshot-release-zenodo-package.R:171:#' @param release_id The release id (becomes the datapackage `id`).
api/functions/analysis-snapshot-release-zenodo-package.R:172:analysis_release_zenodo_build_datapackage <- function(staging_dir, name, version, release_id) {
api/functions/analysis-snapshot-release-zenodo-package.R:182:      hash = digest::digest(file = full_path, algo = "sha256"),
api/functions/analysis-snapshot-release-zenodo-package.R:192:    id = as.character(release_id)[[1]],
api/functions/analysis-snapshot-release-zenodo-package.R:222:      paste0(digest::digest(file = full_path, algo = "sha256"), "  ", rel_path)
api/functions/analysis-snapshot-release-zenodo-package.R:282:  # never depends on a system `tar` binary being present/compatible.
api/functions/analysis-snapshot-release-zenodo-package.R:283:  utils::tar(tarfile = archive_path, files = entries, compression = "gzip", tar = "internal")
api/functions/analysis-snapshot-release-zenodo-package.R:285:  sha256 <- digest::digest(file = archive_path, algo = "sha256")
api/functions/analysis-snapshot-release-zenodo-package.R:327:#'   zenodo_metadata_path, release_id).
api/functions/analysis-snapshot-release-zenodo-package.R:330:    release_id = "latest",
api/functions/analysis-snapshot-release-zenodo-package.R:337:  head <- analysis_release_zenodo_fetch_head(api_base_url, release_id, http_get_json = http_get_json)
api/functions/analysis-snapshot-release-zenodo-package.R:338:  resolved_release_id <- as.character(head$release_id)[[1]]
api/functions/analysis-snapshot-release-zenodo-package.R:341:  # value that actually becomes `<release_id>.tar.gz` and the `RELEASE_ID=`
api/functions/analysis-snapshot-release-zenodo-package.R:344:  .analysis_release_zenodo_assert_valid_release_id(resolved_release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-package.R:348:  analysis_release_zenodo_download_bundle(
api/functions/analysis-snapshot-release-zenodo-package.R:349:    api_base_url, resolved_release_id, bundle_path, http_download = http_download
api/functions/analysis-snapshot-release-zenodo-package.R:369:    (version %||% head$source_data_version %||% resolved_release_id)
api/functions/analysis-snapshot-release-zenodo-package.R:401:    release_id = resolved_release_id
api/functions/analysis-snapshot-release-zenodo-package.R:412:  archive_path <- file.path(archive_dir, paste0(resolved_release_id, ".tar.gz"))
api/functions/analysis-snapshot-release-zenodo-package.R:420:    release_id = resolved_release_id
api/functions/analysis-snapshot-release-zenodo-docs.R:26:  release_id <- as.character(head$release_id %||% "")[[1]]
api/functions/analysis-snapshot-release-zenodo-docs.R:27:  version <- as.character((head$source_data_version %||% head$release_version %||% release_id))[[1]]
api/functions/analysis-snapshot-release-zenodo-docs.R:32:    sprintf("- Release ID: `%s`\n", release_id),
api/functions/analysis-snapshot-release-zenodo-docs.R:52:  release_id <- as.character(head$release_id %||% "")[[1]]
api/functions/analysis-snapshot-release-zenodo-docs.R:72:      release_id
api/functions/analysis-snapshot-release-zenodo-docs.R:116:  release_id <- as.character(head$release_id %||% "")[[1]]
api/functions/analysis-snapshot-release-zenodo-docs.R:117:  resolved_version <- as.character((version %||% head$source_data_version %||% release_id))[[1]]
api/functions/analysis-snapshot-release-zenodo-docs.R:124:    sprintf("- Initial Zenodo dataset package for analysis-snapshot release `%s`.\n", release_id),
api/functions/analysis-snapshot-release-zenodo-docs.R:134:  release_id <- as.character(head$release_id %||% "")[[1]]
api/functions/analysis-snapshot-release-zenodo-docs.R:135:  resolved_version <- as.character((version %||% head$source_data_version %||% release_id))[[1]]
api/functions/analysis-snapshot-release-zenodo-docs.R:149:    sprintf("title: \"SysNDD analysis-snapshot release %s\"\n", release_id),
api/functions/analysis-snapshot-release-zenodo-verify.R:11:# and moves an operator-supplied filesystem path: release-id validation
api/functions/analysis-snapshot-release-zenodo-verify.R:94:# `.analysis_release_zenodo_assert_valid_release_id()` now lives in the
api/functions/analysis-snapshot-release-zenodo-verify.R:97:# why (Codex round-2 finding: the upload path built an admin PATCH URL and a
api/functions/analysis-snapshot-release-zenodo-verify.R:128:#' @param api_base_url Base URL of the SysNDD API (e.g. "http://localhost:7778").
api/functions/analysis-snapshot-release-zenodo-verify.R:129:#' @param release_id "latest" (default) or an explicit `asr_<16 hex>` id.
api/functions/analysis-snapshot-release-zenodo-verify.R:130:#'   Validated via `.analysis_release_zenodo_assert_valid_release_id()`
api/functions/analysis-snapshot-release-zenodo-verify.R:131:#'   before it is ever placed into the request URL.
api/functions/analysis-snapshot-release-zenodo-verify.R:133:#' @return The parsed head list (release_id, created_at, license,
api/functions/analysis-snapshot-release-zenodo-verify.R:137:    release_id = "latest",
api/functions/analysis-snapshot-release-zenodo-verify.R:140:  release_id <- as.character(release_id)[[1]]
api/functions/analysis-snapshot-release-zenodo-verify.R:141:  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = TRUE)
api/functions/analysis-snapshot-release-zenodo-verify.R:142:  url <- paste0(base_url, "/api/analysis/releases/", release_id)
api/functions/analysis-snapshot-release-zenodo-verify.R:148:#' @param release_id An EXPLICIT `asr_<16 hex>` id (there is no
api/functions/analysis-snapshot-release-zenodo-verify.R:151:#'   `.analysis_release_zenodo_assert_valid_release_id(allow_latest = FALSE)`
api/functions/analysis-snapshot-release-zenodo-verify.R:156:#'   unvalidated `../`/quote/newline-shaped `release_id` would otherwise
api/functions/analysis-snapshot-release-zenodo-verify.R:157:#'   reach the URL-building `paste0()` below unchecked. A bundle URL always
api/functions/analysis-snapshot-release-zenodo-verify.R:162:analysis_release_zenodo_download_bundle <- function(
api/functions/analysis-snapshot-release-zenodo-verify.R:164:    release_id,
api/functions/analysis-snapshot-release-zenodo-verify.R:168:  release_id <- as.character(release_id)[[1]]
api/functions/analysis-snapshot-release-zenodo-verify.R:169:  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-verify.R:170:  url <- paste0(base_url, "/api/analysis/releases/", release_id, "/bundle")
api/functions/analysis-snapshot-release-zenodo-verify.R:206:# tree (called immediately after untar(), before any hashing/copying -- item
api/functions/analysis-snapshot-release-zenodo-verify.R:216:#' real regular file per `fs::file_info(path)$type == "file"`; anything else
api/functions/analysis-snapshot-release-zenodo-verify.R:220:#' symlinks and reasoned that "everything else the pure-R `untar()` engine can
api/functions/analysis-snapshot-release-zenodo-verify.R:224:#' (or a future tar implementation change), and `digest::digest(file = ...)`
api/functions/analysis-snapshot-release-zenodo-verify.R:229:#' Deliberately uses `fs::file_info()$type` (already a repo dependency, see
api/functions/analysis-snapshot-release-zenodo-verify.R:237:#' `fs::file_info()$type` reports the real POSIX file type (`"file"`,
api/functions/analysis-snapshot-release-zenodo-verify.R:246:.analysis_release_zenodo_reject_unsafe_files <- function(root_dir, context) {
api/functions/analysis-snapshot-release-zenodo-verify.R:267:  # the file's bytes (e.g. `digest::digest(file = ...)`), which would
api/functions/analysis-snapshot-release-zenodo-verify.R:268:  # otherwise block indefinitely on a FIFO/pipe. `fs::file_info()` itself
api/functions/analysis-snapshot-release-zenodo-verify.R:276:    !identical(as.character(fs::file_info(full_path)$type), "file")
api/functions/analysis-snapshot-release-zenodo-verify.R:301:#' rejected -- `digest::digest(file = ...)` and `file.copy()` both follow
api/functions/analysis-snapshot-release-zenodo-verify.R:304:#' otherwise block `digest::digest()` indefinitely (Codex round 3, HIGH); (3)
api/functions/analysis-snapshot-release-zenodo-verify.R:320:  actual_bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
api/functions/analysis-snapshot-release-zenodo-verify.R:329:  tar_entries <- utils::untar(bundle_path, list = TRUE)
api/functions/analysis-snapshot-release-zenodo-verify.R:338:  utils::untar(bundle_path, exdir = exdir)
api/functions/analysis-snapshot-release-zenodo-verify.R:343:  .analysis_release_zenodo_reject_unsafe_files(exdir, "Extracted release bundle")
api/functions/analysis-snapshot-release-zenodo-verify.R:362:    actual_sha <- digest::digest(file = target, algo = "sha256")
api/functions/analysis-snapshot-release-zenodo-verify.R:503:#' `utils::tar()` would then follow and embed verbatim. Delegates to the
api/functions/analysis-snapshot-release-zenodo-verify.R:504:#' shared `.analysis_release_zenodo_reject_unsafe_files()` (same check now
api/functions/analysis-snapshot-release-zenodo-verify.R:508:  .analysis_release_zenodo_reject_unsafe_files(staging_dir, "Zenodo staging")

exec
/bin/bash -lc 'nl -ba api/functions/analysis-snapshot-release-zenodo-common.R
nl -ba api/functions/analysis-snapshot-release-zenodo-verify.R
nl -ba api/functions/analysis-snapshot-release-zenodo-package.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
     1	# api/functions/analysis-snapshot-release-zenodo-common.R
     2	#
     3	# Tiny shared helpers for the analysis-snapshot RELEASE Zenodo operator
     4	# scripts (#573 Slice C, Codex round-2 hardening item 2 -- HIGH): the `%||%`
     5	# NULL-coalesce helper and the STRICT release-id shape validator
     6	# (`.analysis_release_zenodo_assert_valid_release_id()`).
     7	#
     8	# Guard-sourced by BOTH the package/verify pair
     9	# (`analysis-snapshot-release-zenodo-verify.R`, itself guard-sourced by
    10	# `-package.R`) AND the upload/DOI file
    11	# (`analysis-snapshot-release-zenodo-upload.R`) so the validator is defined
    12	# exactly once and every operator-script path -- package AND upload/DOI --
    13	# rejects a malformed release id identically, before it is ever placed into a
    14	# URL or a printed shell command.
    15	#
    16	# Extracted here (rather than left duplicated only in `-verify.R`, where the
    17	# round-1 guard originally lived) because Codex round 2 found the upload/DOI
    18	# path (`record_doi()`/`manual_doi_command()`, and the CLI's `--release-id`
    19	# flag) built an admin PATCH URL AND a printed `curl` command straight from
    20	# an UNVALIDATED `--release-id` -- a value like `asr_x' ; rm -rf ~ ; #`
    21	# becomes a copy/paste command-injection payload once printed inside a
    22	# single-quoted shell command, and a `../` value alters the URL path.
    23	#
    24	# NOT API-runtime code: not registered in `bootstrap/load_modules.R`. Kept
    25	# well under the repo's 600-line soft ceiling on purpose -- this file only
    26	# grows if a THIRD operator-script path needs the same guard.
    27
    28	.analysis_release_zenodo_common_loaded <- TRUE
    29
    30	`%||%` <- function(a, b) {
    31	  if (is.null(a) || length(a) == 0) {
    32	    b
    33	  } else {
    34	    a
    35	  }
    36	}
    37
    38	# A published release id is `"asr_" + 16 lowercase hex chars`
    39	# (`analysis_release_id()` in `analysis-snapshot-release-manifest.R`). This is
    40	# the ONLY shape ever allowed to become a filename, path component, URL
    41	# segment, or a value interpolated into a printed shell command.
    42	.ANALYSIS_RELEASE_ZENODO_ID_PATTERN <- "^asr_[0-9a-f]{16}$"
    43
    44	#' Stop unless `release_id` is exactly `"latest"` (only when
    45	#' `allow_latest = TRUE`, i.e. a caller-supplied REQUEST arg) or a
    46	#' well-formed `asr_<16 lowercase hex>` id.
    47	#'
    48	#' Shared by BOTH:
    49	#' - the package/verify path (`analysis_release_zenodo_fetch_head()`'s
    50	#'   REQUEST arg, and defense-in-depth on the RESOLVED id from the release
    51	#'   head in `analysis_release_zenodo_package()`) -- this is the value that
    52	#'   becomes `<release_id>.tar.gz` and the `RELEASE_ID=` marker line;
    53	#' - the upload/DOI path (`analysis_release_zenodo_record_doi()`,
    54	#'   `analysis_release_zenodo_manual_doi_command()`, called before EITHER
    55	#'   builds the admin PATCH URL or the printed `curl` command from the
    56	#'   CLI's `--release-id`).
    57	#'
    58	#' Any other value (`../evil`, an id containing a quote, `;`, a newline, or
    59	#' other shell metacharacters, ...) stops loudly here, before it is ever used
    60	#' as a path/filename/marker/URL segment or interpolated into a command.
    61	#'
    62	#' @return `release_id` (as a length-1 character), invisibly, on success.
    63	.analysis_release_zenodo_assert_valid_release_id <- function(release_id, allow_latest = FALSE) {
    64	  value <- as.character(release_id)[[1]]
    65	  if (isTRUE(allow_latest) && identical(value, "latest")) {
    66	    return(invisible(value))
    67	  }
    68	  if (!grepl(.ANALYSIS_RELEASE_ZENODO_ID_PATTERN, value)) {
    69	    stop(sprintf(
    70	      "Invalid analysis-snapshot release id %s: expected %s'asr_<16 lowercase hex>'",
    71	      shQuote(value), if (isTRUE(allow_latest)) "'latest' or " else ""
    72	    ), call. = FALSE)
    73	  }
    74	  invisible(value)
    75	}
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
    21	# does not matter (same idiom as the `-docs.R` sibling). Also guard-sources
    22	# the sibling `analysis-snapshot-release-zenodo-common.R` below (release-id
    23	# validator, Codex round-2 item 2) so this file works standalone even if a
    24	# caller sources it directly instead of via `-package.R`.
    25
    26	.analysis_release_zenodo_verify_loaded <- TRUE
    27
    28	if (!exists(".analysis_release_zenodo_common_loaded", mode = "logical")) {
    29	  # Same self-locating guard-source idiom as `-package.R`'s docs/verify
    30	  # blocks (resolves this file's own directory from the active source()
    31	  # frame so the sibling common file loads regardless of cwd or how this
    32	  # file was sourced).
    33	  .analysis_release_zenodo_common_self_dir <- local({
    34	    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
    35	    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
    36	  })
    37	  .analysis_release_zenodo_common_candidates <- c(
    38	    if (!is.null(.analysis_release_zenodo_common_self_dir)) {
    39	      file.path(.analysis_release_zenodo_common_self_dir, "analysis-snapshot-release-zenodo-common.R")
    40	    },
    41	    "functions/analysis-snapshot-release-zenodo-common.R",
    42	    "/app/functions/analysis-snapshot-release-zenodo-common.R"
    43	  )
    44	  for (.analysis_release_zenodo_common_path in .analysis_release_zenodo_common_candidates) {
    45	    if (file.exists(.analysis_release_zenodo_common_path)) {
    46	      # local = TRUE: evaluate into THIS call's parent frame (same reasoning
    47	      # as `-package.R`'s guard blocks).
    48	      source(.analysis_release_zenodo_common_path, local = TRUE)
    49	      break
    50	    }
    51	  }
    52	  rm(
    53	    .analysis_release_zenodo_common_self_dir, .analysis_release_zenodo_common_candidates,
    54	    .analysis_release_zenodo_common_path
    55	  )
    56	}
    57
    58	# --------------------------------------------------------------------------- #
    59	# Shared constants (forbidden files/dirs, sensitive text, expected layout,
    60	# allowed file-type suffixes, the staging-ownership sentinel). The
    61	# release-id shape constant lives in the guard-sourced common.R above.
    62	# --------------------------------------------------------------------------- #
    63
    64	.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES <- c(".env", ".env.local", ".envrc")
    65	.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS <- c(
    66	  ".git", ".planning", ".superpowers", ".venv", "__pycache__"
    67	)
    68	.ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS <- c(
    69	  "/home/", "/users/", "bernt-popp", "zenodo_token", "zenodo_access_token",
    70	  "bearer ", "development/sysndd", "development/nddscore", ".env", "git_sha"
    71	)
    72	# A well-formed analysis-release staging tree only ever contains these
    73	# suffixes (the release payload/docs). Doubles as both the file-type
    74	# ALLOWLIST (item 3: any staged regular file whose suffix is not in this set
    75	# fails validation, catching `.csv`/`.pem`/extensionless/binary secret files
    76	# without needing to scan binaries) and the set of suffixes the sensitive-
    77	# text content scan reads.
    78	.ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES <- c(".md", ".json", ".sql", ".cff", ".sha256", ".txt")
    79	.ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL <- c(
    80	  "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
    81	  "datapackage.json", "zenodo_metadata.json", "checksums.sha256"
    82	)
    83	.ANALYSIS_RELEASE_ZENODO_NESTED_DIR <- "analysis_snapshot_release"
    84	.ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED <- c("manifest.json", "checksums.sha256")
    85
    86	# The ownership marker this tool writes at the staging root immediately
    87	# after creating it. `analysis_release_zenodo_package()` refuses to
    88	# recursively delete a pre-existing `--staging-dir` unless it is empty or
    89	# carries this sentinel -- see `.analysis_release_zenodo_staging_owned_by_tool()`.
    90	.ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL <- ".analysis-release-zenodo-staging"
    91
    92	# --------------------------------------------------------------------------- #
    93	# Release-id validation -- path/filename/marker-injection guard (item 2).
    94	# `.analysis_release_zenodo_assert_valid_release_id()` now lives in the
    95	# shared `analysis-snapshot-release-zenodo-common.R` (guard-sourced above)
    96	# so the upload/DOI path validates identically -- see that file's header for
    97	# why (Codex round-2 finding: the upload path built an admin PATCH URL and a
    98	# printed shell command from an unvalidated `--release-id`).
    99	# --------------------------------------------------------------------------- #
   100
   101	# --------------------------------------------------------------------------- #
   102	# Fetch (DI seams: http_get_json / http_download)
   103	# --------------------------------------------------------------------------- #
   104
   105	#' Default JSON GET; tests inject a stub. Mirrors `.nddscore_http_get_json`.
   106	.analysis_release_zenodo_http_get_json <- function(url) {
   107	  resp <- httr2::request(url) |>
   108	    httr2::req_retry(
   109	      max_tries = 4,
   110	      is_transient = ~ httr2::resp_status(.x) %in% c(429, 503, 504)
   111	    ) |>
   112	    httr2::req_timeout(30) |>
   113	    httr2::req_perform()
   114	  httr2::resp_body_json(resp, simplifyVector = FALSE)
   115	}
   116
   117	#' Default streamed binary GET; tests inject a stub. Mirrors `.nddscore_http_download`.
   118	.analysis_release_zenodo_http_download <- function(url, destfile) {
   119	  httr2::request(url) |>
   120	    httr2::req_retry(max_tries = 4) |>
   121	    httr2::req_timeout(300) |>
   122	    httr2::req_perform(path = destfile)
   123	  invisible(destfile)
   124	}
   125
   126	#' Fetch a published release's head + parsed manifest over the public API.
   127	#'
   128	#' @param api_base_url Base URL of the SysNDD API (e.g. "http://localhost:7778").
   129	#' @param release_id "latest" (default) or an explicit `asr_<16 hex>` id.
   130	#'   Validated via `.analysis_release_zenodo_assert_valid_release_id()`
   131	#'   before it is ever placed into the request URL.
   132	#' @param http_get_json Function(url) -> parsed JSON list. Injectable seam.
   133	#' @return The parsed head list (release_id, created_at, license,
   134	#'   source_data_version, bundle_sha256, manifest, ...).
   135	analysis_release_zenodo_fetch_head <- function(
   136	    api_base_url,
   137	    release_id = "latest",
   138	    http_get_json = .analysis_release_zenodo_http_get_json) {
   139	  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
   140	  release_id <- as.character(release_id)[[1]]
   141	  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = TRUE)
   142	  url <- paste0(base_url, "/api/analysis/releases/", release_id)
   143	  http_get_json(url)
   144	}
   145
   146	#' Download a published release's whole `bundle.tar.gz`, verbatim, to `destfile`.
   147	#'
   148	#' @param release_id An EXPLICIT `asr_<16 hex>` id (there is no
   149	#'   `/releases/latest/bundle` route -- callers must resolve the concrete id
   150	#'   via `analysis_release_zenodo_fetch_head()` first). Validated via
   151	#'   `.analysis_release_zenodo_assert_valid_release_id(allow_latest = FALSE)`
   152	#'   immediately after coercion (Codex round 3, MEDIUM): the package
   153	#'   orchestrator (`analysis_release_zenodo_package()`) already re-validates
   154	#'   the RESOLVED id before calling this function, but this exported helper
   155	#'   can be called directly by other code, and a direct caller passing an
   156	#'   unvalidated `../`/quote/newline-shaped `release_id` would otherwise
   157	#'   reach the URL-building `paste0()` below unchecked. A bundle URL always
   158	#'   targets a concrete id, so `allow_latest` is FALSE here even though
   159	#'   `fetch_head()` permits `"latest"` for its own request arg.
   160	#' @param http_download Function(url, destfile). Injectable seam.
   161	#' @return `destfile`, invisibly-compatible (returned for chaining).
   162	analysis_release_zenodo_download_bundle <- function(
   163	    api_base_url,
   164	    release_id,
   165	    destfile,
   166	    http_download = .analysis_release_zenodo_http_download) {
   167	  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
   168	  release_id <- as.character(release_id)[[1]]
   169	  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
   170	  url <- paste0(base_url, "/api/analysis/releases/", release_id, "/bundle")
   171	  http_download(url, destfile)
   172	  if (!file.exists(destfile) || file.size(destfile) == 0) {
   173	    stop("Analysis-snapshot release bundle download produced an empty file", call. = FALSE)
   174	  }
   175	  destfile
   176	}
   177
   178	# --------------------------------------------------------------------------- #
   179	# Path-traversal guard, shared by both the tar-member listing and the inner
   180	# `checksums.sha256` entries (item 4).
   181	# --------------------------------------------------------------------------- #
   182
   183	#' Stop if any `paths` entry is absolute (POSIX `/...`, a Windows drive
   184	#' letter `X:...`, a leading-backslash root-relative path `\...`, or a UNC
   185	#' path `\\host\share...`) or contains a `..` path segment split on EITHER
   186	#' `/` OR `\` (Codex round-2 item 4, MEDIUM: the original check split only on
   187	#' `/`, so `..\escape` and `\\host\share` slipped through). Used on BOTH the
   188	#' tar member list (before extraction) and every `checksums.sha256` entry
   189	#' (before it is resolved to a file under `exdir`) -- a tampered bundle
   190	#' cannot escape the extraction directory via either separator convention.
   191	.analysis_release_zenodo_assert_no_traversal <- function(paths, context) {
   192	  offenders <- Filter(function(p) {
   193	    startsWith(p, "/") || startsWith(p, "\\") || grepl("^[A-Za-z]:", p) ||
   194	      any(strsplit(p, "[/\\\\]")[[1]] == "..")
   195	  }, paths)
   196	  if (length(offenders) > 0) {
   197	    stop(sprintf(
   198	      "%s path traversal rejected: %s", context, paste(offenders, collapse = ", ")
   199	    ), call. = FALSE)
   200	  }
   201	  invisible(TRUE)
   202	}
   203
   204	# --------------------------------------------------------------------------- #
   205	# Symlink / non-regular-file rejection -- shared between the EXTRACTED bundle
   206	# tree (called immediately after untar(), before any hashing/copying -- item
   207	# 1, HIGH) and the staging tree (the pre-existing safety validator).
   208	# --------------------------------------------------------------------------- #
   209
   210	#' Reject symlinks AND any other non-regular file (FIFO/pipe, socket, device,
   211	#' ...) anywhere under `root_dir`. A symlink is detected via
   212	#' `Sys.readlink(path) != ""` -- on this Linux host runtime `Sys.readlink()`
   213	#' returns the link target for a symlink, `""` otherwise. Directories are
   214	#' identified via `list.files(..., include.dirs = TRUE)` and are always
   215	#' allowed. Every remaining entry (not a directory, not a symlink) MUST be a
   216	#' real regular file per `fs::file_info(path)$type == "file"`; anything else
   217	#' is rejected.
   218	#'
   219	#' Codex round 3 (HIGH): the earlier version of this guard only detected
   220	#' symlinks and reasoned that "everything else the pure-R `untar()` engine can
   221	#' create is either a regular file or a symlink" -- true for tar member TYPES
   222	#' the pure-R engine writes, but a bundle's `checksums.sha256` entry could
   223	#' still name a path that resolves to a special file placed some other way
   224	#' (or a future tar implementation change), and `digest::digest(file = ...)`
   225	#' on a FIFO/pipe blocks INDEFINITELY waiting for a writer that will never
   226	#' come -- a fail-closed violation (a malicious/corrupt bundle could hang the
   227	#' operator's extraction run forever instead of failing loudly).
   228	#'
   229	#' Deliberately uses `fs::file_info()$type` (already a repo dependency, see
   230	#' `functions/backup-functions.R`/`logging-functions.R`), NOT base R's
   231	#' `file_test("-f", path)`: verified against R's own source
   232	#' (`utils:::file_test`), `"-f"` is implemented as
   233	#' `!is.na(file.info(x)$isdir) & !file.info(x)$isdir` -- i.e. "exists and is
   234	#' not a directory" -- which is TRUE for a FIFO/socket/device too (confirmed
   235	#' empirically: `file_test("-f", <a real fifo>)` returns `TRUE` on this
   236	#' runtime). Using it here would silently fail to close this exact gap.
   237	#' `fs::file_info()$type` reports the real POSIX file type (`"file"`,
   238	#' `"FIFO"`, `"socket"`, `"character_device"`, `"block_device"`, ...) so a
   239	#' FIFO is genuinely distinguished from a regular file.
   240	#'
   241	#' Checks BOTH files and directory entries so a symlinked directory is caught
   242	#' even if `list.files()` would otherwise silently walk through it.
   243	#'
   244	#' @param root_dir Root of the tree to walk.
   245	#' @param context Prefix for the error message (identifies which tree).
   246	.analysis_release_zenodo_reject_unsafe_files <- function(root_dir, context) {
   247	  rel_paths <- list.files(
   248	    root_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE,
   249	    full.names = FALSE, include.dirs = TRUE
   250	  )
   251	  symlink_offenders <- Filter(function(rel_path) {
   252	    full_path <- file.path(root_dir, rel_path)
   253	    target <- suppressWarnings(Sys.readlink(full_path))
   254	    !is.na(target) && nzchar(target)
   255	  }, rel_paths)
   256
   257	  if (length(symlink_offenders) > 0) {
   258	    stop(sprintf(
   259	      "%s contains symlinks (not allowed): %s",
   260	      context, paste(sort(symlink_offenders), collapse = ", ")
   261	    ), call. = FALSE)
   262	  }
   263
   264	  # Item 1 (HIGH): every remaining non-directory entry must be a real regular
   265	  # file. Evaluated AFTER the symlink check above (by this point every
   266	  # remaining rel_path is confirmed non-symlink), and BEFORE any caller reads
   267	  # the file's bytes (e.g. `digest::digest(file = ...)`), which would
   268	  # otherwise block indefinitely on a FIFO/pipe. `fs::file_info()` itself
   269	  # only stats the path (never opens/reads it), so this check cannot block
   270	  # even when `full_path` is a FIFO.
   271	  non_regular_offenders <- Filter(function(rel_path) {
   272	    full_path <- file.path(root_dir, rel_path)
   273	    if (dir.exists(full_path)) {
   274	      return(FALSE)
   275	    }
   276	    !identical(as.character(fs::file_info(full_path)$type), "file")
   277	  }, rel_paths)
   278
   279	  if (length(non_regular_offenders) > 0) {
   280	    stop(sprintf(
   281	      "%s contains non-regular file(s) (not allowed): %s",
   282	      context, paste(sort(non_regular_offenders), collapse = ", ")
   283	    ), call. = FALSE)
   284	  }
   285	  invisible(TRUE)
   286	}
   287
   288	#' Verify a downloaded bundle against the release head's `bundle_sha256`,
   289	#' extract it, then verify the bundle's OWN inner `checksums.sha256` against
   290	#' every extracted file. Mirrors `nddscore_extract_and_verify()`'s verify
   291	#' loop, but the outer digest is SHA-256 (not MD5), and the release bundle's
   292	#' files sit directly at the archive root (no named top-level subdirectory
   293	#' to search for).
   294	#'
   295	#' Hardening: (1, item 4) every tar member path and every `checksums.sha256`
   296	#' entry is rejected if absolute or containing a `..` segment (either `/` or
   297	#' `\` separated), BEFORE it is ever joined onto `exdir`; (2, item 1, HIGH)
   298	#' IMMEDIATELY after extraction and BEFORE any hashing or copying, the whole
   299	#' extracted tree (INCLUDING `checksums.sha256` itself) is walked and any
   300	#' symlink OR other non-regular file (FIFO/pipe, socket, device, ...) is
   301	#' rejected -- `digest::digest(file = ...)` and `file.copy()` both follow
   302	#' symlinks transparently, so a symlinked release member could otherwise pull
   303	#' host-readable content into the archive undetected, and a FIFO would
   304	#' otherwise block `digest::digest()` indefinitely (Codex round 3, HIGH); (3)
   305	#' after the existing per-line checksum verification, COVERAGE is asserted --
   306	#' every extracted regular file except `checksums.sha256` itself must appear
   307	#' EXACTLY ONCE in the checksums list, so a tampered bundle that drops a
   308	#' checksum line for a present file (or lists the same path twice) fails
   309	#' loudly instead of silently passing.
   310	#'
   311	#' @param bundle_path Path to the downloaded `bundle.tar.gz`.
   312	#' @param expected_bundle_sha256 The release head's `bundle_sha256`.
   313	#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
   314	#' @return Path to the extraction directory (== `exdir`).
   315	analysis_release_zenodo_extract_and_verify <- function(
   316	    bundle_path, expected_bundle_sha256, exdir = NULL) {
   317	  if (!file.exists(bundle_path)) {
   318	    stop("Analysis-snapshot release bundle not found for verification", call. = FALSE)
   319	  }
   320	  actual_bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
   321	  expected <- tolower(as.character(expected_bundle_sha256 %||% "")[[1]])
   322	  if (!identical(tolower(actual_bundle_sha256), expected)) {
   323	    stop(sprintf(
   324	      "Analysis-snapshot release bundle checksum mismatch (expected %s, got %s)",
   325	      expected, actual_bundle_sha256
   326	    ), call. = FALSE)
   327	  }
   328
   329	  tar_entries <- utils::untar(bundle_path, list = TRUE)
   330	  .analysis_release_zenodo_assert_no_traversal(tar_entries, context = "tar member")
   331
   332	  if (is.null(exdir)) {
   333	    exdir <- file.path(
   334	      tempdir(), paste0("analysis_release_zenodo_extract_", as.integer(stats::runif(1, 1, 1e9)))
   335	    )
   336	  }
   337	  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
   338	  utils::untar(bundle_path, exdir = exdir)
   339
   340	  # Item 1 (HIGH): reject any symlink OR other non-regular file in the
   341	  # EXTRACTED tree immediately, before any file below is hashed or copied --
   342	  # see the hardening note above.
   343	  .analysis_release_zenodo_reject_unsafe_files(exdir, "Extracted release bundle")
   344
   345	  sha_file <- file.path(exdir, "checksums.sha256")
   346	  if (!file.exists(sha_file)) {
   347	    stop("Extracted release bundle has no checksums.sha256", call. = FALSE)
   348	  }
   349	  sha_lines <- readLines(sha_file, warn = FALSE)
   350	  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
   351
   352	  checksummed_paths <- character(0)
   353	  for (line in sha_lines) {
   354	    parts <- strsplit(trimws(line), "\\s+")[[1]]
   355	    expected_sha <- parts[[1]]
   356	    rel_name <- parts[[length(parts)]]
   357	    .analysis_release_zenodo_assert_no_traversal(rel_name, context = "checksums.sha256 entry")
   358	    target <- file.path(exdir, rel_name)
   359	    if (!file.exists(target)) {
   360	      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name), call. = FALSE)
   361	    }
   362	    actual_sha <- digest::digest(file = target, algo = "sha256")
   363	    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
   364	      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name), call. = FALSE)
   365	    }
   366	    checksummed_paths <- c(checksummed_paths, rel_name)
   367	  }
   368
   369	  duplicate_entries <- unique(checksummed_paths[duplicated(checksummed_paths)])
   370	  if (length(duplicate_entries) > 0) {
   371	    stop(sprintf(
   372	      "checksums.sha256 lists duplicate entries: %s", paste(duplicate_entries, collapse = ", ")
   373	    ), call. = FALSE)
   374	  }
   375
   376	  extracted_files <- list.files(exdir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
   377	  extracted_files <- extracted_files[extracted_files != "checksums.sha256"]
   378	  uncovered <- base::setdiff(extracted_files, checksummed_paths)
   379	  if (length(uncovered) > 0) {
   380	    stop(sprintf(
   381	      "Extracted release bundle contains file(s) not listed in checksums.sha256: %s",
   382	      paste(sort(uncovered), collapse = ", ")
   383	    ), call. = FALSE)
   384	  }
   385
   386	  exdir
   387	}
   388
   389	# --------------------------------------------------------------------------- #
   390	# Shared public-file iterator -- filter-at-source, reused by every
   391	# builder/checksums/validator step (belt half of belt-and-suspenders).
   392	# Case-insensitive (item 3) and excludes the staging-ownership sentinel
   393	# (item 1), which is an internal marker, never a shipped release file.
   394	# --------------------------------------------------------------------------- #
   395
   396	#' Sorted, files-only, relative POSIX paths under `root_dir`, excluding
   397	#' forbidden filenames, any path with a forbidden dir-part segment, and the
   398	#' staging-ownership sentinel. Matching is case-insensitive.
   399	#'
   400	#' @return character vector of relative paths ("/"-separated).
   401	.analysis_release_zenodo_iter_public_files <- function(root_dir) {
   402	  all_files <- list.files(
   403	    root_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
   404	  )
   405	  keep <- vapply(all_files, function(rel_path) {
   406	    if (rel_path == .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL) {
   407	      return(FALSE)
   408	    }
   409	    base <- tolower(basename(rel_path))
   410	    if (base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES) {
   411	      return(FALSE)
   412	    }
   413	    segments <- tolower(strsplit(rel_path, "/", fixed = TRUE)[[1]])
   414	    !any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
   415	  }, logical(1))
   416	  sort(all_files[keep])
   417	}
   418
   419	# --------------------------------------------------------------------------- #
   420	# Staging-directory delete guard (item 1, BLOCKER) -- refuse to
   421	# `unlink(recursive = TRUE)` any directory this tool did not itself create.
   422	# --------------------------------------------------------------------------- #
   423
   424	#' TRUE when `staging_dir` is safe for this tool to recursively delete: it
   425	#' does not exist yet, is empty, or carries the ownership sentinel written by
   426	#' a prior run of this tool. A pre-existing, non-empty directory WITHOUT the
   427	#' sentinel is presumed to be an operator typo (e.g. `--staging-dir
   428	#' /important/dir`) and must never be silently rmtree'd.
   429	.analysis_release_zenodo_staging_owned_by_tool <- function(staging_dir) {
   430	  if (!dir.exists(staging_dir)) {
   431	    return(TRUE)
   432	  }
   433	  contents <- list.files(staging_dir, all.files = TRUE, no.. = TRUE)
   434	  if (length(contents) == 0L) {
   435	    return(TRUE)
   436	  }
   437	  file.exists(file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL))
   438	}
   439
   440	#' Stop with a clear, actionable message unless `staging_dir` is safe to
   441	#' recursively delete (see `.analysis_release_zenodo_staging_owned_by_tool()`).
   442	.analysis_release_zenodo_assert_staging_deletable <- function(staging_dir) {
   443	  if (!.analysis_release_zenodo_staging_owned_by_tool(staging_dir)) {
   444	    stop(sprintf(
   445	      paste0(
   446	        "refusing to delete %s: not an analysis-release staging dir; ",
   447	        "remove it manually or choose another --staging-dir"
   448	      ),
   449	      staging_dir
   450	    ), call. = FALSE)
   451	  }
   452	  invisible(TRUE)
   453	}
   454
   455	#' Write the ownership sentinel at the staging root. Called immediately after
   456	#' `dir.create(staging_dir)` (before any other staging content) so a later
   457	#' re-run recognizes this directory as the tool's own even if that later run
   458	#' is interrupted before completing.
   459	.analysis_release_zenodo_write_staging_sentinel <- function(staging_dir) {
   460	  writeLines(
   461	    paste0(
   462	      "This directory is owned by package-analysis-release-zenodo.R and is ",
   463	      "safe for it to recursively replace on the next run. Do not remove ",
   464	      "this file manually if you want that protection to keep applying."
   465	    ),
   466	    file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL)
   467	  )
   468	  invisible(TRUE)
   469	}
   470
   471	# --------------------------------------------------------------------------- #
   472	# THE SAFETY VALIDATOR -- defense in depth, runs LAST before tarring.
   473	# Independent checks; each collects offending paths and stops loudly.
   474	# --------------------------------------------------------------------------- #
   475
   476	.analysis_release_zenodo_validate_no_forbidden <- function(staging_dir) {
   477	  # Deliberately re-walks the tree directly (not via the shared iterator,
   478	  # which already excludes these) -- an independent re-check, not a
   479	  # tautology. Case-insensitive (item 3): both the forbidden filename and
   480	  # forbidden dir-part segments are matched lowercase, so `.ENV`,
   481	  # `.Git/config`, etc. no longer slip through.
   482	  all_files <- list.files(
   483	    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
   484	  )
   485	  offenders <- Filter(function(rel_path) {
   486	    base <- tolower(basename(rel_path))
   487	    segments <- tolower(strsplit(rel_path, "/", fixed = TRUE)[[1]])
   488	    base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES ||
   489	      any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
   490	  }, all_files)
   491
   492	  if (length(offenders) > 0) {
   493	    stop(sprintf(
   494	      "Zenodo staging contains private files: %s",
   495	      paste(sort(offenders), collapse = ", ")
   496	    ), call. = FALSE)
   497	  }
   498	  invisible(TRUE)
   499	}
   500
   501	#' Reject symlinks / non-regular files anywhere in the staging tree (item 3)
   502	#' -- a symlink could point outside the archive, or at a private file
   503	#' `utils::tar()` would then follow and embed verbatim. Delegates to the
   504	#' shared `.analysis_release_zenodo_reject_unsafe_files()` (same check now
   505	#' also run on the EXTRACTED bundle tree, see `extract_and_verify()` above)
   506	#' so both trees are guarded by one implementation.
   507	.analysis_release_zenodo_validate_no_symlinks <- function(staging_dir) {
   508	  .analysis_release_zenodo_reject_unsafe_files(staging_dir, "Zenodo staging")
   509	}
   510
   511	.analysis_release_zenodo_has_allowed_suffix <- function(rel_path) {
   512	  lower <- tolower(rel_path)
   513	  any(vapply(
   514	    .ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES,
   515	    function(suffix) endsWith(lower, suffix), logical(1)
   516	  ))
   517	}
   518
   519	#' File-type ALLOWLIST (item 3): any staged regular file whose (lowercased)
   520	#' suffix is not in `.ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES` fails
   521	#' validation. This catches `.csv`/`.pem`/extensionless/binary secret files
   522	#' without needing to scan binary content -- a well-formed analysis-release
   523	#' staging tree only ever contains the release payload/docs suffixes.
   524	.analysis_release_zenodo_validate_allowed_suffix <- function(staging_dir) {
   525	  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
   526	  offenders <- Filter(
   527	    function(rel_path) !.analysis_release_zenodo_has_allowed_suffix(rel_path), rel_paths
   528	  )
   529	  if (length(offenders) > 0) {
   530	    stop(sprintf(
   531	      "Zenodo staging contains file(s) with an unexpected type/suffix: %s",
   532	      paste(offenders, collapse = ", ")
   533	    ), call. = FALSE)
   534	  }
   535	  invisible(TRUE)
   536	}
   537
   538	.analysis_release_zenodo_validate_no_sensitive_text <- function(staging_dir) {
   539	  offenders <- character(0)
   540	  for (rel_path in .analysis_release_zenodo_iter_public_files(staging_dir)) {
   541	    if (!.analysis_release_zenodo_has_allowed_suffix(rel_path)) {
   542	      next
   543	    }
   544	    full_path <- file.path(staging_dir, rel_path)
   545	    text <- tolower(paste(readLines(full_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
   546	    hit <- Find(function(pattern) grepl(pattern, text, fixed = TRUE),
   547	                .ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS)
   548	    if (!is.null(hit)) {
   549	      offenders <- c(offenders, sprintf("%s (matched '%s')", rel_path, hit))
   550	    }
   551	  }
   552	  if (length(offenders) > 0) {
   553	    stop(sprintf(
   554	      "Zenodo staging contains sensitive public text: %s",
   555	      paste(offenders, collapse = "; ")
   556	    ), call. = FALSE)
   557	  }
   558	  invisible(TRUE)
   559	}
   560
   561	.analysis_release_zenodo_validate_layout <- function(staging_dir) {
   562	  expected_top <- .ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL
   563	  expected_nested <- file.path(
   564	    .ANALYSIS_RELEASE_ZENODO_NESTED_DIR, .ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED
   565	  )
   566	  expected <- c(expected_top, expected_nested)
   567
   568	  missing <- Filter(function(rel_path) !file.exists(file.path(staging_dir, rel_path)), expected)
   569	  if (length(missing) > 0) {
   570	    stop(sprintf(
   571	      "Zenodo staging is missing expected members: %s",
   572	      paste(missing, collapse = ", ")
   573	    ), call. = FALSE)
   574	  }
   575	  invisible(TRUE)
   576	}
   577
   578	#' The safety validator. Independent checks, in order; stops with a clear
   579	#' message naming the offending relative paths on the first failing check.
   580	analysis_release_zenodo_validate_staging <- function(staging_dir) {
   581	  .analysis_release_zenodo_validate_no_forbidden(staging_dir)
   582	  .analysis_release_zenodo_validate_no_symlinks(staging_dir)
   583	  .analysis_release_zenodo_validate_allowed_suffix(staging_dir)
   584	  .analysis_release_zenodo_validate_no_sensitive_text(staging_dir)
   585	  .analysis_release_zenodo_validate_layout(staging_dir)
   586	  invisible(TRUE)
   587	}
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

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-zenodo-verify.R | sed -n '240,587p'
nl -ba api/functions/analysis-snapshot-release-zenodo-upload.R
nl -ba api/scripts/package-analysis-release-zenodo.R
nl -ba api/scripts/upload-analysis-release-zenodo.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
   240	#'
   241	#' Checks BOTH files and directory entries so a symlinked directory is caught
   242	#' even if `list.files()` would otherwise silently walk through it.
   243	#'
   244	#' @param root_dir Root of the tree to walk.
   245	#' @param context Prefix for the error message (identifies which tree).
   246	.analysis_release_zenodo_reject_unsafe_files <- function(root_dir, context) {
   247	  rel_paths <- list.files(
   248	    root_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE,
   249	    full.names = FALSE, include.dirs = TRUE
   250	  )
   251	  symlink_offenders <- Filter(function(rel_path) {
   252	    full_path <- file.path(root_dir, rel_path)
   253	    target <- suppressWarnings(Sys.readlink(full_path))
   254	    !is.na(target) && nzchar(target)
   255	  }, rel_paths)
   256
   257	  if (length(symlink_offenders) > 0) {
   258	    stop(sprintf(
   259	      "%s contains symlinks (not allowed): %s",
   260	      context, paste(sort(symlink_offenders), collapse = ", ")
   261	    ), call. = FALSE)
   262	  }
   263
   264	  # Item 1 (HIGH): every remaining non-directory entry must be a real regular
   265	  # file. Evaluated AFTER the symlink check above (by this point every
   266	  # remaining rel_path is confirmed non-symlink), and BEFORE any caller reads
   267	  # the file's bytes (e.g. `digest::digest(file = ...)`), which would
   268	  # otherwise block indefinitely on a FIFO/pipe. `fs::file_info()` itself
   269	  # only stats the path (never opens/reads it), so this check cannot block
   270	  # even when `full_path` is a FIFO.
   271	  non_regular_offenders <- Filter(function(rel_path) {
   272	    full_path <- file.path(root_dir, rel_path)
   273	    if (dir.exists(full_path)) {
   274	      return(FALSE)
   275	    }
   276	    !identical(as.character(fs::file_info(full_path)$type), "file")
   277	  }, rel_paths)
   278
   279	  if (length(non_regular_offenders) > 0) {
   280	    stop(sprintf(
   281	      "%s contains non-regular file(s) (not allowed): %s",
   282	      context, paste(sort(non_regular_offenders), collapse = ", ")
   283	    ), call. = FALSE)
   284	  }
   285	  invisible(TRUE)
   286	}
   287
   288	#' Verify a downloaded bundle against the release head's `bundle_sha256`,
   289	#' extract it, then verify the bundle's OWN inner `checksums.sha256` against
   290	#' every extracted file. Mirrors `nddscore_extract_and_verify()`'s verify
   291	#' loop, but the outer digest is SHA-256 (not MD5), and the release bundle's
   292	#' files sit directly at the archive root (no named top-level subdirectory
   293	#' to search for).
   294	#'
   295	#' Hardening: (1, item 4) every tar member path and every `checksums.sha256`
   296	#' entry is rejected if absolute or containing a `..` segment (either `/` or
   297	#' `\` separated), BEFORE it is ever joined onto `exdir`; (2, item 1, HIGH)
   298	#' IMMEDIATELY after extraction and BEFORE any hashing or copying, the whole
   299	#' extracted tree (INCLUDING `checksums.sha256` itself) is walked and any
   300	#' symlink OR other non-regular file (FIFO/pipe, socket, device, ...) is
   301	#' rejected -- `digest::digest(file = ...)` and `file.copy()` both follow
   302	#' symlinks transparently, so a symlinked release member could otherwise pull
   303	#' host-readable content into the archive undetected, and a FIFO would
   304	#' otherwise block `digest::digest()` indefinitely (Codex round 3, HIGH); (3)
   305	#' after the existing per-line checksum verification, COVERAGE is asserted --
   306	#' every extracted regular file except `checksums.sha256` itself must appear
   307	#' EXACTLY ONCE in the checksums list, so a tampered bundle that drops a
   308	#' checksum line for a present file (or lists the same path twice) fails
   309	#' loudly instead of silently passing.
   310	#'
   311	#' @param bundle_path Path to the downloaded `bundle.tar.gz`.
   312	#' @param expected_bundle_sha256 The release head's `bundle_sha256`.
   313	#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
   314	#' @return Path to the extraction directory (== `exdir`).
   315	analysis_release_zenodo_extract_and_verify <- function(
   316	    bundle_path, expected_bundle_sha256, exdir = NULL) {
   317	  if (!file.exists(bundle_path)) {
   318	    stop("Analysis-snapshot release bundle not found for verification", call. = FALSE)
   319	  }
   320	  actual_bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
   321	  expected <- tolower(as.character(expected_bundle_sha256 %||% "")[[1]])
   322	  if (!identical(tolower(actual_bundle_sha256), expected)) {
   323	    stop(sprintf(
   324	      "Analysis-snapshot release bundle checksum mismatch (expected %s, got %s)",
   325	      expected, actual_bundle_sha256
   326	    ), call. = FALSE)
   327	  }
   328
   329	  tar_entries <- utils::untar(bundle_path, list = TRUE)
   330	  .analysis_release_zenodo_assert_no_traversal(tar_entries, context = "tar member")
   331
   332	  if (is.null(exdir)) {
   333	    exdir <- file.path(
   334	      tempdir(), paste0("analysis_release_zenodo_extract_", as.integer(stats::runif(1, 1, 1e9)))
   335	    )
   336	  }
   337	  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
   338	  utils::untar(bundle_path, exdir = exdir)
   339
   340	  # Item 1 (HIGH): reject any symlink OR other non-regular file in the
   341	  # EXTRACTED tree immediately, before any file below is hashed or copied --
   342	  # see the hardening note above.
   343	  .analysis_release_zenodo_reject_unsafe_files(exdir, "Extracted release bundle")
   344
   345	  sha_file <- file.path(exdir, "checksums.sha256")
   346	  if (!file.exists(sha_file)) {
   347	    stop("Extracted release bundle has no checksums.sha256", call. = FALSE)
   348	  }
   349	  sha_lines <- readLines(sha_file, warn = FALSE)
   350	  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
   351
   352	  checksummed_paths <- character(0)
   353	  for (line in sha_lines) {
   354	    parts <- strsplit(trimws(line), "\\s+")[[1]]
   355	    expected_sha <- parts[[1]]
   356	    rel_name <- parts[[length(parts)]]
   357	    .analysis_release_zenodo_assert_no_traversal(rel_name, context = "checksums.sha256 entry")
   358	    target <- file.path(exdir, rel_name)
   359	    if (!file.exists(target)) {
   360	      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name), call. = FALSE)
   361	    }
   362	    actual_sha <- digest::digest(file = target, algo = "sha256")
   363	    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
   364	      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name), call. = FALSE)
   365	    }
   366	    checksummed_paths <- c(checksummed_paths, rel_name)
   367	  }
   368
   369	  duplicate_entries <- unique(checksummed_paths[duplicated(checksummed_paths)])
   370	  if (length(duplicate_entries) > 0) {
   371	    stop(sprintf(
   372	      "checksums.sha256 lists duplicate entries: %s", paste(duplicate_entries, collapse = ", ")
   373	    ), call. = FALSE)
   374	  }
   375
   376	  extracted_files <- list.files(exdir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
   377	  extracted_files <- extracted_files[extracted_files != "checksums.sha256"]
   378	  uncovered <- base::setdiff(extracted_files, checksummed_paths)
   379	  if (length(uncovered) > 0) {
   380	    stop(sprintf(
   381	      "Extracted release bundle contains file(s) not listed in checksums.sha256: %s",
   382	      paste(sort(uncovered), collapse = ", ")
   383	    ), call. = FALSE)
   384	  }
   385
   386	  exdir
   387	}
   388
   389	# --------------------------------------------------------------------------- #
   390	# Shared public-file iterator -- filter-at-source, reused by every
   391	# builder/checksums/validator step (belt half of belt-and-suspenders).
   392	# Case-insensitive (item 3) and excludes the staging-ownership sentinel
   393	# (item 1), which is an internal marker, never a shipped release file.
   394	# --------------------------------------------------------------------------- #
   395
   396	#' Sorted, files-only, relative POSIX paths under `root_dir`, excluding
   397	#' forbidden filenames, any path with a forbidden dir-part segment, and the
   398	#' staging-ownership sentinel. Matching is case-insensitive.
   399	#'
   400	#' @return character vector of relative paths ("/"-separated).
   401	.analysis_release_zenodo_iter_public_files <- function(root_dir) {
   402	  all_files <- list.files(
   403	    root_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
   404	  )
   405	  keep <- vapply(all_files, function(rel_path) {
   406	    if (rel_path == .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL) {
   407	      return(FALSE)
   408	    }
   409	    base <- tolower(basename(rel_path))
   410	    if (base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES) {
   411	      return(FALSE)
   412	    }
   413	    segments <- tolower(strsplit(rel_path, "/", fixed = TRUE)[[1]])
   414	    !any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
   415	  }, logical(1))
   416	  sort(all_files[keep])
   417	}
   418
   419	# --------------------------------------------------------------------------- #
   420	# Staging-directory delete guard (item 1, BLOCKER) -- refuse to
   421	# `unlink(recursive = TRUE)` any directory this tool did not itself create.
   422	# --------------------------------------------------------------------------- #
   423
   424	#' TRUE when `staging_dir` is safe for this tool to recursively delete: it
   425	#' does not exist yet, is empty, or carries the ownership sentinel written by
   426	#' a prior run of this tool. A pre-existing, non-empty directory WITHOUT the
   427	#' sentinel is presumed to be an operator typo (e.g. `--staging-dir
   428	#' /important/dir`) and must never be silently rmtree'd.
   429	.analysis_release_zenodo_staging_owned_by_tool <- function(staging_dir) {
   430	  if (!dir.exists(staging_dir)) {
   431	    return(TRUE)
   432	  }
   433	  contents <- list.files(staging_dir, all.files = TRUE, no.. = TRUE)
   434	  if (length(contents) == 0L) {
   435	    return(TRUE)
   436	  }
   437	  file.exists(file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL))
   438	}
   439
   440	#' Stop with a clear, actionable message unless `staging_dir` is safe to
   441	#' recursively delete (see `.analysis_release_zenodo_staging_owned_by_tool()`).
   442	.analysis_release_zenodo_assert_staging_deletable <- function(staging_dir) {
   443	  if (!.analysis_release_zenodo_staging_owned_by_tool(staging_dir)) {
   444	    stop(sprintf(
   445	      paste0(
   446	        "refusing to delete %s: not an analysis-release staging dir; ",
   447	        "remove it manually or choose another --staging-dir"
   448	      ),
   449	      staging_dir
   450	    ), call. = FALSE)
   451	  }
   452	  invisible(TRUE)
   453	}
   454
   455	#' Write the ownership sentinel at the staging root. Called immediately after
   456	#' `dir.create(staging_dir)` (before any other staging content) so a later
   457	#' re-run recognizes this directory as the tool's own even if that later run
   458	#' is interrupted before completing.
   459	.analysis_release_zenodo_write_staging_sentinel <- function(staging_dir) {
   460	  writeLines(
   461	    paste0(
   462	      "This directory is owned by package-analysis-release-zenodo.R and is ",
   463	      "safe for it to recursively replace on the next run. Do not remove ",
   464	      "this file manually if you want that protection to keep applying."
   465	    ),
   466	    file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL)
   467	  )
   468	  invisible(TRUE)
   469	}
   470
   471	# --------------------------------------------------------------------------- #
   472	# THE SAFETY VALIDATOR -- defense in depth, runs LAST before tarring.
   473	# Independent checks; each collects offending paths and stops loudly.
   474	# --------------------------------------------------------------------------- #
   475
   476	.analysis_release_zenodo_validate_no_forbidden <- function(staging_dir) {
   477	  # Deliberately re-walks the tree directly (not via the shared iterator,
   478	  # which already excludes these) -- an independent re-check, not a
   479	  # tautology. Case-insensitive (item 3): both the forbidden filename and
   480	  # forbidden dir-part segments are matched lowercase, so `.ENV`,
   481	  # `.Git/config`, etc. no longer slip through.
   482	  all_files <- list.files(
   483	    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
   484	  )
   485	  offenders <- Filter(function(rel_path) {
   486	    base <- tolower(basename(rel_path))
   487	    segments <- tolower(strsplit(rel_path, "/", fixed = TRUE)[[1]])
   488	    base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES ||
   489	      any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
   490	  }, all_files)
   491
   492	  if (length(offenders) > 0) {
   493	    stop(sprintf(
   494	      "Zenodo staging contains private files: %s",
   495	      paste(sort(offenders), collapse = ", ")
   496	    ), call. = FALSE)
   497	  }
   498	  invisible(TRUE)
   499	}
   500
   501	#' Reject symlinks / non-regular files anywhere in the staging tree (item 3)
   502	#' -- a symlink could point outside the archive, or at a private file
   503	#' `utils::tar()` would then follow and embed verbatim. Delegates to the
   504	#' shared `.analysis_release_zenodo_reject_unsafe_files()` (same check now
   505	#' also run on the EXTRACTED bundle tree, see `extract_and_verify()` above)
   506	#' so both trees are guarded by one implementation.
   507	.analysis_release_zenodo_validate_no_symlinks <- function(staging_dir) {
   508	  .analysis_release_zenodo_reject_unsafe_files(staging_dir, "Zenodo staging")
   509	}
   510
   511	.analysis_release_zenodo_has_allowed_suffix <- function(rel_path) {
   512	  lower <- tolower(rel_path)
   513	  any(vapply(
   514	    .ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES,
   515	    function(suffix) endsWith(lower, suffix), logical(1)
   516	  ))
   517	}
   518
   519	#' File-type ALLOWLIST (item 3): any staged regular file whose (lowercased)
   520	#' suffix is not in `.ANALYSIS_RELEASE_ZENODO_ALLOWED_SUFFIXES` fails
   521	#' validation. This catches `.csv`/`.pem`/extensionless/binary secret files
   522	#' without needing to scan binary content -- a well-formed analysis-release
   523	#' staging tree only ever contains the release payload/docs suffixes.
   524	.analysis_release_zenodo_validate_allowed_suffix <- function(staging_dir) {
   525	  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
   526	  offenders <- Filter(
   527	    function(rel_path) !.analysis_release_zenodo_has_allowed_suffix(rel_path), rel_paths
   528	  )
   529	  if (length(offenders) > 0) {
   530	    stop(sprintf(
   531	      "Zenodo staging contains file(s) with an unexpected type/suffix: %s",
   532	      paste(offenders, collapse = ", ")
   533	    ), call. = FALSE)
   534	  }
   535	  invisible(TRUE)
   536	}
   537
   538	.analysis_release_zenodo_validate_no_sensitive_text <- function(staging_dir) {
   539	  offenders <- character(0)
   540	  for (rel_path in .analysis_release_zenodo_iter_public_files(staging_dir)) {
   541	    if (!.analysis_release_zenodo_has_allowed_suffix(rel_path)) {
   542	      next
   543	    }
   544	    full_path <- file.path(staging_dir, rel_path)
   545	    text <- tolower(paste(readLines(full_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
   546	    hit <- Find(function(pattern) grepl(pattern, text, fixed = TRUE),
   547	                .ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS)
   548	    if (!is.null(hit)) {
   549	      offenders <- c(offenders, sprintf("%s (matched '%s')", rel_path, hit))
   550	    }
   551	  }
   552	  if (length(offenders) > 0) {
   553	    stop(sprintf(
   554	      "Zenodo staging contains sensitive public text: %s",
   555	      paste(offenders, collapse = "; ")
   556	    ), call. = FALSE)
   557	  }
   558	  invisible(TRUE)
   559	}
   560
   561	.analysis_release_zenodo_validate_layout <- function(staging_dir) {
   562	  expected_top <- .ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL
   563	  expected_nested <- file.path(
   564	    .ANALYSIS_RELEASE_ZENODO_NESTED_DIR, .ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED
   565	  )
   566	  expected <- c(expected_top, expected_nested)
   567
   568	  missing <- Filter(function(rel_path) !file.exists(file.path(staging_dir, rel_path)), expected)
   569	  if (length(missing) > 0) {
   570	    stop(sprintf(
   571	      "Zenodo staging is missing expected members: %s",
   572	      paste(missing, collapse = ", ")
   573	    ), call. = FALSE)
   574	  }
   575	  invisible(TRUE)
   576	}
   577
   578	#' The safety validator. Independent checks, in order; stops with a clear
   579	#' message naming the offending relative paths on the first failing check.
   580	analysis_release_zenodo_validate_staging <- function(staging_dir) {
   581	  .analysis_release_zenodo_validate_no_forbidden(staging_dir)
   582	  .analysis_release_zenodo_validate_no_symlinks(staging_dir)
   583	  .analysis_release_zenodo_validate_allowed_suffix(staging_dir)
   584	  .analysis_release_zenodo_validate_no_sensitive_text(staging_dir)
   585	  .analysis_release_zenodo_validate_layout(staging_dir)
   586	  invisible(TRUE)
   587	}
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
    28	# (`analysis_release_zenodo_record_doi()`/`analysis_release_zenodo_manual_doi_command()`/
    29	# `analysis_release_zenodo_print_doi_record_back()` below); the CLI script
    30	# only wires flags/env into the latter, so this file stays the single place
    31	# that decides WHEN a DOI is recorded/printed and is easy to test in
    32	# isolation.
    33	#
    34	# Codex round-2 hardening (item 2, HIGH): the DOI/record-back path takes an
    35	# operator-supplied `--release-id` and both builds an admin PATCH URL from it
    36	# AND interpolates it into a printed single-quoted `curl` command -- so an
    37	# unvalidated value is a path/URL-injection AND a copy/paste
    38	# command-injection vector. Every DOI URL/command builder below calls the
    39	# shared `.analysis_release_zenodo_assert_valid_release_id()` (guard-sourced
    40	# from the sibling `analysis-snapshot-release-zenodo-common.R`, same
    41	# validator the package/verify path already used) FIRST, and
    42	# `manual_doi_command()` additionally `shQuote()`s every interpolated value
    43	# as defense in depth.
    44
    45	if (!exists(".analysis_release_zenodo_common_loaded", mode = "logical")) {
    46	  # Same self-locating guard-source idiom as `-package.R`'s docs/verify
    47	  # blocks and `-verify.R`'s own common guard block: resolves this file's
    48	  # own directory from the active source() frame so the sibling common file
    49	  # loads regardless of cwd or how this file was sourced (directly by the
    50	  # CLI script, or by `source_api_file()` in tests).
    51	  .analysis_release_zenodo_common_self_dir <- local({
    52	    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
    53	    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
    54	  })
    55	  .analysis_release_zenodo_common_candidates <- c(
    56	    if (!is.null(.analysis_release_zenodo_common_self_dir)) {
    57	      file.path(.analysis_release_zenodo_common_self_dir, "analysis-snapshot-release-zenodo-common.R")
    58	    },
    59	    "functions/analysis-snapshot-release-zenodo-common.R",
    60	    "/app/functions/analysis-snapshot-release-zenodo-common.R"
    61	  )
    62	  for (.analysis_release_zenodo_common_path in .analysis_release_zenodo_common_candidates) {
    63	    if (file.exists(.analysis_release_zenodo_common_path)) {
    64	      # local = TRUE: evaluate into THIS call's parent frame (same reasoning
    65	      # as `-package.R`'s guard blocks).
    66	      source(.analysis_release_zenodo_common_path, local = TRUE)
    67	      break
    68	    }
    69	  }
    70	  rm(
    71	    .analysis_release_zenodo_common_self_dir, .analysis_release_zenodo_common_candidates,
    72	    .analysis_release_zenodo_common_path
    73	  )
    74	}
    75
    76	# --------------------------------------------------------------------------- #
    77	# Zenodo API base URLs + publish safety interlock
    78	# --------------------------------------------------------------------------- #
    79
    80	.ANALYSIS_RELEASE_ZENODO_API_PROD <- "https://zenodo.org/api"
    81	.ANALYSIS_RELEASE_ZENODO_API_SANDBOX <- "https://sandbox.zenodo.org/api"
    82
    83	#' Resolve the Zenodo API base URL for the requested environment.
    84	analysis_release_zenodo_resolve_api <- function(sandbox = FALSE) {
    85	  if (isTRUE(sandbox)) {
    86	    .ANALYSIS_RELEASE_ZENODO_API_SANDBOX
    87	  } else {
    88	    .ANALYSIS_RELEASE_ZENODO_API_PROD
    89	  }
    90	}
    91
    92	#' Stop unless BOTH `publish` and `confirm_publish` are set. A `publish`
    93	#' request without explicit confirmation is refused -- draft-only is the
    94	#' default, safe outcome. Mirrors the Python sibling's
    95	#' `require_publish_confirmation()` (there a `SystemExit`; here a `stop()`).
    96	analysis_release_zenodo_require_publish_confirmation <- function(publish, confirm_publish) {
    97	  if (isTRUE(publish) && !isTRUE(confirm_publish)) {
    98	    stop("--publish requires --confirm-publish", call. = FALSE)
    99	  }
   100	  invisible(NULL)
   101	}
   102
   103	# --------------------------------------------------------------------------- #
   104	# DI seams: default httr2 implementations. Tests inject plain stub closures
   105	# with the SAME formal signature instead of mocking httr2/network calls.
   106	# --------------------------------------------------------------------------- #
   107
   108	#' Default JSON request against the Zenodo deposit API. `token` is turned
   109	#' into a `Authorization: Bearer <token>` header; a non-NULL `body` is sent
   110	#' as a JSON object (Content-Type set by `httr2::req_body_json()`). The
   111	#' create-deposition call passes `body = list()`, which `jsonlite::toJSON()`
   112	#' would otherwise serialize as `[]` (an empty *array*) rather than the `{}`
   113	#' Zenodo's API expects for "create an empty deposition" -- special-cased via
   114	#' `req_body_raw()` so the wire format is the literal JSON object Zenodo
   115	#' documents.
   116	.analysis_release_zenodo_http_json <- function(method, url, token, body = NULL) {
   117	  req <- httr2::request(url) |>
   118	    httr2::req_method(method) |>
   119	    httr2::req_headers(Authorization = paste("Bearer", as.character(token)[[1]])) |>
   120	    httr2::req_timeout(60)
   121
   122	  if (!is.null(body)) {
   123	    req <- if (is.list(body) && length(body) == 0) {
   124	      httr2::req_body_raw(req, "{}", type = "application/json")
   125	    } else {
   126	      httr2::req_body_json(req, body, auto_unbox = TRUE)
   127	    }
   128	  }
   129
   130	  resp <- httr2::req_perform(req)
   131	  httr2::resp_body_json(resp, simplifyVector = FALSE)
   132	}
   133
   134	#' Default streaming file PUT to a Zenodo bucket URL. Streams `archive_path`
   135	#' from disk as the raw request body (`httr2::req_body_file()`), Bearer auth,
   136	#' a long timeout (large archives, slow upload links).
   137	.analysis_release_zenodo_http_put_file <- function(url, token, archive_path) {
   138	  httr2::request(url) |>
   139	    httr2::req_method("PUT") |>
   140	    httr2::req_headers(Authorization = paste("Bearer", as.character(token)[[1]])) |>
   141	    httr2::req_timeout(3600) |>
   142	    httr2::req_body_file(archive_path) |>
   143	    httr2::req_perform()
   144	}
   145
   146	# --------------------------------------------------------------------------- #
   147	# Deposition lifecycle
   148	# --------------------------------------------------------------------------- #
   149
   150	#' Get-or-create a Zenodo deposition. `deposition_id = NULL` creates a fresh
   151	#' draft (`POST {api}/deposit/depositions` with an empty JSON object body);
   152	#' an explicit id reuses an existing draft (`GET
   153	#' {api}/deposit/depositions/{id}`). Returns the parsed deposition list.
   154	#'
   155	#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
   156	#'   Injectable seam; defaults to the real httr2 call.
   157	analysis_release_zenodo_get_or_create_deposition <- function(
   158	    api, token, deposition_id = NULL, http = .analysis_release_zenodo_http_json) {
   159	  api <- sub("/+$", "", as.character(api)[[1]])
   160	  if (is.null(deposition_id)) {
   161	    http("POST", paste0(api, "/deposit/depositions"), token, body = list())
   162	  } else {
   163	    deposition_id <- as.character(deposition_id)[[1]]
   164	    http("GET", paste0(api, "/deposit/depositions/", deposition_id), token)
   165	  }
   166	}
   167
   168	#' Overwrite a deposition's metadata. `PUT {api}/deposit/depositions/{id}`
   169	#' with body `{"metadata": <metadata>}`.
   170	#'
   171	#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
   172	analysis_release_zenodo_set_metadata <- function(
   173	    api, token, deposition_id, metadata, http = .analysis_release_zenodo_http_json) {
   174	  api <- sub("/+$", "", as.character(api)[[1]])
   175	  deposition_id <- as.character(deposition_id)[[1]]
   176	  url <- paste0(api, "/deposit/depositions/", deposition_id)
   177	  http("PUT", url, token, body = list(metadata = metadata))
   178	}
   179
   180	#' Stream the archive to the deposition's Zenodo bucket.
   181	#' `PUT {bucket_url}/{basename(archive_path)}`.
   182	#'
   183	#' @param put Function(url, token, archive_path). Injectable seam; defaults
   184	#'   to the real httr2 streaming PUT.
   185	#' @return The upload URL, invisibly.
   186	analysis_release_zenodo_upload_bucket <- function(
   187	    bucket_url, token, archive_path, put = .analysis_release_zenodo_http_put_file) {
   188	  bucket_url <- sub("/+$", "", as.character(bucket_url)[[1]])
   189	  url <- paste0(bucket_url, "/", basename(archive_path))
   190	  put(url, token, archive_path)
   191	  invisible(url)
   192	}
   193
   194	#' Publish a draft deposition. `POST
   195	#' {api}/deposit/depositions/{id}/actions/publish`. Returns the published
   196	#' deposition (`{doi, conceptdoi, id, links: {html, ...}}`).
   197	#'
   198	#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
   199	analysis_release_zenodo_publish_deposition <- function(
   200	    api, token, deposition_id, http = .analysis_release_zenodo_http_json) {
   201	  api <- sub("/+$", "", as.character(api)[[1]])
   202	  deposition_id <- as.character(deposition_id)[[1]]
   203	  url <- paste0(api, "/deposit/depositions/", deposition_id, "/actions/publish")
   204	  http("POST", url, token)
   205	}
   206
   207	# --------------------------------------------------------------------------- #
   208	# DOI record-back (OPT-IN, SysNDD-admin side) -- additive metadata, outside
   209	# any release content hash. Never called automatically; the CLI script only
   210	# invokes `analysis_release_zenodo_record_doi()` when the operator passes
   211	# `--record-doi` AND `SYSNDD_ADMIN_TOKEN` is set. Otherwise it prints
   212	# `analysis_release_zenodo_manual_doi_command()` so the operator can record
   213	# it by hand.
   214	# --------------------------------------------------------------------------- #
   215
   216	.ANALYSIS_RELEASE_ZENODO_DOI_FIELD_NAMES <- c(
   217	  "zenodo_record_id", "zenodo_record_url", "version_doi", "concept_doi"
   218	)
   219
   220	#' Keep only the four recognized DOI fields with a non-empty value. An
   221	#' omitted/NULL/NA/empty-string field is dropped, never forwarded as "",
   222	#' NULL, or NA -- the admin endpoint treats an omitted field as "leave
   223	#' unchanged", so a forwarded empty value would incorrectly clear it.
   224	#' `is.na()` is checked BEFORE `nzchar()` because `nzchar(NA_character_)` is
   225	#' TRUE in R -- without the guard an NA field survives the filter and is
   226	#' emitted as an explicit `null` instead of being omitted.
   227	.analysis_release_zenodo_doi_non_empty_fields <- function(doi_fields) {
   228	  doi_fields <- doi_fields[names(doi_fields) %in% .ANALYSIS_RELEASE_ZENODO_DOI_FIELD_NAMES]
   229	  Filter(function(value) {
   230	    if (is.null(value) || length(value) == 0) {
   231	      return(FALSE)
   232	    }
   233	    scalar <- value[[1]]
   234	    if (is.na(scalar)) {
   235	      return(FALSE)
   236	    }
   237	    nzchar(trimws(as.character(scalar)))
   238	  }, doi_fields)
   239	}
   240
   241	#' PATCH the four Zenodo/DOI provenance fields onto a published release head.
   242	#' Additive-only: forwards ONLY the supplied non-empty fields, matching the
   243	#' admin endpoint's "an omitted field is left unchanged, never nulled out"
   244	#' contract (see AGENTS.md "Analysis-snapshot releases (#573)").
   245	#'
   246	#' @param sysndd_api_base_url Base URL of the SysNDD API.
   247	#' @param admin_token A pre-minted SysNDD Administrator bearer token
   248	#'   (`SYSNDD_ADMIN_TOKEN`). Distinct from the Zenodo `token` used elsewhere
   249	#'   in this file.
   250	#' @param release_id Validated via
   251	#'   `.analysis_release_zenodo_assert_valid_release_id()` BEFORE the admin
   252	#'   PATCH URL is built (Codex round-2 item 2, HIGH) -- an invalid id
   253	#'   (`../evil`, a quote/`;`/newline-shaped value, ...) stops here, before it
   254	#'   is ever placed into the URL.
   255	#' @param patch Function(method, url, token, body = NULL) -> parsed JSON list.
   256	#'   Injectable seam; defaults to the real httr2 call.
   257	analysis_release_zenodo_record_doi <- function(
   258	    sysndd_api_base_url, admin_token, release_id, doi_fields,
   259	    patch = .analysis_release_zenodo_http_json) {
   260	  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
   261	  release_id <- as.character(release_id)[[1]]
   262	  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
   263	  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
   264	  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
   265	  patch("PATCH", url, admin_token, body = fields)
   266	}
   267
   268	#' Build the exact `curl -X PATCH ...` command an operator can run by hand to
   269	#' record DOI/record provenance when `--record-doi` was not opted into (the
   270	#' default). Never executed automatically.
   271	#'
   272	#' Codex round-2 item 2 (HIGH): `release_id` is validated via
   273	#' `.analysis_release_zenodo_assert_valid_release_id()` BEFORE the URL or
   274	#' command string is built -- an invalid id stops here rather than becoming a
   275	#' path-altering URL segment or a copy/paste command-injection payload once
   276	#' printed. Defense in depth: the resolved URL and the JSON body are each
   277	#' `shQuote()`d (POSIX `sh` quoting -- wraps in single quotes and escapes any
   278	#' embedded single quote), so even a doi_fields VALUE containing a quote,
   279	#' `;`, or a newline cannot break out of the single-quoted `curl` arguments.
   280	analysis_release_zenodo_manual_doi_command <- function(sysndd_api_base_url, release_id, doi_fields) {
   281	  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
   282	  release_id <- as.character(release_id)[[1]]
   283	  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
   284	  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
   285	  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
   286	  body_json <- as.character(jsonlite::toJSON(fields, auto_unbox = TRUE))
   287
   288	  paste0(
   289	    "curl -X PATCH ", shQuote(url), " ",
   290	    "-H 'Authorization: Bearer <SYSNDD_ADMIN_TOKEN>' ",
   291	    "-H 'Content-Type: application/json' ",
   292	    "-d ", shQuote(body_json)
   293	  )
   294	}
   295
   296	# --------------------------------------------------------------------------- #
   297	# DOI record-back print step -- the CLI-facing decision of WHEN to
   298	# auto-record vs. print a manual command vs. print instructions-only.
   299	# Lives here (not in the CLI script) so it is directly unit-testable via
   300	# `source_api_file()`, the same convention as the rest of this file.
   301	# --------------------------------------------------------------------------- #
   302
   303	#' Print the (opt-in) DOI record-back step after `analysis_release_zenodo_upload()`
   304	#' completes. Never calls the SysNDD admin endpoint unless the operator
   305	#' explicitly asked for it (`--record-doi`) AND supplied credentials
   306	#' (`SYSNDD_ADMIN_TOKEN`) AND the run reached a real, published DOI.
   307	#'
   308	#' Codex round-2 hardening:
   309	#' - item 2 (HIGH): `release_id` is validated via
   310	#'   `.analysis_release_zenodo_assert_valid_release_id()` immediately after
   311	#'   the "no id supplied" short-circuit and BEFORE any URL or command is
   312	#'   built from it (`record_doi()`/`manual_doi_command()` also validate
   313	#'   internally -- this is defense in depth, not the only gate).
   314	#' - item 3 (MEDIUM): when the upload was a DRAFT (`result$published` is
   315	#'   FALSE), this prints ONLY post-publication instructions -- never a
   316	#'   ready-to-run PATCH command populated with draft values, which would let
   317	#'   an operator record a draft DOI and violate the locked published-only
   318	#'   rule (the automatic `--record-doi` path already gated on `published`;
   319	#'   the PRINTED fallback command previously did not).
   320	#'
   321	#' @param result The list returned by `analysis_release_zenodo_upload()`.
   322	#' @param release_id Operator-supplied `--release-id` (or `NULL`).
   323	#' @param api_base_url Base URL of the SysNDD API.
   324	#' @param record_doi Whether `--record-doi` was passed.
   325	#' @param printer Function(...) used for output; defaults to `cat`.
   326	#'   Injectable seam so tests can capture output without `capture.output()`.
   327	#' @param record_doi_fn Function with `analysis_release_zenodo_record_doi()`'s
   328	#'   signature. Injectable seam (mirrors every other HTTP boundary in this
   329	#'   file) so tests can exercise the automatic-record branch without a real
   330	#'   network call.
   331	analysis_release_zenodo_print_doi_record_back <- function(
   332	    result, release_id, api_base_url, record_doi, printer = cat,
   333	    record_doi_fn = analysis_release_zenodo_record_doi) {
   334	  have_release_id <- !is.null(release_id) && nzchar(as.character(release_id)[[1]])
   335	  if (!have_release_id) {
   336	    printer("\nNo --release-id supplied -- pass one to record or print a DOI record-back command.\n")
   337	    return(invisible(NULL))
   338	  }
   339
   340	  release_id <- as.character(release_id)[[1]]
   341	  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
   342
   343	  if (!isTRUE(result$published)) {
   344	    printer(
   345	      "\nDraft uploaded (not published) -- a draft DOI is never recorded (published-only ",
   346	      "rule). Publish first with --publish --confirm-publish, then re-run with ",
   347	      "--record-doi (and SYSNDD_ADMIN_TOKEN set), or record the DOI by hand once ",
   348	      "the deposition is published.\n",
   349	      sep = ""
   350	    )
   351	    return(invisible(NULL))
   352	  }
   353
   354	  doi_fields <- list(
   355	    zenodo_record_id = as.character(result$deposition_id),
   356	    zenodo_record_url = result$record_url,
   357	    version_doi = result$version_doi,
   358	    concept_doi = result$concept_doi
   359	  )
   360	  have_published_doi <- !is.na(result$version_doi) && nzchar(as.character(result$version_doi))
   361	  admin_token <- Sys.getenv("SYSNDD_ADMIN_TOKEN", "")
   362
   363	  if (isTRUE(record_doi) && nzchar(admin_token) && have_published_doi) {
   364	    updated <- record_doi_fn(
   365	      sysndd_api_base_url = api_base_url,
   366	      admin_token = admin_token,
   367	      release_id = release_id,
   368	      doi_fields = doi_fields
   369	    )
   370	    printer("\nDOI recorded on the SysNDD release head:\n")
   371	    printer(sprintf("  release_id:        %s\n", updated$release_id %||% release_id))
   372	    printer(sprintf("  version_doi:       %s\n", updated$version_doi %||% doi_fields$version_doi))
   373	    printer(sprintf("  zenodo_record_url: %s\n", updated$zenodo_record_url %||% doi_fields$zenodo_record_url))
   374	  } else {
   375	    printer(
   376	      "\nDOI not recorded automatically",
   377	      if (!have_published_doi) " (no published DOI)" else "",
   378	      ". Run with --record-doi and SYSNDD_ADMIN_TOKEN set, ",
   379	      "or record it by hand:\n",
   380	      sep = ""
   381	    )
   382	    printer(analysis_release_zenodo_manual_doi_command(api_base_url, release_id, doi_fields), "\n")
   383	  }
   384	  invisible(NULL)
   385	}
   386
   387	# --------------------------------------------------------------------------- #
   388	# Orchestrator -- mirrors the Python sibling's `main()` flow. Pure w.r.t.
   389	# SysNDD: it never calls `analysis_release_zenodo_record_doi()` itself (the
   390	# CLI script does that, after this returns).
   391	# --------------------------------------------------------------------------- #
   392
   393	#' Upload a packaged Zenodo archive: get-or-create deposition -> set metadata
   394	#' -> stream archive to bucket -> (if `publish`) publish. Draft-only unless
   395	#' BOTH `publish` and `confirm_publish` are set (enforced first, via
   396	#' `analysis_release_zenodo_require_publish_confirmation()`).
   397	#'
   398	#' @return list(deposition_id, reserved_doi, draft_url, published (bool),
   399	#'   version_doi, concept_doi, record_url). `version_doi`/`concept_doi`/
   400	#'   `record_url` are `NA_character_` unless `published` is TRUE.
   401	analysis_release_zenodo_upload <- function(
   402	    archive_path,
   403	    metadata_path,
   404	    token,
   405	    sandbox = FALSE,
   406	    deposition_id = NULL,
   407	    publish = FALSE,
   408	    confirm_publish = FALSE,
   409	    get_or_create_deposition = analysis_release_zenodo_get_or_create_deposition,
   410	    set_metadata = analysis_release_zenodo_set_metadata,
   411	    upload_bucket = analysis_release_zenodo_upload_bucket,
   412	    publish_deposition = analysis_release_zenodo_publish_deposition) {
   413	  analysis_release_zenodo_require_publish_confirmation(publish, confirm_publish)
   414
   415	  if (is.null(token) || !nzchar(as.character(token)[[1]])) {
   416	    # No `--token` CLI flag exists (item 6, #573 Slice C hardening) -- a
   417	    # flag would leak the token into shell history/argv. The `token`
   418	    # parameter here is for programmatic/test callers only; the CLI wrapper
   419	    # always resolves it from `Sys.getenv("ZENODO_TOKEN")`.
   420	    stop("ZENODO_TOKEN not set (export it in your shell before running this script)", call. = FALSE)
   421	  }
   422	  if (!file.exists(archive_path)) {
   423	    stop(sprintf("Archive does not exist: %s", archive_path), call. = FALSE)
   424	  }
   425	  if (!file.exists(metadata_path)) {
   426	    stop(sprintf("Metadata does not exist: %s", metadata_path), call. = FALSE)
   427	  }
   428
   429	  api <- analysis_release_zenodo_resolve_api(sandbox)
   430	  metadata <- jsonlite::fromJSON(metadata_path, simplifyVector = FALSE)
   431
   432	  deposition <- get_or_create_deposition(api, token, deposition_id = deposition_id)
   433	  resolved_deposition_id <- deposition$id
   434	  bucket_url <- deposition$links$bucket
   435	  reserved_doi <- deposition$metadata$prereserve_doi$doi
   436
   437	  set_metadata(api, token, resolved_deposition_id, metadata)
   438	  upload_bucket(bucket_url, token, archive_path)
   439
   440	  result <- list(
   441	    deposition_id = resolved_deposition_id,
   442	    reserved_doi = reserved_doi %||% NA_character_,
   443	    draft_url = deposition$links$html %||% NA_character_,
   444	    published = FALSE,
   445	    version_doi = NA_character_,
   446	    concept_doi = NA_character_,
   447	    record_url = NA_character_
   448	  )
   449
   450	  if (isTRUE(publish)) {
   451	    published_deposition <- publish_deposition(api, token, resolved_deposition_id)
   452	    result$published <- TRUE
   453	    result$version_doi <- published_deposition$doi %||% NA_character_
   454	    result$concept_doi <- published_deposition$conceptdoi %||% NA_character_
   455	    result$record_url <- published_deposition$links$html %||% NA_character_
   456	  }
   457
   458	  result
   459	}
     1	#!/usr/bin/env Rscript
     2	# api/scripts/package-analysis-release-zenodo.R
     3	#
     4	# Thin operator CLI: fetch a PUBLISHED analysis-snapshot release (#573) over
     5	# the public SysNDD HTTP API and assemble a Zenodo-shaped dataset staging
     6	# directory + deterministic tar.gz archive, ready for
     7	# `upload-analysis-release-zenodo.R`.
     8	#
     9	# All packaging logic lives in
    10	# `api/functions/analysis-snapshot-release-zenodo-package.R`
    11	# (`analysis_release_zenodo_package()`, which itself guard-sources the
    12	# sibling `-docs.R` file); this script only parses flags, resolves + sources
    13	# that ONE file, calls the orchestrator, and prints the resulting paths --
    14	# mirroring the sibling
    15	# `../nddscore/scripts/package_sysndd_zenodo_dataset.py`.
    16	#
    17	# Usage (from the repo root, or from api/ -- CWD-independent, see below):
    18	#   Rscript api/scripts/package-analysis-release-zenodo.R \
    19	#     [--api-base-url http://localhost:7778] [--release-id latest] \
    20	#     [--staging-dir outputs/analysis-release-zenodo/staging] \
    21	#     [--archive-dir outputs/analysis-release-zenodo/archive] \
    22	#     [--version <override>]
    23	#
    24	# Requires: httr2, jsonlite, digest (all in api/renv.lock). No DB, no
    25	# bootstrap, no `external_proxy_budget()` -- a pure HTTP client, runnable on
    26	# any host with R (see AGENTS.md "Analysis-snapshot releases (#573)" and
    27	# `.superpowers/sdd/slice-c-scout.md` S3 for why the public API is the read
    28	# path, not the DB).
    29	#
    30	# CWD note: this script resolves
    31	# `api/functions/analysis-snapshot-release-zenodo-package.R` relative to ITS
    32	# OWN file location (via `sys.frame(1)$ofile`, falling back to Rscript's own
    33	# `--file=` argument -- the same idiom `capture-external-fixtures.R` uses),
    34	# so it may be invoked from any working directory; it does NOT assume CWD is
    35	# the repo root or `api/`.
    36
    37	# --------------------------------------------------------------------------- #
    38	# Resolve this script's own directory, then source the packager (functions
    39	# only -- no top-level network calls in that file, so this is safe to do
    40	# unconditionally, even when this CLI script is itself only `source()`d).
    41	# --------------------------------------------------------------------------- #
    42
    43	.package_analysis_release_zenodo_script_dir <- function() {
    44	  script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
    45	  if (is.null(script_file) || !nzchar(script_file)) {
    46	    full_args <- commandArgs(trailingOnly = FALSE)
    47	    file_arg <- grep("^--file=", full_args, value = TRUE)
    48	    script_file <- if (length(file_arg) >= 1) sub("^--file=", "", file_arg[1]) else "."
    49	  }
    50	  dirname(normalizePath(script_file, mustWork = FALSE))
    51	}
    52
    53	.package_analysis_release_zenodo_script_dir_value <- .package_analysis_release_zenodo_script_dir()
    54	source(
    55	  file.path(
    56	    .package_analysis_release_zenodo_script_dir_value, "..", "functions",
    57	    "analysis-snapshot-release-zenodo-package.R"
    58	  ),
    59	  local = FALSE
    60	)
    61
    62	# --------------------------------------------------------------------------- #
    63	# CLI arg parsing -- manual commandArgs() flag loop (repo convention; no
    64	# optparse dependency, see `verify-endpoints.R`).
    65	# --------------------------------------------------------------------------- #
    66
    67	#' Parse + run the packaging CLI. Wrapped in a function (rather than bare
    68	#' top-level code) so the file can be `source()`d for its function
    69	#' definitions alone -- see the `sys.nframe() == 0L` main-guard at the
    70	#' bottom of this file, which only calls this when the script is run
    71	#' directly (`Rscript package-analysis-release-zenodo.R`), never when
    72	#' `source()`d (e.g. by a test).
    73	#' Write/overwrite the stable `outputs/analysis-release-zenodo/latest.env`
    74	#' pointer file the `analysis-release-zenodo-upload-draft` Make target reads
    75	#' to find this run's content-addressed archive (releases are `asr_<16
    76	#' hex>`-named, not date-versioned, so the Makefile cannot hardcode a
    77	#' filename). Fixed, CWD-relative location regardless of `--staging-dir`/
    78	#' `--archive-dir` overrides -- deliberately NOT under `staging_dir`/
    79	#' `archive_dir` so the marker's location never depends on those flags.
    80	#' Paths are written `normalizePath()`-resolved (absolute) so the marker is
    81	#' still correct if the upload step runs from a different CWD than the
    82	#' package step.
    83	.write_package_analysis_release_zenodo_marker <- function(result) {
    84	  marker_path <- "outputs/analysis-release-zenodo/latest.env"
    85	  dir.create(dirname(marker_path), recursive = TRUE, showWarnings = FALSE)
    86	  cat(
    87	    sprintf(
    88	      "ARCHIVE_PATH=%s\nMETADATA_PATH=%s\nRELEASE_ID=%s\n",
    89	      normalizePath(result$archive_path, mustWork = FALSE),
    90	      normalizePath(result$zenodo_metadata_path, mustWork = FALSE),
    91	      result$release_id
    92	    ),
    93	    file = marker_path
    94	  )
    95	  marker_path
    96	}
    97
    98	run_package_analysis_release_zenodo_cli <- function() {
    99	  args <- commandArgs(trailingOnly = TRUE)
   100
   101	  api_base_url <- Sys.getenv("SYSNDD_API_BASE_URL", "http://localhost:7778")
   102	  release_id <- "latest"
   103	  staging_dir <- "outputs/analysis-release-zenodo/staging"
   104	  archive_dir <- "outputs/analysis-release-zenodo/archive"
   105	  version <- NULL
   106
   107	  if (length(args) > 0) {
   108	    for (i in seq_along(args)) {
   109	      if (args[i] == "--api-base-url" && i < length(args)) {
   110	        api_base_url <- args[i + 1]
   111	      } else if (args[i] == "--release-id" && i < length(args)) {
   112	        release_id <- args[i + 1]
   113	      } else if (args[i] == "--staging-dir" && i < length(args)) {
   114	        staging_dir <- args[i + 1]
   115	      } else if (args[i] == "--archive-dir" && i < length(args)) {
   116	        archive_dir <- args[i + 1]
   117	      } else if (args[i] == "--version" && i < length(args)) {
   118	        version <- args[i + 1]
   119	      }
   120	    }
   121	  }
   122
   123	  message(sprintf(
   124	    "[package-analysis-release-zenodo] api_base_url=%s release_id=%s staging_dir=%s archive_dir=%s",
   125	    api_base_url, release_id, staging_dir, archive_dir
   126	  ))
   127
   128	  result <- analysis_release_zenodo_package(
   129	    api_base_url = api_base_url,
   130	    release_id = release_id,
   131	    staging_dir = staging_dir,
   132	    archive_dir = archive_dir,
   133	    version = version
   134	  )
   135
   136	  marker_path <- .write_package_analysis_release_zenodo_marker(result)
   137
   138	  cat(sprintf("Release ID:           %s\n", result$release_id))
   139	  cat(sprintf("Staging dir:          %s\n", result$staging_dir))
   140	  cat(sprintf("Archive path:         %s\n", result$archive_path))
   141	  cat(sprintf("Archive sha256 path:  %s\n", result$archive_sha256_path))
   142	  cat(sprintf("Zenodo metadata path: %s\n", result$zenodo_metadata_path))
   143	  cat(sprintf("Marker file:          %s\n", marker_path))
   144	  cat(sprintf(
   145	    "\nNext: make analysis-release-zenodo-upload-draft (or: Rscript api/scripts/upload-analysis-release-zenodo.R --archive %s --metadata %s --release-id %s)\n",
   146	    result$archive_path, result$zenodo_metadata_path, result$release_id
   147	  ))
   148
   149	  invisible(result)
   150	}
   151
   152	# Main guard: `sys.nframe()` is 0 only at the true top level of a directly
   153	# `Rscript`-invoked file; a `source()`d file (e.g. from a test) always adds
   154	# at least one frame, so this line never fires under `source()`. This check
   155	# MUST stay at top level (not inside a function) -- see AGENTS.md-adjacent
   156	# `.superpowers/sdd/task-c2-report.md` for the empirical verification.
   157	if (sys.nframe() == 0L) run_package_analysis_release_zenodo_cli()
     1	#!/usr/bin/env Rscript
     2	# api/scripts/upload-analysis-release-zenodo.R
     3	#
     4	# Thin operator CLI: upload a packaged analysis-snapshot release archive
     5	# (#573; output of `package-analysis-release-zenodo.R`) to a Zenodo
     6	# deposition -- get-or-create -> set metadata -> stream archive to bucket ->
     7	# (optional, double-gated) publish -- then, opt-in, PATCH the resulting
     8	# DOI/record provenance back onto the SysNDD release head.
     9	#
    10	# All upload/record-back logic lives in
    11	# `api/functions/analysis-snapshot-release-zenodo-upload.R`; this script
    12	# only parses flags, sources that file, calls the orchestrator, and prints
    13	# results -- mirroring the sibling
    14	# `../nddscore/scripts/upload_sysndd_zenodo_dataset.py`.
    15	#
    16	# Usage (from the repo root, or from api/ -- CWD-independent, see below):
    17	#   Rscript api/scripts/upload-analysis-release-zenodo.R \
    18	#     --archive <path/to/archive.tar.gz> --metadata <path/to/zenodo_metadata.json> \
    19	#     [--sandbox] [--deposition-id <id>] [--publish --confirm-publish] \
    20	#     [--record-doi --release-id <asr_...>] [--api-base-url <SysNDD API base>]
    21	#
    22	# ZENODO_TOKEN is READ FROM THE ENVIRONMENT ONLY -- there is deliberately no
    23	# `--token` flag. A CLI flag would leak the token into shell history and
    24	# `ps`/`/proc/<pid>/cmdline` argv on any multi-user host; the underlying
    25	# `analysis_release_zenodo_upload()` function still accepts a `token`
    26	# parameter for tests/programmatic callers, but this CLI wrapper only ever
    27	# reads `Sys.getenv("ZENODO_TOKEN")`.
    28	#
    29	# Publish safety interlock: `--publish` alone is REFUSED -- both `--publish`
    30	# AND `--confirm-publish` must be passed, or the run stops before any HTTP
    31	# call is made (`analysis_release_zenodo_require_publish_confirmation()`).
    32	# Without `--publish`, the archive is uploaded to a Zenodo DRAFT only, for
    33	# manual review before publishing.
    34	#
    35	# DOI record-back is OPT-IN and requires BOTH `--record-doi` AND the
    36	# `SYSNDD_ADMIN_TOKEN` env var (a pre-minted SysNDD Administrator bearer
    37	# token) to be set, plus `--release-id` and a successfully PUBLISHED Zenodo
    38	# DOI. Absent any of those, this script NEVER calls the SysNDD admin PATCH
    39	# endpoint automatically -- it prints the exact manual `curl` command instead
    40	# so the operator can record it by hand. A DRAFT upload (no `--publish`, or
    41	# `--publish` without `--confirm-publish`) never gets a populated PATCH
    42	# command either way -- only post-publication instructions are printed,
    43	# because a draft DOI is not final and the record-back rule is
    44	# published-only (see `analysis_release_zenodo_print_doi_record_back()`).
    45	# `--release-id` is validated (`^asr_[0-9a-f]{16}$`) before it is ever placed
    46	# into the admin URL or the printed command.
    47	#
    48	# Requires: httr2, jsonlite (api/renv.lock). No DB, no bootstrap, no
    49	# `external_proxy_budget()` -- see AGENTS.md "Analysis-snapshot releases
    50	# (#573)" and `.superpowers/sdd/slice-c-scout.md`.
    51	#
    52	# CWD note: resolves `api/functions/analysis-snapshot-release-zenodo-
    53	# upload.R` relative to ITS OWN file location (same idiom as
    54	# `package-analysis-release-zenodo.R` / `capture-external-fixtures.R`), so it
    55	# may be invoked from any working directory.
    56
    57	# --------------------------------------------------------------------------- #
    58	# Resolve this script's own directory, then source the upload/record-back
    59	# functions (function definitions only -- no top-level network calls in that
    60	# file, so this is safe to do unconditionally, even when this CLI script is
    61	# itself only `source()`d).
    62	# --------------------------------------------------------------------------- #
    63
    64	.upload_analysis_release_zenodo_script_dir <- function() {
    65	  script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
    66	  if (is.null(script_file) || !nzchar(script_file)) {
    67	    full_args <- commandArgs(trailingOnly = FALSE)
    68	    file_arg <- grep("^--file=", full_args, value = TRUE)
    69	    script_file <- if (length(file_arg) >= 1) sub("^--file=", "", file_arg[1]) else "."
    70	  }
    71	  dirname(normalizePath(script_file, mustWork = FALSE))
    72	}
    73
    74	.upload_analysis_release_zenodo_script_dir_value <- .upload_analysis_release_zenodo_script_dir()
    75	source(
    76	  file.path(
    77	    .upload_analysis_release_zenodo_script_dir_value, "..", "functions",
    78	    "analysis-snapshot-release-zenodo-upload.R"
    79	  ),
    80	  local = FALSE
    81	)
    82
    83	# --------------------------------------------------------------------------- #
    84	# CLI arg parsing -- manual commandArgs() flag loop (repo convention; no
    85	# optparse dependency, see `verify-endpoints.R`).
    86	# --------------------------------------------------------------------------- #
    87
    88	#' Parse + run the upload CLI. Wrapped in a function (rather than bare
    89	#' top-level code) so the file can be `source()`d for its function
    90	#' definitions alone -- see the `sys.nframe() == 0L` main-guard at the
    91	#' bottom of this file, which only calls this when the script is run
    92	#' directly (`Rscript upload-analysis-release-zenodo.R`), never when
    93	#' `source()`d (e.g. by a test).
    94	run_upload_analysis_release_zenodo_cli <- function() {
    95	  args <- commandArgs(trailingOnly = TRUE)
    96
    97	  archive <- NULL
    98	  metadata <- NULL
    99	  # ZENODO_TOKEN is env-only -- see the "no --token flag" note in the file
   100	  # header. There is no CLI flag to set/override it.
   101	  token <- Sys.getenv("ZENODO_TOKEN", "")
   102	  sandbox <- FALSE
   103	  deposition_id <- NULL
   104	  publish <- FALSE
   105	  confirm_publish <- FALSE
   106	  record_doi <- FALSE
   107	  release_id <- NULL
   108	  api_base_url <- Sys.getenv("SYSNDD_API_BASE_URL", "http://localhost:7778")
   109
   110	  if (length(args) > 0) {
   111	    for (i in seq_along(args)) {
   112	      if (args[i] == "--archive" && i < length(args)) {
   113	        archive <- args[i + 1]
   114	      } else if (args[i] == "--metadata" && i < length(args)) {
   115	        metadata <- args[i + 1]
   116	      } else if (args[i] == "--sandbox") {
   117	        sandbox <- TRUE
   118	      } else if (args[i] == "--deposition-id" && i < length(args)) {
   119	        deposition_id <- args[i + 1]
   120	      } else if (args[i] == "--publish") {
   121	        publish <- TRUE
   122	      } else if (args[i] == "--confirm-publish") {
   123	        confirm_publish <- TRUE
   124	      } else if (args[i] == "--record-doi") {
   125	        record_doi <- TRUE
   126	      } else if (args[i] == "--release-id" && i < length(args)) {
   127	        release_id <- args[i + 1]
   128	      } else if (args[i] == "--api-base-url" && i < length(args)) {
   129	        api_base_url <- args[i + 1]
   130	      }
   131	    }
   132	  }
   133
   134	  if (is.null(archive) || !nzchar(archive)) {
   135	    stop("--archive is required", call. = FALSE)
   136	  }
   137	  if (is.null(metadata) || !nzchar(metadata)) {
   138	    stop("--metadata is required", call. = FALSE)
   139	  }
   140
   141	  result <- analysis_release_zenodo_upload(
   142	    archive_path = archive,
   143	    metadata_path = metadata,
   144	    token = token,
   145	    sandbox = sandbox,
   146	    deposition_id = deposition_id,
   147	    publish = publish,
   148	    confirm_publish = confirm_publish
   149	  )
   150
   151	  cat(sprintf("Zenodo deposition id: %s\n", result$deposition_id))
   152	  cat(sprintf(
   153	    "Zenodo reserved DOI:  %s\n",
   154	    if (is.na(result$reserved_doi)) "not returned" else result$reserved_doi
   155	  ))
   156	  cat(sprintf(
   157	    "Zenodo draft URL:     %s\n",
   158	    if (is.na(result$draft_url)) "not returned" else result$draft_url
   159	  ))
   160
   161	  if (isTRUE(result$published)) {
   162	    cat(sprintf("Published Zenodo DOI: %s\n", result$version_doi))
   163	    cat(sprintf("Published Zenodo URL: %s\n", result$record_url))
   164	  } else {
   165	    cat("Draft uploaded only. Review in Zenodo before publishing.\n")
   166	  }
   167
   168	  # Item 3 (MEDIUM, Codex round 2): `analysis_release_zenodo_print_doi_record_back()`
   169	  # (in the functions file, not duplicated here) prints ONLY post-publication
   170	  # instructions for a draft upload -- never a populated PATCH command.
   171	  analysis_release_zenodo_print_doi_record_back(result, release_id, api_base_url, record_doi)
   172
   173	  invisible(result)
   174	}
   175
   176	# Main guard: `sys.nframe()` is 0 only at the true top level of a directly
   177	# `Rscript`-invoked file; a `source()`d file (e.g. from a test) always adds
   178	# at least one frame, so this line never fires under `source()`. This check
   179	# MUST stay at top level (not inside a function).
   180	if (sys.nframe() == 0L) run_upload_analysis_release_zenodo_cli()

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-zenodo-upload.R | sed -n '70,410p'
nl -ba api/functions/analysis-snapshot-release-zenodo-docs.R
nl -ba Makefile | sed -n '1,220p'
git diff --check origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
    70	  rm(
    71	    .analysis_release_zenodo_common_self_dir, .analysis_release_zenodo_common_candidates,
    72	    .analysis_release_zenodo_common_path
    73	  )
    74	}
    75
    76	# --------------------------------------------------------------------------- #
    77	# Zenodo API base URLs + publish safety interlock
    78	# --------------------------------------------------------------------------- #
    79
    80	.ANALYSIS_RELEASE_ZENODO_API_PROD <- "https://zenodo.org/api"
    81	.ANALYSIS_RELEASE_ZENODO_API_SANDBOX <- "https://sandbox.zenodo.org/api"
    82
    83	#' Resolve the Zenodo API base URL for the requested environment.
    84	analysis_release_zenodo_resolve_api <- function(sandbox = FALSE) {
    85	  if (isTRUE(sandbox)) {
    86	    .ANALYSIS_RELEASE_ZENODO_API_SANDBOX
    87	  } else {
    88	    .ANALYSIS_RELEASE_ZENODO_API_PROD
    89	  }
    90	}
    91
    92	#' Stop unless BOTH `publish` and `confirm_publish` are set. A `publish`
    93	#' request without explicit confirmation is refused -- draft-only is the
    94	#' default, safe outcome. Mirrors the Python sibling's
    95	#' `require_publish_confirmation()` (there a `SystemExit`; here a `stop()`).
    96	analysis_release_zenodo_require_publish_confirmation <- function(publish, confirm_publish) {
    97	  if (isTRUE(publish) && !isTRUE(confirm_publish)) {
    98	    stop("--publish requires --confirm-publish", call. = FALSE)
    99	  }
   100	  invisible(NULL)
   101	}
   102
   103	# --------------------------------------------------------------------------- #
   104	# DI seams: default httr2 implementations. Tests inject plain stub closures
   105	# with the SAME formal signature instead of mocking httr2/network calls.
   106	# --------------------------------------------------------------------------- #
   107
   108	#' Default JSON request against the Zenodo deposit API. `token` is turned
   109	#' into a `Authorization: Bearer <token>` header; a non-NULL `body` is sent
   110	#' as a JSON object (Content-Type set by `httr2::req_body_json()`). The
   111	#' create-deposition call passes `body = list()`, which `jsonlite::toJSON()`
   112	#' would otherwise serialize as `[]` (an empty *array*) rather than the `{}`
   113	#' Zenodo's API expects for "create an empty deposition" -- special-cased via
   114	#' `req_body_raw()` so the wire format is the literal JSON object Zenodo
   115	#' documents.
   116	.analysis_release_zenodo_http_json <- function(method, url, token, body = NULL) {
   117	  req <- httr2::request(url) |>
   118	    httr2::req_method(method) |>
   119	    httr2::req_headers(Authorization = paste("Bearer", as.character(token)[[1]])) |>
   120	    httr2::req_timeout(60)
   121
   122	  if (!is.null(body)) {
   123	    req <- if (is.list(body) && length(body) == 0) {
   124	      httr2::req_body_raw(req, "{}", type = "application/json")
   125	    } else {
   126	      httr2::req_body_json(req, body, auto_unbox = TRUE)
   127	    }
   128	  }
   129
   130	  resp <- httr2::req_perform(req)
   131	  httr2::resp_body_json(resp, simplifyVector = FALSE)
   132	}
   133
   134	#' Default streaming file PUT to a Zenodo bucket URL. Streams `archive_path`
   135	#' from disk as the raw request body (`httr2::req_body_file()`), Bearer auth,
   136	#' a long timeout (large archives, slow upload links).
   137	.analysis_release_zenodo_http_put_file <- function(url, token, archive_path) {
   138	  httr2::request(url) |>
   139	    httr2::req_method("PUT") |>
   140	    httr2::req_headers(Authorization = paste("Bearer", as.character(token)[[1]])) |>
   141	    httr2::req_timeout(3600) |>
   142	    httr2::req_body_file(archive_path) |>
   143	    httr2::req_perform()
   144	}
   145
   146	# --------------------------------------------------------------------------- #
   147	# Deposition lifecycle
   148	# --------------------------------------------------------------------------- #
   149
   150	#' Get-or-create a Zenodo deposition. `deposition_id = NULL` creates a fresh
   151	#' draft (`POST {api}/deposit/depositions` with an empty JSON object body);
   152	#' an explicit id reuses an existing draft (`GET
   153	#' {api}/deposit/depositions/{id}`). Returns the parsed deposition list.
   154	#'
   155	#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
   156	#'   Injectable seam; defaults to the real httr2 call.
   157	analysis_release_zenodo_get_or_create_deposition <- function(
   158	    api, token, deposition_id = NULL, http = .analysis_release_zenodo_http_json) {
   159	  api <- sub("/+$", "", as.character(api)[[1]])
   160	  if (is.null(deposition_id)) {
   161	    http("POST", paste0(api, "/deposit/depositions"), token, body = list())
   162	  } else {
   163	    deposition_id <- as.character(deposition_id)[[1]]
   164	    http("GET", paste0(api, "/deposit/depositions/", deposition_id), token)
   165	  }
   166	}
   167
   168	#' Overwrite a deposition's metadata. `PUT {api}/deposit/depositions/{id}`
   169	#' with body `{"metadata": <metadata>}`.
   170	#'
   171	#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
   172	analysis_release_zenodo_set_metadata <- function(
   173	    api, token, deposition_id, metadata, http = .analysis_release_zenodo_http_json) {
   174	  api <- sub("/+$", "", as.character(api)[[1]])
   175	  deposition_id <- as.character(deposition_id)[[1]]
   176	  url <- paste0(api, "/deposit/depositions/", deposition_id)
   177	  http("PUT", url, token, body = list(metadata = metadata))
   178	}
   179
   180	#' Stream the archive to the deposition's Zenodo bucket.
   181	#' `PUT {bucket_url}/{basename(archive_path)}`.
   182	#'
   183	#' @param put Function(url, token, archive_path). Injectable seam; defaults
   184	#'   to the real httr2 streaming PUT.
   185	#' @return The upload URL, invisibly.
   186	analysis_release_zenodo_upload_bucket <- function(
   187	    bucket_url, token, archive_path, put = .analysis_release_zenodo_http_put_file) {
   188	  bucket_url <- sub("/+$", "", as.character(bucket_url)[[1]])
   189	  url <- paste0(bucket_url, "/", basename(archive_path))
   190	  put(url, token, archive_path)
   191	  invisible(url)
   192	}
   193
   194	#' Publish a draft deposition. `POST
   195	#' {api}/deposit/depositions/{id}/actions/publish`. Returns the published
   196	#' deposition (`{doi, conceptdoi, id, links: {html, ...}}`).
   197	#'
   198	#' @param http Function(method, url, token, body = NULL) -> parsed JSON list.
   199	analysis_release_zenodo_publish_deposition <- function(
   200	    api, token, deposition_id, http = .analysis_release_zenodo_http_json) {
   201	  api <- sub("/+$", "", as.character(api)[[1]])
   202	  deposition_id <- as.character(deposition_id)[[1]]
   203	  url <- paste0(api, "/deposit/depositions/", deposition_id, "/actions/publish")
   204	  http("POST", url, token)
   205	}
   206
   207	# --------------------------------------------------------------------------- #
   208	# DOI record-back (OPT-IN, SysNDD-admin side) -- additive metadata, outside
   209	# any release content hash. Never called automatically; the CLI script only
   210	# invokes `analysis_release_zenodo_record_doi()` when the operator passes
   211	# `--record-doi` AND `SYSNDD_ADMIN_TOKEN` is set. Otherwise it prints
   212	# `analysis_release_zenodo_manual_doi_command()` so the operator can record
   213	# it by hand.
   214	# --------------------------------------------------------------------------- #
   215
   216	.ANALYSIS_RELEASE_ZENODO_DOI_FIELD_NAMES <- c(
   217	  "zenodo_record_id", "zenodo_record_url", "version_doi", "concept_doi"
   218	)
   219
   220	#' Keep only the four recognized DOI fields with a non-empty value. An
   221	#' omitted/NULL/NA/empty-string field is dropped, never forwarded as "",
   222	#' NULL, or NA -- the admin endpoint treats an omitted field as "leave
   223	#' unchanged", so a forwarded empty value would incorrectly clear it.
   224	#' `is.na()` is checked BEFORE `nzchar()` because `nzchar(NA_character_)` is
   225	#' TRUE in R -- without the guard an NA field survives the filter and is
   226	#' emitted as an explicit `null` instead of being omitted.
   227	.analysis_release_zenodo_doi_non_empty_fields <- function(doi_fields) {
   228	  doi_fields <- doi_fields[names(doi_fields) %in% .ANALYSIS_RELEASE_ZENODO_DOI_FIELD_NAMES]
   229	  Filter(function(value) {
   230	    if (is.null(value) || length(value) == 0) {
   231	      return(FALSE)
   232	    }
   233	    scalar <- value[[1]]
   234	    if (is.na(scalar)) {
   235	      return(FALSE)
   236	    }
   237	    nzchar(trimws(as.character(scalar)))
   238	  }, doi_fields)
   239	}
   240
   241	#' PATCH the four Zenodo/DOI provenance fields onto a published release head.
   242	#' Additive-only: forwards ONLY the supplied non-empty fields, matching the
   243	#' admin endpoint's "an omitted field is left unchanged, never nulled out"
   244	#' contract (see AGENTS.md "Analysis-snapshot releases (#573)").
   245	#'
   246	#' @param sysndd_api_base_url Base URL of the SysNDD API.
   247	#' @param admin_token A pre-minted SysNDD Administrator bearer token
   248	#'   (`SYSNDD_ADMIN_TOKEN`). Distinct from the Zenodo `token` used elsewhere
   249	#'   in this file.
   250	#' @param release_id Validated via
   251	#'   `.analysis_release_zenodo_assert_valid_release_id()` BEFORE the admin
   252	#'   PATCH URL is built (Codex round-2 item 2, HIGH) -- an invalid id
   253	#'   (`../evil`, a quote/`;`/newline-shaped value, ...) stops here, before it
   254	#'   is ever placed into the URL.
   255	#' @param patch Function(method, url, token, body = NULL) -> parsed JSON list.
   256	#'   Injectable seam; defaults to the real httr2 call.
   257	analysis_release_zenodo_record_doi <- function(
   258	    sysndd_api_base_url, admin_token, release_id, doi_fields,
   259	    patch = .analysis_release_zenodo_http_json) {
   260	  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
   261	  release_id <- as.character(release_id)[[1]]
   262	  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
   263	  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
   264	  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
   265	  patch("PATCH", url, admin_token, body = fields)
   266	}
   267
   268	#' Build the exact `curl -X PATCH ...` command an operator can run by hand to
   269	#' record DOI/record provenance when `--record-doi` was not opted into (the
   270	#' default). Never executed automatically.
   271	#'
   272	#' Codex round-2 item 2 (HIGH): `release_id` is validated via
   273	#' `.analysis_release_zenodo_assert_valid_release_id()` BEFORE the URL or
   274	#' command string is built -- an invalid id stops here rather than becoming a
   275	#' path-altering URL segment or a copy/paste command-injection payload once
   276	#' printed. Defense in depth: the resolved URL and the JSON body are each
   277	#' `shQuote()`d (POSIX `sh` quoting -- wraps in single quotes and escapes any
   278	#' embedded single quote), so even a doi_fields VALUE containing a quote,
   279	#' `;`, or a newline cannot break out of the single-quoted `curl` arguments.
   280	analysis_release_zenodo_manual_doi_command <- function(sysndd_api_base_url, release_id, doi_fields) {
   281	  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
   282	  release_id <- as.character(release_id)[[1]]
   283	  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
   284	  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
   285	  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
   286	  body_json <- as.character(jsonlite::toJSON(fields, auto_unbox = TRUE))
   287
   288	  paste0(
   289	    "curl -X PATCH ", shQuote(url), " ",
   290	    "-H 'Authorization: Bearer <SYSNDD_ADMIN_TOKEN>' ",
   291	    "-H 'Content-Type: application/json' ",
   292	    "-d ", shQuote(body_json)
   293	  )
   294	}
   295
   296	# --------------------------------------------------------------------------- #
   297	# DOI record-back print step -- the CLI-facing decision of WHEN to
   298	# auto-record vs. print a manual command vs. print instructions-only.
   299	# Lives here (not in the CLI script) so it is directly unit-testable via
   300	# `source_api_file()`, the same convention as the rest of this file.
   301	# --------------------------------------------------------------------------- #
   302
   303	#' Print the (opt-in) DOI record-back step after `analysis_release_zenodo_upload()`
   304	#' completes. Never calls the SysNDD admin endpoint unless the operator
   305	#' explicitly asked for it (`--record-doi`) AND supplied credentials
   306	#' (`SYSNDD_ADMIN_TOKEN`) AND the run reached a real, published DOI.
   307	#'
   308	#' Codex round-2 hardening:
   309	#' - item 2 (HIGH): `release_id` is validated via
   310	#'   `.analysis_release_zenodo_assert_valid_release_id()` immediately after
   311	#'   the "no id supplied" short-circuit and BEFORE any URL or command is
   312	#'   built from it (`record_doi()`/`manual_doi_command()` also validate
   313	#'   internally -- this is defense in depth, not the only gate).
   314	#' - item 3 (MEDIUM): when the upload was a DRAFT (`result$published` is
   315	#'   FALSE), this prints ONLY post-publication instructions -- never a
   316	#'   ready-to-run PATCH command populated with draft values, which would let
   317	#'   an operator record a draft DOI and violate the locked published-only
   318	#'   rule (the automatic `--record-doi` path already gated on `published`;
   319	#'   the PRINTED fallback command previously did not).
   320	#'
   321	#' @param result The list returned by `analysis_release_zenodo_upload()`.
   322	#' @param release_id Operator-supplied `--release-id` (or `NULL`).
   323	#' @param api_base_url Base URL of the SysNDD API.
   324	#' @param record_doi Whether `--record-doi` was passed.
   325	#' @param printer Function(...) used for output; defaults to `cat`.
   326	#'   Injectable seam so tests can capture output without `capture.output()`.
   327	#' @param record_doi_fn Function with `analysis_release_zenodo_record_doi()`'s
   328	#'   signature. Injectable seam (mirrors every other HTTP boundary in this
   329	#'   file) so tests can exercise the automatic-record branch without a real
   330	#'   network call.
   331	analysis_release_zenodo_print_doi_record_back <- function(
   332	    result, release_id, api_base_url, record_doi, printer = cat,
   333	    record_doi_fn = analysis_release_zenodo_record_doi) {
   334	  have_release_id <- !is.null(release_id) && nzchar(as.character(release_id)[[1]])
   335	  if (!have_release_id) {
   336	    printer("\nNo --release-id supplied -- pass one to record or print a DOI record-back command.\n")
   337	    return(invisible(NULL))
   338	  }
   339
   340	  release_id <- as.character(release_id)[[1]]
   341	  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
   342
   343	  if (!isTRUE(result$published)) {
   344	    printer(
   345	      "\nDraft uploaded (not published) -- a draft DOI is never recorded (published-only ",
   346	      "rule). Publish first with --publish --confirm-publish, then re-run with ",
   347	      "--record-doi (and SYSNDD_ADMIN_TOKEN set), or record the DOI by hand once ",
   348	      "the deposition is published.\n",
   349	      sep = ""
   350	    )
   351	    return(invisible(NULL))
   352	  }
   353
   354	  doi_fields <- list(
   355	    zenodo_record_id = as.character(result$deposition_id),
   356	    zenodo_record_url = result$record_url,
   357	    version_doi = result$version_doi,
   358	    concept_doi = result$concept_doi
   359	  )
   360	  have_published_doi <- !is.na(result$version_doi) && nzchar(as.character(result$version_doi))
   361	  admin_token <- Sys.getenv("SYSNDD_ADMIN_TOKEN", "")
   362
   363	  if (isTRUE(record_doi) && nzchar(admin_token) && have_published_doi) {
   364	    updated <- record_doi_fn(
   365	      sysndd_api_base_url = api_base_url,
   366	      admin_token = admin_token,
   367	      release_id = release_id,
   368	      doi_fields = doi_fields
   369	    )
   370	    printer("\nDOI recorded on the SysNDD release head:\n")
   371	    printer(sprintf("  release_id:        %s\n", updated$release_id %||% release_id))
   372	    printer(sprintf("  version_doi:       %s\n", updated$version_doi %||% doi_fields$version_doi))
   373	    printer(sprintf("  zenodo_record_url: %s\n", updated$zenodo_record_url %||% doi_fields$zenodo_record_url))
   374	  } else {
   375	    printer(
   376	      "\nDOI not recorded automatically",
   377	      if (!have_published_doi) " (no published DOI)" else "",
   378	      ". Run with --record-doi and SYSNDD_ADMIN_TOKEN set, ",
   379	      "or record it by hand:\n",
   380	      sep = ""
   381	    )
   382	    printer(analysis_release_zenodo_manual_doi_command(api_base_url, release_id, doi_fields), "\n")
   383	  }
   384	  invisible(NULL)
   385	}
   386
   387	# --------------------------------------------------------------------------- #
   388	# Orchestrator -- mirrors the Python sibling's `main()` flow. Pure w.r.t.
   389	# SysNDD: it never calls `analysis_release_zenodo_record_doi()` itself (the
   390	# CLI script does that, after this returns).
   391	# --------------------------------------------------------------------------- #
   392
   393	#' Upload a packaged Zenodo archive: get-or-create deposition -> set metadata
   394	#' -> stream archive to bucket -> (if `publish`) publish. Draft-only unless
   395	#' BOTH `publish` and `confirm_publish` are set (enforced first, via
   396	#' `analysis_release_zenodo_require_publish_confirmation()`).
   397	#'
   398	#' @return list(deposition_id, reserved_doi, draft_url, published (bool),
   399	#'   version_doi, concept_doi, record_url). `version_doi`/`concept_doi`/
   400	#'   `record_url` are `NA_character_` unless `published` is TRUE.
   401	analysis_release_zenodo_upload <- function(
   402	    archive_path,
   403	    metadata_path,
   404	    token,
   405	    sandbox = FALSE,
   406	    deposition_id = NULL,
   407	    publish = FALSE,
   408	    confirm_publish = FALSE,
   409	    get_or_create_deposition = analysis_release_zenodo_get_or_create_deposition,
   410	    set_metadata = analysis_release_zenodo_set_metadata,
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
     1	# SysNDD Development Automation
     2	# Usage: make <target>
     3	# Run `make` or `make help` to see available commands
     4
     5	# =============================================================================
     6	# Davis-Hansson Preamble (https://tech.davis-hansson.com/p/make/)
     7	# =============================================================================
     8	SHELL := bash
     9	.ONESHELL:
    10	.SHELLFLAGS := -eu -o pipefail -c
    11	.DELETE_ON_ERROR:
    12	MAKEFLAGS += --warn-undefined-variables
    13	MAKEFLAGS += --no-builtin-rules
    14
    15	# =============================================================================
    16	# Project Root (auto-detected)
    17	# =============================================================================
    18	ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
    19	HOST_R_HOME := $(shell R RHOME 2>/dev/null)
    20	HOST_R_MARIADB_LIB_DIR ?= $(patsubst %/,%,$(dir $(HOST_R_HOME)))/mariadb
    21	HOST_R_ENV_LD_LIBRARY_PATH := $(shell printf '%s' "$${LD_LIBRARY_PATH-}")
    22	HOST_R_LD_LIBRARY_PATH ?= $(if $(wildcard $(HOST_R_MARIADB_LIB_DIR)/libmariadb.so*),$(HOST_R_MARIADB_LIB_DIR)$(if $(HOST_R_ENV_LD_LIBRARY_PATH),:$(HOST_R_ENV_LD_LIBRARY_PATH)),$(HOST_R_ENV_LD_LIBRARY_PATH))
    23	HOST_RSCRIPT := env LD_LIBRARY_PATH="$(HOST_R_LD_LIBRARY_PATH)" Rscript --no-init-file
    24
    25	include $(ROOT_DIR)/make/mcp-select-principal.mk
    26
    27	# =============================================================================
    28	# ANSI Color Codes
    29	# =============================================================================
    30	GREEN := \033[0;32m
    31	RED := \033[0;31m
    32	CYAN := \033[0;36m
    33	YELLOW := \033[0;33m
    34	RESET := \033[0m
    35
    36	# =============================================================================
    37	# Default Goal
    38	# =============================================================================
    39	.DEFAULT_GOAL := help
    40
    41	# =============================================================================
    42	# PHONY Declarations
    43	# =============================================================================
    44	.PHONY: help check-r check-npm check-docker install-api install-app dev serve-app build-app verify-app-bundle-budget watch-app test-api test-api-fast test-api-full mcp-transport-spike test-mcp-smoke coverage lint-api lint-app format-api format-app verify-seo-app code-quality-audit pre-commit ci-local _ci-cleanup preflight docker-build docker-up docker-down docker-dev docker-dev-db docker-logs docker-status cache-clear refresh-analysis-snapshots install-dev doctor worktree-setup worktree-prune refresh-fixtures test-ci-scripts verify-gate playwright-stack playwright-stack-down playwright-stack-logs docs-screenshots docs-screenshots-down verify-doc-screenshots _playwright-seed-templates _playwright-seed-users _playwright-seed-docs-data analysis-release-zenodo-package analysis-release-zenodo-upload-draft
    45
    46	# =============================================================================
    47	# Help Target (Self-documenting)
    48	# =============================================================================
    49	help: ## Show this help message
    50		@printf "SysNDD Development Commands\n\n"
    51		@printf "$(CYAN)Environment:$(RESET)\n"
    52		@grep -E '^[a-zA-Z_-]+:.*?## \[env\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[env\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
    53		@printf "\n$(CYAN)Development:$(RESET)\n"
    54		@grep -E '^[a-zA-Z_-]+:.*?## \[dev\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[dev\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
    55		@printf "\n$(CYAN)Testing:$(RESET)\n"
    56		@grep -E '^[a-zA-Z_-]+:.*?## \[test\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[test\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
    57		@printf "\n$(CYAN)Linting:$(RESET)\n"
    58		@grep -E '^[a-zA-Z_-]+:.*?## \[lint\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[lint\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
    59		@printf "\n$(CYAN)Docker:$(RESET)\n"
    60		@grep -E '^[a-zA-Z_-]+:.*?## \[docker\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[docker\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
    61		@printf "\n$(CYAN)Quality:$(RESET)\n"
    62		@grep -E '^[a-zA-Z_-]+:.*?## \[quality\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[quality\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
    63
    64	# =============================================================================
    65	# Prerequisite Checks (not in help)
    66	# =============================================================================
    67	check-r:
    68		@command -v R > /dev/null 2>&1 || \
    69			(printf "$(RED)ERROR: R is not installed$(RESET)\n" && \
    70			 printf "Install R from: https://www.r-project.org/\n" && \
    71			 exit 1)
    72
    73	check-npm:
    74		@command -v npm > /dev/null 2>&1 || \
    75			(printf "$(RED)ERROR: npm is not installed$(RESET)\n" && \
    76			 printf "Install Node.js/npm from: https://nodejs.org/\n" && \
    77			 exit 1)
    78
    79	check-docker:
    80		@docker info > /dev/null 2>&1 || \
    81			(printf "$(RED)ERROR: Docker is not running$(RESET)\n" && \
    82			 printf "Start Docker Desktop and try again.\n" && \
    83			 exit 1)
    84
    85	# =============================================================================
    86	# Development Targets
    87	# =============================================================================
    88	install-api: check-r ## [dev] Install R dependencies with renv::restore()
    89		@printf "$(CYAN)==> Installing R dependencies...$(RESET)\n"
    90		@cd $(ROOT_DIR)/api && R -e "renv::restore(prompt = FALSE)" && \
    91			printf "$(GREEN)✓ install-api complete$(RESET)\n" || \
    92			(printf "$(RED)✗ install-api failed$(RESET)\n" && exit 1)
    93
    94	install-app: check-npm ## [dev] Install frontend dependencies with npm install
    95		@printf "$(CYAN)==> Installing frontend dependencies...$(RESET)\n"
    96		@cd $(ROOT_DIR)/app && npm install && \
    97			printf "$(GREEN)✓ install-app complete$(RESET)\n" || \
    98			(printf "$(RED)✗ install-app failed$(RESET)\n" && exit 1)
    99
   100	dev: docker-dev ## [dev] Start full Docker dev stack (alias for docker-dev)
   101
   102	serve-app: check-npm ## [dev] Start Vue development server with hot reload
   103		@printf "$(CYAN)==> Starting Vue development server...$(RESET)\n"
   104		@cd $(ROOT_DIR)/app && npm run serve
   105
   106	build-app: check-npm ## [dev] Build frontend for production
   107		@printf "$(CYAN)==> Building frontend for production...$(RESET)\n"
   108		@cd $(ROOT_DIR)/app && npm run build && \
   109			printf "$(GREEN)✓ build-app complete$(RESET)\n" || \
   110			(printf "$(RED)✗ build-app failed$(RESET)\n" && exit 1)
   111
   112	verify-app-bundle-budget: check-npm ## [quality] Verify production public-route bundle budgets
   113		@cd $(ROOT_DIR)/app && npm run build:bundle-budget
   114
   115	watch-app: check-docker ## [dev] Start Docker Compose watch for frontend hot-reload
   116		@printf "$(CYAN)==> Starting Docker Compose watch mode...$(RESET)\n"
   117		@cd $(ROOT_DIR) && docker compose watch
   118
   119	# =============================================================================
   120	# Testing Targets
   121	# =============================================================================
   122	test-api: check-r ## [test] Run R API tests with testthat
   123		@printf "$(CYAN)==> Running R API tests...$(RESET)\n"
   124		@cd $(ROOT_DIR)/api && $(HOST_RSCRIPT) scripts/run-ci-tests.R full && \
   125			printf "$(GREEN)✓ test-api complete$(RESET)\n" || \
   126			(printf "$(RED)✗ test-api failed$(RESET)\n" && exit 1)
   127
   128	test-api-fast: check-r ## [test] Run the fast R API test gate used on pull requests
   129		@printf "$(CYAN)==> Running fast R API tests...$(RESET)\n"
   130		@cd $(ROOT_DIR)/api && $(HOST_RSCRIPT) scripts/run-ci-tests.R fast && \
   131			printf "$(GREEN)✓ test-api-fast complete$(RESET)\n" || \
   132			(printf "$(RED)✗ test-api-fast failed$(RESET)\n" && exit 1)
   133
   134	test-api-full: check-r ## [test] Run full R API test suite including slow tests
   135		@printf "$(CYAN)==> Running full R API test suite (including slow tests)...$(RESET)\n"
   136		@cd $(ROOT_DIR)/api && RUN_SLOW_TESTS=true $(HOST_RSCRIPT) scripts/run-ci-tests.R full && \
   137			printf "$(GREEN)✓ test-api-full complete$(RESET)\n" || \
   138			(printf "$(RED)✗ test-api-full failed$(RESET)\n" && exit 1)
   139
   140	mcp-transport-spike: check-r ## [test] Verify mcptools HTTP MCP initialize/list/call behavior
   141		@printf "$(CYAN)==> Running MCP transport spike...$(RESET)\n"
   142		@cd $(ROOT_DIR)/api && Rscript scripts/mcp-transport-spike.R && \
   143			printf "$(GREEN)✓ mcp-transport-spike complete$(RESET)\n" || \
   144			(printf "$(RED)✗ mcp-transport-spike failed$(RESET)\n" && exit 1)
   145
   146	test-mcp-smoke: check-r ## [test] Probe a running MCP sidecar with initialize and tools/list
   147		@printf "$(CYAN)==> Running MCP smoke probe...$(RESET)\n"
   148		@cd $(ROOT_DIR)/api && MCP_URL=$${MCP_URL:-http://127.0.0.1:8787} Rscript scripts/mcp-smoke.R && \
   149			printf "$(GREEN)✓ test-mcp-smoke complete$(RESET)\n" || \
   150			(printf "$(RED)✗ test-mcp-smoke failed$(RESET)\n" && exit 1)
   151
   152	coverage: check-r ## [test] Generate test coverage report with covr
   153		@printf "$(CYAN)==> Calculating test coverage...$(RESET)\n"
   154		@mkdir -p $(ROOT_DIR)/coverage
   155		@cd $(ROOT_DIR)/api && $(HOST_RSCRIPT) scripts/coverage.R && \
   156			printf "$(GREEN)✓ coverage complete$(RESET)\n" || \
   157			(printf "$(RED)✗ coverage failed$(RESET)\n" && exit 1)
   158
   159	# =============================================================================
   160	# Linting Targets
   161	# =============================================================================
   162	lint-api: check-r ## [lint] Check R code with lintr + migration prefix check
   163		@printf "$(CYAN)==> Checking R code with lintr...$(RESET)\n"
   164		@cd $(ROOT_DIR)/api && $(HOST_RSCRIPT) scripts/lint-check.R && \
   165			printf "$(GREEN)✓ lintr complete$(RESET)\n" || \
   166			(printf "$(RED)✗ lintr failed$(RESET)\n" && exit 1)
   167		@printf "$(CYAN)==> Checking migration prefixes...$(RESET)\n"
   168		@cd $(ROOT_DIR) && ./scripts/check-migration-prefixes.sh && \
   169			printf "$(GREEN)✓ lint-api complete$(RESET)\n" || \
   170			(printf "$(RED)✗ lint-api failed$(RESET)\n" && exit 1)
   171
   172	lint-app: check-npm ## [lint] Check frontend code with ESLint and MSW↔OpenAPI drift
   173		@printf "$(CYAN)==> Checking frontend code with ESLint...$(RESET)\n"
   174		@cd $(ROOT_DIR)/app && npm run lint && \
   175			printf "$(GREEN)✓ eslint complete$(RESET)\n" || \
   176			(printf "$(RED)✗ eslint failed$(RESET)\n" && exit 1)
   177		@printf "$(CYAN)==> Verifying MSW handlers against OpenAPI annotations...$(RESET)\n"
   178		@$(ROOT_DIR)/scripts/verify-msw-against-openapi.sh && \
   179			printf "$(GREEN)✓ lint-app complete$(RESET)\n" || \
   180			(printf "$(RED)✗ verify-msw-against-openapi failed$(RESET)\n" && exit 1)
   181
   182	format-api: check-r ## [lint] Format R code with styler
   183		@printf "$(CYAN)==> Formatting R code with styler...$(RESET)\n"
   184		@cd $(ROOT_DIR)/api && Rscript scripts/style-code.R && \
   185			printf "$(GREEN)✓ format-api complete$(RESET)\n" || \
   186			(printf "$(RED)✗ format-api failed$(RESET)\n" && exit 1)
   187
   188	format-app: check-npm ## [lint] Format frontend code with ESLint --fix
   189		@printf "$(CYAN)==> Formatting frontend code with ESLint --fix...$(RESET)\n"
   190		@cd $(ROOT_DIR)/app && npm run lint -- --fix && \
   191			printf "$(GREEN)✓ format-app complete$(RESET)\n" || \
   192			(printf "$(RED)✗ format-app failed$(RESET)\n" && exit 1)
   193
   194	verify-seo-app: check-npm ## [quality] Build fixture SEO pages and verify crawlable output
   195		@printf "$(CYAN)==> Building frontend for SEO verification...$(RESET)\n"
   196		@cd $(ROOT_DIR)/app && npm run build:production -- --emptyOutDir=false
   197		@printf "$(CYAN)==> Generating fixture SEO pages...$(RESET)\n"
   198		@cd $(ROOT_DIR)/app && npm run seo:generate:fixture
   199		@printf "$(CYAN)==> Verifying prerendered SEO output...$(RESET)\n"
   200		@cd $(ROOT_DIR)/app && npm run seo:verify && \
   201			printf "$(GREEN)✓ verify-seo-app complete$(RESET)\n" || \
   202			(printf "$(RED)✗ verify-seo-app failed$(RESET)\n" && exit 1)
   203
   204	code-quality-audit: ## [quality] Run fast deterministic code-quality ratchet
   205		@printf "$(CYAN)==> Running code-quality audit...$(RESET)\n"
   206		@$(ROOT_DIR)/scripts/code-quality-audit.sh && \
   207			printf "$(GREEN)✓ code-quality audit clean$(RESET)\n" || \
   208			(printf "$(RED)✗ code-quality audit failed$(RESET)\n" && exit 1)
   209
   210	# =============================================================================
   211	# Quality Targets
   212	# =============================================================================
   213	pre-commit: ## [quality] Run all quality checks before committing
   214		@printf "$(CYAN)==> Running pre-commit quality checks...$(RESET)\n"
   215		@printf "\n$(CYAN)[1/5] Running fast code-quality audit...$(RESET)\n"
   216		@$(MAKE) code-quality-audit
   217		@printf "\n$(CYAN)[2/5] Running CI script harnesses...$(RESET)\n"
   218		@$(MAKE) test-ci-scripts
   219		@printf "\n$(CYAN)[3/5] Linting R code...$(RESET)\n"
   220		@$(MAKE) lint-api

exec
/bin/bash -lc "rg -n -C 6 'analysis-release-zenodo' Makefile .gitignore documentation/09-deployment.qmd CHANGELOG.md AGENTS.md api/version_spec.json
nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-verify-round3.R
nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-verify.R | sed -n '135,285p'
rg -n 'analysis_release_zenodo_(get_or_create|set_metadata|publish|upload_bucket)|deposition_id|bucket_url' api/tests/testthat/test-unit-analysis-release-zenodo-upload.R api/functions/analysis-snapshot-release-zenodo-upload.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
documentation/09-deployment.qmd-312-**Reproducibility boundary.** A release reproduces the served separation metrics (functional modularity, phenotype silhouette) and the phenotype-functional cross-cluster correlation from the bundled reproducibility inputs — recompute them per the "Verify" instructions in the release's own `README.md`. LLM cluster summaries and precomputed fCoSE network-layout coordinates are **served-only** and are intentionally excluded from releases; they are not part of the reproducible scientific content.
documentation/09-deployment.qmd-313-
documentation/09-deployment.qmd-314-**Public download surface** (no auth): `GET /api/analysis/releases/<release_id>/manifest.json` returns the exact stored manifest bytes (`sha256(bytes) == manifest_sha256` on the release head); `GET /api/analysis/releases/<release_id>/file?path=<file_path>` returns one content-addressed file by its exact manifest path (e.g. `path=functional_clusters/payload.json`); `GET /api/analysis/releases/<release_id>/bundle` streams the whole frozen `bundle.tar.gz`.
documentation/09-deployment.qmd-315-
documentation/09-deployment.qmd-316-#### Zenodo archival (operator scripts, #573 Slice C)
documentation/09-deployment.qmd-317-
documentation/09-deployment.qmd:318:Once a release is published (above), an operator can archive it to Zenodo with two host-run scripts (`api/scripts/package-analysis-release-zenodo.R` + `api/scripts/upload-analysis-release-zenodo.R`, mirroring the existing NDDScore/Zenodo release scripts in `../nddscore`). Both are plain HTTP clients: the packager reads the release only through the public `/api/analysis/releases/*` routes above (no DB, no `docker exec`), and the uploader only talks to the Zenodo REST API and (optionally) the admin DOI PATCH endpoint. Neither is wired into `docker-compose.yml`, `bootstrap/load_modules.R`, or the worker — run them on the host (or CI) where a published release is reachable over HTTP.
documentation/09-deployment.qmd-319-
documentation/09-deployment.qmd-320-**Prerequisites:**
documentation/09-deployment.qmd-321-
documentation/09-deployment.qmd-322-- Host R with `httr2`, `jsonlite`, and `digest` (all already in `api/renv.lock`).
documentation/09-deployment.qmd-323-- `ZENODO_TOKEN` — a Zenodo personal access token (`https://zenodo.org/account/settings/applications/tokens/new/`, scope `deposit:write` + `deposit:actions`). Set it in your shell or a git-ignored `.env`; it is **never** committed and the Makefile never bakes it in as a literal.
documentation/09-deployment.qmd-324-- `SYSNDD_API_BASE_URL` (optional) — the public API base to read the release from; defaults to `http://localhost:7778`.
documentation/09-deployment.qmd-325-- `SYSNDD_ADMIN_TOKEN` (optional) — a pre-minted SysNDD Administrator bearer token, only needed for the automated DOI record-back in step 6.
documentation/09-deployment.qmd-326-
documentation/09-deployment.qmd-327-**Flow:**
documentation/09-deployment.qmd-328-
documentation/09-deployment.qmd-329-1. **Package.**
documentation/09-deployment.qmd-330-   ```bash
documentation/09-deployment.qmd:331:   make analysis-release-zenodo-package
documentation/09-deployment.qmd-332-   # or, for an explicit release rather than the current `latest`:
documentation/09-deployment.qmd:333:   ARGS="--release-id asr_<16 hex>" make analysis-release-zenodo-package
documentation/09-deployment.qmd-334-   ```
documentation/09-deployment.qmd:335:   Downloads the release's `bundle.tar.gz`, verifies its checksum, re-stages the files under `analysis_snapshot_release/`, adds Zenodo-facing `README.md`/`DATA_CARD.md`/`SCHEMA.md`/`CHANGELOG.md`/`CITATION.cff`/`zenodo_metadata.json`/`datapackage.json`, runs the packaging safety validator (case-insensitive `.env`/`.git`/sensitive-text rejection, a file-type allowlist, and a symlink rejection — defense-in-depth; a release payload has no such content by construction), and writes `outputs/analysis-release-zenodo/archive/<release_id>.tar.gz` + `.sha256` plus a `outputs/analysis-release-zenodo/latest.env` pointer file (`ARCHIVE_PATH`/`METADATA_PATH`/`RELEASE_ID`) so the next step can find the content-addressed archive without a hardcoded, drift-prone filename.
documentation/09-deployment.qmd:336:2. **Review** the staging directory (`outputs/analysis-release-zenodo/staging/`) by eye before uploading anything — the validator is a safety net, not a substitute for a human look.
documentation/09-deployment.qmd-337-3. **Upload a draft.**
documentation/09-deployment.qmd-338-   ```bash
documentation/09-deployment.qmd:339:   make analysis-release-zenodo-upload-draft
documentation/09-deployment.qmd-340-   # against the Zenodo sandbox instead of production, for a dry run:
documentation/09-deployment.qmd:341:   UPLOAD_ARGS="--sandbox" make analysis-release-zenodo-upload-draft
documentation/09-deployment.qmd-342-   ```
documentation/09-deployment.qmd:343:   Requires `ZENODO_TOKEN` (the target fails fast with a clear message if it is unset) and `outputs/analysis-release-zenodo/latest.env` (fails fast with "run analysis-release-zenodo-package first" if absent). Creates (or reuses, via `--deposition-id`) a Zenodo deposition, sets its metadata, and streams the archive to the deposition bucket — **always a DRAFT**, never published. Prints the reserved DOI and the draft's Zenodo web URL.
documentation/09-deployment.qmd-344-4. **Review the draft** in the Zenodo web UI (metadata, file listing, reserved DOI) before publishing.
documentation/09-deployment.qmd-345-5. **Publish — deliberately, by hand.** There is no Make target for this on purpose: publishing is a one-way action, so it stays a manual `Rscript` invocation behind a double gate (`analysis_release_zenodo_require_publish_confirmation()` refuses to make any HTTP call unless **both** flags are present). `ZENODO_TOKEN` must already be exported in the shell — there is no `--token` flag (a CLI flag would leak the token into shell history and process argv):
documentation/09-deployment.qmd-346-   ```bash
documentation/09-deployment.qmd:347:   Rscript api/scripts/upload-analysis-release-zenodo.R \
documentation/09-deployment.qmd:348:     --archive outputs/analysis-release-zenodo/archive/<release_id>.tar.gz \
documentation/09-deployment.qmd:349:     --metadata outputs/analysis-release-zenodo/staging/zenodo_metadata.json \
documentation/09-deployment.qmd-350-     --release-id <release_id> \
documentation/09-deployment.qmd-351-     --deposition-id <id-from-step-3> --publish --confirm-publish
documentation/09-deployment.qmd-352-   ```
documentation/09-deployment.qmd-353-6. **Record the DOI** back onto the SysNDD release head — additive only; it never touches `content_digest`/`manifest_sha256`, so the bytes a consumer already downloaded stay valid. Either automatically, by adding `--record-doi` (with `SYSNDD_ADMIN_TOKEN` set) to the publish command in step 5, or by running the manual `curl` command the script prints when `--record-doi` is omitted (equivalent to the `PATCH .../releases/<release_id>/doi` call documented above).
documentation/09-deployment.qmd-354-
documentation/09-deployment.qmd-355-**Defaults and safety.** Every upload is a DRAFT unless step 5's double gate is satisfied explicitly. The archive itself is a self-contained, independently-verifiable copy (its own `manifest.json`, `checksums.sha256`, and — for the two cluster layers — reproducibility bundles), so a Zenodo consumer never depends on SysNDD staying reachable. No manuscript or paper references appear anywhere in the packaged output.
--
.gitignore-86-secrets/
.gitignore-87-
.gitignore-88-# Superpowers SDD scratch (ledger, task briefs, review packages)
.gitignore-89-.superpowers/
.gitignore-90-
.gitignore-91-# Analysis-snapshot release Zenodo packaging output (#573 Slice C): staging
.gitignore:92:# trees + archives generated by `make analysis-release-zenodo-package`.
.gitignore:93:outputs/analysis-release-zenodo/
--
Makefile-38-# =============================================================================
Makefile-39-.DEFAULT_GOAL := help
Makefile-40-
Makefile-41-# =============================================================================
Makefile-42-# PHONY Declarations
Makefile-43-# =============================================================================
Makefile:44:.PHONY: help check-r check-npm check-docker install-api install-app dev serve-app build-app verify-app-bundle-budget watch-app test-api test-api-fast test-api-full mcp-transport-spike test-mcp-smoke coverage lint-api lint-app format-api format-app verify-seo-app code-quality-audit pre-commit ci-local _ci-cleanup preflight docker-build docker-up docker-down docker-dev docker-dev-db docker-logs docker-status cache-clear refresh-analysis-snapshots install-dev doctor worktree-setup worktree-prune refresh-fixtures test-ci-scripts verify-gate playwright-stack playwright-stack-down playwright-stack-logs docs-screenshots docs-screenshots-down verify-doc-screenshots _playwright-seed-templates _playwright-seed-users _playwright-seed-docs-data analysis-release-zenodo-package analysis-release-zenodo-upload-draft
Makefile-45-
Makefile-46-# =============================================================================
Makefile-47-# Help Target (Self-documenting)
Makefile-48-# =============================================================================
Makefile-49-help: ## Show this help message
Makefile-50-	@printf "SysNDD Development Commands\n\n"
--
Makefile-378-# ARGS/UPLOAD_ARGS are passed through to the analysis-release Zenodo operator
Makefile-379-# scripts below (e.g. ARGS="--release-id asr_..." or UPLOAD_ARGS="--sandbox");
Makefile-380-# default empty so --warn-undefined-variables stays quiet.
Makefile-381-ARGS ?=
Makefile-382-UPLOAD_ARGS ?=
Makefile-383-
Makefile:384:analysis-release-zenodo-package: check-r ## [quality] Package a published analysis-snapshot release into a Zenodo staging dir + tarball
Makefile-385-	@printf "$(CYAN)==> Packaging analysis-snapshot release for Zenodo...$(RESET)\n"
Makefile:386:	@cd $(ROOT_DIR) && $(HOST_RSCRIPT) api/scripts/package-analysis-release-zenodo.R $(ARGS) && \
Makefile:387:		printf "$(GREEN)✓ analysis-release-zenodo-package complete (see outputs/analysis-release-zenodo/latest.env)$(RESET)\n" || \
Makefile:388:		(printf "$(RED)✗ analysis-release-zenodo-package failed$(RESET)\n" && exit 1)
Makefile-389-
Makefile:390:analysis-release-zenodo-upload-draft: check-r ## [quality] Upload the last-packaged release to a Zenodo DRAFT (never publishes)
Makefile-391-	@if [ -z "$${ZENODO_TOKEN:-}" ]; then \
Makefile-392-		printf "$(RED)✗ ZENODO_TOKEN is not set (export it in your shell or .env before running this target)$(RESET)\n"; \
Makefile-393-		exit 1; \
Makefile-394-	fi
Makefile:395:	@if [ ! -f "$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env" ]; then \
Makefile:396:		printf "$(RED)✗ outputs/analysis-release-zenodo/latest.env not found -- run 'make analysis-release-zenodo-package' first$(RESET)\n"; \
Makefile-397-		exit 1; \
Makefile-398-	fi
Makefile-399-	@printf "$(CYAN)==> Uploading last-packaged analysis-snapshot release to a Zenodo DRAFT (never publishes)...$(RESET)\n"
Makefile:400:	@MARKER="$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env"; \
Makefile-401-		ARCHIVE_PATH="$$(sed -n 's/^ARCHIVE_PATH=//p' "$$MARKER" | tail -n1)"; \
Makefile-402-		METADATA_PATH="$$(sed -n 's/^METADATA_PATH=//p' "$$MARKER" | tail -n1)"; \
Makefile-403-		RELEASE_ID="$$(sed -n 's/^RELEASE_ID=//p' "$$MARKER" | tail -n1)"; \
Makefile:404:		cd $(ROOT_DIR) && $(HOST_RSCRIPT) api/scripts/upload-analysis-release-zenodo.R \
Makefile-405-			--archive "$$ARCHIVE_PATH" --metadata "$$METADATA_PATH" --release-id "$$RELEASE_ID" $(UPLOAD_ARGS) && \
Makefile:406:		printf "$(GREEN)✓ analysis-release-zenodo-upload-draft complete -- DRAFT only; publishing is a deliberate manual step (see documentation/09-deployment.qmd)$(RESET)\n" || \
Makefile:407:		(printf "$(RED)✗ analysis-release-zenodo-upload-draft failed$(RESET)\n" && exit 1)
Makefile-408-
Makefile-409-# =============================================================================
Makefile-410-# Docker Targets
Makefile-411-# =============================================================================
Makefile-412-# Compose file sets:
Makefile-413-#   Production:  docker-compose.yml
--
AGENTS.md-119-- **The build is a fail-closed 400 gate**, not a best-effort export (`analysis_snapshot_release_build()`, `functions/analysis-snapshot-release.R`). In order: (1) each registry layer must be `status_code == "available"` from `analysis_snapshot_get_public()`; (2) a **hard** partition-coherence re-check (`analysis_snapshot_assert_partition_coherent(..., require_coherence = TRUE)`) runs on every cluster layer regardless of the `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE` env downgrade — `available` only proves freshness/schema/source-version, not #514 coherence, so a release can never freeze an incoherent-but-`public_ready` snapshot; (3) each cluster layer must have a stored reproducibility bundle (the snapshot builder makes it best-effort, the release makes it mandatory); (4) all layers must share one `source_data_version`, and the correlation layer's dependency lineage must match the pinned functional + phenotype `snapshot_id`+`payload_hash` (the #571/#572 dependency gate); (5) a **TOCTOU guard** — the same per-preset advisory lock the axis refresh holds, plus a fresh pre-insert re-read of every layer immediately before persisting — closes the race between the initial read and the insert. Any gate failure is `stop_for_bad_request()` (400; there is no 409 class), naming the failing layer/reason. A rebuild whose content is **identical** to an existing release is not an error: it returns the existing head idempotently (200, no duplicate row); a genuinely new content set is 201.
AGENTS.md-120-- **Hashing facts, precisely.** Every file carries its **own** `content_sha256`. For each cluster layer, `sha256(reproducibility.json) == reproducibility_hash` **exactly** — this uses the raw pre-gzip bundle bytes (`analysis_reproducibility_decode_raw()`, `memDecompress(..., asChar = TRUE)`), never `analysis_reproducibility_decode()`, whose `jsonlite::fromJSON()` + re-serialize round-trip drops the bundle's full-precision (`digits = NA`) contract and breaks the equality. By contrast, `payload_hash`/`input_hash`/`snapshot_id` are recorded in the manifest as cross-checkable **lineage anchors** against the live `meta.snapshot.{payload_hash,input_hash,snapshot_id}` on the corresponding `/api/analysis/*` endpoint — they are **not** equal to a hash of the release's own `payload.json` file (the stored payload round-trips through `DECIMAL(8,7)`/`DECIMAL(8,5)` DB columns before the release freezes it, so a reconstructed byte-for-byte match is neither guaranteed nor attempted).
AGENTS.md-121-- **DOI is additive, outside the hash.** `PATCH /api/admin/analysis/releases/<id>/doi` (Administrator) records `{zenodo_record_id, zenodo_record_url, version_doi, concept_doi}` — any subset, an omitted field is left unchanged, never nulled out — and never touches `content_digest`/`manifest_sha256`; recording a DOI after publish changes zero release bytes.
AGENTS.md-122-- **Never pruned.** A published release is permanent; `DELETE /api/admin/analysis/releases/<id>` only works on a `draft`. `analysis_snapshot_prune()` (`analysis-snapshot-repository.R`) now skips any `snapshot_id` still referenced by an `analysis_snapshot_release_member` row (`analysis_release_referenced_snapshot_ids()`), so a snapshot pinned by a release keeps serving its live reproducibility endpoint too — even though release integrity never depends on the source snapshot surviving (each release is self-contained).
AGENTS.md-123-- **Build is synchronous, admin, DB-only — the worker is NOT required.** Unlike snapshot refresh, `POST /api/admin/analysis/releases` runs inline on the API request (`analysis_snapshot_release_build()` is called directly from the endpoint, not submitted as an async job): no clustering recompute, no external calls, no LLM, no cache writes. A release can be built even if the worker is down, as long as public-ready snapshots already exist.
AGENTS.md-124-- **`GET .../releases/<release_id>/file?path=<file_path>` uses a query param, not a nested path segment**, because Plumber 1.3.2 has no `<path:.*>` wildcard — only named, typed, single-segment path params (`<id>`, `<id:int>`) exist, so a nested archive path (e.g. `functional_clusters/payload.json`) cannot be expressed as a URL path segment. The manifest's `files[].path` values are the caller's index into this route.
AGENTS.md:125:- **Zenodo operator scripts (#573 Slice C).** `api/scripts/{package,upload}-analysis-release-zenodo.R` (+ helpers `api/functions/analysis-snapshot-release-zenodo-{common,package,verify,docs,upload}.R`) archive a published release to Zenodo. They are HOST-RUN, HTTP-only (read a published release via the public API only — no DB/worker involvement), draft-only by default behind a `--publish --confirm-publish` double-gate, and support an opt-in `--record-doi` record-back to the additive DOI PATCH endpoint above. `make analysis-release-zenodo-package` / `make analysis-release-zenodo-upload-draft` wrap them for local operator use (the package step also writes a `outputs/analysis-release-zenodo/latest.env` pointer file so the upload step can find the content-addressed archive without a hardcoded filename, and the Makefile reads that file back with a safe `sed` field-extract, not a `source`, so a marker-format change can never inject shell); the Makefile never passes `--publish`. These scripts are operator-only — NOT sourced by `bootstrap/load_modules.R` — and are exempt from the external-budget guard (one-shot scripts, not request-path code), covered by `test-unit-analysis-release-zenodo-{package,verify,upload,upload-doi-safety}.R`. Hardening (post-Codex-review, #573 Slice C round 1): the resolved/requested `release_id` is validated against `^asr_[0-9a-f]{16}$` (`.analysis_release_zenodo_assert_valid_release_id()`, now in the shared `-common.R` guard-sourced by BOTH the package/verify pair and the upload/DOI file) before it can become a filename/path/marker value; `analysis_release_zenodo_package()` refuses to `unlink(recursive = TRUE)` a pre-existing `--staging-dir` unless it is empty or carries an ownership sentinel (`.analysis-release-zenodo-staging`) this tool itself wrote on a prior run — a non-empty, non-sentinel dir stops the build instead of being silently rmtree'd; the safety validator matches forbidden names/dir-parts case-insensitively, enforces a file-type allowlist (`.md`/`.json`/`.sha256`/`.cff`/`.txt`/`.sql` only), and rejects symlinks; `analysis_release_zenodo_extract_and_verify()` requires full checksum COVERAGE (every extracted file, no unstamped extras) and rejects absolute/`..` paths in both tar members and checksum entries; the tarball is made byte-identical across rebuilds of the same staged content by normalizing every staged file/dir's mtime to a fixed epoch before tarring (R's internal tar writer already zeroes the gzip container timestamp); and the upload CLI reads `ZENODO_TOKEN` from the environment ONLY — there is no `--token` flag, to avoid leaking the token into shell history/argv. Round 2: `extract_and_verify()` walks the EXTRACTED bundle tree (`.analysis_release_zenodo_reject_symlinks()`) and rejects any symlink IMMEDIATELY after `untar()`, before any checksum hashing or staging copy can follow it (`Sys.readlink(path) != ""`); the `..`-traversal check now also splits on `\` and rejects a leading `\`/UNC/drive-letter prefix, not just POSIX `/`-absolute paths, for both tar members and checksum entries; the upload/DOI path (`record_doi()`, `manual_doi_command()`, and the CLI-facing `analysis_release_zenodo_print_doi_record_back()`) validates `--release-id` with the SAME shared validator before building any admin PATCH URL or printed `curl` command, and `manual_doi_command()` additionally `shQuote()`s the interpolated URL/JSON body as defense in depth; and `print_doi_record_back()` never prints a populated PATCH command for a DRAFT upload (published-only rule) — only post-publication instructions, regardless of `--record-doi`. Round 3: the extracted-tree guard (renamed `.analysis_release_zenodo_reject_unsafe_files()`) now rejects ANY non-regular file, not just symlinks — a FIFO/pipe passed the round-2 symlink-only check and would then block `digest::digest(file = ...)` indefinitely (no writer ever connects); the type check uses `fs::file_info(path)$type == "file"`, deliberately NOT base R's `file_test("-f", path)`, which (per `utils:::file_test`'s own source) only tests "exists and is not a directory" and is therefore still `TRUE` for a FIFO/socket/device — verified empirically before relying on it. `analysis_release_zenodo_download_bundle()` also now validates its own `release_id` argument (`allow_latest = FALSE`) immediately after coercion, so a direct caller of this exported helper (not just the package orchestrator, which already re-validated the resolved id) cannot interpolate an unvalidated value into the bundle URL.
AGENTS.md-126-
AGENTS.md-127-### Cluster-analysis statistical soundness (#508–#512)
AGENTS.md-128-
AGENTS.md-129-The two-axis cluster analysis (phenotype MCA/HCPC and functional STRING/Leiden) and the served "function is modular, phenotype is a continuum" cross-axis interpretation are made mathematically sound and self-reproducing. `validation_schema_version` is `"2.0"`, `ANALYSIS_SNAPSHOT_SCHEMA_VERSION` is `"1.2"`. The **key lever**: `analysis_snapshot_payload_hash` deliberately excludes `partition_validation` (`analysis-snapshot-builder.R`), so everything in the validation block is **additive** — new metrics never change `cluster_hash` and never invalidate LLM summaries. Only changes to cluster **membership** (the #508 MCA filter, the #509 `kk=Inf` consolidation, the #510 channel switch) change `cluster_hash` and therefore require a coordinated forced snapshot refresh + LLM regeneration.
AGENTS.md-130-
AGENTS.md-131-- **Common cross-axis footing (#511)** lives in `api/functions/analysis-null-models.R` (worker/heavy-path only; registered in `bootstrap/load_modules.R`). Both axes report a **unit-free, null-calibrated `separation_z`** so the contrast is like-for-like instead of raw-silhouette-vs-raw-modularity: functional = **modularity z-score** vs a **degree-preserving configuration-model null** (`modularity_null_zscore`: `igraph::rewire(keeping_degseq)` + permuted weight multiset, re-restricting **both** the observed graph and every replicate to the largest connected component, and **re-detecting communities with the identical seeded Leiden on each replicate** — the Guimerà/Sales-Pardo/Amaral re-optimized null, so `modularity_z` benchmarks against the modularity a degree-matched random graph genuinely reaches rather than being a near-tautological Q-vs-0 test; **never** revert this to carrying the observed labels onto the null, which inflates the z by orders of magnitude); phenotype = **silhouette z-score** vs a **label-permutation null** (`silhouette_null_zscore`). The `modularity_null_zscore` `recluster` argument selects the flavour: the functional axis passes a Leiden closure (re-optimized, `null_model = "…_reoptimized"`), while the phenotype `shared_modularity_z` passes **none** and holds the external MCA/HCPC labels **fixed** on the kNN null (`"…_fixed_labels"`) because the graph cannot re-derive that partition (it is an attribute-assortativity test). Additionally a **dip test of unimodality** (`dip_unimodality`, Hartigan; optional `diptest` dependency — degrades to `NA` if absent) is reported on both axes' pairwise-distance distributions as a **corroborating** continuum-vs-modular signal (`dip_p` small → discrete; large → continuum); the functional dip runs on **continuous weighted shortest-path distances** (edge distance `1 - combined_score/1000`), NOT integer hop counts, so it is not a discreteness artifact, and because pairwise distances are mutually dependent `dip_p` corroborates rather than strictly proves. The SAME modularity-z index is also reported for phenotype on a mutual-kNN graph of the MCA coords (`knn_similarity_graph` → `shared_modularity_z`). Never resurrect a direct silhouette-vs-modularity comparison.
--
CHANGELOG.md-9-## [0.30.3] — 2026-07-19
CHANGELOG.md-10-
CHANGELOG.md-11-Zenodo archival operator scripts for analysis-snapshot releases (#573, Slice C). A published analysis-snapshot release (Slice A) can now be archived to Zenodo with two host-run, HTTP-only scripts — no DB, no worker, no docker exec. Note: 0.30.1 (#574 category clustering) and 0.30.2 (#573 Slice B UI) are reserved for those PRs, which this assumes land first.
CHANGELOG.md-12-
CHANGELOG.md-13-### Added
CHANGELOG.md-14-
CHANGELOG.md:15:- **`api/scripts/package-analysis-release-zenodo.R`**: fetches a published release over the public `/api/analysis/releases/*` API, verifies its bundle checksum, re-stages the files under `analysis_snapshot_release/`, adds Zenodo-facing docs/metadata (`README.md`, `DATA_CARD.md`, `SCHEMA.md`, `CHANGELOG.md`, `CITATION.cff`, `zenodo_metadata.json`, `datapackage.json`), runs a packaging safety validator, and produces a deterministic `<release_id>.tar.gz` + checksum. Writes a `outputs/analysis-release-zenodo/latest.env` pointer file so downstream tooling can find the content-addressed archive without a hardcoded filename.
CHANGELOG.md:16:- **`api/scripts/upload-analysis-release-zenodo.R`**: uploads a packaged archive to a Zenodo deposition (get-or-create, set metadata, stream file to bucket), with an optional, doubly-gated `--publish --confirm-publish` step and an opt-in `--record-doi` record-back to the additive `PATCH /api/admin/analysis/releases/<id>/doi` endpoint. Draft-only by default; publishing is always a deliberate, explicit action.
CHANGELOG.md:17:- Two Make targets, `analysis-release-zenodo-package` and `analysis-release-zenodo-upload-draft`, wrap the scripts for local operator use; the Makefile itself never passes `--publish`.
CHANGELOG.md-18-- Operator runbook documented in `documentation/09-deployment.qmd` under "Zenodo archival (operator scripts, #573 Slice C)".
CHANGELOG.md-19-
CHANGELOG.md-20-## [0.30.0] — 2026-07-18
CHANGELOG.md-21-
CHANGELOG.md-22-Immutable public analysis-snapshot releases (#573, Slice A). SysNDD's derived
CHANGELOG.md-23-cluster analyses (functional STRING/Leiden clusters, phenotype MCA/HCPC
     1	# Unit tests for the Codex round-3 hardening of the analysis-snapshot
     2	# RELEASE Zenodo fetch/extract-verify helpers (#573 Slice C):
     3	# api/functions/analysis-snapshot-release-zenodo-verify.R.
     4	#
     5	# Split out of the sibling test-unit-analysis-release-zenodo-verify.R (which
     6	# covers the pre-existing/round-1/round-2 fetch/extract/staging-validator
     7	# behavior) to keep both files under the repo's 600-line soft ceiling --
     8	# mirrors the `-upload.R`/`-upload-doi-safety.R` split precedent. Shares
     9	# `build_fixture_bundle()` (the tar.gz + inner checksums.sha256 builder) via
    10	# `analysis-release-zenodo-verify-fixtures.R`, sourced below, rather than
    11	# duplicating it.
    12	#
    13	# Covers item 1 (HIGH): `.analysis_release_zenodo_reject_unsafe_files()`
    14	# (renamed from `.analysis_release_zenodo_reject_symlinks()`) rejects ANY
    15	# non-regular file under the extracted bundle tree -- not just symlinks --
    16	# so a FIFO/pipe can never reach `digest::digest(file = ...)`, which would
    17	# otherwise block indefinitely reading it.
    18
    19	library(testthat)
    20
    21	source_api_file("functions/analysis-snapshot-release-zenodo-package.R", local = FALSE)
    22	source_api_file("tests/testthat/analysis-release-zenodo-verify-fixtures.R", local = FALSE)
    23
    24	# --------------------------------------------------------------------------- #
    25	# extract_and_verify: non-regular-file (FIFO) rejection (item 1, HIGH)
    26	# --------------------------------------------------------------------------- #
    27
    28	test_that("extract_and_verify: FAILS when a non-regular file (FIFO) sits in the extraction dir (Codex round-3 item 1, HIGH) -- rejected BEFORE any digest read, does not hang", {
    29	  # Proves the round-3 HIGH fix: the extracted-tree guard must reject ANY
    30	  # non-regular file, not just symlinks. A FIFO passes the round-2 guard
    31	  # (which only checked `Sys.readlink()`), and `digest::digest(file = ...)`
    32	  # on a FIFO with no writer connected blocks INDEFINITELY -- a fail-closed
    33	  # violation.
    34	  #
    35	  # The FIFO's name is deliberately listed in the bundle's OWN
    36	  # checksums.sha256 (via `extra_checksum_lines`): absent the guard, the
    37	  # per-line checksum-verification loop inside `extract_and_verify()` would
    38	  # reach `digest::digest(file = <the fifo path>)` and hang forever. This
    39	  # test's own bounded completion (testthat has no per-test timeout, but a
    40	  # hang here would stall/timeout the whole suite run) is therefore direct
    41	  # evidence the non-regular-file guard fires and stops the function BEFORE
    42	  # the checksum loop ever opens the FIFO for reading. This was manually
    43	  # confirmed by driving `analysis_release_zenodo_extract_and_verify()`
    44	  # directly under a bash `timeout` before this test was written.
    45	  #
    46	  # The FIFO is planted directly in the (pre-created) extraction directory --
    47	  # not packed into the tar.gz itself -- because taring/untaring a FIFO node
    48	  # is an orthogonal, less portable concern; planting it here exercises the
    49	  # exact same post-untar guard call site with no risk of the archive step
    50	  # itself blocking.
    51	  work_dir <- withr::local_tempdir()
    52	  fifo_rel_name <- "evil_fifo"
    53	  bundle_path <- build_fixture_bundle(
    54	    work_dir, extra_checksum_lines = paste0(strrep("0", 64L), "  ", fifo_rel_name)
    55	  )
    56	  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
    57
    58	  exdir <- file.path(work_dir, "extracted_fifo_member")
    59	  dir.create(exdir, recursive = TRUE)
    60	  fifo_path <- file.path(exdir, fifo_rel_name)
    61	  fifo_created <- identical(
    62	    base::system2("mkfifo", shQuote(fifo_path), stdout = FALSE, stderr = FALSE), 0L
    63	  )
    64	  skip_if_not(fifo_created, "host does not support mkfifo (e.g. some restricted/Windows runners)")
    65
    66	  expect_error(
    67	    analysis_release_zenodo_extract_and_verify(bundle_path, expected_sha, exdir = exdir),
    68	    "non-regular file"
    69	  )
    70	  # The FIFO node itself is untouched (stat'd, never opened for reading),
    71	  # which is exactly why the guard call above returned promptly instead of
    72	  # blocking.
    73	  expect_true(file.exists(fifo_path))
    74	})
    75
    76	test_that("extract_and_verify: a normal bundle with no special files still passes (non-regular-file guard has no false positive)", {
    77	  work_dir <- withr::local_tempdir()
    78	  bundle_path <- build_fixture_bundle(work_dir)
    79	  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
    80
    81	  exdir <- file.path(work_dir, "extracted_ok")
    82	  expect_no_error(
    83	    analysis_release_zenodo_extract_and_verify(bundle_path, expected_sha, exdir = exdir)
    84	  )
    85	  expect_true(file.exists(file.path(exdir, "a.txt")))
    86	})
   135	    )
   136	  )
   137	})
   138
   139	# --------------------------------------------------------------------------- #
   140	# fetch_head / download_bundle -- DI seams, no real network
   141	# --------------------------------------------------------------------------- #
   142
   143	test_that("fetch_head: builds the /releases/latest URL and passes the stub's JSON through", {
   144	  captured_url <- NULL
   145	  stub_get_json <- function(url) {
   146	    captured_url <<- url
   147	    list(release_id = "asr_abcdef0123456789", bundle_sha256 = "deadbeef")
   148	  }
   149	  head <- analysis_release_zenodo_fetch_head("http://localhost:7778", "latest", http_get_json = stub_get_json)
   150	  expect_identical(captured_url, "http://localhost:7778/api/analysis/releases/latest")
   151	  expect_identical(head$release_id, "asr_abcdef0123456789")
   152	})
   153
   154	test_that("fetch_head: builds the /releases/<id> URL for an explicit release_id (trailing slash tolerated)", {
   155	  captured_url <- NULL
   156	  stub_get_json <- function(url) {
   157	    captured_url <<- url
   158	    list(release_id = "asr_0000000000000000")
   159	  }
   160	  head <- analysis_release_zenodo_fetch_head(
   161	    "http://localhost:7778/", "asr_0000000000000000", http_get_json = stub_get_json
   162	  )
   163	  expect_identical(captured_url, "http://localhost:7778/api/analysis/releases/asr_0000000000000000")
   164	  expect_identical(head$release_id, "asr_0000000000000000")
   165	})
   166
   167	test_that("download_bundle: builds the /releases/<id>/bundle URL and streams the stub's content through", {
   168	  captured <- new.env()
   169	  work_dir <- withr::local_tempdir()
   170	  dest <- file.path(work_dir, "bundle.tar.gz")
   171	  stub_download <- function(url, destfile) {
   172	    assign("url", url, envir = captured)
   173	    assign("destfile", destfile, envir = captured)
   174	    writeBin(as.raw(c(1, 2, 3)), destfile)
   175	  }
   176	  result <- analysis_release_zenodo_download_bundle(
   177	    "http://localhost:7778", "asr_0000000000000000", dest, http_download = stub_download
   178	  )
   179	  expect_identical(get("url", envir = captured), "http://localhost:7778/api/analysis/releases/asr_0000000000000000/bundle")
   180	  expect_identical(get("destfile", envir = captured), dest)
   181	  expect_identical(result, dest)
   182	  expect_true(file.exists(dest))
   183	})
   184
   185	test_that("download_bundle: errors when the injected downloader produces an empty file", {
   186	  work_dir <- withr::local_tempdir()
   187	  dest <- file.path(work_dir, "empty.tar.gz")
   188	  stub_download <- function(url, destfile) {
   189	    file.create(destfile)
   190	  }
   191	  expect_error(
   192	    analysis_release_zenodo_download_bundle(
   193	      "http://localhost:7778", "asr_0000000000000000", dest, http_download = stub_download
   194	    ),
   195	    "empty"
   196	  )
   197	})
   198
   199	# --------------------------------------------------------------------------- #
   200	# download_bundle: release_id shape validation (Codex round-3 item 2,
   201	# MEDIUM). The package orchestrator already re-validates the RESOLVED id
   202	# before calling download_bundle(), but this exported helper can be called
   203	# directly, so it must reject a malformed id itself, before it is ever
   204	# interpolated into the bundle URL and before http_download is invoked.
   205	# --------------------------------------------------------------------------- #
   206
   207	test_that("download_bundle: rejects a malformed release_id ('asr_x') before calling http_download", {
   208	  called <- FALSE
   209	  stub_download <- function(url, destfile) {
   210	    called <<- TRUE
   211	    file.create(destfile)
   212	  }
   213	  work_dir <- withr::local_tempdir()
   214	  dest <- file.path(work_dir, "bundle.tar.gz")
   215	  expect_error(
   216	    analysis_release_zenodo_download_bundle(
   217	      "http://localhost:7778", "asr_x", dest, http_download = stub_download
   218	    ),
   219	    "Invalid analysis-snapshot release id"
   220	  )
   221	  expect_false(called)
   222	  expect_false(file.exists(dest))
   223	})
   224
   225	test_that("download_bundle: rejects a release_id containing '..' (path traversal shape) before calling http_download", {
   226	  called <- FALSE
   227	  stub_download <- function(url, destfile) {
   228	    called <<- TRUE
   229	    file.create(destfile)
   230	  }
   231	  work_dir <- withr::local_tempdir()
   232	  dest <- file.path(work_dir, "bundle.tar.gz")
   233	  expect_error(
   234	    analysis_release_zenodo_download_bundle(
   235	      "http://localhost:7778", "../evil", dest, http_download = stub_download
   236	    ),
   237	    "Invalid analysis-snapshot release id"
   238	  )
   239	  expect_false(called)
   240	})
   241
   242	test_that("download_bundle: rejects a release_id containing a quote before calling http_download", {
   243	  called <- FALSE
   244	  stub_download <- function(url, destfile) {
   245	    called <<- TRUE
   246	    file.create(destfile)
   247	  }
   248	  work_dir <- withr::local_tempdir()
   249	  dest <- file.path(work_dir, "bundle.tar.gz")
   250	  expect_error(
   251	    analysis_release_zenodo_download_bundle(
   252	      "http://localhost:7778", "asr_1234567890abcd'; rm -rf /", dest, http_download = stub_download
   253	    ),
   254	    "Invalid analysis-snapshot release id"
   255	  )
   256	  expect_false(called)
   257	})
   258
   259	test_that("download_bundle: rejects 'latest' (a bundle URL always targets a concrete id)", {
   260	  called <- FALSE
   261	  stub_download <- function(url, destfile) {
   262	    called <<- TRUE
   263	    file.create(destfile)
   264	  }
   265	  work_dir <- withr::local_tempdir()
   266	  dest <- file.path(work_dir, "bundle.tar.gz")
   267	  expect_error(
   268	    analysis_release_zenodo_download_bundle(
   269	      "http://localhost:7778", "latest", dest, http_download = stub_download
   270	    ),
   271	    "Invalid analysis-snapshot release id"
   272	  )
   273	  expect_false(called)
   274	})
   275
   276	# --------------------------------------------------------------------------- #
   277	# extract_and_verify
   278	# --------------------------------------------------------------------------- #
   279
   280	test_that("extract_and_verify: passes with a matching bundle_sha256 and matching inner checksums", {
   281	  work_dir <- withr::local_tempdir()
   282	  bundle_path <- build_fixture_bundle(work_dir)
   283	  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
   284
   285	  exdir <- file.path(work_dir, "extracted")
api/functions/analysis-snapshot-release-zenodo-upload.R:150:#' Get-or-create a Zenodo deposition. `deposition_id = NULL` creates a fresh
api/functions/analysis-snapshot-release-zenodo-upload.R:157:analysis_release_zenodo_get_or_create_deposition <- function(
api/functions/analysis-snapshot-release-zenodo-upload.R:158:    api, token, deposition_id = NULL, http = .analysis_release_zenodo_http_json) {
api/functions/analysis-snapshot-release-zenodo-upload.R:160:  if (is.null(deposition_id)) {
api/functions/analysis-snapshot-release-zenodo-upload.R:163:    deposition_id <- as.character(deposition_id)[[1]]
api/functions/analysis-snapshot-release-zenodo-upload.R:164:    http("GET", paste0(api, "/deposit/depositions/", deposition_id), token)
api/functions/analysis-snapshot-release-zenodo-upload.R:172:analysis_release_zenodo_set_metadata <- function(
api/functions/analysis-snapshot-release-zenodo-upload.R:173:    api, token, deposition_id, metadata, http = .analysis_release_zenodo_http_json) {
api/functions/analysis-snapshot-release-zenodo-upload.R:175:  deposition_id <- as.character(deposition_id)[[1]]
api/functions/analysis-snapshot-release-zenodo-upload.R:176:  url <- paste0(api, "/deposit/depositions/", deposition_id)
api/functions/analysis-snapshot-release-zenodo-upload.R:181:#' `PUT {bucket_url}/{basename(archive_path)}`.
api/functions/analysis-snapshot-release-zenodo-upload.R:186:analysis_release_zenodo_upload_bucket <- function(
api/functions/analysis-snapshot-release-zenodo-upload.R:187:    bucket_url, token, archive_path, put = .analysis_release_zenodo_http_put_file) {
api/functions/analysis-snapshot-release-zenodo-upload.R:188:  bucket_url <- sub("/+$", "", as.character(bucket_url)[[1]])
api/functions/analysis-snapshot-release-zenodo-upload.R:189:  url <- paste0(bucket_url, "/", basename(archive_path))
api/functions/analysis-snapshot-release-zenodo-upload.R:199:analysis_release_zenodo_publish_deposition <- function(
api/functions/analysis-snapshot-release-zenodo-upload.R:200:    api, token, deposition_id, http = .analysis_release_zenodo_http_json) {
api/functions/analysis-snapshot-release-zenodo-upload.R:202:  deposition_id <- as.character(deposition_id)[[1]]
api/functions/analysis-snapshot-release-zenodo-upload.R:203:  url <- paste0(api, "/deposit/depositions/", deposition_id, "/actions/publish")
api/functions/analysis-snapshot-release-zenodo-upload.R:355:    zenodo_record_id = as.character(result$deposition_id),
api/functions/analysis-snapshot-release-zenodo-upload.R:398:#' @return list(deposition_id, reserved_doi, draft_url, published (bool),
api/functions/analysis-snapshot-release-zenodo-upload.R:406:    deposition_id = NULL,
api/functions/analysis-snapshot-release-zenodo-upload.R:409:    get_or_create_deposition = analysis_release_zenodo_get_or_create_deposition,
api/functions/analysis-snapshot-release-zenodo-upload.R:410:    set_metadata = analysis_release_zenodo_set_metadata,
api/functions/analysis-snapshot-release-zenodo-upload.R:411:    upload_bucket = analysis_release_zenodo_upload_bucket,
api/functions/analysis-snapshot-release-zenodo-upload.R:412:    publish_deposition = analysis_release_zenodo_publish_deposition) {
api/functions/analysis-snapshot-release-zenodo-upload.R:432:  deposition <- get_or_create_deposition(api, token, deposition_id = deposition_id)
api/functions/analysis-snapshot-release-zenodo-upload.R:433:  resolved_deposition_id <- deposition$id
api/functions/analysis-snapshot-release-zenodo-upload.R:434:  bucket_url <- deposition$links$bucket
api/functions/analysis-snapshot-release-zenodo-upload.R:437:  set_metadata(api, token, resolved_deposition_id, metadata)
api/functions/analysis-snapshot-release-zenodo-upload.R:438:  upload_bucket(bucket_url, token, archive_path)
api/functions/analysis-snapshot-release-zenodo-upload.R:441:    deposition_id = resolved_deposition_id,
api/functions/analysis-snapshot-release-zenodo-upload.R:451:    published_deposition <- publish_deposition(api, token, resolved_deposition_id)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:59:  result <- analysis_release_zenodo_upload_bucket(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:69:test_that("upload_bucket: strips a trailing slash from bucket_url before building the target URL", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:75:  analysis_release_zenodo_upload_bucket("https://zenodo.example/bucket/", "token", archive, put = stub_put)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:84:test_that("get_or_create_deposition: NULL deposition_id -> POST .../deposit/depositions", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:94:  result <- analysis_release_zenodo_get_or_create_deposition(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:95:    "https://zenodo.org/api", "tok", deposition_id = NULL, http = stub_http
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:105:test_that("get_or_create_deposition: explicit deposition_id -> GET .../deposit/depositions/{id}", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:114:  result <- analysis_release_zenodo_get_or_create_deposition(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:115:    "https://zenodo.org/api", "tok", deposition_id = 42, http = stub_http
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:138:  analysis_release_zenodo_set_metadata(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:159:  result <- analysis_release_zenodo_publish_deposition(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:328:  fake_get_or_create <- function(api, token, deposition_id = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:335:  fake_set_metadata <- function(api, token, deposition_id, metadata) NULL
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:336:  fake_upload_bucket <- function(bucket_url, token, archive_path) invisible(NULL)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:337:  fake_publish <- function(api, token, deposition_id) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:355:  expect_identical(result$deposition_id, 111)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:365:  fake_get_or_create <- function(api, token, deposition_id = NULL) {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:368:  fake_set_metadata <- function(api, token, deposition_id, metadata) NULL
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:369:  fake_upload_bucket <- function(bucket_url, token, archive_path) invisible(NULL)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:370:  fake_publish <- function(api, token, deposition_id) {

codex
The two requested changes are present in the execution path: the non-regular-file check occurs immediately after extraction and before checksum reads, and `download_bundle()` validates before URL construction or its injectable downloader. I’m completing the adjacent sweep now, including shell/marker handling and the upload/DOI boundaries.
exec
/bin/bash -lc "git diff --unified=80 origin/master...HEAD -- .gitignore Makefile app/package.json app/package-lock.json api/version_spec.json CHANGELOG.md documentation/09-deployment.qmd
rg -n -C 4 'source\\(|unlink\\(|system\\(|system2\\(|setwd\\(|readLines\\(|writeLines\\(|cat\\(|file\\.copy\\(|file\\.exists\\(|file\\.size\\(|normalizePath\\(|tar\\(|untar\\(' api/functions/analysis-snapshot-release-zenodo-*.R api/scripts/{package,upload}-analysis-release-zenodo.R
rg -n -C 3 'PATCH.*doi|analysis/releases.*doi|require_role|analysis_release.*doi' api/endpoints/admin_analysis_snapshot_endpoints.R api/functions/analysis-snapshot-release*.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
diff --git a/.gitignore b/.gitignore
index c3aedec2..c7f0f765 100644
--- a/.gitignore
+++ b/.gitignore
@@ -10,80 +10,84 @@ app/docker/nginx/key.pem

 # TLS certificate renewal (issue #25): real site-specific config + any
 # accidentally-local key/CSR output must never be committed. Only the
 # *.example template is tracked.
 scripts/cert/cert-renewal.conf
 scripts/cert/*.key.pem
 scripts/cert/*.csr.pem
 scripts/cert/*.crt
 scripts/cert/*.pem

 # testing files
 TESTING.md

 # claude files
 .claude.planning/intel/

 # Coverage reports
 coverage/

 # Local Node helper dependencies
 api/layout/node_modules/

 # Environment files with secrets
 .env
 .env.local
 .env.*.local
 .playwright-mcp/

 # Local plan data (database backups)
 .plan/
 __pycache__/

 # Parallel worktree workflow (v11.0+ phase worktrees)
 /worktrees/

 # git worktrees (created by superpowers workflow)
 .worktrees/

 # Generated UI audit screenshots
 .planning/ui-audit/**/*.png
 .planning/ui-audit/**/lighthouse/
 .planning/ui-audit/**/lighthouse-profile/
 .planning/ui-audit/**/lighthouse-summary.json
 .planning/ui-audit/**/playwright-audit*.json

 # Generated Playwright design-audit captures
 .planning/screenshots/*-design-audit/
 .planning/screenshots/**/*.png

 # Generated NDDScore test fixture archives
 api/tests/testthat/fixtures/nddscore/*.tar.gz

 # Understand-Anything knowledge graph artifacts
 .understand-anything/

 # Frontend design audit (2026-06): keep markdown reports + scripts + small JSON; ignore heavy captures
 .planning/audits/**/screenshots/
 .planning/audits/**/lighthouse/*.json
 .planning/audits/**/lighthouse/*.err
 .planning/audits/**/lighthouse/run.log
 .planning/audits/**/ratings-raw.json
 .planning/audits/**/capture.log
 ratings-final-raw.json
 .planning/audits/**/lighthouse-final/*.json
 .planning/audits/**/lighthouse-final/*.err
 .planning/audits/**/lighthouse-final/run.log
 .planning/audits/**/lh-b1/
 .planning/audits/**/lh-b2/
 .planning/audits/**/lh-b3/
 .planning/audits/**/capture-final.log
 .planning/audits/**/lighthouse-recheck/

 # Runtime worker output: blocked omim_update pending ontology CSVs (#470)
 api/data/pending_ontology/

 # Operator-generated runtime secrets (never commit).
 secrets/

 # Superpowers SDD scratch (ledger, task briefs, review packages)
 .superpowers/
+
+# Analysis-snapshot release Zenodo packaging output (#573 Slice C): staging
+# trees + archives generated by `make analysis-release-zenodo-package`.
+outputs/analysis-release-zenodo/
diff --git a/CHANGELOG.md b/CHANGELOG.md
index 48651d8b..10996e09 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -1,88 +1,99 @@
 # Changelog

 All notable changes to SysNDD are documented in this file.

 The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (loosely, in the `0.x` line — additive changes land as patch bumps while the public API still stabilises).

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
diff --git a/Makefile b/Makefile
index f6a2865c..4e563781 100644
--- a/Makefile
+++ b/Makefile
@@ -1,124 +1,124 @@
 # SysNDD Development Automation
 # Usage: make <target>
 # Run `make` or `make help` to see available commands

 # =============================================================================
 # Davis-Hansson Preamble (https://tech.davis-hansson.com/p/make/)
 # =============================================================================
 SHELL := bash
 .ONESHELL:
 .SHELLFLAGS := -eu -o pipefail -c
 .DELETE_ON_ERROR:
 MAKEFLAGS += --warn-undefined-variables
 MAKEFLAGS += --no-builtin-rules

 # =============================================================================
 # Project Root (auto-detected)
 # =============================================================================
 ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
 HOST_R_HOME := $(shell R RHOME 2>/dev/null)
 HOST_R_MARIADB_LIB_DIR ?= $(patsubst %/,%,$(dir $(HOST_R_HOME)))/mariadb
 HOST_R_ENV_LD_LIBRARY_PATH := $(shell printf '%s' "$${LD_LIBRARY_PATH-}")
 HOST_R_LD_LIBRARY_PATH ?= $(if $(wildcard $(HOST_R_MARIADB_LIB_DIR)/libmariadb.so*),$(HOST_R_MARIADB_LIB_DIR)$(if $(HOST_R_ENV_LD_LIBRARY_PATH),:$(HOST_R_ENV_LD_LIBRARY_PATH)),$(HOST_R_ENV_LD_LIBRARY_PATH))
 HOST_RSCRIPT := env LD_LIBRARY_PATH="$(HOST_R_LD_LIBRARY_PATH)" Rscript --no-init-file

 include $(ROOT_DIR)/make/mcp-select-principal.mk

 # =============================================================================
 # ANSI Color Codes
 # =============================================================================
 GREEN := \033[0;32m
 RED := \033[0;31m
 CYAN := \033[0;36m
 YELLOW := \033[0;33m
 RESET := \033[0m

 # =============================================================================
 # Default Goal
 # =============================================================================
 .DEFAULT_GOAL := help

 # =============================================================================
 # PHONY Declarations
 # =============================================================================
-.PHONY: help check-r check-npm check-docker install-api install-app dev serve-app build-app verify-app-bundle-budget watch-app test-api test-api-fast test-api-full mcp-transport-spike test-mcp-smoke coverage lint-api lint-app format-api format-app verify-seo-app code-quality-audit pre-commit ci-local _ci-cleanup preflight docker-build docker-up docker-down docker-dev docker-dev-db docker-logs docker-status cache-clear refresh-analysis-snapshots install-dev doctor worktree-setup worktree-prune refresh-fixtures test-ci-scripts verify-gate playwright-stack playwright-stack-down playwright-stack-logs docs-screenshots docs-screenshots-down verify-doc-screenshots _playwright-seed-templates _playwright-seed-users _playwright-seed-docs-data
+.PHONY: help check-r check-npm check-docker install-api install-app dev serve-app build-app verify-app-bundle-budget watch-app test-api test-api-fast test-api-full mcp-transport-spike test-mcp-smoke coverage lint-api lint-app format-api format-app verify-seo-app code-quality-audit pre-commit ci-local _ci-cleanup preflight docker-build docker-up docker-down docker-dev docker-dev-db docker-logs docker-status cache-clear refresh-analysis-snapshots install-dev doctor worktree-setup worktree-prune refresh-fixtures test-ci-scripts verify-gate playwright-stack playwright-stack-down playwright-stack-logs docs-screenshots docs-screenshots-down verify-doc-screenshots _playwright-seed-templates _playwright-seed-users _playwright-seed-docs-data analysis-release-zenodo-package analysis-release-zenodo-upload-draft

 # =============================================================================
 # Help Target (Self-documenting)
 # =============================================================================
 help: ## Show this help message
 	@printf "SysNDD Development Commands\n\n"
 	@printf "$(CYAN)Environment:$(RESET)\n"
 	@grep -E '^[a-zA-Z_-]+:.*?## \[env\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[env\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
 	@printf "\n$(CYAN)Development:$(RESET)\n"
 	@grep -E '^[a-zA-Z_-]+:.*?## \[dev\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[dev\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
 	@printf "\n$(CYAN)Testing:$(RESET)\n"
 	@grep -E '^[a-zA-Z_-]+:.*?## \[test\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[test\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
 	@printf "\n$(CYAN)Linting:$(RESET)\n"
 	@grep -E '^[a-zA-Z_-]+:.*?## \[lint\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[lint\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
 	@printf "\n$(CYAN)Docker:$(RESET)\n"
 	@grep -E '^[a-zA-Z_-]+:.*?## \[docker\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[docker\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
 	@printf "\n$(CYAN)Quality:$(RESET)\n"
 	@grep -E '^[a-zA-Z_-]+:.*?## \[quality\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[quality\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true

 # =============================================================================
 # Prerequisite Checks (not in help)
 # =============================================================================
 check-r:
 	@command -v R > /dev/null 2>&1 || \
 		(printf "$(RED)ERROR: R is not installed$(RESET)\n" && \
 		 printf "Install R from: https://www.r-project.org/\n" && \
 		 exit 1)

 check-npm:
 	@command -v npm > /dev/null 2>&1 || \
 		(printf "$(RED)ERROR: npm is not installed$(RESET)\n" && \
 		 printf "Install Node.js/npm from: https://nodejs.org/\n" && \
 		 exit 1)

 check-docker:
 	@docker info > /dev/null 2>&1 || \
 		(printf "$(RED)ERROR: Docker is not running$(RESET)\n" && \
 		 printf "Start Docker Desktop and try again.\n" && \
 		 exit 1)

 # =============================================================================
 # Development Targets
 # =============================================================================
 install-api: check-r ## [dev] Install R dependencies with renv::restore()
 	@printf "$(CYAN)==> Installing R dependencies...$(RESET)\n"
 	@cd $(ROOT_DIR)/api && R -e "renv::restore(prompt = FALSE)" && \
 		printf "$(GREEN)✓ install-api complete$(RESET)\n" || \
 		(printf "$(RED)✗ install-api failed$(RESET)\n" && exit 1)

 install-app: check-npm ## [dev] Install frontend dependencies with npm install
 	@printf "$(CYAN)==> Installing frontend dependencies...$(RESET)\n"
 	@cd $(ROOT_DIR)/app && npm install && \
 		printf "$(GREEN)✓ install-app complete$(RESET)\n" || \
 		(printf "$(RED)✗ install-app failed$(RESET)\n" && exit 1)

 dev: docker-dev ## [dev] Start full Docker dev stack (alias for docker-dev)

 serve-app: check-npm ## [dev] Start Vue development server with hot reload
 	@printf "$(CYAN)==> Starting Vue development server...$(RESET)\n"
 	@cd $(ROOT_DIR)/app && npm run serve

 build-app: check-npm ## [dev] Build frontend for production
 	@printf "$(CYAN)==> Building frontend for production...$(RESET)\n"
 	@cd $(ROOT_DIR)/app && npm run build && \
 		printf "$(GREEN)✓ build-app complete$(RESET)\n" || \
 		(printf "$(RED)✗ build-app failed$(RESET)\n" && exit 1)

 verify-app-bundle-budget: check-npm ## [quality] Verify production public-route bundle budgets
 	@cd $(ROOT_DIR)/app && npm run build:bundle-budget

 watch-app: check-docker ## [dev] Start Docker Compose watch for frontend hot-reload
 	@printf "$(CYAN)==> Starting Docker Compose watch mode...$(RESET)\n"
 	@cd $(ROOT_DIR) && docker compose watch

 # =============================================================================
 # Testing Targets
 # =============================================================================
 test-api: check-r ## [test] Run R API tests with testthat
 	@printf "$(CYAN)==> Running R API tests...$(RESET)\n"
 	@cd $(ROOT_DIR)/api && $(HOST_RSCRIPT) scripts/run-ci-tests.R full && \
@@ -298,160 +298,191 @@ ci-local: ## [quality] Run CI checks locally (lint + test with DB - mirrors GitH
 _ci-cleanup:
 	@printf "\n$(CYAN)Cleaning up test database...$(RESET)\n"
 	@cd $(ROOT_DIR) && $(COMPOSE_DB_DEV) stop mysql-test 2>/dev/null || true

 test-ci-scripts: ## [quality] Run lightweight bash harnesses for CI helper scripts
 	@printf "$(CYAN)==> Running code-quality-audit.sh harness...$(RESET)\n"
 	@bash $(ROOT_DIR)/scripts/tests/test-code-quality-audit.sh && \
 		printf "$(GREEN)✓ code-quality-audit harness green$(RESET)\n" || \
 		(printf "$(RED)✗ code-quality-audit harness failed$(RESET)\n" && exit 1)
 	@printf "$(CYAN)==> Running ci-smoke.sh harness...$(RESET)\n"
 	@bash $(ROOT_DIR)/scripts/tests/test-ci-smoke.sh && \
 		printf "$(GREEN)✓ ci-smoke harness green$(RESET)\n" || \
 		(printf "$(RED)✗ ci-smoke harness failed$(RESET)\n" && exit 1)

 verify-gate: ## [quality] Run verify-test-gate.sh + its bash harness (Phase B B4)
 	@$(MAKE) test-ci-scripts
 	@printf "$(CYAN)==> Running verify-test-gate.sh harness...$(RESET)\n"
 	@bash $(ROOT_DIR)/scripts/tests/test-verify-test-gate.sh && \
 		printf "$(GREEN)✓ verify-test-gate harness green$(RESET)\n" || \
 		(printf "$(RED)✗ verify-test-gate harness failed$(RESET)\n" && exit 1)
 	@printf "$(CYAN)==> Running verify-test-gate.sh on current branch...$(RESET)\n"
 	@bash $(ROOT_DIR)/scripts/verify-test-gate.sh && \
 		printf "$(GREEN)✓ verify-test-gate clean on current branch$(RESET)\n" || \
 		(printf "$(RED)✗ verify-test-gate rejected current branch$(RESET)\n" && exit 1)

 # Configuration for preflight validation
 #
 # The prod docker-compose.yml routes traefik by `Host(`sysndd.dbmr.unibe.ch`)`
 # ONLY — the dev override file relaxes it to also accept `localhost` /
 # `127.0.0.1`, but preflight uses the prod compose file without the override,
 # so we MUST curl with the real prod Host header (via -H) or traefik returns
 # 404. PREFLIGHT_HOST_HEADER is the Host header curl will send; override it
 # with `make preflight PREFLIGHT_HOST_HEADER=example.com` if needed.
 PREFLIGHT_TIMEOUT := 120
 PREFLIGHT_HEALTH_ENDPOINT := http://localhost/api/health/ready
 PREFLIGHT_HOST_HEADER := sysndd.dbmr.unibe.ch

 preflight: check-docker ## [quality] Run production preflight validation
 	@printf "$(CYAN)==> Running production preflight validation...$(RESET)\n"
 	@printf "\n$(CYAN)[1/4] Building production API image...$(RESET)\n"
 	@docker build -t sysndd-api:preflight -f $(ROOT_DIR)/api/Dockerfile $(ROOT_DIR)/api/ || \
 		(printf "$(RED)Build failed$(RESET)\n" && exit 1)
 	@printf "$(GREEN)Build complete$(RESET)\n"
 	@printf "\n$(CYAN)[2/4] Starting production containers...$(RESET)\n"
 	@cd $(ROOT_DIR) && docker compose -f docker-compose.yml up -d --build || \
 		(printf "$(RED)Container startup failed$(RESET)\n" && exit 1)
 	@printf "$(GREEN)Containers started$(RESET)\n"
 	@printf "\n$(CYAN)[3/4] Waiting for health check (timeout: $(PREFLIGHT_TIMEOUT)s)...$(RESET)\n"
 	@SECONDS_ELAPSED=0; HEALTH_OK=0; \
 	while [ $$SECONDS_ELAPSED -lt $(PREFLIGHT_TIMEOUT) ]; do \
 		if RESPONSE=$$(curl -sf -H "Host: $(PREFLIGHT_HOST_HEADER)" $(PREFLIGHT_HEALTH_ENDPOINT) 2>/dev/null); then \
 			printf "$(GREEN)Health check passed!$(RESET)\n"; \
 			printf "Response: $$RESPONSE\n"; \
 			HEALTH_OK=1; \
 			break; \
 		fi; \
 		printf "."; \
 		sleep 2; \
 		SECONDS_ELAPSED=$$((SECONDS_ELAPSED+2)); \
 	done; \
 	if [ "$$HEALTH_OK" -eq 0 ]; then \
 		printf "\n$(RED)Health check timed out after $(PREFLIGHT_TIMEOUT)s$(RESET)\n"; \
 		printf "\n$(YELLOW)Last 50 lines of API logs:$(RESET)\n"; \
 		docker compose -f docker-compose.yml logs api --tail=50; \
 		printf "\n$(CYAN)[4/4] Cleanup (after failure)...$(RESET)\n"; \
 		docker compose -f docker-compose.yml down; \
 		printf "\n$(RED)PREFLIGHT FAILED$(RESET)\n"; \
 		exit 1; \
 	fi
 	@printf "\n$(CYAN)[4/4] Cleanup...$(RESET)\n"
 	@cd $(ROOT_DIR) && docker compose -f docker-compose.yml down
 	@printf "\n$(GREEN)========================================$(RESET)\n"
 	@printf "$(GREEN)       PREFLIGHT PASSED                 $(RESET)\n"
 	@printf "$(GREEN)========================================$(RESET)\n"
 	@printf "\n$(CYAN)Production Docker build validated:$(RESET)\n"
 	@printf "  - API image builds successfully\n"
 	@printf "  - Containers start without errors\n"
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
 # Compose file sets:
 #   Production:  docker-compose.yml
 #   Development: docker-compose.yml + docker-compose.override.yml (auto-loaded)
 #   Full dev:    docker-compose.yml + docker-compose.override.yml + docker-compose.dev.yml
 COMPOSE_DEV := docker compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.dev.yml
 COMPOSE_DB_DEV := docker compose -p sysndd -f docker-compose.dev.yml

 docker-build: check-docker ## [docker] Build API Docker image
 	@printf "$(CYAN)==> Building API Docker image...$(RESET)\n"
 	@cd $(ROOT_DIR) && docker build -t sysndd-api api && \
 		printf "$(GREEN)✓ docker-build complete$(RESET)\n" || \
 		(printf "$(RED)✗ docker-build failed$(RESET)\n" && exit 1)

 docker-up: check-docker ## [docker] Start production containers (no dev overrides)
 	@printf "$(CYAN)==> Starting production containers...$(RESET)\n"
 	@cd $(ROOT_DIR) && docker compose -f docker-compose.yml up -d --build && \
 		printf "$(GREEN)✓ docker-up complete$(RESET)\n" || \
 		(printf "$(RED)✗ docker-up failed$(RESET)\n" && exit 1)

 docker-down: check-docker ## [docker] Stop all containers (dev + production)
 	@printf "$(CYAN)==> Stopping all containers...$(RESET)\n"
 	@cd $(ROOT_DIR) && $(COMPOSE_DEV) down 2>/dev/null; \
 		docker compose -f docker-compose.yml down 2>/dev/null; \
 		printf "$(GREEN)✓ docker-down complete$(RESET)\n"

 docker-dev: check-docker ## [docker] Start full dev stack (app + api + db + dev databases)
 	@printf "$(CYAN)==> Starting full Docker dev stack...$(RESET)\n"
 	@cd $(ROOT_DIR) && $(COMPOSE_DEV) up -d && \
 		printf "$(GREEN)✓ Containers started$(RESET)\n" || \
 		(printf "$(RED)✗ docker-dev failed$(RESET)\n" && exit 1)
 	@printf "\n$(CYAN)Services:$(RESET)\n"
 	@printf "  App:       http://localhost       (Vite dev server via Traefik)\n"
 	@printf "  App direct: http://localhost:5173  (bypass Traefik)\n"
 	@printf "  API:       http://localhost/api    (R/Plumber via Traefik)\n"
 	@printf "  API direct: http://localhost:7778  (bypass Traefik)\n"
 	@printf "  Traefik:   http://localhost:8090   (dashboard)\n"
 	@printf "  MySQL dev: localhost:7654\n"
 	@printf "  MySQL test: localhost:7655\n"
 	@printf "\n$(CYAN)Useful commands:$(RESET)\n"
 	@printf "  make docker-logs       View container logs\n"
 	@printf "  make docker-status     Show container status\n"
 	@printf "  make watch-app         Enable Compose Watch for hot-reload\n"
 	@printf "  make dev-rebuild       Rebuild images (after Dockerfile changes)\n"
 	@printf "  make db-restore-latest Restore latest DB backup + recreate views\n"
 	@printf "  make db-views-rebuild  Replay R-script views (post-restore fix)\n"
 	@printf "  make cache-clear       Wipe API memoise cache\n"
 	@printf "  make docker-down       Stop everything\n"

 dev-rebuild: check-docker ## [docker] Rebuild app+api images and restart dev stack (use after Dockerfile changes)
 	@printf "$(CYAN)==> Rebuilding images and starting dev stack...$(RESET)\n"
 	@cd $(ROOT_DIR) && $(COMPOSE_DEV) up -d --build && \
 		printf "$(GREEN)✓ Containers rebuilt and started$(RESET)\n" || \
 		(printf "$(RED)✗ dev-rebuild failed$(RESET)\n" && exit 1)
 	@printf "$(YELLOW)Note: stale images caused real bugs in the past. Use this target whenever Dockerfile.dev or Dockerfile changes.$(RESET)\n"

 db-restore-latest: check-docker ## [docker] Restore newest DB dump from sysndd_mysql_backup volume + recreate views
 	@printf "$(CYAN)==> Restoring latest DB backup...$(RESET)\n"
 	@docker ps --format '{{.Names}}' | grep -q '^sysndd_mysql$$' || \
 		(printf "$(RED)✗ sysndd_mysql container not running. Run 'make dev' first.$(RESET)\n" && exit 1)
 	@LATEST=$$(docker run --rm -v sysndd_mysql_backup:/data alpine sh -c \
 		'ls -t /data/*.sysndd_db.sql.gz 2>/dev/null | head -1'); \
 		[ -n "$$LATEST" ] || { printf "$(RED)✗ No backups found in sysndd_mysql_backup volume$(RESET)\n"; exit 1; }; \
 		printf "  Using: $$LATEST\n"; \
 		docker run --rm -v sysndd_mysql_backup:/data alpine sh -c "gzip -dc $$LATEST" \
 			| sed -E 's#/\*![0-9]{5} DEFINER=[^*]*\*/##g' \
 			| docker exec -i sysndd_mysql sh -c 'mysql -u "$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"' \
 			2> >(grep -vE "Using a password" >&2 || true); \
 		docker exec -i sysndd_mysql sh -c 'mysql -u "$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE" -e "SELECT COUNT(*) FROM non_alt_loci_set"' >/dev/null 2>&1 \
 			|| { printf "$(RED)✗ Restore readiness probe failed (core table missing after restore)$(RESET)\n"; exit 1; }
 	@printf "$(GREEN)✓ Backup restored$(RESET)\n"
 	@$(MAKE) db-views-rebuild

 db-views-rebuild: check-docker ## [docker] Re-extract view DDL from db/C_Rcommands_set-table-connections.R and replay (fixes broken DEFINER views post-restore)
 	@printf "$(CYAN)==> Rebuilding views from R script (DEFINER-stripped)...$(RESET)\n"
 	@docker ps --format '{{.Names}}' | grep -q '^sysndd_mysql$$' || \
 		(printf "$(RED)✗ sysndd_mysql container not running.$(RESET)\n" && exit 1)
 	@python3 -c '\
diff --git a/api/version_spec.json b/api/version_spec.json
index 86e2b6e6..3e5cbe9a 100644
--- a/api/version_spec.json
+++ b/api/version_spec.json
@@ -1,14 +1,14 @@
 {
   "title": "SysNDD API",
   "description": "This is the API powering the SysNDD website, allowing programmatic access to the database contents.",
-  "version": "0.30.0",
+  "version": "0.30.3",
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
index bcc638de..37dfd6d3 100644
--- a/app/package-lock.json
+++ b/app/package-lock.json
@@ -1,89 +1,89 @@
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
index ea8dbd91..21ff6092 100644
--- a/app/package.json
+++ b/app/package.json
@@ -1,83 +1,83 @@
 {
   "name": "sysndd",
-  "version": "0.30.0",
+  "version": "0.30.3",
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
diff --git a/documentation/09-deployment.qmd b/documentation/09-deployment.qmd
index ff2dc9b5..a90b67d0 100644
--- a/documentation/09-deployment.qmd
+++ b/documentation/09-deployment.qmd
@@ -236,161 +236,200 @@ There are three ways to (re)build snapshots, all sharing one submit function:
   ```

 - **Operator script (SSH fallback)** — `make refresh-analysis-snapshots` (or `docker exec sysndd-api-1 Rscript /app/scripts/refresh-analysis-snapshots.R`) forces a rebuild of all presets.

 While a snapshot is still building, the public GeneNetworks and PhenotypeClusters pages show a friendly "analysis is being prepared" panel (with a retry) instead of a raw error.

 Snapshot status meanings:

 - `unsupported_parameter`: the requested parameters are not in the fixed public preset matrix; change the request or predefine and refresh a new preset in code.
 - `snapshot_missing`: the preset is supported, but no public-ready snapshot is active yet; run the refresh job.
 - `snapshot_stale`: an active snapshot exists but is past `stale_after`; public REST reports stale while MCP collapses it to `snapshot_missing` until refresh.
 - `source_version_mismatch`: the stored source version no longer matches current public data; public REST reports the mismatch while MCP collapses it to `snapshot_missing`.

 Available snapshot responses carry a `meta.snapshot` provenance block sourced from the public-ready manifest row: `snapshot_id`, `analysis_type`, `parameter_hash`, `schema_version`, `data_class`, `generated_at`, `stale_after`, `source_data_version`, `input_hash`, `payload_hash`, and `record_counts`. `input_hash` binds the snapshot to its supported parameter set plus the public source-data version; `payload_hash` binds it to the materialized result; `record_counts` reports the stored payload row counts (it excludes generated network metadata). These fields let operators and downstream clients audit lineage and completeness without a second query.

 ### Analysis-snapshot releases (#573)

 Analysis-snapshot **releases** are immutable, content-addressed, independently-verifiable exports of the public-ready snapshots above (functional clusters, phenotype clusters, and the phenotype-functional correlation). A release freezes its own copies of every layer's payload plus (for the two cluster layers) the raw reproducibility bundle, a generated README, `manifest.json`, `checksums.sha256`, and a pre-built `bundle.tar.gz` — so it stays byte-identical across later snapshot refreshes and pruning. Migration `045_add_analysis_snapshot_release.sql` adds the three backing tables.

 > **PRODUCTION PREREQUISITE — #572 lineage runbook.** Do this once, **before building the first production release**, and do it before any subsequent release build after a cluster-axis methodology change. A release built from a phenotype-functional correlation snapshot that predates PR #571 would lack the dependency lineage (`snapshot_id`/`payload_hash` for both cluster axes) the release format requires as a manifest anchor.
 >
 > 1. Deploy current `master`; restart `api`, `worker`, and `worker-maintenance` (worker-executed code is sourced at startup).
 > 2. As Administrator, force-refresh the correlation preset:
 >    ```bash
 >    curl -sS -X POST https://<host>/api/admin/analysis/snapshots/refresh \
 >      -H "Authorization: Bearer <admin-token>" -H "Content-Type: application/json" \
 >      -d '{"analysis_type": "phenotype_functional_correlations", "force": true}'
 >    ```
 > 3. Verify the resulting snapshot carries dependency lineage for **both** cluster axes:
 >    ```bash
 >    curl -sS https://<host>/api/analysis/phenotype_functional_cluster_correlation \
 >      | jq '.meta.snapshot.dependencies'
 >    ```
 >    Both `functional_clusters` and `phenotype_clusters` entries must report a `snapshot_id` and a `payload_hash`.
 > 4. Verify the gate fails closed: force-refresh only one cluster axis (e.g. `analysis_type=functional_clusters&force=true`) and confirm the correlation read now returns `503` `dependency_snapshot_mismatch` until the correlation preset is rebuilt against the new axis.
 > 5. Notify downstream analysis-release stakeholders that the verified live snapshot is ready to build a release from.
 > 6. **Gate:** do not run `POST /api/admin/analysis/releases` for the first production release until steps 2–4 pass. No new code ships with this step — PR #571 (dependency lineage) is already on `master`; this is purely an operational verification.

 **Build a release** (Administrator; synchronous, DB-only — the worker does not need to be involved, only the currently active public-ready snapshots):

 ```bash
 curl -sS -X POST https://<host>/api/admin/analysis/releases \
   -H "Authorization: Bearer <admin-token>" -H "Content-Type: application/json" \
   -d '{"title": "SysNDD analysis-snapshot release 2026.07", "publish": true}'
 ```

 The body is optional in every field: `layers` overrides the default registry (functional clusters, phenotype clusters, phenotype-functional correlation), `title`/`scope_statement`/`license` are presentation metadata, and `publish` (default `true`) either publishes immediately or stages a `draft` for review before a Zenodo run. The response is **201** for a genuinely new release, **200** with the existing head for an idempotent rebuild of identical content (no duplicate row), or **400** naming the specific failing layer and reason when a source snapshot is not `available`, fails the hard coherence re-check, is missing its reproducibility bundle, disagrees on source-data version, or has stale dependency lineage.

 **Inspect releases:**

 ```bash
 # All releases including drafts (Administrator):
 curl -sS https://<host>/api/admin/analysis/releases -H "Authorization: Bearer <admin-token>" | jq

 # Public catalog (published only, no auth):
 curl -sS https://<host>/api/analysis/releases | jq
 curl -sS https://<host>/api/analysis/releases/latest | jq
 ```

 **Publish a draft** (staged with `publish: false` above):

 ```bash
 curl -sS -X POST https://<host>/api/admin/analysis/releases/<release_id>/publish \
   -H "Authorization: Bearer <admin-token>"
 ```

 **Record a DOI** after an out-of-band Zenodo archival run (additive; never changes the release's `content_digest`/`manifest_sha256` — the bytes a consumer already downloaded stay valid):

 ```bash
 curl -sS -X PATCH https://<host>/api/admin/analysis/releases/<release_id>/doi \
   -H "Authorization: Bearer <admin-token>" -H "Content-Type: application/json" \
   -d '{"zenodo_record_id": "...", "zenodo_record_url": "...", "version_doi": "...", "concept_doi": "..."}'
 ```

 **Retention.** Published releases are immutable and retained indefinitely; there is no automatic pruning, and `DELETE /api/admin/analysis/releases/<id>` only accepts a `draft` (a failed/aborted build). A later snapshot refresh followed by a fresh build mints a **new** release with a new `content_digest`/`release_id`; every prior release stays byte-identical because each holds its own frozen, self-contained copy — it does not depend on the source snapshot still existing. `analysis_snapshot_prune()` additionally skips any snapshot still referenced by a release member, so a pinned snapshot's live reproducibility endpoint keeps working for as long as any release cites it.

 **Reproducibility boundary.** A release reproduces the served separation metrics (functional modularity, phenotype silhouette) and the phenotype-functional cross-cluster correlation from the bundled reproducibility inputs — recompute them per the "Verify" instructions in the release's own `README.md`. LLM cluster summaries and precomputed fCoSE network-layout coordinates are **served-only** and are intentionally excluded from releases; they are not part of the reproducible scientific content.

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

 The `ontology-mapping-cron` Compose sidecar keeps the disease cross-ontology mapping index current. Like `pubtatornidd-cron`, it is a *dumb scheduler*: once per week it enqueues a single durable `disease_ontology_mapping_refresh` async job (via `api/scripts/ontology_mapping_refresh_enqueue.R`) and exits. The `worker` service — which must have outbound egress for the MONDO downloads — claims and runs the orchestrator (`api/functions/disease-ontology-mapping-refresh.R`). The sidecar itself connects over the internal `backend` network only (enqueue only; no egress needed).

 The orchestrator: single-flights via a non-blocking MySQL advisory lock (`GET_LOCK('disease_ontology_mapping_refresh', 0)`); conditionally downloads `mondo.obo` (~50 MB) and `mondo.sssom.tsv` (~80 MB) using `If-None-Match`/`If-Modified-Since` headers so unchanged releases skip the full rebuild; rebuilds `mondo_term`, `mondo_xref`, and `disease_ontology_mapping` inside a single DB transaction; updates projection columns on `disease_ontology_set`; writes a `disease_ontology_mapping_meta` provenance row; and returns a structured run summary in the job `result_json`.

 **Configuration (environment variables, with defaults):**

 - `ONTOLOGY_MAPPING_REFRESH_AT=03:00` — weekly enqueue time, `HH:MM` in container (UTC) time.
 - `ONTOLOGY_MAPPING_REFRESH_DOW=sunday` — weekday for the enqueue (full name, lowercase).
 - `DISEASE_ONTOLOGY_MONDO_OBO_URL` — optional OBO URL override (defaults to `http://purl.obolibrary.org/obo/mondo.obo`).
 - `DISEASE_ONTOLOGY_MONDO_SSSOM_URL` — optional SSSOM URL override.
 - `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_ON_STARTUP=true` — set to `false` to disable auto-enqueue on API startup.
 - `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_STAGGER_SECONDS=360` — startup-bootstrap delay in seconds (set `0` to disable). Prevents co-launch with the analysis-snapshot and PubtatorNDD bootstraps.
 - `EXTERNAL_PROXY_MONDO_DEFAULT_TIMEOUT=120`, `EXTERNAL_PROXY_MONDO_DEFAULT_MAX=300`, `EXTERNAL_PROXY_MONDO_DEFAULT_TRIES=3` — budget tuning for the large MONDO artifact downloads.

 **Worker egress requirement:** the `worker` service must be attached to both the internal `backend` network (DB access) and the egress-capable `proxy` network. Attaching it only to `backend` breaks MONDO downloads because `backend` is `internal: true`.

 **Worker restart:** after deploying new or changed files in `api/functions/`, `api/services/`, or `api/endpoints/`, restart the worker container (`docker compose restart worker`) before expecting the new handlers to be live — worker-executed code is sourced once at startup.

 **Admin HTTP triggers** (no SSH needed, Administrator token required):
 ```bash
 # Trigger a forced rebuild:
 curl -sS -X POST https://<host>/api/admin/ontology/mappings/refresh \
   -H "Authorization: Bearer <admin-token>" \
   -H "Content-Type: application/json" -d '{"force": true}'

 # Check status (per-meta-row diagnostics):
 curl -sS https://<host>/api/admin/ontology/mappings/status \
   -H "Authorization: Bearer <admin-token>" | jq
 ```

 **Important:** when an operator ontology refresh runs (`force_apply_ontology` job), it rebuilds `disease_ontology_set` from scratch, erasing the denormalized projection columns (`UMLS`, `MedGen`, `NCIT`, `GARD`, `ontology_mapping_release`). The chaining handler in `api/functions/admin-ontology-refresh.R` automatically enqueues a `disease_ontology_mapping_refresh(force=TRUE)` afterward to re-derive them. Never run `refresh_disease_ontology_set()` in isolation without also triggering the mapping refresh.

 ### OMIM dictionary update: blocked state and remediation

 The `omim_update` async job refreshes `disease_ontology_set` from OMIM on each run. When `identify_critical_ontology_changes()` finds entity-referenced terms that require manual review, the job returns `status = "blocked"` and writes a pending CSV. **Before returning blocked**, the handler additively inserts all brand-new, entity-unreferenced terms via `apply_additive_terms_on_block()` so the dictionary continues to grow each cycle without manual intervention. The additive step is best-effort: an insert failure is logged and reported in `result_json` as `additive_error`, but never converts a blocked result into a job failure. A successful additive insert chains the usual `disease_ontology_mapping_refresh` refresh.

 **`GET /api/admin/ontology/dictionary-status`** (Administrator; `/api/admin/ontology` router, mounted before `/api/admin`) reports the current blocked/stale state derived from async job history — not from `MAX(update_date)` in the table, which additive auto-apply would stamp fresh every nightly cycle even when staged critical changes remain unresolved. Key response fields:

 - `blocked` / `blocked_job_id` — whether the latest `omim_update` result is `"blocked"` and its pending CSV is still fresh (≤48 h).
 - `stale` — `true` if blocked, if a blocked run postdates the last full apply, or if the last full apply is absent or older than `ONTOLOGY_DICTIONARY_STALE_AFTER_DAYS` (default 30 days).
 - `last_full_apply_at` / `last_additive_apply_at` — timestamps of the most recent full and additive-only applies.
 - `critical_count` / `additive_applied` — from the most recent blocked job's `result_json`.
 - `disease_ontology_last_applied` / `max_omim_id` — live DB values from `disease_ontology_set` (informational; reflects additive inserts as well as full applies).

 ```bash
 curl -sS https://<host>/api/admin/ontology/dictionary-status \
   -H "Authorization: Bearer <admin-token>" | jq
 ```

 **Configuration:** `ONTOLOGY_DICTIONARY_STALE_AFTER_DAYS` (default `30`) — number of days after the last full apply before `stale` becomes `true`. Tune lower for more sensitive alerting; higher for quarterly-refresh deployments.

 **Remediation — flush staged critical changes:** a `blocked` status does not halt new-term ingestion (additive auto-apply continues each cycle), but the entity-referenced critical changes remain staged until an operator reviews and applies them. To resolve:

 ```bash
 # Option A — Admin HTTP (no SSH needed):
 curl -sS -X PUT "https://<host>/api/admin/force_apply_ontology?blocked_job_id=<id>" \
   -H "Authorization: Bearer <admin-token>"

 # Option B — Admin UI: Admin → Manage Annotations → Force Apply
 #   (the blocked_job_id is shown in the dictionary-status response)
 ```

 After a successful Force Apply the chaining handler automatically re-derives cross-ontology mapping projections; no separate mapping refresh is required.

 ### Gemini model configuration

 The effective Gemini model resolves in this order: `GEMINI_MODEL`, `api/config.yml` key `gemini_model`, then the SysNDD default `gemini-3.5-flash`. The admin LLM configuration endpoint reports the source, default model, validity, and any warning so operators can see when an environment override is active.

 Invalid or shut-down models are rejected before Gemini is called. If Google releases a model before the built-in catalog is updated, set `GEMINI_ALLOWED_MODELS_EXTRA` to a comma-separated allowlist of the new IDs; unknown allowlisted models are accepted but surfaced with an operator warning. The allowlist does not re-enable cataloged shut-down models.

 ### GeneNetworks layout artifacts

 GeneNetworks display layouts are precomputed derived-analysis artifacts, not request-path work. The API and worker images contain Node 24 plus the minimal `api/layout/` dependencies needed to run the headless Cytoscape/fCoSE helper. The worker should run the durable `network_layout_prewarm` job after data/cache refreshes that can change the displayed gene network.

 The public `/api/analysis/network_edges` request path only reads matching artifacts from `/app/cache/network_layouts`; it must not run fCoSE synchronously. If an artifact is absent, invalid, or stale, the API marks the display layout as unavailable and the browser falls back to its existing fCoSE layout. Cache invalidation is controlled by the content-aware layout key, which includes the displayed node/edge set, query parameters, layout options, Cytoscape/fCoSE versions, and the current `CACHE_VERSION`.

 ### MCP sidecar settings
api/scripts/upload-analysis-release-zenodo.R-57-# --------------------------------------------------------------------------- #
api/scripts/upload-analysis-release-zenodo.R-58-# Resolve this script's own directory, then source the upload/record-back
api/scripts/upload-analysis-release-zenodo.R-59-# functions (function definitions only -- no top-level network calls in that
api/scripts/upload-analysis-release-zenodo.R-60-# file, so this is safe to do unconditionally, even when this CLI script is
api/scripts/upload-analysis-release-zenodo.R:61:# itself only `source()`d).
api/scripts/upload-analysis-release-zenodo.R-62-# --------------------------------------------------------------------------- #
api/scripts/upload-analysis-release-zenodo.R-63-
api/scripts/upload-analysis-release-zenodo.R-64-.upload_analysis_release_zenodo_script_dir <- function() {
api/scripts/upload-analysis-release-zenodo.R-65-  script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
--
api/scripts/upload-analysis-release-zenodo.R-67-    full_args <- commandArgs(trailingOnly = FALSE)
api/scripts/upload-analysis-release-zenodo.R-68-    file_arg <- grep("^--file=", full_args, value = TRUE)
api/scripts/upload-analysis-release-zenodo.R-69-    script_file <- if (length(file_arg) >= 1) sub("^--file=", "", file_arg[1]) else "."
api/scripts/upload-analysis-release-zenodo.R-70-  }
api/scripts/upload-analysis-release-zenodo.R:71:  dirname(normalizePath(script_file, mustWork = FALSE))
api/scripts/upload-analysis-release-zenodo.R-72-}
api/scripts/upload-analysis-release-zenodo.R-73-
api/scripts/upload-analysis-release-zenodo.R-74-.upload_analysis_release_zenodo_script_dir_value <- .upload_analysis_release_zenodo_script_dir()
api/scripts/upload-analysis-release-zenodo.R:75:source(
api/scripts/upload-analysis-release-zenodo.R-76-  file.path(
api/scripts/upload-analysis-release-zenodo.R-77-    .upload_analysis_release_zenodo_script_dir_value, "..", "functions",
api/scripts/upload-analysis-release-zenodo.R-78-    "analysis-snapshot-release-zenodo-upload.R"
api/scripts/upload-analysis-release-zenodo.R-79-  ),
--
api/scripts/upload-analysis-release-zenodo.R-85-# optparse dependency, see `verify-endpoints.R`).
api/scripts/upload-analysis-release-zenodo.R-86-# --------------------------------------------------------------------------- #
api/scripts/upload-analysis-release-zenodo.R-87-
api/scripts/upload-analysis-release-zenodo.R-88-#' Parse + run the upload CLI. Wrapped in a function (rather than bare
api/scripts/upload-analysis-release-zenodo.R:89:#' top-level code) so the file can be `source()`d for its function
api/scripts/upload-analysis-release-zenodo.R-90-#' definitions alone -- see the `sys.nframe() == 0L` main-guard at the
api/scripts/upload-analysis-release-zenodo.R-91-#' bottom of this file, which only calls this when the script is run
api/scripts/upload-analysis-release-zenodo.R-92-#' directly (`Rscript upload-analysis-release-zenodo.R`), never when
api/scripts/upload-analysis-release-zenodo.R:93:#' `source()`d (e.g. by a test).
api/scripts/upload-analysis-release-zenodo.R-94-run_upload_analysis_release_zenodo_cli <- function() {
api/scripts/upload-analysis-release-zenodo.R-95-  args <- commandArgs(trailingOnly = TRUE)
api/scripts/upload-analysis-release-zenodo.R-96-
api/scripts/upload-analysis-release-zenodo.R-97-  archive <- NULL
--
api/scripts/upload-analysis-release-zenodo.R-147-    publish = publish,
api/scripts/upload-analysis-release-zenodo.R-148-    confirm_publish = confirm_publish
api/scripts/upload-analysis-release-zenodo.R-149-  )
api/scripts/upload-analysis-release-zenodo.R-150-
api/scripts/upload-analysis-release-zenodo.R:151:  cat(sprintf("Zenodo deposition id: %s\n", result$deposition_id))
api/scripts/upload-analysis-release-zenodo.R:152:  cat(sprintf(
api/scripts/upload-analysis-release-zenodo.R-153-    "Zenodo reserved DOI:  %s\n",
api/scripts/upload-analysis-release-zenodo.R-154-    if (is.na(result$reserved_doi)) "not returned" else result$reserved_doi
api/scripts/upload-analysis-release-zenodo.R-155-  ))
api/scripts/upload-analysis-release-zenodo.R:156:  cat(sprintf(
api/scripts/upload-analysis-release-zenodo.R-157-    "Zenodo draft URL:     %s\n",
api/scripts/upload-analysis-release-zenodo.R-158-    if (is.na(result$draft_url)) "not returned" else result$draft_url
api/scripts/upload-analysis-release-zenodo.R-159-  ))
api/scripts/upload-analysis-release-zenodo.R-160-
api/scripts/upload-analysis-release-zenodo.R-161-  if (isTRUE(result$published)) {
api/scripts/upload-analysis-release-zenodo.R:162:    cat(sprintf("Published Zenodo DOI: %s\n", result$version_doi))
api/scripts/upload-analysis-release-zenodo.R:163:    cat(sprintf("Published Zenodo URL: %s\n", result$record_url))
api/scripts/upload-analysis-release-zenodo.R-164-  } else {
api/scripts/upload-analysis-release-zenodo.R:165:    cat("Draft uploaded only. Review in Zenodo before publishing.\n")
api/scripts/upload-analysis-release-zenodo.R-166-  }
api/scripts/upload-analysis-release-zenodo.R-167-
api/scripts/upload-analysis-release-zenodo.R-168-  # Item 3 (MEDIUM, Codex round 2): `analysis_release_zenodo_print_doi_record_back()`
api/scripts/upload-analysis-release-zenodo.R-169-  # (in the functions file, not duplicated here) prints ONLY post-publication
--
api/scripts/upload-analysis-release-zenodo.R-173-  invisible(result)
api/scripts/upload-analysis-release-zenodo.R-174-}
api/scripts/upload-analysis-release-zenodo.R-175-
api/scripts/upload-analysis-release-zenodo.R-176-# Main guard: `sys.nframe()` is 0 only at the true top level of a directly
api/scripts/upload-analysis-release-zenodo.R:177:# `Rscript`-invoked file; a `source()`d file (e.g. from a test) always adds
api/scripts/upload-analysis-release-zenodo.R:178:# at least one frame, so this line never fires under `source()`. This check
api/scripts/upload-analysis-release-zenodo.R-179-# MUST stay at top level (not inside a function).
api/scripts/upload-analysis-release-zenodo.R-180-if (sys.nframe() == 0L) run_upload_analysis_release_zenodo_cli()
--
api/scripts/package-analysis-release-zenodo.R-36-
api/scripts/package-analysis-release-zenodo.R-37-# --------------------------------------------------------------------------- #
api/scripts/package-analysis-release-zenodo.R-38-# Resolve this script's own directory, then source the packager (functions
api/scripts/package-analysis-release-zenodo.R-39-# only -- no top-level network calls in that file, so this is safe to do
api/scripts/package-analysis-release-zenodo.R:40:# unconditionally, even when this CLI script is itself only `source()`d).
api/scripts/package-analysis-release-zenodo.R-41-# --------------------------------------------------------------------------- #
api/scripts/package-analysis-release-zenodo.R-42-
api/scripts/package-analysis-release-zenodo.R-43-.package_analysis_release_zenodo_script_dir <- function() {
api/scripts/package-analysis-release-zenodo.R-44-  script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
--
api/scripts/package-analysis-release-zenodo.R-46-    full_args <- commandArgs(trailingOnly = FALSE)
api/scripts/package-analysis-release-zenodo.R-47-    file_arg <- grep("^--file=", full_args, value = TRUE)
api/scripts/package-analysis-release-zenodo.R-48-    script_file <- if (length(file_arg) >= 1) sub("^--file=", "", file_arg[1]) else "."
api/scripts/package-analysis-release-zenodo.R-49-  }
api/scripts/package-analysis-release-zenodo.R:50:  dirname(normalizePath(script_file, mustWork = FALSE))
api/scripts/package-analysis-release-zenodo.R-51-}
api/scripts/package-analysis-release-zenodo.R-52-
api/scripts/package-analysis-release-zenodo.R-53-.package_analysis_release_zenodo_script_dir_value <- .package_analysis_release_zenodo_script_dir()
api/scripts/package-analysis-release-zenodo.R:54:source(
api/scripts/package-analysis-release-zenodo.R-55-  file.path(
api/scripts/package-analysis-release-zenodo.R-56-    .package_analysis_release_zenodo_script_dir_value, "..", "functions",
api/scripts/package-analysis-release-zenodo.R-57-    "analysis-snapshot-release-zenodo-package.R"
api/scripts/package-analysis-release-zenodo.R-58-  ),
--
api/scripts/package-analysis-release-zenodo.R-64-# optparse dependency, see `verify-endpoints.R`).
api/scripts/package-analysis-release-zenodo.R-65-# --------------------------------------------------------------------------- #
api/scripts/package-analysis-release-zenodo.R-66-
api/scripts/package-analysis-release-zenodo.R-67-#' Parse + run the packaging CLI. Wrapped in a function (rather than bare
api/scripts/package-analysis-release-zenodo.R:68:#' top-level code) so the file can be `source()`d for its function
api/scripts/package-analysis-release-zenodo.R-69-#' definitions alone -- see the `sys.nframe() == 0L` main-guard at the
api/scripts/package-analysis-release-zenodo.R-70-#' bottom of this file, which only calls this when the script is run
api/scripts/package-analysis-release-zenodo.R-71-#' directly (`Rscript package-analysis-release-zenodo.R`), never when
api/scripts/package-analysis-release-zenodo.R:72:#' `source()`d (e.g. by a test).
api/scripts/package-analysis-release-zenodo.R-73-#' Write/overwrite the stable `outputs/analysis-release-zenodo/latest.env`
api/scripts/package-analysis-release-zenodo.R-74-#' pointer file the `analysis-release-zenodo-upload-draft` Make target reads
api/scripts/package-analysis-release-zenodo.R-75-#' to find this run's content-addressed archive (releases are `asr_<16
api/scripts/package-analysis-release-zenodo.R-76-#' hex>`-named, not date-versioned, so the Makefile cannot hardcode a
api/scripts/package-analysis-release-zenodo.R-77-#' filename). Fixed, CWD-relative location regardless of `--staging-dir`/
api/scripts/package-analysis-release-zenodo.R-78-#' `--archive-dir` overrides -- deliberately NOT under `staging_dir`/
api/scripts/package-analysis-release-zenodo.R-79-#' `archive_dir` so the marker's location never depends on those flags.
api/scripts/package-analysis-release-zenodo.R:80:#' Paths are written `normalizePath()`-resolved (absolute) so the marker is
api/scripts/package-analysis-release-zenodo.R-81-#' still correct if the upload step runs from a different CWD than the
api/scripts/package-analysis-release-zenodo.R-82-#' package step.
api/scripts/package-analysis-release-zenodo.R-83-.write_package_analysis_release_zenodo_marker <- function(result) {
api/scripts/package-analysis-release-zenodo.R-84-  marker_path <- "outputs/analysis-release-zenodo/latest.env"
api/scripts/package-analysis-release-zenodo.R-85-  dir.create(dirname(marker_path), recursive = TRUE, showWarnings = FALSE)
api/scripts/package-analysis-release-zenodo.R:86:  cat(
api/scripts/package-analysis-release-zenodo.R-87-    sprintf(
api/scripts/package-analysis-release-zenodo.R-88-      "ARCHIVE_PATH=%s\nMETADATA_PATH=%s\nRELEASE_ID=%s\n",
api/scripts/package-analysis-release-zenodo.R:89:      normalizePath(result$archive_path, mustWork = FALSE),
api/scripts/package-analysis-release-zenodo.R:90:      normalizePath(result$zenodo_metadata_path, mustWork = FALSE),
api/scripts/package-analysis-release-zenodo.R-91-      result$release_id
api/scripts/package-analysis-release-zenodo.R-92-    ),
api/scripts/package-analysis-release-zenodo.R-93-    file = marker_path
api/scripts/package-analysis-release-zenodo.R-94-  )
--
api/scripts/package-analysis-release-zenodo.R-134-  )
api/scripts/package-analysis-release-zenodo.R-135-
api/scripts/package-analysis-release-zenodo.R-136-  marker_path <- .write_package_analysis_release_zenodo_marker(result)
api/scripts/package-analysis-release-zenodo.R-137-
api/scripts/package-analysis-release-zenodo.R:138:  cat(sprintf("Release ID:           %s\n", result$release_id))
api/scripts/package-analysis-release-zenodo.R:139:  cat(sprintf("Staging dir:          %s\n", result$staging_dir))
api/scripts/package-analysis-release-zenodo.R:140:  cat(sprintf("Archive path:         %s\n", result$archive_path))
api/scripts/package-analysis-release-zenodo.R:141:  cat(sprintf("Archive sha256 path:  %s\n", result$archive_sha256_path))
api/scripts/package-analysis-release-zenodo.R:142:  cat(sprintf("Zenodo metadata path: %s\n", result$zenodo_metadata_path))
api/scripts/package-analysis-release-zenodo.R:143:  cat(sprintf("Marker file:          %s\n", marker_path))
api/scripts/package-analysis-release-zenodo.R:144:  cat(sprintf(
api/scripts/package-analysis-release-zenodo.R-145-    "\nNext: make analysis-release-zenodo-upload-draft (or: Rscript api/scripts/upload-analysis-release-zenodo.R --archive %s --metadata %s --release-id %s)\n",
api/scripts/package-analysis-release-zenodo.R-146-    result$archive_path, result$zenodo_metadata_path, result$release_id
api/scripts/package-analysis-release-zenodo.R-147-  ))
api/scripts/package-analysis-release-zenodo.R-148-
api/scripts/package-analysis-release-zenodo.R-149-  invisible(result)
api/scripts/package-analysis-release-zenodo.R-150-}
api/scripts/package-analysis-release-zenodo.R-151-
api/scripts/package-analysis-release-zenodo.R-152-# Main guard: `sys.nframe()` is 0 only at the true top level of a directly
api/scripts/package-analysis-release-zenodo.R:153:# `Rscript`-invoked file; a `source()`d file (e.g. from a test) always adds
api/scripts/package-analysis-release-zenodo.R:154:# at least one frame, so this line never fires under `source()`. This check
api/scripts/package-analysis-release-zenodo.R-155-# MUST stay at top level (not inside a function) -- see AGENTS.md-adjacent
api/scripts/package-analysis-release-zenodo.R-156-# `.superpowers/sdd/task-c2-report.md` for the empirical verification.
api/scripts/package-analysis-release-zenodo.R-157-if (sys.nframe() == 0L) run_package_analysis_release_zenodo_cli()
--
api/functions/analysis-snapshot-release-zenodo-package.R-46-  }
api/functions/analysis-snapshot-release-zenodo-package.R-47-}
api/functions/analysis-snapshot-release-zenodo-package.R-48-
api/functions/analysis-snapshot-release-zenodo-package.R-49-if (!exists(".analysis_release_zenodo_docs_loaded", mode = "logical")) {
api/functions/analysis-snapshot-release-zenodo-package.R:50:  # Resolve this file's own directory from the active source() frame (the
api/functions/analysis-snapshot-release-zenodo-package.R-51-  # proven `helper-functions.R` / `async-job-repository.R` idiom) so the
api/functions/analysis-snapshot-release-zenodo-package.R-52-  # sibling docs file loads regardless of cwd or how this file was sourced.
api/functions/analysis-snapshot-release-zenodo-package.R-53-  .analysis_release_zenodo_self_dir <- local({
api/functions/analysis-snapshot-release-zenodo-package.R-54-    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
api/functions/analysis-snapshot-release-zenodo-package.R:55:    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
api/functions/analysis-snapshot-release-zenodo-package.R-56-  })
api/functions/analysis-snapshot-release-zenodo-package.R-57-  .analysis_release_zenodo_docs_candidates <- c(
api/functions/analysis-snapshot-release-zenodo-package.R-58-    if (!is.null(.analysis_release_zenodo_self_dir)) {
api/functions/analysis-snapshot-release-zenodo-package.R-59-      file.path(.analysis_release_zenodo_self_dir, "analysis-snapshot-release-zenodo-docs.R")
--
api/functions/analysis-snapshot-release-zenodo-package.R-61-    "functions/analysis-snapshot-release-zenodo-docs.R",
api/functions/analysis-snapshot-release-zenodo-package.R-62-    "/app/functions/analysis-snapshot-release-zenodo-docs.R"
api/functions/analysis-snapshot-release-zenodo-package.R-63-  )
api/functions/analysis-snapshot-release-zenodo-package.R-64-  for (.analysis_release_zenodo_docs_path in .analysis_release_zenodo_docs_candidates) {
api/functions/analysis-snapshot-release-zenodo-package.R:65:    if (file.exists(.analysis_release_zenodo_docs_path)) {
api/functions/analysis-snapshot-release-zenodo-package.R-66-      # local = TRUE (not FALSE): evaluate into THIS call's parent frame, i.e.
api/functions/analysis-snapshot-release-zenodo-package.R-67-      # the same environment this main file is itself being sourced into
api/functions/analysis-snapshot-release-zenodo-package.R-68-      # (mirrors the working `async-job-repository.R` guard-source precedent).
api/functions/analysis-snapshot-release-zenodo-package.R-69-      # `local = FALSE` would instead always target globalenv() regardless of
api/functions/analysis-snapshot-release-zenodo-package.R-70-      # caller, splitting the two files' symbols across different
api/functions/analysis-snapshot-release-zenodo-package.R-71-      # environments whenever `source_api_file(local = FALSE)` sources this
api/functions/analysis-snapshot-release-zenodo-package.R-72-      # file into a non-global test environment.
api/functions/analysis-snapshot-release-zenodo-package.R:73:      source(.analysis_release_zenodo_docs_path, local = TRUE)
api/functions/analysis-snapshot-release-zenodo-package.R-74-      break
api/functions/analysis-snapshot-release-zenodo-package.R-75-    }
api/functions/analysis-snapshot-release-zenodo-package.R-76-  }
api/functions/analysis-snapshot-release-zenodo-package.R-77-  rm(.analysis_release_zenodo_self_dir, .analysis_release_zenodo_docs_candidates, .analysis_release_zenodo_docs_path)
--
api/functions/analysis-snapshot-release-zenodo-package.R-81-  # Same guard-source idiom as the docs block above, targeting the sibling
api/functions/analysis-snapshot-release-zenodo-package.R-82-  # fetch/extract-verify + safety-validator file instead.
api/functions/analysis-snapshot-release-zenodo-package.R-83-  .analysis_release_zenodo_self_dir <- local({
api/functions/analysis-snapshot-release-zenodo-package.R-84-    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
api/functions/analysis-snapshot-release-zenodo-package.R:85:    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
api/functions/analysis-snapshot-release-zenodo-package.R-86-  })
api/functions/analysis-snapshot-release-zenodo-package.R-87-  .analysis_release_zenodo_verify_candidates <- c(
api/functions/analysis-snapshot-release-zenodo-package.R-88-    if (!is.null(.analysis_release_zenodo_self_dir)) {
api/functions/analysis-snapshot-release-zenodo-package.R-89-      file.path(.analysis_release_zenodo_self_dir, "analysis-snapshot-release-zenodo-verify.R")
--
api/functions/analysis-snapshot-release-zenodo-package.R-91-    "functions/analysis-snapshot-release-zenodo-verify.R",
api/functions/analysis-snapshot-release-zenodo-package.R-92-    "/app/functions/analysis-snapshot-release-zenodo-verify.R"
api/functions/analysis-snapshot-release-zenodo-package.R-93-  )
api/functions/analysis-snapshot-release-zenodo-package.R-94-  for (.analysis_release_zenodo_verify_path in .analysis_release_zenodo_verify_candidates) {
api/functions/analysis-snapshot-release-zenodo-package.R:95:    if (file.exists(.analysis_release_zenodo_verify_path)) {
api/functions/analysis-snapshot-release-zenodo-package.R-96-      # local = TRUE for the same reason as the docs block above.
api/functions/analysis-snapshot-release-zenodo-package.R:97:      source(.analysis_release_zenodo_verify_path, local = TRUE)
api/functions/analysis-snapshot-release-zenodo-package.R-98-      break
api/functions/analysis-snapshot-release-zenodo-package.R-99-    }
api/functions/analysis-snapshot-release-zenodo-package.R-100-  }
api/functions/analysis-snapshot-release-zenodo-package.R-101-  rm(
--
api/functions/analysis-snapshot-release-zenodo-package.R-200-# --------------------------------------------------------------------------- #
api/functions/analysis-snapshot-release-zenodo-package.R-201-
api/functions/analysis-snapshot-release-zenodo-package.R-202-.analysis_release_zenodo_write_text <- function(path, content) {
api/functions/analysis-snapshot-release-zenodo-package.R-203-  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
api/functions/analysis-snapshot-release-zenodo-package.R:204:  cat(content, file = path)
api/functions/analysis-snapshot-release-zenodo-package.R-205-  invisible(path)
api/functions/analysis-snapshot-release-zenodo-package.R-206-}
api/functions/analysis-snapshot-release-zenodo-package.R-207-
api/functions/analysis-snapshot-release-zenodo-package.R-208-#' Write `checksums.sha256` at the staging root, covering every iterated file
--
api/functions/analysis-snapshot-release-zenodo-package.R-264-#' @return list(archive_path, archive_sha256_path).
api/functions/analysis-snapshot-release-zenodo-package.R-265-analysis_release_zenodo_make_tarball <- function(staging_dir, archive_path) {
api/functions/analysis-snapshot-release-zenodo-package.R-266-  archive_dir <- dirname(archive_path)
api/functions/analysis-snapshot-release-zenodo-package.R-267-  dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
api/functions/analysis-snapshot-release-zenodo-package.R:268:  archive_path <- normalizePath(file.path(archive_dir, basename(archive_path)), mustWork = FALSE)
api/functions/analysis-snapshot-release-zenodo-package.R-269-
api/functions/analysis-snapshot-release-zenodo-package.R:270:  staging_dir <- normalizePath(staging_dir, mustWork = TRUE)
api/functions/analysis-snapshot-release-zenodo-package.R-271-  parent_dir <- dirname(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R-272-  base_name <- basename(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R-273-
api/functions/analysis-snapshot-release-zenodo-package.R-274-  .analysis_release_zenodo_normalize_mtimes(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R-275-
api/functions/analysis-snapshot-release-zenodo-package.R-276-  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R-277-  entries <- sort(file.path(base_name, rel_paths))
api/functions/analysis-snapshot-release-zenodo-package.R-278-
api/functions/analysis-snapshot-release-zenodo-package.R:279:  previous_wd <- setwd(parent_dir)
api/functions/analysis-snapshot-release-zenodo-package.R:280:  on.exit(setwd(previous_wd), add = TRUE)
api/functions/analysis-snapshot-release-zenodo-package.R-281-  # tar = "internal" forces R's built-in (pure-R) tar writer so the archive
api/functions/analysis-snapshot-release-zenodo-package.R-282-  # never depends on a system `tar` binary being present/compatible.
api/functions/analysis-snapshot-release-zenodo-package.R:283:  utils::tar(tarfile = archive_path, files = entries, compression = "gzip", tar = "internal")
api/functions/analysis-snapshot-release-zenodo-package.R-284-
api/functions/analysis-snapshot-release-zenodo-package.R-285-  sha256 <- digest::digest(file = archive_path, algo = "sha256")
api/functions/analysis-snapshot-release-zenodo-package.R-286-  sha_path <- paste0(archive_path, ".sha256")
api/functions/analysis-snapshot-release-zenodo-package.R:287:  cat(paste0(sha256, "  ", basename(archive_path), "\n"), file = sha_path)
api/functions/analysis-snapshot-release-zenodo-package.R-288-
api/functions/analysis-snapshot-release-zenodo-package.R-289-  list(archive_path = archive_path, archive_sha256_path = sha_path)
api/functions/analysis-snapshot-release-zenodo-package.R-290-}
api/functions/analysis-snapshot-release-zenodo-package.R-291-
--
api/functions/analysis-snapshot-release-zenodo-package.R-313-  rel_paths <- list.files(src_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
api/functions/analysis-snapshot-release-zenodo-package.R-314-  for (rel_path in rel_paths) {
api/functions/analysis-snapshot-release-zenodo-package.R-315-    dest_path <- file.path(dest_dir, rel_path)
api/functions/analysis-snapshot-release-zenodo-package.R-316-    dir.create(dirname(dest_path), recursive = TRUE, showWarnings = FALSE)
api/functions/analysis-snapshot-release-zenodo-package.R:317:    file.copy(file.path(src_dir, rel_path), dest_path, overwrite = TRUE, copy.date = TRUE)
api/functions/analysis-snapshot-release-zenodo-package.R-318-  }
api/functions/analysis-snapshot-release-zenodo-package.R-319-  invisible(dest_dir)
api/functions/analysis-snapshot-release-zenodo-package.R-320-}
api/functions/analysis-snapshot-release-zenodo-package.R-321-
--
api/functions/analysis-snapshot-release-zenodo-package.R-343-  # a path/marker-injection payload through.
api/functions/analysis-snapshot-release-zenodo-package.R-344-  .analysis_release_zenodo_assert_valid_release_id(resolved_release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-package.R-345-
api/functions/analysis-snapshot-release-zenodo-package.R-346-  bundle_path <- tempfile(fileext = ".tar.gz")
api/functions/analysis-snapshot-release-zenodo-package.R:347:  on.exit(unlink(bundle_path, force = TRUE), add = TRUE)
api/functions/analysis-snapshot-release-zenodo-package.R-348-  analysis_release_zenodo_download_bundle(
api/functions/analysis-snapshot-release-zenodo-package.R-349-    api_base_url, resolved_release_id, bundle_path, http_download = http_download
api/functions/analysis-snapshot-release-zenodo-package.R-350-  )
api/functions/analysis-snapshot-release-zenodo-package.R-351-  extracted_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, head$bundle_sha256)
api/functions/analysis-snapshot-release-zenodo-package.R:352:  on.exit(unlink(extracted_dir, recursive = TRUE, force = TRUE), add = TRUE)
api/functions/analysis-snapshot-release-zenodo-package.R-353-
api/functions/analysis-snapshot-release-zenodo-package.R-354-  # BLOCKER guard (item 1): refuse to recursively delete a pre-existing
api/functions/analysis-snapshot-release-zenodo-package.R-355-  # `--staging-dir` unless this tool itself created it (empty, absent, or
api/functions/analysis-snapshot-release-zenodo-package.R-356-  # carrying the ownership sentinel) -- an operator typo must never
api/functions/analysis-snapshot-release-zenodo-package.R-357-  # irreversibly rmtree an unrelated directory.
api/functions/analysis-snapshot-release-zenodo-package.R-358-  .analysis_release_zenodo_assert_staging_deletable(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R-359-  if (dir.exists(staging_dir)) {
api/functions/analysis-snapshot-release-zenodo-package.R:360:    unlink(staging_dir, recursive = TRUE, force = TRUE)
api/functions/analysis-snapshot-release-zenodo-package.R-361-  }
api/functions/analysis-snapshot-release-zenodo-package.R-362-  dir.create(staging_dir, recursive = TRUE)
api/functions/analysis-snapshot-release-zenodo-package.R-363-  .analysis_release_zenodo_write_staging_sentinel(staging_dir)
api/functions/analysis-snapshot-release-zenodo-package.R-364-
--
api/functions/analysis-snapshot-release-zenodo-upload.R-44-
api/functions/analysis-snapshot-release-zenodo-upload.R-45-if (!exists(".analysis_release_zenodo_common_loaded", mode = "logical")) {
api/functions/analysis-snapshot-release-zenodo-upload.R-46-  # Same self-locating guard-source idiom as `-package.R`'s docs/verify
api/functions/analysis-snapshot-release-zenodo-upload.R-47-  # blocks and `-verify.R`'s own common guard block: resolves this file's
api/functions/analysis-snapshot-release-zenodo-upload.R:48:  # own directory from the active source() frame so the sibling common file
api/functions/analysis-snapshot-release-zenodo-upload.R-49-  # loads regardless of cwd or how this file was sourced (directly by the
api/functions/analysis-snapshot-release-zenodo-upload.R-50-  # CLI script, or by `source_api_file()` in tests).
api/functions/analysis-snapshot-release-zenodo-upload.R-51-  .analysis_release_zenodo_common_self_dir <- local({
api/functions/analysis-snapshot-release-zenodo-upload.R-52-    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
api/functions/analysis-snapshot-release-zenodo-upload.R:53:    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
api/functions/analysis-snapshot-release-zenodo-upload.R-54-  })
api/functions/analysis-snapshot-release-zenodo-upload.R-55-  .analysis_release_zenodo_common_candidates <- c(
api/functions/analysis-snapshot-release-zenodo-upload.R-56-    if (!is.null(.analysis_release_zenodo_common_self_dir)) {
api/functions/analysis-snapshot-release-zenodo-upload.R-57-      file.path(.analysis_release_zenodo_common_self_dir, "analysis-snapshot-release-zenodo-common.R")
--
api/functions/analysis-snapshot-release-zenodo-upload.R-59-    "functions/analysis-snapshot-release-zenodo-common.R",
api/functions/analysis-snapshot-release-zenodo-upload.R-60-    "/app/functions/analysis-snapshot-release-zenodo-common.R"
api/functions/analysis-snapshot-release-zenodo-upload.R-61-  )
api/functions/analysis-snapshot-release-zenodo-upload.R-62-  for (.analysis_release_zenodo_common_path in .analysis_release_zenodo_common_candidates) {
api/functions/analysis-snapshot-release-zenodo-upload.R:63:    if (file.exists(.analysis_release_zenodo_common_path)) {
api/functions/analysis-snapshot-release-zenodo-upload.R-64-      # local = TRUE: evaluate into THIS call's parent frame (same reasoning
api/functions/analysis-snapshot-release-zenodo-upload.R-65-      # as `-package.R`'s guard blocks).
api/functions/analysis-snapshot-release-zenodo-upload.R:66:      source(.analysis_release_zenodo_common_path, local = TRUE)
api/functions/analysis-snapshot-release-zenodo-upload.R-67-      break
api/functions/analysis-snapshot-release-zenodo-upload.R-68-    }
api/functions/analysis-snapshot-release-zenodo-upload.R-69-  }
api/functions/analysis-snapshot-release-zenodo-upload.R-70-  rm(
--
api/functions/analysis-snapshot-release-zenodo-upload.R-418-    # parameter here is for programmatic/test callers only; the CLI wrapper
api/functions/analysis-snapshot-release-zenodo-upload.R-419-    # always resolves it from `Sys.getenv("ZENODO_TOKEN")`.
api/functions/analysis-snapshot-release-zenodo-upload.R-420-    stop("ZENODO_TOKEN not set (export it in your shell before running this script)", call. = FALSE)
api/functions/analysis-snapshot-release-zenodo-upload.R-421-  }
api/functions/analysis-snapshot-release-zenodo-upload.R:422:  if (!file.exists(archive_path)) {
api/functions/analysis-snapshot-release-zenodo-upload.R-423-    stop(sprintf("Archive does not exist: %s", archive_path), call. = FALSE)
api/functions/analysis-snapshot-release-zenodo-upload.R-424-  }
api/functions/analysis-snapshot-release-zenodo-upload.R:425:  if (!file.exists(metadata_path)) {
api/functions/analysis-snapshot-release-zenodo-upload.R-426-    stop(sprintf("Metadata does not exist: %s", metadata_path), call. = FALSE)
api/functions/analysis-snapshot-release-zenodo-upload.R-427-  }
api/functions/analysis-snapshot-release-zenodo-upload.R-428-
api/functions/analysis-snapshot-release-zenodo-upload.R-429-  api <- analysis_release_zenodo_resolve_api(sandbox)
--
api/functions/analysis-snapshot-release-zenodo-verify.R-26-.analysis_release_zenodo_verify_loaded <- TRUE
api/functions/analysis-snapshot-release-zenodo-verify.R-27-
api/functions/analysis-snapshot-release-zenodo-verify.R-28-if (!exists(".analysis_release_zenodo_common_loaded", mode = "logical")) {
api/functions/analysis-snapshot-release-zenodo-verify.R-29-  # Same self-locating guard-source idiom as `-package.R`'s docs/verify
api/functions/analysis-snapshot-release-zenodo-verify.R:30:  # blocks (resolves this file's own directory from the active source()
api/functions/analysis-snapshot-release-zenodo-verify.R-31-  # frame so the sibling common file loads regardless of cwd or how this
api/functions/analysis-snapshot-release-zenodo-verify.R-32-  # file was sourced).
api/functions/analysis-snapshot-release-zenodo-verify.R-33-  .analysis_release_zenodo_common_self_dir <- local({
api/functions/analysis-snapshot-release-zenodo-verify.R-34-    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
api/functions/analysis-snapshot-release-zenodo-verify.R:35:    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
api/functions/analysis-snapshot-release-zenodo-verify.R-36-  })
api/functions/analysis-snapshot-release-zenodo-verify.R-37-  .analysis_release_zenodo_common_candidates <- c(
api/functions/analysis-snapshot-release-zenodo-verify.R-38-    if (!is.null(.analysis_release_zenodo_common_self_dir)) {
api/functions/analysis-snapshot-release-zenodo-verify.R-39-      file.path(.analysis_release_zenodo_common_self_dir, "analysis-snapshot-release-zenodo-common.R")
--
api/functions/analysis-snapshot-release-zenodo-verify.R-41-    "functions/analysis-snapshot-release-zenodo-common.R",
api/functions/analysis-snapshot-release-zenodo-verify.R-42-    "/app/functions/analysis-snapshot-release-zenodo-common.R"
api/functions/analysis-snapshot-release-zenodo-verify.R-43-  )
api/functions/analysis-snapshot-release-zenodo-verify.R-44-  for (.analysis_release_zenodo_common_path in .analysis_release_zenodo_common_candidates) {
api/functions/analysis-snapshot-release-zenodo-verify.R:45:    if (file.exists(.analysis_release_zenodo_common_path)) {
api/functions/analysis-snapshot-release-zenodo-verify.R-46-      # local = TRUE: evaluate into THIS call's parent frame (same reasoning
api/functions/analysis-snapshot-release-zenodo-verify.R-47-      # as `-package.R`'s guard blocks).
api/functions/analysis-snapshot-release-zenodo-verify.R:48:      source(.analysis_release_zenodo_common_path, local = TRUE)
api/functions/analysis-snapshot-release-zenodo-verify.R-49-      break
api/functions/analysis-snapshot-release-zenodo-verify.R-50-    }
api/functions/analysis-snapshot-release-zenodo-verify.R-51-  }
api/functions/analysis-snapshot-release-zenodo-verify.R-52-  rm(
--
api/functions/analysis-snapshot-release-zenodo-verify.R-168-  release_id <- as.character(release_id)[[1]]
api/functions/analysis-snapshot-release-zenodo-verify.R-169-  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-verify.R-170-  url <- paste0(base_url, "/api/analysis/releases/", release_id, "/bundle")
api/functions/analysis-snapshot-release-zenodo-verify.R-171-  http_download(url, destfile)
api/functions/analysis-snapshot-release-zenodo-verify.R:172:  if (!file.exists(destfile) || file.size(destfile) == 0) {
api/functions/analysis-snapshot-release-zenodo-verify.R-173-    stop("Analysis-snapshot release bundle download produced an empty file", call. = FALSE)
api/functions/analysis-snapshot-release-zenodo-verify.R-174-  }
api/functions/analysis-snapshot-release-zenodo-verify.R-175-  destfile
api/functions/analysis-snapshot-release-zenodo-verify.R-176-}
--
api/functions/analysis-snapshot-release-zenodo-verify.R-202-}
api/functions/analysis-snapshot-release-zenodo-verify.R-203-
api/functions/analysis-snapshot-release-zenodo-verify.R-204-# --------------------------------------------------------------------------- #
api/functions/analysis-snapshot-release-zenodo-verify.R-205-# Symlink / non-regular-file rejection -- shared between the EXTRACTED bundle
api/functions/analysis-snapshot-release-zenodo-verify.R:206:# tree (called immediately after untar(), before any hashing/copying -- item
api/functions/analysis-snapshot-release-zenodo-verify.R-207-# 1, HIGH) and the staging tree (the pre-existing safety validator).
api/functions/analysis-snapshot-release-zenodo-verify.R-208-# --------------------------------------------------------------------------- #
api/functions/analysis-snapshot-release-zenodo-verify.R-209-
api/functions/analysis-snapshot-release-zenodo-verify.R-210-#' Reject symlinks AND any other non-regular file (FIFO/pipe, socket, device,
--
api/functions/analysis-snapshot-release-zenodo-verify.R-216-#' real regular file per `fs::file_info(path)$type == "file"`; anything else
api/functions/analysis-snapshot-release-zenodo-verify.R-217-#' is rejected.
api/functions/analysis-snapshot-release-zenodo-verify.R-218-#'
api/functions/analysis-snapshot-release-zenodo-verify.R-219-#' Codex round 3 (HIGH): the earlier version of this guard only detected
api/functions/analysis-snapshot-release-zenodo-verify.R:220:#' symlinks and reasoned that "everything else the pure-R `untar()` engine can
api/functions/analysis-snapshot-release-zenodo-verify.R-221-#' create is either a regular file or a symlink" -- true for tar member TYPES
api/functions/analysis-snapshot-release-zenodo-verify.R-222-#' the pure-R engine writes, but a bundle's `checksums.sha256` entry could
api/functions/analysis-snapshot-release-zenodo-verify.R-223-#' still name a path that resolves to a special file placed some other way
api/functions/analysis-snapshot-release-zenodo-verify.R-224-#' (or a future tar implementation change), and `digest::digest(file = ...)`
--
api/functions/analysis-snapshot-release-zenodo-verify.R-297-#' `\` separated), BEFORE it is ever joined onto `exdir`; (2, item 1, HIGH)
api/functions/analysis-snapshot-release-zenodo-verify.R-298-#' IMMEDIATELY after extraction and BEFORE any hashing or copying, the whole
api/functions/analysis-snapshot-release-zenodo-verify.R-299-#' extracted tree (INCLUDING `checksums.sha256` itself) is walked and any
api/functions/analysis-snapshot-release-zenodo-verify.R-300-#' symlink OR other non-regular file (FIFO/pipe, socket, device, ...) is
api/functions/analysis-snapshot-release-zenodo-verify.R:301:#' rejected -- `digest::digest(file = ...)` and `file.copy()` both follow
api/functions/analysis-snapshot-release-zenodo-verify.R-302-#' symlinks transparently, so a symlinked release member could otherwise pull
api/functions/analysis-snapshot-release-zenodo-verify.R-303-#' host-readable content into the archive undetected, and a FIFO would
api/functions/analysis-snapshot-release-zenodo-verify.R-304-#' otherwise block `digest::digest()` indefinitely (Codex round 3, HIGH); (3)
api/functions/analysis-snapshot-release-zenodo-verify.R-305-#' after the existing per-line checksum verification, COVERAGE is asserted --
--
api/functions/analysis-snapshot-release-zenodo-verify.R-313-#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
api/functions/analysis-snapshot-release-zenodo-verify.R-314-#' @return Path to the extraction directory (== `exdir`).
api/functions/analysis-snapshot-release-zenodo-verify.R-315-analysis_release_zenodo_extract_and_verify <- function(
api/functions/analysis-snapshot-release-zenodo-verify.R-316-    bundle_path, expected_bundle_sha256, exdir = NULL) {
api/functions/analysis-snapshot-release-zenodo-verify.R:317:  if (!file.exists(bundle_path)) {
api/functions/analysis-snapshot-release-zenodo-verify.R-318-    stop("Analysis-snapshot release bundle not found for verification", call. = FALSE)
api/functions/analysis-snapshot-release-zenodo-verify.R-319-  }
api/functions/analysis-snapshot-release-zenodo-verify.R-320-  actual_bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
api/functions/analysis-snapshot-release-zenodo-verify.R-321-  expected <- tolower(as.character(expected_bundle_sha256 %||% "")[[1]])
--
api/functions/analysis-snapshot-release-zenodo-verify.R-325-      expected, actual_bundle_sha256
api/functions/analysis-snapshot-release-zenodo-verify.R-326-    ), call. = FALSE)
api/functions/analysis-snapshot-release-zenodo-verify.R-327-  }
api/functions/analysis-snapshot-release-zenodo-verify.R-328-
api/functions/analysis-snapshot-release-zenodo-verify.R:329:  tar_entries <- utils::untar(bundle_path, list = TRUE)
api/functions/analysis-snapshot-release-zenodo-verify.R-330-  .analysis_release_zenodo_assert_no_traversal(tar_entries, context = "tar member")
api/functions/analysis-snapshot-release-zenodo-verify.R-331-
api/functions/analysis-snapshot-release-zenodo-verify.R-332-  if (is.null(exdir)) {
api/functions/analysis-snapshot-release-zenodo-verify.R-333-    exdir <- file.path(
api/functions/analysis-snapshot-release-zenodo-verify.R-334-      tempdir(), paste0("analysis_release_zenodo_extract_", as.integer(stats::runif(1, 1, 1e9)))
api/functions/analysis-snapshot-release-zenodo-verify.R-335-    )
api/functions/analysis-snapshot-release-zenodo-verify.R-336-  }
api/functions/analysis-snapshot-release-zenodo-verify.R-337-  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
api/functions/analysis-snapshot-release-zenodo-verify.R:338:  utils::untar(bundle_path, exdir = exdir)
api/functions/analysis-snapshot-release-zenodo-verify.R-339-
api/functions/analysis-snapshot-release-zenodo-verify.R-340-  # Item 1 (HIGH): reject any symlink OR other non-regular file in the
api/functions/analysis-snapshot-release-zenodo-verify.R-341-  # EXTRACTED tree immediately, before any file below is hashed or copied --
api/functions/analysis-snapshot-release-zenodo-verify.R-342-  # see the hardening note above.
api/functions/analysis-snapshot-release-zenodo-verify.R-343-  .analysis_release_zenodo_reject_unsafe_files(exdir, "Extracted release bundle")
api/functions/analysis-snapshot-release-zenodo-verify.R-344-
api/functions/analysis-snapshot-release-zenodo-verify.R-345-  sha_file <- file.path(exdir, "checksums.sha256")
api/functions/analysis-snapshot-release-zenodo-verify.R:346:  if (!file.exists(sha_file)) {
api/functions/analysis-snapshot-release-zenodo-verify.R-347-    stop("Extracted release bundle has no checksums.sha256", call. = FALSE)
api/functions/analysis-snapshot-release-zenodo-verify.R-348-  }
api/functions/analysis-snapshot-release-zenodo-verify.R:349:  sha_lines <- readLines(sha_file, warn = FALSE)
api/functions/analysis-snapshot-release-zenodo-verify.R-350-  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
api/functions/analysis-snapshot-release-zenodo-verify.R-351-
api/functions/analysis-snapshot-release-zenodo-verify.R-352-  checksummed_paths <- character(0)
api/functions/analysis-snapshot-release-zenodo-verify.R-353-  for (line in sha_lines) {
--
api/functions/analysis-snapshot-release-zenodo-verify.R-355-    expected_sha <- parts[[1]]
api/functions/analysis-snapshot-release-zenodo-verify.R-356-    rel_name <- parts[[length(parts)]]
api/functions/analysis-snapshot-release-zenodo-verify.R-357-    .analysis_release_zenodo_assert_no_traversal(rel_name, context = "checksums.sha256 entry")
api/functions/analysis-snapshot-release-zenodo-verify.R-358-    target <- file.path(exdir, rel_name)
api/functions/analysis-snapshot-release-zenodo-verify.R:359:    if (!file.exists(target)) {
api/functions/analysis-snapshot-release-zenodo-verify.R-360-      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name), call. = FALSE)
api/functions/analysis-snapshot-release-zenodo-verify.R-361-    }
api/functions/analysis-snapshot-release-zenodo-verify.R-362-    actual_sha <- digest::digest(file = target, algo = "sha256")
api/functions/analysis-snapshot-release-zenodo-verify.R-363-    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
--
api/functions/analysis-snapshot-release-zenodo-verify.R-417-}
api/functions/analysis-snapshot-release-zenodo-verify.R-418-
api/functions/analysis-snapshot-release-zenodo-verify.R-419-# --------------------------------------------------------------------------- #
api/functions/analysis-snapshot-release-zenodo-verify.R-420-# Staging-directory delete guard (item 1, BLOCKER) -- refuse to
api/functions/analysis-snapshot-release-zenodo-verify.R:421:# `unlink(recursive = TRUE)` any directory this tool did not itself create.
api/functions/analysis-snapshot-release-zenodo-verify.R-422-# --------------------------------------------------------------------------- #
api/functions/analysis-snapshot-release-zenodo-verify.R-423-
api/functions/analysis-snapshot-release-zenodo-verify.R-424-#' TRUE when `staging_dir` is safe for this tool to recursively delete: it
api/functions/analysis-snapshot-release-zenodo-verify.R-425-#' does not exist yet, is empty, or carries the ownership sentinel written by
--
api/functions/analysis-snapshot-release-zenodo-verify.R-433-  contents <- list.files(staging_dir, all.files = TRUE, no.. = TRUE)
api/functions/analysis-snapshot-release-zenodo-verify.R-434-  if (length(contents) == 0L) {
api/functions/analysis-snapshot-release-zenodo-verify.R-435-    return(TRUE)
api/functions/analysis-snapshot-release-zenodo-verify.R-436-  }
api/functions/analysis-snapshot-release-zenodo-verify.R:437:  file.exists(file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_STAGING_SENTINEL))
api/functions/analysis-snapshot-release-zenodo-verify.R-438-}
api/functions/analysis-snapshot-release-zenodo-verify.R-439-
api/functions/analysis-snapshot-release-zenodo-verify.R-440-#' Stop with a clear, actionable message unless `staging_dir` is safe to
api/functions/analysis-snapshot-release-zenodo-verify.R-441-#' recursively delete (see `.analysis_release_zenodo_staging_owned_by_tool()`).
--
api/functions/analysis-snapshot-release-zenodo-verify.R-456-#' `dir.create(staging_dir)` (before any other staging content) so a later
api/functions/analysis-snapshot-release-zenodo-verify.R-457-#' re-run recognizes this directory as the tool's own even if that later run
api/functions/analysis-snapshot-release-zenodo-verify.R-458-#' is interrupted before completing.
api/functions/analysis-snapshot-release-zenodo-verify.R-459-.analysis_release_zenodo_write_staging_sentinel <- function(staging_dir) {
api/functions/analysis-snapshot-release-zenodo-verify.R:460:  writeLines(
api/functions/analysis-snapshot-release-zenodo-verify.R-461-    paste0(
api/functions/analysis-snapshot-release-zenodo-verify.R-462-      "This directory is owned by package-analysis-release-zenodo.R and is ",
api/functions/analysis-snapshot-release-zenodo-verify.R-463-      "safe for it to recursively replace on the next run. Do not remove ",
api/functions/analysis-snapshot-release-zenodo-verify.R-464-      "this file manually if you want that protection to keep applying."
--
api/functions/analysis-snapshot-release-zenodo-verify.R-499-}
api/functions/analysis-snapshot-release-zenodo-verify.R-500-
api/functions/analysis-snapshot-release-zenodo-verify.R-501-#' Reject symlinks / non-regular files anywhere in the staging tree (item 3)
api/functions/analysis-snapshot-release-zenodo-verify.R-502-#' -- a symlink could point outside the archive, or at a private file
api/functions/analysis-snapshot-release-zenodo-verify.R:503:#' `utils::tar()` would then follow and embed verbatim. Delegates to the
api/functions/analysis-snapshot-release-zenodo-verify.R-504-#' shared `.analysis_release_zenodo_reject_unsafe_files()` (same check now
api/functions/analysis-snapshot-release-zenodo-verify.R-505-#' also run on the EXTRACTED bundle tree, see `extract_and_verify()` above)
api/functions/analysis-snapshot-release-zenodo-verify.R-506-#' so both trees are guarded by one implementation.
api/functions/analysis-snapshot-release-zenodo-verify.R-507-.analysis_release_zenodo_validate_no_symlinks <- function(staging_dir) {
--
api/functions/analysis-snapshot-release-zenodo-verify.R-541-    if (!.analysis_release_zenodo_has_allowed_suffix(rel_path)) {
api/functions/analysis-snapshot-release-zenodo-verify.R-542-      next
api/functions/analysis-snapshot-release-zenodo-verify.R-543-    }
api/functions/analysis-snapshot-release-zenodo-verify.R-544-    full_path <- file.path(staging_dir, rel_path)
api/functions/analysis-snapshot-release-zenodo-verify.R:545:    text <- tolower(paste(readLines(full_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
api/functions/analysis-snapshot-release-zenodo-verify.R-546-    hit <- Find(function(pattern) grepl(pattern, text, fixed = TRUE),
api/functions/analysis-snapshot-release-zenodo-verify.R-547-                .ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS)
api/functions/analysis-snapshot-release-zenodo-verify.R-548-    if (!is.null(hit)) {
api/functions/analysis-snapshot-release-zenodo-verify.R-549-      offenders <- c(offenders, sprintf("%s (matched '%s')", rel_path, hit))
--
api/functions/analysis-snapshot-release-zenodo-verify.R-564-    .ANALYSIS_RELEASE_ZENODO_NESTED_DIR, .ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED
api/functions/analysis-snapshot-release-zenodo-verify.R-565-  )
api/functions/analysis-snapshot-release-zenodo-verify.R-566-  expected <- c(expected_top, expected_nested)
api/functions/analysis-snapshot-release-zenodo-verify.R-567-
api/functions/analysis-snapshot-release-zenodo-verify.R:568:  missing <- Filter(function(rel_path) !file.exists(file.path(staging_dir, rel_path)), expected)
api/functions/analysis-snapshot-release-zenodo-verify.R-569-  if (length(missing) > 0) {
api/functions/analysis-snapshot-release-zenodo-verify.R-570-    stop(sprintf(
api/functions/analysis-snapshot-release-zenodo-verify.R-571-      "Zenodo staging is missing expected members: %s",
api/functions/analysis-snapshot-release-zenodo-verify.R-572-      paste(missing, collapse = ", ")
api/functions/analysis-snapshot-release-zenodo-common.R-50-#'   REQUEST arg, and defense-in-depth on the RESOLVED id from the release
api/functions/analysis-snapshot-release-zenodo-common.R-51-#'   head in `analysis_release_zenodo_package()`) -- this is the value that
api/functions/analysis-snapshot-release-zenodo-common.R-52-#'   becomes `<release_id>.tar.gz` and the `RELEASE_ID=` marker line;
api/functions/analysis-snapshot-release-zenodo-common.R:53:#' - the upload/DOI path (`analysis_release_zenodo_record_doi()`,
api/functions/analysis-snapshot-release-zenodo-common.R:54:#'   `analysis_release_zenodo_manual_doi_command()`, called before EITHER
api/functions/analysis-snapshot-release-zenodo-common.R-55-#'   builds the admin PATCH URL or the printed `curl` command from the
api/functions/analysis-snapshot-release-zenodo-common.R-56-#'   CLI's `--release-id`).
api/functions/analysis-snapshot-release-zenodo-common.R-57-#'
--
api/functions/analysis-snapshot-release-zenodo-package.R-370-  )[[1]]
api/functions/analysis-snapshot-release-zenodo-package.R-371-
api/functions/analysis-snapshot-release-zenodo-package.R-372-  .analysis_release_zenodo_write_text(
api/functions/analysis-snapshot-release-zenodo-package.R:373:    file.path(staging_dir, "README.md"), analysis_release_zenodo_build_readme(head, doi)
api/functions/analysis-snapshot-release-zenodo-package.R-374-  )
api/functions/analysis-snapshot-release-zenodo-package.R-375-  .analysis_release_zenodo_write_text(
api/functions/analysis-snapshot-release-zenodo-package.R-376-    file.path(staging_dir, "DATA_CARD.md"), analysis_release_zenodo_build_data_card(head)
--
api/functions/analysis-snapshot-release-zenodo-package.R-384-  )
api/functions/analysis-snapshot-release-zenodo-package.R-385-  .analysis_release_zenodo_write_text(
api/functions/analysis-snapshot-release-zenodo-package.R-386-    file.path(staging_dir, "CITATION.cff"),
api/functions/analysis-snapshot-release-zenodo-package.R:387:    analysis_release_zenodo_build_citation_cff(head, resolved_version, doi)
api/functions/analysis-snapshot-release-zenodo-package.R-388-  )
api/functions/analysis-snapshot-release-zenodo-package.R-389-
api/functions/analysis-snapshot-release-zenodo-package.R-390-  metadata <- analysis_release_zenodo_build_metadata(head, version = resolved_version)
--
api/functions/analysis-snapshot-release-repository.R-449-#'   `zenodo_record_url`, `version_doi`, `concept_doi`.
api/functions/analysis-snapshot-release-repository.R-450-#' @return logical(1), TRUE iff a row was updated.
api/functions/analysis-snapshot-release-repository.R-451-#' @export
api/functions/analysis-snapshot-release-repository.R:452:analysis_release_set_doi <- function(release_id, doi_fields = list(), conn) {
api/functions/analysis-snapshot-release-repository.R-453-  allowed <- c("zenodo_record_id", "zenodo_record_url", "version_doi", "concept_doi")
api/functions/analysis-snapshot-release-repository.R-454-  present <- intersect(names(doi_fields), allowed)
api/functions/analysis-snapshot-release-repository.R-455-  if (length(present) == 0L) {
--
api/functions/analysis-snapshot-release-repository.R-457-  }
api/functions/analysis-snapshot-release-repository.R-458-
api/functions/analysis-snapshot-release-repository.R-459-  set_clause <- paste(paste0(present, " = ?"), collapse = ", ")
api/functions/analysis-snapshot-release-repository.R:460:  value_params <- lapply(present, function(k) .analysis_release_chr(doi_fields[[k]]))
api/functions/analysis-snapshot-release-repository.R-461-  affected <- DBI::dbExecute(
api/functions/analysis-snapshot-release-repository.R-462-    conn,
api/functions/analysis-snapshot-release-repository.R-463-    paste0("UPDATE analysis_snapshot_release SET ", set_clause, " WHERE release_id = ?"),
--
api/functions/analysis-snapshot-release-zenodo-docs.R-22-.analysis_release_zenodo_docs_loaded <- TRUE
api/functions/analysis-snapshot-release-zenodo-docs.R-23-
api/functions/analysis-snapshot-release-zenodo-docs.R-24-#' `README.md`: version/id/DOI header + a 4-step "Use" walkthrough.
api/functions/analysis-snapshot-release-zenodo-docs.R:25:analysis_release_zenodo_build_readme <- function(head, doi = NULL) {
api/functions/analysis-snapshot-release-zenodo-docs.R-26-  release_id <- as.character(head$release_id %||% "")[[1]]
api/functions/analysis-snapshot-release-zenodo-docs.R-27-  version <- as.character((head$source_data_version %||% head$release_version %||% release_id))[[1]]
api/functions/analysis-snapshot-release-zenodo-docs.R-28-  doi_text <- doi %||% "reserved Zenodo DOI to be added before publication"
--
api/functions/analysis-snapshot-release-zenodo-docs.R-130-
api/functions/analysis-snapshot-release-zenodo-docs.R-131-#' `CITATION.cff`: CFF 1.2.0, `type: dataset`, optional `doi:`, single author
api/functions/analysis-snapshot-release-zenodo-docs.R-132-#' block with ORCID, `license: CC-BY-4.0`.
api/functions/analysis-snapshot-release-zenodo-docs.R:133:analysis_release_zenodo_build_citation_cff <- function(head, version, doi = NULL) {
api/functions/analysis-snapshot-release-zenodo-docs.R-134-  release_id <- as.character(head$release_id %||% "")[[1]]
api/functions/analysis-snapshot-release-zenodo-docs.R-135-  resolved_version <- as.character((version %||% head$source_data_version %||% release_id))[[1]]
api/functions/analysis-snapshot-release-zenodo-docs.R-136-  release_date <- .analysis_release_zenodo_created_at_date(head$created_at)
--
api/functions/analysis-snapshot-release-zenodo-upload.R-25-# Publish is DOUBLE-gated: `analysis_release_zenodo_require_publish_confirmation()`
api/functions/analysis-snapshot-release-zenodo-upload.R-26-# stops unless BOTH `publish` and `confirm_publish` are set -- the orchestrator
api/functions/analysis-snapshot-release-zenodo-upload.R-27-# is draft-only by default. DOI record-back to the SysNDD admin API is OPT-IN
api/functions/analysis-snapshot-release-zenodo-upload.R:28:# (`analysis_release_zenodo_record_doi()`/`analysis_release_zenodo_manual_doi_command()`/
api/functions/analysis-snapshot-release-zenodo-upload.R:29:# `analysis_release_zenodo_print_doi_record_back()` below); the CLI script
api/functions/analysis-snapshot-release-zenodo-upload.R-30-# only wires flags/env into the latter, so this file stays the single place
api/functions/analysis-snapshot-release-zenodo-upload.R-31-# that decides WHEN a DOI is recorded/printed and is easy to test in
api/functions/analysis-snapshot-release-zenodo-upload.R-32-# isolation.
--
api/functions/analysis-snapshot-release-zenodo-upload.R-207-# --------------------------------------------------------------------------- #
api/functions/analysis-snapshot-release-zenodo-upload.R-208-# DOI record-back (OPT-IN, SysNDD-admin side) -- additive metadata, outside
api/functions/analysis-snapshot-release-zenodo-upload.R-209-# any release content hash. Never called automatically; the CLI script only
api/functions/analysis-snapshot-release-zenodo-upload.R:210:# invokes `analysis_release_zenodo_record_doi()` when the operator passes
api/functions/analysis-snapshot-release-zenodo-upload.R-211-# `--record-doi` AND `SYSNDD_ADMIN_TOKEN` is set. Otherwise it prints
api/functions/analysis-snapshot-release-zenodo-upload.R:212:# `analysis_release_zenodo_manual_doi_command()` so the operator can record
api/functions/analysis-snapshot-release-zenodo-upload.R-213-# it by hand.
api/functions/analysis-snapshot-release-zenodo-upload.R-214-# --------------------------------------------------------------------------- #
api/functions/analysis-snapshot-release-zenodo-upload.R-215-
--
api/functions/analysis-snapshot-release-zenodo-upload.R-224-#' `is.na()` is checked BEFORE `nzchar()` because `nzchar(NA_character_)` is
api/functions/analysis-snapshot-release-zenodo-upload.R-225-#' TRUE in R -- without the guard an NA field survives the filter and is
api/functions/analysis-snapshot-release-zenodo-upload.R-226-#' emitted as an explicit `null` instead of being omitted.
api/functions/analysis-snapshot-release-zenodo-upload.R:227:.analysis_release_zenodo_doi_non_empty_fields <- function(doi_fields) {
api/functions/analysis-snapshot-release-zenodo-upload.R-228-  doi_fields <- doi_fields[names(doi_fields) %in% .ANALYSIS_RELEASE_ZENODO_DOI_FIELD_NAMES]
api/functions/analysis-snapshot-release-zenodo-upload.R-229-  Filter(function(value) {
api/functions/analysis-snapshot-release-zenodo-upload.R-230-    if (is.null(value) || length(value) == 0) {
--
api/functions/analysis-snapshot-release-zenodo-upload.R-254-#'   is ever placed into the URL.
api/functions/analysis-snapshot-release-zenodo-upload.R-255-#' @param patch Function(method, url, token, body = NULL) -> parsed JSON list.
api/functions/analysis-snapshot-release-zenodo-upload.R-256-#'   Injectable seam; defaults to the real httr2 call.
api/functions/analysis-snapshot-release-zenodo-upload.R:257:analysis_release_zenodo_record_doi <- function(
api/functions/analysis-snapshot-release-zenodo-upload.R-258-    sysndd_api_base_url, admin_token, release_id, doi_fields,
api/functions/analysis-snapshot-release-zenodo-upload.R-259-    patch = .analysis_release_zenodo_http_json) {
api/functions/analysis-snapshot-release-zenodo-upload.R-260-  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
api/functions/analysis-snapshot-release-zenodo-upload.R-261-  release_id <- as.character(release_id)[[1]]
api/functions/analysis-snapshot-release-zenodo-upload.R-262-  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-upload.R:263:  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
api/functions/analysis-snapshot-release-zenodo-upload.R:264:  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
api/functions/analysis-snapshot-release-zenodo-upload.R-265-  patch("PATCH", url, admin_token, body = fields)
api/functions/analysis-snapshot-release-zenodo-upload.R-266-}
api/functions/analysis-snapshot-release-zenodo-upload.R-267-
--
api/functions/analysis-snapshot-release-zenodo-upload.R-277-#' `shQuote()`d (POSIX `sh` quoting -- wraps in single quotes and escapes any
api/functions/analysis-snapshot-release-zenodo-upload.R-278-#' embedded single quote), so even a doi_fields VALUE containing a quote,
api/functions/analysis-snapshot-release-zenodo-upload.R-279-#' `;`, or a newline cannot break out of the single-quoted `curl` arguments.
api/functions/analysis-snapshot-release-zenodo-upload.R:280:analysis_release_zenodo_manual_doi_command <- function(sysndd_api_base_url, release_id, doi_fields) {
api/functions/analysis-snapshot-release-zenodo-upload.R-281-  base_url <- sub("/+$", "", as.character(sysndd_api_base_url)[[1]])
api/functions/analysis-snapshot-release-zenodo-upload.R-282-  release_id <- as.character(release_id)[[1]]
api/functions/analysis-snapshot-release-zenodo-upload.R-283-  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-upload.R:284:  url <- paste0(base_url, "/api/admin/analysis/releases/", release_id, "/doi")
api/functions/analysis-snapshot-release-zenodo-upload.R:285:  fields <- .analysis_release_zenodo_doi_non_empty_fields(doi_fields)
api/functions/analysis-snapshot-release-zenodo-upload.R-286-  body_json <- as.character(jsonlite::toJSON(fields, auto_unbox = TRUE))
api/functions/analysis-snapshot-release-zenodo-upload.R-287-
api/functions/analysis-snapshot-release-zenodo-upload.R-288-  paste0(
--
api/functions/analysis-snapshot-release-zenodo-upload.R-324-#' @param record_doi Whether `--record-doi` was passed.
api/functions/analysis-snapshot-release-zenodo-upload.R-325-#' @param printer Function(...) used for output; defaults to `cat`.
api/functions/analysis-snapshot-release-zenodo-upload.R-326-#'   Injectable seam so tests can capture output without `capture.output()`.
api/functions/analysis-snapshot-release-zenodo-upload.R:327:#' @param record_doi_fn Function with `analysis_release_zenodo_record_doi()`'s
api/functions/analysis-snapshot-release-zenodo-upload.R-328-#'   signature. Injectable seam (mirrors every other HTTP boundary in this
api/functions/analysis-snapshot-release-zenodo-upload.R-329-#'   file) so tests can exercise the automatic-record branch without a real
api/functions/analysis-snapshot-release-zenodo-upload.R-330-#'   network call.
api/functions/analysis-snapshot-release-zenodo-upload.R:331:analysis_release_zenodo_print_doi_record_back <- function(
api/functions/analysis-snapshot-release-zenodo-upload.R-332-    result, release_id, api_base_url, record_doi, printer = cat,
api/functions/analysis-snapshot-release-zenodo-upload.R:333:    record_doi_fn = analysis_release_zenodo_record_doi) {
api/functions/analysis-snapshot-release-zenodo-upload.R-334-  have_release_id <- !is.null(release_id) && nzchar(as.character(release_id)[[1]])
api/functions/analysis-snapshot-release-zenodo-upload.R-335-  if (!have_release_id) {
api/functions/analysis-snapshot-release-zenodo-upload.R-336-    printer("\nNo --release-id supplied -- pass one to record or print a DOI record-back command.\n")
--
api/functions/analysis-snapshot-release-zenodo-upload.R-379-      "or record it by hand:\n",
api/functions/analysis-snapshot-release-zenodo-upload.R-380-      sep = ""
api/functions/analysis-snapshot-release-zenodo-upload.R-381-    )
api/functions/analysis-snapshot-release-zenodo-upload.R:382:    printer(analysis_release_zenodo_manual_doi_command(api_base_url, release_id, doi_fields), "\n")
api/functions/analysis-snapshot-release-zenodo-upload.R-383-  }
api/functions/analysis-snapshot-release-zenodo-upload.R-384-  invisible(NULL)
api/functions/analysis-snapshot-release-zenodo-upload.R-385-}
api/functions/analysis-snapshot-release-zenodo-upload.R-386-
api/functions/analysis-snapshot-release-zenodo-upload.R-387-# --------------------------------------------------------------------------- #
api/functions/analysis-snapshot-release-zenodo-upload.R-388-# Orchestrator -- mirrors the Python sibling's `main()` flow. Pure w.r.t.
api/functions/analysis-snapshot-release-zenodo-upload.R:389:# SysNDD: it never calls `analysis_release_zenodo_record_doi()` itself (the
api/functions/analysis-snapshot-release-zenodo-upload.R-390-# CLI script does that, after this returns).
api/functions/analysis-snapshot-release-zenodo-upload.R-391-# --------------------------------------------------------------------------- #
api/functions/analysis-snapshot-release-zenodo-upload.R-392-
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
api/endpoints/admin_analysis_snapshot_endpoints.R-156-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-157-#* @post /releases
api/endpoints/admin_analysis_snapshot_endpoints.R-158-function(req, res) {
api/endpoints/admin_analysis_snapshot_endpoints.R:159:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-160-
api/endpoints/admin_analysis_snapshot_endpoints.R-161-  body <- .admin_release_parse_json_body(req)
api/endpoints/admin_analysis_snapshot_endpoints.R-162-  publish_flag <- if (is.null(body$publish)) TRUE else isTRUE(body$publish)
--
api/endpoints/admin_analysis_snapshot_endpoints.R-198-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-199-#* @get /releases
api/endpoints/admin_analysis_snapshot_endpoints.R-200-function(req, res, limit = NULL, offset = NULL) {
api/endpoints/admin_analysis_snapshot_endpoints.R:201:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-202-
api/endpoints/admin_analysis_snapshot_endpoints.R-203-  limit_int <- .admin_release_query_int(limit, 50L)
api/endpoints/admin_analysis_snapshot_endpoints.R-204-  offset_int <- .admin_release_query_int(offset, 0L)
--
api/endpoints/admin_analysis_snapshot_endpoints.R-220-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-221-#* @get /releases/<release_id>
api/endpoints/admin_analysis_snapshot_endpoints.R-222-function(req, res, release_id) {
api/endpoints/admin_analysis_snapshot_endpoints.R:223:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-224-
api/endpoints/admin_analysis_snapshot_endpoints.R-225-  head <- analysis_release_get(release_id, include_draft = TRUE, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R-226-  if (is.null(head)) {
--
api/endpoints/admin_analysis_snapshot_endpoints.R-239-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-240-#* @post /releases/<release_id>/publish
api/endpoints/admin_analysis_snapshot_endpoints.R-241-function(req, res, release_id) {
api/endpoints/admin_analysis_snapshot_endpoints.R:242:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-243-  svc_release_publish(release_id, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R-244-}
api/endpoints/admin_analysis_snapshot_endpoints.R-245-
--
api/endpoints/admin_analysis_snapshot_endpoints.R-261-#* @patch /releases/<release_id>/doi
api/endpoints/admin_analysis_snapshot_endpoints.R-262-function(req, res, release_id, zenodo_record_id = NULL, zenodo_record_url = NULL,
api/endpoints/admin_analysis_snapshot_endpoints.R-263-         version_doi = NULL, concept_doi = NULL) {
api/endpoints/admin_analysis_snapshot_endpoints.R:264:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-265-
api/endpoints/admin_analysis_snapshot_endpoints.R-266-  doi_fields <- list(
api/endpoints/admin_analysis_snapshot_endpoints.R-267-    zenodo_record_id = zenodo_record_id,
--
api/endpoints/admin_analysis_snapshot_endpoints.R-288-#*
api/endpoints/admin_analysis_snapshot_endpoints.R-289-#* @delete /releases/<release_id>
api/endpoints/admin_analysis_snapshot_endpoints.R-290-function(req, res, release_id) {
api/endpoints/admin_analysis_snapshot_endpoints.R:291:  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-292-  svc_release_delete_draft(release_id, conn = pool)
api/endpoints/admin_analysis_snapshot_endpoints.R-293-}

exec
/bin/bash -lc "nl -ba api/endpoints/admin_analysis_snapshot_endpoints.R | sed -n '250,290p'
nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-upload.R | sed -n '1,190p'
nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-upload.R | sed -n '300,450p'
nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-upload-doi-safety.R | sed -n '1,239p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
     1	# Unit tests for the analysis-snapshot RELEASE Zenodo upload/DOI-record-back
     2	# logic (#573 Slice C / Task C2):
     3	# api/functions/analysis-snapshot-release-zenodo-upload.R.
     4	#
     5	# Pure, DB-free, NO NETWORK: every HTTP boundary is an injectable seam
     6	# (`http`/`put`/`patch`) so tests supply plain stub closures instead of a
     7	# mocking library -- the direct R analog of the sibling
     8	# `../nddscore/tests/test_sysndd_zenodo_upload.py`'s
     9	# `monkeypatch.setattr(...requests.put, fake_put)` style.
    10
    11	library(testthat)
    12
    13	source_api_file("functions/analysis-snapshot-release-zenodo-upload.R", local = FALSE)
    14
    15	# --------------------------------------------------------------------------- #
    16	# require_publish_confirmation -- the double-gate safety interlock
    17	# --------------------------------------------------------------------------- #
    18
    19	test_that("require_publish_confirmation: publish=TRUE, confirm_publish=FALSE stops with the exact message", {
    20	  expect_error(
    21	    analysis_release_zenodo_require_publish_confirmation(TRUE, FALSE),
    22	    "^--publish requires --confirm-publish$"
    23	  )
    24	})
    25
    26	test_that("require_publish_confirmation: publish=FALSE, confirm_publish=FALSE is a no-op", {
    27	  expect_no_error(analysis_release_zenodo_require_publish_confirmation(FALSE, FALSE))
    28	})
    29
    30	test_that("require_publish_confirmation: publish=TRUE, confirm_publish=TRUE is a no-op", {
    31	  expect_no_error(analysis_release_zenodo_require_publish_confirmation(TRUE, TRUE))
    32	})
    33
    34	# --------------------------------------------------------------------------- #
    35	# resolve_api
    36	# --------------------------------------------------------------------------- #
    37
    38	test_that("resolve_api: sandbox=TRUE returns the sandbox host, FALSE/default returns prod", {
    39	  expect_identical(analysis_release_zenodo_resolve_api(TRUE), "https://sandbox.zenodo.org/api")
    40	  expect_identical(analysis_release_zenodo_resolve_api(FALSE), "https://zenodo.org/api")
    41	  expect_identical(analysis_release_zenodo_resolve_api(), "https://zenodo.org/api")
    42	})
    43
    44	# --------------------------------------------------------------------------- #
    45	# upload_bucket -- direct analog of the sibling's test #3
    46	# --------------------------------------------------------------------------- #
    47
    48	test_that("upload_bucket: PUTs to {bucket}/{basename(archive)}, Bearer token, body is the archive file", {
    49	  archive <- withr::local_tempfile()
    50	  writeBin(charToRaw("abc"), archive)
    51
    52	  captured <- new.env()
    53	  stub_put <- function(url, token, archive_path) {
    54	    assign("url", url, envir = captured)
    55	    assign("token", token, envir = captured)
    56	    assign("bytes", readBin(archive_path, "raw", file.info(archive_path)$size), envir = captured)
    57	  }
    58
    59	  result <- analysis_release_zenodo_upload_bucket(
    60	    "https://zenodo.example/bucket", "token", archive, put = stub_put
    61	  )
    62
    63	  expect_identical(get("url", envir = captured), paste0("https://zenodo.example/bucket/", basename(archive)))
    64	  expect_identical(get("token", envir = captured), "token")
    65	  expect_identical(get("bytes", envir = captured), charToRaw("abc"))
    66	  expect_identical(result, paste0("https://zenodo.example/bucket/", basename(archive)))
    67	})
    68
    69	test_that("upload_bucket: strips a trailing slash from bucket_url before building the target URL", {
    70	  archive <- withr::local_tempfile()
    71	  writeBin(charToRaw("xyz"), archive)
    72	  captured_url <- NULL
    73	  stub_put <- function(url, token, archive_path) captured_url <<- url
    74
    75	  analysis_release_zenodo_upload_bucket("https://zenodo.example/bucket/", "token", archive, put = stub_put)
    76
    77	  expect_identical(captured_url, paste0("https://zenodo.example/bucket/", basename(archive)))
    78	})
    79
    80	# --------------------------------------------------------------------------- #
    81	# get_or_create_deposition -- create path (POST, no id) vs reuse path (GET)
    82	# --------------------------------------------------------------------------- #
    83
    84	test_that("get_or_create_deposition: NULL deposition_id -> POST .../deposit/depositions", {
    85	  captured <- new.env()
    86	  stub_http <- function(method, url, token, body = NULL) {
    87	    assign("method", method, envir = captured)
    88	    assign("url", url, envir = captured)
    89	    assign("token", token, envir = captured)
    90	    assign("body", body, envir = captured)
    91	    list(id = 999, links = list(bucket = "https://bucket.example"))
    92	  }
    93
    94	  result <- analysis_release_zenodo_get_or_create_deposition(
    95	    "https://zenodo.org/api", "tok", deposition_id = NULL, http = stub_http
    96	  )
    97
    98	  expect_identical(get("method", envir = captured), "POST")
    99	  expect_identical(get("url", envir = captured), "https://zenodo.org/api/deposit/depositions")
   100	  expect_identical(get("token", envir = captured), "tok")
   101	  expect_identical(get("body", envir = captured), list())
   102	  expect_identical(result$id, 999)
   103	})
   104
   105	test_that("get_or_create_deposition: explicit deposition_id -> GET .../deposit/depositions/{id}", {
   106	  captured <- new.env()
   107	  stub_http <- function(method, url, token, body = NULL) {
   108	    assign("method", method, envir = captured)
   109	    assign("url", url, envir = captured)
   110	    assign("body", body, envir = captured)
   111	    list(id = 42)
   112	  }
   113
   114	  result <- analysis_release_zenodo_get_or_create_deposition(
   115	    "https://zenodo.org/api", "tok", deposition_id = 42, http = stub_http
   116	  )
   117
   118	  expect_identical(get("method", envir = captured), "GET")
   119	  expect_identical(get("url", envir = captured), "https://zenodo.org/api/deposit/depositions/42")
   120	  expect_null(get("body", envir = captured))
   121	  expect_identical(result$id, 42)
   122	})
   123
   124	# --------------------------------------------------------------------------- #
   125	# set_metadata
   126	# --------------------------------------------------------------------------- #
   127
   128	test_that("set_metadata: PUTs to .../deposit/depositions/{id} with body {\"metadata\": ...}", {
   129	  captured <- new.env()
   130	  stub_http <- function(method, url, token, body = NULL) {
   131	    assign("method", method, envir = captured)
   132	    assign("url", url, envir = captured)
   133	    assign("body", body, envir = captured)
   134	    NULL
   135	  }
   136	  metadata <- list(title = "Test dataset", upload_type = "dataset")
   137
   138	  analysis_release_zenodo_set_metadata(
   139	    "https://zenodo.org/api", "tok", 123, metadata, http = stub_http
   140	  )
   141
   142	  expect_identical(get("method", envir = captured), "PUT")
   143	  expect_identical(get("url", envir = captured), "https://zenodo.org/api/deposit/depositions/123")
   144	  expect_identical(get("body", envir = captured), list(metadata = metadata))
   145	})
   146
   147	# --------------------------------------------------------------------------- #
   148	# publish_deposition
   149	# --------------------------------------------------------------------------- #
   150
   151	test_that("publish_deposition: POSTs to .../deposit/depositions/{id}/actions/publish", {
   152	  captured <- new.env()
   153	  stub_http <- function(method, url, token, body = NULL) {
   154	    assign("method", method, envir = captured)
   155	    assign("url", url, envir = captured)
   156	    list(doi = "10.5281/zenodo.999", conceptdoi = "10.5281/zenodo.998", links = list(html = "https://zenodo.org/record/999"))
   157	  }
   158
   159	  result <- analysis_release_zenodo_publish_deposition(
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
   300	  expect_false(grepl("null", command, fixed = TRUE))
   301	  expect_false(grepl("\"NA\"", command, fixed = TRUE))
   302	})
   303
   304	# --------------------------------------------------------------------------- #
   305	# upload(): full orchestration with stubbed HTTP -- draft-only and publish
   306	# --------------------------------------------------------------------------- #
   307
   308	# Deliberately uses plain `tempfile()`, NOT `withr::local_tempfile()`: the
   309	# latter schedules cleanup via `withr::defer(..., envir = parent.frame())`,
   310	# and `parent.frame()` evaluated INSIDE this helper resolves to this
   311	# function's own (short-lived) call frame, not the calling `test_that()`
   312	# block -- so the files would be deleted the instant this helper returns,
   313	# before the caller can use them (same trap documented in
   314	# `test-unit-analysis-release-zenodo-package.R`'s `make_well_formed_staging()`
   315	# comment). Session tempdir cleanup at process exit is sufficient here.
   316	.zenodo_upload_test_files <- function() {
   317	  archive <- file.path(tempdir(), paste0("zenodo_upload_test_", as.integer(stats::runif(1, 1, 1e9)), ".tar.gz"))
   318	  writeBin(charToRaw("archive bytes"), archive)
   319	  metadata_path <- file.path(tempdir(), paste0("zenodo_upload_test_", as.integer(stats::runif(1, 1, 1e9)), ".json"))
   320	  writeLines('{"title": "Test", "upload_type": "dataset"}', metadata_path)
   321	  list(archive = archive, metadata_path = metadata_path)
   322	}
   323
   324	test_that("upload(): draft-only flow (publish=FALSE) never calls publish_deposition", {
   325	  files <- .zenodo_upload_test_files()
   326	  publish_called <- FALSE
   327
   328	  fake_get_or_create <- function(api, token, deposition_id = NULL) {
   329	    list(
   330	      id = 111,
   331	      links = list(bucket = "https://bucket.example/111", html = "https://zenodo.org/deposit/111"),
   332	      metadata = list(prereserve_doi = list(doi = "10.5281/zenodo.111"))
   333	    )
   334	  }
   335	  fake_set_metadata <- function(api, token, deposition_id, metadata) NULL
   336	  fake_upload_bucket <- function(bucket_url, token, archive_path) invisible(NULL)
   337	  fake_publish <- function(api, token, deposition_id) {
   338	    publish_called <<- TRUE
   339	    list()
   340	  }
   341
   342	  result <- analysis_release_zenodo_upload(
   343	    archive_path = files$archive,
   344	    metadata_path = files$metadata_path,
   345	    token = "tok",
   346	    publish = FALSE,
   347	    confirm_publish = FALSE,
   348	    get_or_create_deposition = fake_get_or_create,
   349	    set_metadata = fake_set_metadata,
   350	    upload_bucket = fake_upload_bucket,
   351	    publish_deposition = fake_publish
   352	  )
   353
   354	  expect_false(publish_called)
   355	  expect_identical(result$deposition_id, 111)
   356	  expect_identical(result$reserved_doi, "10.5281/zenodo.111")
   357	  expect_identical(result$draft_url, "https://zenodo.org/deposit/111")
   358	  expect_false(result$published)
   359	  expect_true(is.na(result$version_doi))
   360	})
   361
   362	test_that("upload(): publish=TRUE + confirm_publish=TRUE publishes and fills version/concept DOI + record_url", {
   363	  files <- .zenodo_upload_test_files()
   364
   365	  fake_get_or_create <- function(api, token, deposition_id = NULL) {
   366	    list(id = 222, links = list(bucket = "https://bucket.example/222", html = "https://zenodo.org/deposit/222"))
   367	  }
   368	  fake_set_metadata <- function(api, token, deposition_id, metadata) NULL
   369	  fake_upload_bucket <- function(bucket_url, token, archive_path) invisible(NULL)
   370	  fake_publish <- function(api, token, deposition_id) {
   371	    list(
   372	      doi = "10.5281/zenodo.222",
   373	      conceptdoi = "10.5281/zenodo.221",
   374	      links = list(html = "https://zenodo.org/record/222")
   375	    )
   376	  }
   377
   378	  result <- analysis_release_zenodo_upload(
   379	    archive_path = files$archive,
   380	    metadata_path = files$metadata_path,
   381	    token = "tok",
   382	    publish = TRUE,
   383	    confirm_publish = TRUE,
   384	    get_or_create_deposition = fake_get_or_create,
   385	    set_metadata = fake_set_metadata,
   386	    upload_bucket = fake_upload_bucket,
   387	    publish_deposition = fake_publish
   388	  )
   389
   390	  expect_true(result$published)
   391	  expect_identical(result$version_doi, "10.5281/zenodo.222")
   392	  expect_identical(result$concept_doi, "10.5281/zenodo.221")
   393	  expect_identical(result$record_url, "https://zenodo.org/record/222")
   394	})
   395
   396	test_that("upload(): publish=TRUE without confirm_publish stops before any HTTP seam is invoked", {
   397	  files <- .zenodo_upload_test_files()
   398	  called <- FALSE
   399	  fake_get_or_create <- function(...) {
   400	    called <<- TRUE
   401	    list(id = 1, links = list(bucket = "https://bucket.example"))
   402	  }
   403
   404	  expect_error(
   405	    analysis_release_zenodo_upload(
   406	      archive_path = files$archive,
   407	      metadata_path = files$metadata_path,
   408	      token = "tok",
   409	      publish = TRUE,
   410	      confirm_publish = FALSE,
   411	      get_or_create_deposition = fake_get_or_create
   412	    ),
   413	    "--publish requires --confirm-publish"
   414	  )
   415	  expect_false(called)
   416	})
   417
   418	test_that("upload(): missing token stops with a clear message", {
   419	  files <- .zenodo_upload_test_files()
   420	  expect_error(
   421	    analysis_release_zenodo_upload(
   422	      archive_path = files$archive, metadata_path = files$metadata_path, token = ""
   423	    ),
   424	    "ZENODO_TOKEN"
   425	  )
   426	})
   427
   428	test_that("upload(): missing archive file stops with a clear message", {
   429	  files <- .zenodo_upload_test_files()
   430	  expect_error(
   431	    analysis_release_zenodo_upload(
   432	      archive_path = file.path(tempdir(), "does-not-exist.tar.gz"),
   433	      metadata_path = files$metadata_path,
   434	      token = "tok"
   435	    ),
   436	    "Archive does not exist"
   437	  )
   438	})
   439
   440	test_that("upload(): missing metadata file stops with a clear message", {
   441	  files <- .zenodo_upload_test_files()
   442	  expect_error(
   443	    analysis_release_zenodo_upload(
   444	      archive_path = files$archive,
   445	      metadata_path = file.path(tempdir(), "does-not-exist.json"),
   446	      token = "tok"
   447	    ),
   448	    "Metadata does not exist"
   449	  )
   450	})
     1	# Unit tests for the Codex round-2 hardening of the analysis-snapshot
     2	# RELEASE Zenodo upload/DOI-record-back logic (#573 Slice C):
     3	# api/functions/analysis-snapshot-release-zenodo-upload.R.
     4	#
     5	# Split out of the sibling test-unit-analysis-release-zenodo-upload.R (which
     6	# covers the pre-existing upload/deposition-lifecycle behavior) to keep both
     7	# files under the repo's 600-line soft ceiling -- mirrors the
     8	# `-docs.R`/`-verify.R` and `comparisons-functions.R`/`comparisons-parsers.R`
     9	# split precedent.
    10	#
    11	# Pure, DB-free, NO NETWORK: every HTTP boundary is an injectable seam
    12	# (`patch`/`record_doi_fn`) so tests supply plain stub closures instead of a
    13	# mocking library or a real network call.
    14	#
    15	# Covers:
    16	# - item 2 (HIGH): `record_doi()`, `manual_doi_command()`, and
    17	#   `print_doi_record_back()` all reject an invalid `--release-id` (a quote,
    18	#   `;`, embedded newline, or `../` traversal shape) BEFORE building any
    19	#   admin PATCH URL or printed shell command from it.
    20	# - item 2 (HIGH) defense in depth: `manual_doi_command()` `shQuote()`s the
    21	#   URL and JSON body it prints.
    22	# - item 3 (MEDIUM): `print_doi_record_back()` never prints a populated PATCH
    23	#   command for a DRAFT upload (published-only rule), regardless of whether
    24	#   `--record-doi` was passed.
    25
    26	library(testthat)
    27
    28	source_api_file("functions/analysis-snapshot-release-zenodo-upload.R", local = FALSE)
    29
    30	# --------------------------------------------------------------------------- #
    31	# record_doi / manual_doi_command -- release-id validation (Codex round-2
    32	# item 2, HIGH): an invalid --release-id must be rejected BEFORE either
    33	# builds the admin PATCH URL or the printed shell command from it.
    34	# --------------------------------------------------------------------------- #
    35
    36	.invalid_release_ids_round2 <- list(
    37	  quote = "asr_deadbeefcafeb' OR '1'='1",
    38	  semicolon = "asr_deadbeefcafeb; rm -rf ~",
    39	  newline = "asr_deadbeefcafeb\nrm -rf /",
    40	  traversal = "../evil"
    41	)
    42
    43	for (.label in names(.invalid_release_ids_round2)) {
    44	  local({
    45	    label <- .label
    46	    bad_id <- .invalid_release_ids_round2[[label]]
    47
    48	    test_that(paste0("record_doi: rejects a release_id containing ", label, " before calling patch"), {
    49	      called <- FALSE
    50	      stub_patch <- function(method, url, token, body = NULL) {
    51	        called <<- TRUE
    52	        list()
    53	      }
    54	      expect_error(
    55	        analysis_release_zenodo_record_doi(
    56	          "http://localhost:7778", "admin-token", bad_id,
    57	          doi_fields = list(zenodo_record_id = "1"), patch = stub_patch
    58	        ),
    59	        "Invalid analysis-snapshot release id"
    60	      )
    61	      expect_false(called)
    62	    })
    63
    64	    test_that(paste0("manual_doi_command: rejects a release_id containing ", label, " before building any command"), {
    65	      expect_error(
    66	        analysis_release_zenodo_manual_doi_command(
    67	          "http://localhost:7778", bad_id, doi_fields = list(zenodo_record_id = "1")
    68	        ),
    69	        "Invalid analysis-snapshot release id"
    70	      )
    71	    })
    72	  })
    73	}
    74
    75	test_that("record_doi: accepts a well-formed asr_<16 hex> release_id", {
    76	  captured_url <- NULL
    77	  stub_patch <- function(method, url, token, body = NULL) {
    78	    captured_url <<- url
    79	    list()
    80	  }
    81	  analysis_release_zenodo_record_doi(
    82	    "http://localhost:7778", "admin-token", "asr_deadbeefcafebabe",
    83	    doi_fields = list(zenodo_record_id = "1"), patch = stub_patch
    84	  )
    85	  expect_identical(captured_url, "http://localhost:7778/api/admin/analysis/releases/asr_deadbeefcafebabe/doi")
    86	})
    87
    88	test_that("manual_doi_command: shQuote()s the URL and JSON body (defense in depth, Codex round-2 item 2)", {
    89	  # A well-formed release_id can never itself carry shell metacharacters (the
    90	  # validator rejects those), but a doi_fields VALUE is not release-id
    91	  # shaped -- shQuote() on the whole JSON body means even an adversarial
    92	  # field value cannot break out of the printed `curl` command's arguments.
    93	  fields <- list(zenodo_record_id = "1' ; rm -rf ~ ; #")
    94	  command <- analysis_release_zenodo_manual_doi_command(
    95	    "http://localhost:7778", "asr_deadbeefcafebabe", doi_fields = fields
    96	  )
    97
    98	  expected_url <- "http://localhost:7778/api/admin/analysis/releases/asr_deadbeefcafebabe/doi"
    99	  expected_body_json <- as.character(jsonlite::toJSON(fields, auto_unbox = TRUE))
   100
   101	  expect_true(grepl(shQuote(expected_url), command, fixed = TRUE))
   102	  expect_true(grepl(shQuote(expected_body_json), command, fixed = TRUE))
   103	  # The dangerous value must never appear as a NAIVELY single-quoted,
   104	  # unescaped argument -- that would let a POSIX shell split it into
   105	  # multiple commands at the un-escaped `;`.
   106	  expect_false(grepl("-d '1' ; rm -rf ~ ; #'", command, fixed = TRUE))
   107	})
   108
   109	# --------------------------------------------------------------------------- #
   110	# print_doi_record_back -- the CLI-facing DOI print step. Codex round-2
   111	# item 2 (HIGH, release-id validation before ANY URL/command is built) and
   112	# item 3 (MEDIUM, no populated PATCH command for a DRAFT).
   113	# --------------------------------------------------------------------------- #
   114
   115	.captured_prints <- function() {
   116	  out <- character(0)
   117	  list(
   118	    printer = function(...) out <<- c(out, paste0(..., collapse = "")),
   119	    get = function() paste(out, collapse = "")
   120	  )
   121	}
   122
   123	.published_result <- list(
   124	  deposition_id = 555,
   125	  reserved_doi = "10.5281/zenodo.555",
   126	  draft_url = "https://zenodo.org/deposit/555",
   127	  published = TRUE,
   128	  version_doi = "10.5281/zenodo.555",
   129	  concept_doi = "10.5281/zenodo.554",
   130	  record_url = "https://zenodo.org/record/555"
   131	)
   132
   133	.draft_result <- list(
   134	  deposition_id = 555,
   135	  reserved_doi = "10.5281/zenodo.555",
   136	  draft_url = "https://zenodo.org/deposit/555",
   137	  published = FALSE,
   138	  version_doi = NA_character_,
   139	  concept_doi = NA_character_,
   140	  record_url = NA_character_
   141	)
   142
   143	test_that("print_doi_record_back: DRAFT upload prints NO populated PATCH command (Codex round-2 item 3, MEDIUM)", {
   144	  captured <- .captured_prints()
   145	  analysis_release_zenodo_print_doi_record_back(
   146	    .draft_result, "asr_deadbeefcafebabe", "http://localhost:7778",
   147	    record_doi = FALSE, printer = captured$printer
   148	  )
   149	  output <- captured$get()
   150
   151	  expect_false(grepl("curl -X PATCH", output, fixed = TRUE))
   152	  expect_false(grepl("/doi", output, fixed = TRUE))
   153	  expect_true(grepl("not published", output, fixed = TRUE) || grepl("Draft", output, fixed = TRUE))
   154	  expect_true(grepl("--publish --confirm-publish", output, fixed = TRUE))
   155	})
   156
   157	test_that("print_doi_record_back: DRAFT upload with --record-doi still prints NO PATCH command (published-only rule)", {
   158	  # Even if the operator passed --record-doi, a draft's DOI is never final --
   159	  # the published-only rule must win regardless of the record_doi flag.
   160	  captured <- .captured_prints()
   161	  withr::local_envvar(SYSNDD_ADMIN_TOKEN = "admin-token")
   162	  analysis_release_zenodo_print_doi_record_back(
   163	    .draft_result, "asr_deadbeefcafebabe", "http://localhost:7778",
   164	    record_doi = TRUE, printer = captured$printer
   165	  )
   166	  output <- captured$get()
   167
   168	  expect_false(grepl("curl -X PATCH", output, fixed = TRUE))
   169	  expect_false(grepl("DOI recorded on the SysNDD release head", output, fixed = TRUE))
   170	})
   171
   172	test_that("print_doi_record_back: PUBLISHED upload without --record-doi prints the populated manual command", {
   173	  captured <- .captured_prints()
   174	  analysis_release_zenodo_print_doi_record_back(
   175	    .published_result, "asr_deadbeefcafebabe", "http://localhost:7778",
   176	    record_doi = FALSE, printer = captured$printer
   177	  )
   178	  output <- captured$get()
   179
   180	  expect_true(grepl("curl -X PATCH", output, fixed = TRUE))
   181	  expect_true(grepl("10.5281/zenodo.555", output, fixed = TRUE))
   182	})
   183
   184	test_that("print_doi_record_back: PUBLISHED upload with --record-doi and admin token auto-records via the injected seam (no manual command printed)", {
   185	  captured <- .captured_prints()
   186	  withr::local_envvar(SYSNDD_ADMIN_TOKEN = "admin-token")
   187	  captured_call <- new.env()
   188	  stub_record_doi_fn <- function(sysndd_api_base_url, admin_token, release_id, doi_fields) {
   189	    assign("release_id", release_id, envir = captured_call)
   190	    assign("doi_fields", doi_fields, envir = captured_call)
   191	    list(release_id = release_id, version_doi = doi_fields$version_doi, zenodo_record_url = doi_fields$zenodo_record_url)
   192	  }
   193
   194	  analysis_release_zenodo_print_doi_record_back(
   195	    .published_result, "asr_deadbeefcafebabe", "http://localhost:7778",
   196	    record_doi = TRUE, printer = captured$printer, record_doi_fn = stub_record_doi_fn
   197	  )
   198	  output <- captured$get()
   199
   200	  expect_false(grepl("curl -X PATCH", output, fixed = TRUE))
   201	  expect_true(grepl("DOI recorded on the SysNDD release head", output, fixed = TRUE))
   202	  expect_identical(get("release_id", envir = captured_call), "asr_deadbeefcafebabe")
   203	  expect_identical(get("doi_fields", envir = captured_call)$version_doi, "10.5281/zenodo.555")
   204	})
   205
   206	for (.label in names(.invalid_release_ids_round2)) {
   207	  local({
   208	    label <- .label
   209	    bad_id <- .invalid_release_ids_round2[[label]]
   210
   211	    test_that(paste0(
   212	      "print_doi_record_back: rejects a release_id containing ", label,
   213	      " before building any URL/command (Codex round-2 item 2, HIGH)"
   214	    ), {
   215	      captured <- .captured_prints()
   216	      expect_error(
   217	        analysis_release_zenodo_print_doi_record_back(
   218	          .published_result, bad_id, "http://localhost:7778",
   219	          record_doi = FALSE, printer = captured$printer
   220	        ),
   221	        "Invalid analysis-snapshot release id"
   222	      )
   223	      # Nothing (no manual command, no partial URL) was ever printed before
   224	      # the validator stopped the run.
   225	      expect_false(grepl("curl", captured$get(), fixed = TRUE))
   226	    })
   227	  })
   228	}
   229
   230	test_that("print_doi_record_back: no --release-id supplied prints guidance and never validates/builds anything", {
   231	  captured <- .captured_prints()
   232	  expect_no_error(
   233	    analysis_release_zenodo_print_doi_record_back(
   234	      .published_result, NULL, "http://localhost:7778",
   235	      record_doi = FALSE, printer = captured$printer
   236	    )
   237	  )
   238	  expect_true(grepl("No --release-id supplied", captured$get(), fixed = TRUE))
   239	})

exec
/bin/bash -lc "Rscript --vanilla -e 'files <- c(\"api/functions/analysis-snapshot-release-zenodo-common.R\", \"api/functions/analysis-snapshot-release-zenodo-verify.R\", \"api/functions/analysis-snapshot-release-zenodo-docs.R\", \"api/functions/analysis-snapshot-release-zenodo-package.R\", \"api/functions/analysis-snapshot-release-zenodo-upload.R\", \"api/scripts/package-analysis-release-zenodo.R\", \"api/scripts/upload-analysis-release-zenodo.R\"); invisible(lapply(files, parse)); print(fs::file_info(\"/dev/null\")"'$type)'"' && git diff --numstat origin/master...HEAD -- ':(exclude).planning/**' && git diff --name-only origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 exited 2 in 0ms:
Fatal error: creating temporary file for '-e' failed

codex
The sandbox prevents R from creating even its temporary session file, so I cannot execute the targeted test suite here. I’ve continued with static path/order verification and the repository’s committed DI tests; the limitation does not affect the code inspection.
exec
/bin/bash -lc "sed -n '1,240p' /home/bernt-popp/.codex/superpowers/skills/verification-before-completion/SKILL.md
rg -n \"fs[[:space:]]*=|Package: fs|\\\"fs\\\"\" api/renv.lock api/DESCRIPTION 2>/dev/null || true
rg -n \"file_info\\(\" api/functions | head -50
rg -n \"analysis-snapshot-release-zenodo\" api/bootstrap/load_modules.R api/start_sysndd_api.R docker-compose.yml docker-compose*.yml 2>/dev/null || true
wc -l api/functions/analysis-snapshot-release-zenodo-{common,package,verify,docs,upload}.R api/scripts/{package,upload}-analysis-release-zenodo.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
api/renv.lock:4183:    "fs": {
api/renv.lock:4184:      "Package": "fs",
api/renv.lock:5095:        "fs",
api/renv.lock:5133:        "fs",
api/renv.lock:7247:        "fs",
api/renv.lock:8501:        "fs",
api/renv.lock:8629:        "fs",
api/renv.lock:8691:        "fs",
api/functions/analysis-snapshot-release-zenodo-verify.R:216:#' real regular file per `fs::file_info(path)$type == "file"`; anything else
api/functions/analysis-snapshot-release-zenodo-verify.R:229:#' Deliberately uses `fs::file_info()$type` (already a repo dependency, see
api/functions/analysis-snapshot-release-zenodo-verify.R:237:#' `fs::file_info()$type` reports the real POSIX file type (`"file"`,
api/functions/analysis-snapshot-release-zenodo-verify.R:268:  # otherwise block indefinitely on a FIFO/pipe. `fs::file_info()` itself
api/functions/analysis-snapshot-release-zenodo-verify.R:276:    !identical(as.character(fs::file_info(full_path)$type), "file")
api/functions/logging-functions.R:65:        file_mod_time <- fs::file_info(file_path)$modification_time
   75 api/functions/analysis-snapshot-release-zenodo-common.R
  422 api/functions/analysis-snapshot-release-zenodo-package.R
  587 api/functions/analysis-snapshot-release-zenodo-verify.R
  163 api/functions/analysis-snapshot-release-zenodo-docs.R
  459 api/functions/analysis-snapshot-release-zenodo-upload.R
  157 api/scripts/package-analysis-release-zenodo.R
  180 api/scripts/upload-analysis-release-zenodo.R
 2043 total

exec
/bin/bash -lc "git diff --check origin/master...HEAD -- ':(exclude).planning/**'
git status --short
rg -n \"analysis-snapshot-release-zenodo\" api/bootstrap api/start_sysndd_api.R docker-compose.yml docker-compose.override.yml || true
rg -n \"\\"'^asr_'"\\[0-9a-f\\]\\{16\\}\\"'$|assert_valid_release_id" api/functions/analysis-snapshot-release-zenodo-{common,package,verify,docs,upload}.R api/scripts/{package,upload}-analysis-release-zenodo.R
rg -n "digest::digest'"\\(file|reject_unsafe_files|utils::untar\" api/functions/analysis-snapshot-release-zenodo-verify.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt-round2.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt-round3.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt-round4.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review-round2.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review-round3.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review-round4.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review.md
?? .planning/reviews/2026-07-19-573-slice-c-reconciliation.md
api/functions/analysis-snapshot-release-zenodo-verify.R:94:# `.analysis_release_zenodo_assert_valid_release_id()` now lives in the
api/functions/analysis-snapshot-release-zenodo-verify.R:130:#'   Validated via `.analysis_release_zenodo_assert_valid_release_id()`
api/functions/analysis-snapshot-release-zenodo-verify.R:141:  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = TRUE)
api/functions/analysis-snapshot-release-zenodo-verify.R:151:#'   `.analysis_release_zenodo_assert_valid_release_id(allow_latest = FALSE)`
api/functions/analysis-snapshot-release-zenodo-verify.R:169:  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-upload.R:39:# shared `.analysis_release_zenodo_assert_valid_release_id()` (guard-sourced
api/functions/analysis-snapshot-release-zenodo-upload.R:251:#'   `.analysis_release_zenodo_assert_valid_release_id()` BEFORE the admin
api/functions/analysis-snapshot-release-zenodo-upload.R:262:  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-upload.R:273:#' `.analysis_release_zenodo_assert_valid_release_id()` BEFORE the URL or
api/functions/analysis-snapshot-release-zenodo-upload.R:283:  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-upload.R:310:#'   `.analysis_release_zenodo_assert_valid_release_id()` immediately after
api/functions/analysis-snapshot-release-zenodo-upload.R:341:  .analysis_release_zenodo_assert_valid_release_id(release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-package.R:344:  .analysis_release_zenodo_assert_valid_release_id(resolved_release_id, allow_latest = FALSE)
api/functions/analysis-snapshot-release-zenodo-common.R:6:# (`.analysis_release_zenodo_assert_valid_release_id()`).
api/functions/analysis-snapshot-release-zenodo-common.R:63:.analysis_release_zenodo_assert_valid_release_id <- function(release_id, allow_latest = FALSE) {
224:#' (or a future tar implementation change), and `digest::digest(file = ...)`
246:.analysis_release_zenodo_reject_unsafe_files <- function(root_dir, context) {
267:  # the file's bytes (e.g. `digest::digest(file = ...)`), which would
301:#' rejected -- `digest::digest(file = ...)` and `file.copy()` both follow
320:  actual_bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
329:  tar_entries <- utils::untar(bundle_path, list = TRUE)
338:  utils::untar(bundle_path, exdir = exdir)
343:  .analysis_release_zenodo_reject_unsafe_files(exdir, "Extracted release bundle")
362:    actual_sha <- digest::digest(file = target, algo = "sha256")
504:#' shared `.analysis_release_zenodo_reject_unsafe_files()` (same check now
508:  .analysis_release_zenodo_reject_unsafe_files(staging_dir, "Zenodo staging")

codex
BLOCKER: None.

HIGH: None. Round-3 non-regular-file finding is resolved: extraction is followed immediately by `.analysis_release_zenodo_reject_unsafe_files()` at [analysis-snapshot-release-zenodo-verify.R:343](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-verify.R:343), before any inner-file digest at line 362. The guard rejects symlinks, then requires every non-directory entry to have `fs::file_info(... )$type == "file"` at line 276—metadata inspection, not a content read—so FIFO/socket/device entries fail closed rather than reaching `digest()`.

MEDIUM: None. `analysis_release_zenodo_download_bundle()` coerces and strictly validates the concrete `asr_<16 lowercase hex>` ID before constructing the URL or invoking the downloader at [analysis-snapshot-release-zenodo-verify.R:167](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-verify.R:167). `../`, quote, and newline-shaped IDs cannot match the anchored validator.

LOW: None.

Adjacent sweep found the locked controls intact: host-only/public-read packaging, no bootstrap registration, sentinel-guarded staging deletion, safe marker extraction without `source`, draft-default double-gated publishing, and published-only opt-in DOI record-back with JSON bodies.

`git diff --check origin/master...HEAD` was clean. I could not run R tests because this read-only sandbox blocks R from creating its temporary session file.

VERDICT: SHIP
tokens used
110,406
BLOCKER: None.

HIGH: None. Round-3 non-regular-file finding is resolved: extraction is followed immediately by `.analysis_release_zenodo_reject_unsafe_files()` at [analysis-snapshot-release-zenodo-verify.R:343](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-verify.R:343), before any inner-file digest at line 362. The guard rejects symlinks, then requires every non-directory entry to have `fs::file_info(... )$type == "file"` at line 276—metadata inspection, not a content read—so FIFO/socket/device entries fail closed rather than reaching `digest()`.

MEDIUM: None. `analysis_release_zenodo_download_bundle()` coerces and strictly validates the concrete `asr_<16 lowercase hex>` ID before constructing the URL or invoking the downloader at [analysis-snapshot-release-zenodo-verify.R:167](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-verify.R:167). `../`, quote, and newline-shaped IDs cannot match the anchored validator.

LOW: None.

Adjacent sweep found the locked controls intact: host-only/public-read packaging, no bootstrap registration, sentinel-guarded staging deletion, safe marker extraction without `source`, draft-default double-gated publishing, and published-only opt-in DOI record-back with JSON bodies.

`git diff --check origin/master...HEAD` was clean. I could not run R tests because this read-only sandbox blocks R from creating its temporary session file.

VERDICT: SHIP
