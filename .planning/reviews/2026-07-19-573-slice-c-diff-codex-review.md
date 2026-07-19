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
session id: 019f79ce-dd68-7071-90f7-fb85070cd8ae
--------
user
# Adversarial diff review — #573 Slice C (Zenodo operator scripts)

You are a staff-level adversarial reviewer. Review the R operator scripts on this branch that package
and upload an immutable analysis-snapshot release (#573) to Zenodo. Be skeptical: hunt for real
correctness bugs, security issues (secret leakage, path traversal, unsafe uploads), contract
mismatches, and weak tests. Expand scope to adjacent same-class issues.

## The diff to review
```
git diff origin/master...HEAD -- ':(exclude).planning/**'
```
7 commits. New R: `api/functions/analysis-snapshot-release-zenodo-{package,docs,upload}.R` (operator
helpers, NOT in `bootstrap/load_modules.R`), `api/scripts/{package,upload}-analysis-release-zenodo.R`
(host-run CLIs), `api/tests/testthat/test-unit-analysis-release-zenodo-{package,upload}.R`. Plus
`Makefile` targets, `.gitignore`, `documentation/09-deployment.qmd` runbook, `AGENTS.md`, and a version
bump to 0.30.3. Context: `AGENTS.md` "Analysis-snapshot releases (#573)"; the sibling being mirrored is
`/home/bernt-popp/development/nddscore/scripts/{package,upload}_sysndd_zenodo_dataset.py` +
`src/models/sysndd_export.py`; the reuse idioms are in `api/functions/nddscore-release-source.R`; the
DOI PATCH endpoint contract is `api/endpoints/admin_analysis_snapshot_endpoints.R`.

## What Slice C does
- **Packager** (`-package.R`): reads a PUBLISHED release over the public HTTP API (`GET
  /api/analysis/releases/{latest|<id>}` + `/<id>/bundle`), verifies the download against the head's
  `bundle_sha256` (SHA-256), extracts + verifies the bundle's inner `checksums.sha256`, re-stages the
  files under `analysis_snapshot_release/`, writes Zenodo docs (README/DATA_CARD/SCHEMA/CHANGELOG/
  CITATION.cff) + `zenodo_metadata.json` + `datapackage.json` + a staging-wide `checksums.sha256`, runs
  a SAFETY VALIDATOR, and builds a deterministic `<release_id>.tar.gz` + `.sha256`.
- **Uploader** (`-upload.R`): Zenodo deposit REST (get-or-create draft → set metadata → PUT archive to
  bucket → optional publish), then an opt-in DOI record-back to the SysNDD admin PATCH endpoint.

## LOCKED decisions (do NOT flag; DO flag violations)
1. **Read path is public HTTP API only** — no DB, no `docker exec`, host-runnable with httr2/jsonlite/
   digest. DI seams (injectable http/put/patch) with real defaults so unit tests use no mocking library.
2. **Publish is DOUBLE-gated**: `require_publish_confirmation(publish, confirm_publish)` STOPS unless
   BOTH `--publish` AND `--confirm-publish`. Draft-only default. The Makefile must NEVER make publishing
   one keystroke.
3. **DOI record-back is OPT-IN**: only fires with `--record-doi` + `SYSNDD_ADMIN_TOKEN` set (and only
   after an actual publish); otherwise it PRINTS the manual PATCH command. Additive endpoint, outside
   the content hash. Only the SUPPLIED non-empty DOI fields are sent (NULL/NA/"" all dropped).
4. **The SAFETY VALIDATOR** runs last before tarring: forbidden files (.env etc. + forbidden dir
   segments), sensitive-text scan (host paths `/home/`, username `bernt-popp`, token-shaped text,
   internal repo names, git_sha), extract-layout sanity.
5. Operator scripts are EXEMPT from `external_proxy_budget()` (confirmed — not in the guard scan set).
6. Content-addressed release ids (`asr_<16hex>`), not date-versioned. No manuscript references anywhere.

## Focus your adversarial energy on
- **Secret leakage**: is `ZENODO_TOKEN` or `SYSNDD_ADMIN_TOKEN` EVER printed to stdout/stderr, embedded
  in the printed manual `curl` command, or written into any staged file? The manual command must use a
  placeholder, not the real token. Could a token end up in the tarball (the validator should catch it —
  does it actually)?
- **The safety validator**: can a sensitive string slip past? Consider files whose suffix is outside the
  scanned set, binary files, deeply nested files, case variations, a `.env` inside the release subdir.
  Does it fire BEFORE tarring, and does a failure actually abort (not warn)?
- **Checksum/verify correctness**: does the packager FAIL closed on a corrupted bundle download, a wrong
  `bundle_sha256`, or a tampered inner `checksums.sha256`? SHA-256 (not md5) throughout?
- **Upload safety**: `req_body_file` streams (not memory-loads) the archive; the bucket PUT URL is
  `{bucket}/{basename}`; publish truly cannot happen without both flags; the get-or-create reuse path
  is correct.
- **DOI record-back**: only supplied fields sent (NULL/NA/empty dropped — the `nzchar(NA)` gotcha);
  JSON body (robust to slashes in the DOI); never fires without the flag+token; never onto a draft.
- **R footguns**: masked base verbs (`setdiff`/`get`/`merge` — namespaced?), `library()` at file top
  (should be none, so tests don't need httr2), `DBI::dbBind` unname (N/A here), main-guard so sourcing
  the CLI doesn't run network calls, error paths exit non-zero.
- **Test quality**: real assertions vs shallow. Are the validator's 3 failure modes, the checksum
  fail-closed paths, the bucket-PUT body, and the DOI-only-supplied-fields all covered?
- **Runbook accuracy**: does `09-deployment.qmd` describe the REAL flags, and never instruct a one-step
  publish? Could an operator following it accidentally publish or leak a token?
- **File size**: any handwritten source (.R) file > 600 lines? (`-package.R` is ~597 — confirm it's under.)

## Output
Findings grouped by **BLOCKER / HIGH / MEDIUM / LOW**, each with file:line + concrete failure scenario
+ fix direction. End with `VERDICT: SHIP` or `VERDICT: NO-SHIP`. If nothing is ship-blocking, say so
plainly — do not manufacture issues.
codex
I’ll review the branch as an adversarial, read-only pass, tracing the operator flow from packaging through Zenodo upload and DOI record-back. I’m using the repository’s security and code-quality review guides to check its established failure modes and handoff standards.
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
/bin/bash -lc "git status --short && git diff --stat origin/master...HEAD -- ':(exclude).planning/**' && git diff --name-only origin/master...HEAD -- ':(exclude).planning/**'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review.md
 .gitignore                                         |   4 +
 AGENTS.md                                          |   1 +
 CHANGELOG.md                                       |  11 +
 Makefile                                           |  30 +-
 .../analysis-snapshot-release-zenodo-docs.R        | 163 ++++++
 .../analysis-snapshot-release-zenodo-package.R     | 597 +++++++++++++++++++++
 .../analysis-snapshot-release-zenodo-upload.R      | 312 +++++++++++
 api/scripts/package-analysis-release-zenodo.R      | 157 ++++++
 api/scripts/upload-analysis-release-zenodo.R       | 212 ++++++++
 .../test-unit-analysis-release-zenodo-package.R    | 450 ++++++++++++++++
 .../test-unit-analysis-release-zenodo-upload.R     | 444 +++++++++++++++
 api/version_spec.json                              |   2 +-
 app/package-lock.json                              |   4 +-
 app/package.json                                   |   2 +-
 documentation/09-deployment.qmd                    |  40 +-
 15 files changed, 2423 insertions(+), 6 deletions(-)
.gitignore
AGENTS.md
CHANGELOG.md
Makefile
api/functions/analysis-snapshot-release-zenodo-docs.R
api/functions/analysis-snapshot-release-zenodo-package.R
api/functions/analysis-snapshot-release-zenodo-upload.R
api/scripts/package-analysis-release-zenodo.R
api/scripts/upload-analysis-release-zenodo.R
api/tests/testthat/test-unit-analysis-release-zenodo-package.R
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R
api/version_spec.json
app/package-lock.json
app/package.json
documentation/09-deployment.qmd

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-zenodo-upload.R | sed -n '1,380p' && nl -ba api/scripts/package-analysis-release-zenodo.R | sed -n '1,240p' && nl -ba api/scripts/upload-analysis-release-zenodo.R | sed -n '1,280p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
exec
/bin/bash -lc "nl -ba Makefile | sed -n '1,260p'; nl -ba documentation/09-deployment.qmd | sed -n '1,280p'; nl -ba api/endpoints/admin_analysis_snapshot_endpoints.R | sed -n '1,260p'; nl -ba api/functions/nddscore-release-source.R | sed -n '1,360p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
   273	    stop("ZENODO_TOKEN not set and --token not provided", call. = FALSE)
   274	  }
   275	  if (!file.exists(archive_path)) {
   276	    stop(sprintf("Archive does not exist: %s", archive_path), call. = FALSE)
   277	  }
   278	  if (!file.exists(metadata_path)) {
   279	    stop(sprintf("Metadata does not exist: %s", metadata_path), call. = FALSE)
   280	  }
   281
   282	  api <- analysis_release_zenodo_resolve_api(sandbox)
   283	  metadata <- jsonlite::fromJSON(metadata_path, simplifyVector = FALSE)
   284
   285	  deposition <- get_or_create_deposition(api, token, deposition_id = deposition_id)
   286	  resolved_deposition_id <- deposition$id
   287	  bucket_url <- deposition$links$bucket
   288	  reserved_doi <- deposition$metadata$prereserve_doi$doi
   289
   290	  set_metadata(api, token, resolved_deposition_id, metadata)
   291	  upload_bucket(bucket_url, token, archive_path)
   292
   293	  result <- list(
   294	    deposition_id = resolved_deposition_id,
   295	    reserved_doi = reserved_doi %||% NA_character_,
   296	    draft_url = deposition$links$html %||% NA_character_,
   297	    published = FALSE,
   298	    version_doi = NA_character_,
   299	    concept_doi = NA_character_,
   300	    record_url = NA_character_
   301	  )
   302
   303	  if (isTRUE(publish)) {
   304	    published_deposition <- publish_deposition(api, token, resolved_deposition_id)
   305	    result$published <- TRUE
   306	    result$version_doi <- published_deposition$doi %||% NA_character_
   307	    result$concept_doi <- published_deposition$conceptdoi %||% NA_character_
   308	    result$record_url <- published_deposition$links$html %||% NA_character_
   309	  }
   310
   311	  result
   312	}
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
    19	#     [--token <ZENODO_TOKEN, defaults to env>] [--sandbox] \
    20	#     [--deposition-id <id>] [--publish --confirm-publish] \
    21	#     [--record-doi --release-id <asr_...>] [--api-base-url <SysNDD API base>]
    22	#
    23	# Publish safety interlock: `--publish` alone is REFUSED -- both `--publish`
    24	# AND `--confirm-publish` must be passed, or the run stops before any HTTP
    25	# call is made (`analysis_release_zenodo_require_publish_confirmation()`).
    26	# Without `--publish`, the archive is uploaded to a Zenodo DRAFT only, for
    27	# manual review before publishing.
    28	#
    29	# DOI record-back is OPT-IN and requires BOTH `--record-doi` AND the
    30	# `SYSNDD_ADMIN_TOKEN` env var (a pre-minted SysNDD Administrator bearer
    31	# token) to be set, plus `--release-id` and a successfully PUBLISHED Zenodo
    32	# DOI. Absent any of those, this script NEVER calls the SysNDD admin PATCH
    33	# endpoint automatically -- it prints the exact manual `curl` command instead
    34	# so the operator can record it by hand.
    35	#
    36	# Requires: httr2, jsonlite (api/renv.lock). No DB, no bootstrap, no
    37	# `external_proxy_budget()` -- see AGENTS.md "Analysis-snapshot releases
    38	# (#573)" and `.superpowers/sdd/slice-c-scout.md`.
    39	#
    40	# CWD note: resolves `api/functions/analysis-snapshot-release-zenodo-
    41	# upload.R` relative to ITS OWN file location (same idiom as
    42	# `package-analysis-release-zenodo.R` / `capture-external-fixtures.R`), so it
    43	# may be invoked from any working directory.
    44
    45	# --------------------------------------------------------------------------- #
    46	# Resolve this script's own directory, then source the upload/record-back
    47	# functions (function definitions only -- no top-level network calls in that
    48	# file, so this is safe to do unconditionally, even when this CLI script is
    49	# itself only `source()`d).
    50	# --------------------------------------------------------------------------- #
    51
    52	.upload_analysis_release_zenodo_script_dir <- function() {
    53	  script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
    54	  if (is.null(script_file) || !nzchar(script_file)) {
    55	    full_args <- commandArgs(trailingOnly = FALSE)
    56	    file_arg <- grep("^--file=", full_args, value = TRUE)
    57	    script_file <- if (length(file_arg) >= 1) sub("^--file=", "", file_arg[1]) else "."
    58	  }
    59	  dirname(normalizePath(script_file, mustWork = FALSE))
    60	}
    61
    62	.upload_analysis_release_zenodo_script_dir_value <- .upload_analysis_release_zenodo_script_dir()
    63	source(
    64	  file.path(
    65	    .upload_analysis_release_zenodo_script_dir_value, "..", "functions",
    66	    "analysis-snapshot-release-zenodo-upload.R"
    67	  ),
    68	  local = FALSE
    69	)
    70
    71	# --------------------------------------------------------------------------- #
    72	# CLI arg parsing -- manual commandArgs() flag loop (repo convention; no
    73	# optparse dependency, see `verify-endpoints.R`).
    74	# --------------------------------------------------------------------------- #
    75
    76	#' Parse + run the upload CLI. Wrapped in a function (rather than bare
    77	#' top-level code) so the file can be `source()`d for its function
    78	#' definitions alone -- see the `sys.nframe() == 0L` main-guard at the
    79	#' bottom of this file, which only calls this when the script is run
    80	#' directly (`Rscript upload-analysis-release-zenodo.R`), never when
    81	#' `source()`d (e.g. by a test).
    82	run_upload_analysis_release_zenodo_cli <- function() {
    83	  args <- commandArgs(trailingOnly = TRUE)
    84
    85	  archive <- NULL
    86	  metadata <- NULL
    87	  token <- Sys.getenv("ZENODO_TOKEN", "")
    88	  sandbox <- FALSE
    89	  deposition_id <- NULL
    90	  publish <- FALSE
    91	  confirm_publish <- FALSE
    92	  record_doi <- FALSE
    93	  release_id <- NULL
    94	  api_base_url <- Sys.getenv("SYSNDD_API_BASE_URL", "http://localhost:7778")
    95
    96	  if (length(args) > 0) {
    97	    for (i in seq_along(args)) {
    98	      if (args[i] == "--archive" && i < length(args)) {
    99	        archive <- args[i + 1]
   100	      } else if (args[i] == "--metadata" && i < length(args)) {
   101	        metadata <- args[i + 1]
   102	      } else if (args[i] == "--token" && i < length(args)) {
   103	        token <- args[i + 1]
   104	      } else if (args[i] == "--sandbox") {
   105	        sandbox <- TRUE
   106	      } else if (args[i] == "--deposition-id" && i < length(args)) {
   107	        deposition_id <- args[i + 1]
   108	      } else if (args[i] == "--publish") {
   109	        publish <- TRUE
   110	      } else if (args[i] == "--confirm-publish") {
   111	        confirm_publish <- TRUE
   112	      } else if (args[i] == "--record-doi") {
   113	        record_doi <- TRUE
   114	      } else if (args[i] == "--release-id" && i < length(args)) {
   115	        release_id <- args[i + 1]
   116	      } else if (args[i] == "--api-base-url" && i < length(args)) {
   117	        api_base_url <- args[i + 1]
   118	      }
   119	    }
   120	  }
   121
   122	  if (is.null(archive) || !nzchar(archive)) {
   123	    stop("--archive is required", call. = FALSE)
   124	  }
   125	  if (is.null(metadata) || !nzchar(metadata)) {
   126	    stop("--metadata is required", call. = FALSE)
   127	  }
   128
   129	  result <- analysis_release_zenodo_upload(
   130	    archive_path = archive,
   131	    metadata_path = metadata,
   132	    token = token,
   133	    sandbox = sandbox,
   134	    deposition_id = deposition_id,
   135	    publish = publish,
   136	    confirm_publish = confirm_publish
   137	  )
   138
   139	  cat(sprintf("Zenodo deposition id: %s\n", result$deposition_id))
   140	  cat(sprintf(
   141	    "Zenodo reserved DOI:  %s\n",
   142	    if (is.na(result$reserved_doi)) "not returned" else result$reserved_doi
   143	  ))
   144	  cat(sprintf(
   145	    "Zenodo draft URL:     %s\n",
   146	    if (is.na(result$draft_url)) "not returned" else result$draft_url
   147	  ))
   148
   149	  if (isTRUE(result$published)) {
   150	    cat(sprintf("Published Zenodo DOI: %s\n", result$version_doi))
   151	    cat(sprintf("Published Zenodo URL: %s\n", result$record_url))
   152	  } else {
   153	    cat("Draft uploaded only. Review in Zenodo before publishing.\n")
   154	  }
   155
   156	  .print_doi_record_back(result, release_id, api_base_url, record_doi)
   157
   158	  invisible(result)
   159	}
   160
   161	#' The opt-in DOI record-back step. Never calls the SysNDD admin endpoint
   162	#' unless the operator explicitly asked for it (`--record-doi`) AND supplied
   163	#' credentials (`SYSNDD_ADMIN_TOKEN`) AND the run reached a real, published
   164	#' DOI -- a draft's "reserved" DOI is not final and is deliberately NOT
   165	#' recorded automatically. Otherwise prints the exact manual command.
   166	.print_doi_record_back <- function(result, release_id, api_base_url, record_doi) {
   167	  doi_fields <- list(
   168	    zenodo_record_id = as.character(result$deposition_id),
   169	    zenodo_record_url = if (isTRUE(result$published)) result$record_url else result$draft_url,
   170	    version_doi = if (isTRUE(result$published)) result$version_doi else NA_character_,
   171	    concept_doi = if (isTRUE(result$published)) result$concept_doi else NA_character_
   172	  )
   173
   174	  have_release_id <- !is.null(release_id) && nzchar(release_id)
   175	  have_published_doi <- isTRUE(result$published) &&
   176	    !is.na(result$version_doi) && nzchar(as.character(result$version_doi))
   177	  admin_token <- Sys.getenv("SYSNDD_ADMIN_TOKEN", "")
   178
   179	  if (!have_release_id) {
   180	    cat("\nNo --release-id supplied -- pass one to record or print a DOI record-back command.\n")
   181	    return(invisible(NULL))
   182	  }
   183
   184	  if (isTRUE(record_doi) && nzchar(admin_token) && have_published_doi) {
   185	    updated <- analysis_release_zenodo_record_doi(
   186	      sysndd_api_base_url = api_base_url,
   187	      admin_token = admin_token,
   188	      release_id = release_id,
   189	      doi_fields = doi_fields
   190	    )
   191	    cat("\nDOI recorded on the SysNDD release head:\n")
   192	    cat(sprintf("  release_id:        %s\n", updated$release_id %||% release_id))
   193	    cat(sprintf("  version_doi:       %s\n", updated$version_doi %||% doi_fields$version_doi))
   194	    cat(sprintf("  zenodo_record_url: %s\n", updated$zenodo_record_url %||% doi_fields$zenodo_record_url))
   195	  } else {
   196	    cat(
   197	      "\nDOI not recorded automatically",
   198	      if (!have_published_doi) " (deposition not published yet)" else "",
   199	      ". Run with --record-doi and SYSNDD_ADMIN_TOKEN set after publishing, ",
   200	      "or record it by hand:\n",
   201	      sep = ""
   202	    )
   203	    cat(analysis_release_zenodo_manual_doi_command(api_base_url, release_id, doi_fields), "\n")
   204	  }
   205	  invisible(NULL)
   206	}
   207
   208	# Main guard: `sys.nframe()` is 0 only at the true top level of a directly
   209	# `Rscript`-invoked file; a `source()`d file (e.g. from a test) always adds
   210	# at least one frame, so this line never fires under `source()`. This check
   211	# MUST stay at top level (not inside a function).
   212	if (sys.nframe() == 0L) run_upload_analysis_release_zenodo_cli()

 succeeded in 0ms:
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
   221		@printf "\n$(CYAN)[4/5] Linting frontend code...$(RESET)\n"
   222		@$(MAKE) lint-app
   223		@printf "\n$(CYAN)[5/5] Running fast R API tests...$(RESET)\n"
   224		@$(MAKE) test-api-fast
   225		@printf "\n$(GREEN)✓ All pre-commit checks passed!$(RESET)\n"
   226
   227	ci-local: ## [quality] Run CI checks locally (lint + test with DB - mirrors GitHub Actions)
   228		@printf "$(CYAN)==> Running CI checks locally (mirrors GitHub Actions)...$(RESET)\n"
   229		@printf "\n$(CYAN)[1/7] Running CI script harnesses...$(RESET)\n"
   230		@$(MAKE) test-ci-scripts
   231		@printf "\n$(CYAN)[2/7] Starting test database...$(RESET)\n"
   232		@cd $(ROOT_DIR) && $(COMPOSE_DB_DEV) up -d mysql-test && \
   233			printf "$(GREEN)✓ Test database started$(RESET)\n" || \
   234			(printf "$(RED)✗ Failed to start test database$(RESET)\n" && exit 1)
   235		@printf "$(CYAN)Waiting for MySQL to be ready...$(RESET)\n"
   236		@SECONDS=0; \
   237		while [ $$SECONDS -lt 30 ]; do \
   238			if $(COMPOSE_DB_DEV) exec -T mysql-test mysqladmin ping -h localhost -u bernt -pNur7DoofeFliegen. --silent 2>/dev/null; then \
   239				printf "$(GREEN)MySQL ready$(RESET)\n"; \
   240				break; \
   241			fi; \
   242			printf "."; \
   243			sleep 1; \
   244			SECONDS=$$((SECONDS+1)); \
   245		done
   246		@printf "$(CYAN)Resetting test database for CI parity...$(RESET)\n"
   247		@# Reset strategy (issue #360): try root first so we can GRANT to the
   248		@# `bernt` test user, then fall back to the regular MYSQL_USER. In the
   249		@# default local profile the root-over-TCP attempt is EXPECTED to fail
   250		@# (`ERROR 1045 (28000): Access denied for user 'root'@...`) because the
   251		@# dev MySQL container does not grant root over the 127.0.0.1 host; the
   252		@# fallback path is the one that normally succeeds. We capture both
   253		@# attempts and only surface the captured output when the WHOLE reset
   254		@# genuinely fails, so a successful run no longer prints an alarming
   255		@# access-denied error. A real connectivity/permission failure (both
   256		@# attempts down) still prints the diagnostics and still fails the run.
   257		@# NB: `if ! VAR=$$(...)` keeps the capture safe under `set -e` — a failing
   258		@# substitution is consumed by the `if` test instead of aborting the recipe
   259		@# before we can print diagnostics.
   260		@cd $(ROOT_DIR); \
     1	---
     2	title: "Deployment"
     3	---
     4
     5	# Deployment
     6
     7	This page is the concise operator-facing entry point for SysNDD deployment.
     8
     9	## Quick Start
    10
    11	```bash
    12	git clone https://github.com/berntpopp/sysndd.git
    13	cd sysndd
    14	cp .env.example .env
    15	# edit .env
    16	docker compose up -d
    17	```
    18
    19	Legacy archive-downloader deployment scripts are not part of the supported
    20	deployment path; do not use unverified downloaded shell to provision runtime
    21	configuration.
    22
    23	## Key Runtime Settings
    24
    25	### `api/config.yml`
    26
    27	The production API image does not include `api/config.yml`. Provide runtime
    28	configuration through the Compose read-only mount, an operator secret, or an
    29	equivalent deployment-specific config injection mechanism. Never re-add
    30	`COPY config.yml config.yml` to `api/Dockerfile`; local credentials can otherwise
    31	be baked into image layers.
    32
    33	### Backup credential handling (#535 P1-1)
    34
    35	Database backup/restore jobs never carry the DB password in the durable job
    36	payload, in process argv, or in a shell command string:
    37
    38	- `svc_backup_create`/`svc_backup_restore` submit **credential-free** params; the
    39	  durable handlers resolve the credential at run time from the worker's `dw`
    40	  config via `async_job_worker_db_config()`.
    41	- `execute_mysqldump`/`execute_restore` pass the password to the MySQL CLIs
    42	  through a per-invocation **mode-0600 `--defaults-extra-file`** (created
    43	  fail-closed), never `-p<password>` argv or an interpolated `system()` shell
    44	  string.
    45	- Historical terminal backup payloads (and their password-derived
    46	  `request_hash`) are redacted idempotently by
    47	  `async_job_scrub_payload_credentials()`, which runs best-effort at API startup,
    48	  after every restore, and via the operator script.
    49
    50	**Mandatory operator steps after deploying this change** (prior backups, logs,
    51	and payloads may already contain the password, so the code fix alone is not
    52	sufficient):
    53
    54	```bash
    55	# 1. ROTATE the DB password, update the deployed .env / secret, then recreate.
    56	#    Restarting the API automatically runs the idempotent startup scrub, so a
    57	#    normal deploy applies both the rotation and the payload redaction:
    58	docker compose up -d --force-recreate api worker worker-maintenance
    59
    60	# 2. (Optional) Scrub historical backup payloads WITHOUT a restart:
    61	docker exec sysndd-api-1 Rscript /app/scripts/scrub-job-payload-credentials.R
    62	```
    63
    64	Rotation is the primary mitigation for any credential that leaked before this
    65	change — the scrub cannot rewrite old backup files. The scrub also runs after
    66	every restore (an old dump can re-import credential-bearing rows). Its outcome
    67	is logged at WARN in the worker log — the **reliable** signal, since a *full*
    68	restore replaces `async_jobs` and can drop the restore job's own row (so the
    69	`result_json.post_restore_scrub` field is best-effort; this is the restore-
    70	fencing limitation tracked separately as S3). The next API-startup scrub is an
    71	idempotent backstop. Set `ASYNC_JOB_PAYLOAD_SCRUB_ON_STARTUP=false` only to
    72	disable the startup scrub (default on). As of #535 S2b, **all** durable job
    73	families (publication, hgnc/comparisons/omim/force_apply, provider,
    74	pubtator/pubtatornidd, llm) resolve DB credentials at run time via
    75	`async_job_db_connect()` — no payload carries `db_config`. The scrub is
    76	correspondingly job-type agnostic and redacts both `$.db_config.password` and
    77	`$.db_config.db_password` for historical terminal rows.
    78
    79	**Deploy note (S2b payload-schema change):** dropping `db_config` changes the
    80	request-payload hash of `hgnc_update`/`comparisons_update`/`omim_update`/
    81	`force_apply_ontology`. These destructive full-table-replace jobs now dedupe by
    82	**job type** (best-effort submit-time single-flight), which returns a clean 409
    83	for a same-type resubmit even across the deploy. Concurrency safety for
    84	destructive execution does **not** rely on this dedup: the durable **maintenance
    85	lane runs on a single worker** that claims and runs jobs strictly sequentially
    86	(one `worker-maintenance` container), so two destructive jobs never execute
    87	concurrently — even if a rare non-atomic double-submit enqueues two. The scrub
    88	only touches terminal, non-retryable rows, so it never races an active job.
    89
    90	If you ever scale the maintenance lane beyond one worker, add a hard, atomic
    91	**cross-type conflict-group mutex** first (advisory lock over check+insert, or a
    92	generated conflict-key unique index grouping `omim_update`/`force_apply_ontology`
    93	on `disease_ontology_set` and `pubtator_enrichment_refresh`/`pubtatornidd_nightly`
    94	on the enrichment snapshot) — the submit-time single-flight alone is not
    95	sufficient for concurrent workers. Draining in-flight maintenance jobs before
    96	deploying is prudent regardless.
    97
    98	### `MIRAI_WORKERS`
    99
   100	Controls background worker count for long-running jobs.
   101
   102	- small server: `1`
   103	- medium server: `2`
   104	- large server: `4`
   105
   106	Rule of thumb:
   107
   108	```text
   109	Peak memory ~= 500 MB base + workers x 2 GB
   110	```
   111
   112	### `DB_POOL_SIZE`
   113
   114	Controls the database connection pool.
   115
   116	Recommended baseline:
   117
   118	- `MIRAI_WORKERS=1` -> `DB_POOL_SIZE=3-5`
   119	- `MIRAI_WORKERS=2` -> `DB_POOL_SIZE=5-7`
   120	- `MIRAI_WORKERS=4` -> `DB_POOL_SIZE=10-12`
   121
   122	### `CACHE_VERSION`
   123
   124	Increment `CACHE_VERSION` when cached API/worker function behavior or result shape changes and you need invalidation on next startup. The Compose default is `${CACHE_VERSION:-3}` for the `api` and workers that share `api_cache`; MCP has no cache mount or cache fallback. On startup `bootstrap_init_cache_version()` clears every `/app/cache/*.rds` when the stored marker differs. If deployment pins `CACHE_VERSION` explicitly in `.env`, bump it manually when shipping a memoised-shape change.
   125
   126	**Post-deploy operator step for a clustering-algorithm change** (e.g. the correctness fix above): after the redeploy clears the cluster cache, refresh the derived-analysis snapshots so the public/MCP surfaces carry the new partitions + validation. Trigger `POST /api/admin/analysis/snapshots/refresh` (optionally `{ "force": true }`), watch `GET /api/admin/analysis/snapshots/status` until each preset reports `available`, then regenerate any affected LLM cluster summaries and run `make test-mcp-smoke`. Until the refresh completes, the previous public-ready snapshot keeps serving.
   127
   128	**Post-deploy operator step for an LLM-summary version bump** (#485): the cluster-summary cache is keyed on `cluster_hash` **plus** `LLM_SUMMARY_PROMPT_VERSION` (`api/functions/llm-summary-config.R`). Bumping that constant — required whenever the summary/judge prompt or generation logic changes so unchanged-membership clusters are not served a pre-deploy summary — makes every previously-cached summary a lookup miss: the public `*_cluster_summary` endpoints return "not yet available" and the analysis pages simply hide the AI-summary card (the tables, network, and validation card render normally). Regeneration does **not** auto-trigger from the bump alone, because a version change does not alter snapshot currency, so the startup bootstrap re-enqueues nothing. To repopulate after such a deploy, either force a snapshot refresh (`POST /api/admin/analysis/snapshots/refresh {"force": true}` — the refresh chain regenerates summaries at the new version) or drive the Administrator regenerate per cluster type (`POST /api/llm/regenerate?force=true`). Until then the pages are fully usable, just without AI summaries.
   129
   130	### Cluster caches self-invalidate on a methodology change (#514)
   131
   132	The clustering disk cache (`gen_string_clust_obj_mem`, `gen_network_edges_mem`, `gen_mca_clust_obj_mem`) is **self-invalidating** and no longer depends on a human remembering to bump `CACHE_VERSION`. Each clustering function folds a **fingerprint** into its memoise key (`api/functions/analysis-cache-fingerprint.R`): `CLUSTER_LOGIC_VERSION` (a code constant) plus the STRING channel + exp+db edge-file identity (`size:mtime`) for the functional axis and the MCA prevalence band for the phenotype axis. Because the fingerprint is evaluated at **call time**, adding or rebuilding the exp+db artifact self-invalidates the affected entries **without a container restart**, and a code change is handled by bumping `CLUSTER_LOGIC_VERSION`. This closes the failure mode in #514, where a methodology deploy (the #510 text-mining-free graph) served a **stale** partition out of the disk cache while the validator recomputed fresh, producing an internally-incoherent snapshot. A second line of defense, the **snapshot integrity gate** (`ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE`, default `true`), refuses to publish a snapshot whose served membership and validation describe different partitions — the refresh fails, the prior public-ready snapshot keeps serving, and the failed job is visible in history.
   133
   134	**The #510 exp+db artifact is a deploy prerequisite for text-mining-free functional clustering.** `data/9606.protein.links.expdb.v11.5.min400.txt.gz` is a gitignored runtime artifact. If it is absent, functional clustering silently falls back to the text-mining `combined_score` graph — now surfaced as an operator-visible `warning()` and via `GET /api/health` → `analysis.expdb_edges_file_present: false` (also reports `analysis.cluster_logic_version` and `analysis.functional_weight_channels`). Build it once per STRING release inside the API container:
   135
   136	```bash
   137	# one-time data-prep; the ~115 MB detailed links download must be in api/data/ first
   138	docker exec sysndd-api-1 Rscript /app/scripts/build-string-expdb.R
   139	```
   140
   141	The `api`, `worker`, and `worker-maintenance` services bind-mount `./api/data`. MCP does not mount data or cache directories; it reads only dedicated database projections.
   142
   143	**Methodology-deploy runbook (analysis-logic change):**
   144
   145	1. Ensure the exp+db artifact exists (`GET /api/health` → `analysis.expdb_edges_file_present: true`), building it as above if needed.
   146	2. If the clustering algorithm/inputs changed in code, bump `CLUSTER_LOGIC_VERSION` in `api/functions/analysis-cache-fingerprint.R`.
   147	3. Restart the `worker` (and `worker-maintenance`) containers so the durable snapshot-refresh code is re-sourced.
   148	4. Force-refresh both clustering presets: `POST /api/admin/analysis/snapshots/refresh?analysis_type=functional_clusters&force=true` and `…phenotype_clusters&force=true`; watch `GET /api/admin/analysis/snapshots/status` until each reports `available`.
   149	5. Verify coherence: `GET /api/analysis/functional_clustering` shows agreeing membership + metrics, `meta.snapshot.validation.weight_channel == "experimental_database"`, and `membership_weight_channel` matches it. Regenerate LLM summaries only if the cluster hashes changed (`POST /api/llm/regenerate?...&force=true`).
   150
   151	**Analysis-snapshot RELEASE coherence attestation (#573 H4):** the snapshot builder additively persists the validator's reference member sets (in the stored `cluster_member` id space — `hgnc_id` for functional, `entity_id` for phenotype) into `validation_json` so an immutable public release can *independently* re-prove full member-set coherence before freezing a snapshot. This builder code is **worker-executed**, so it only takes effect after a `worker`/`worker-maintenance` restart **and** a snapshot rebuild (a force-refresh of both clustering presets, per steps 3–4 above). Until a snapshot carries the attestation, a release build **gracefully degrades** to the channel + stability coherence check and emits a `warning()` that full member-set verification is unavailable for that snapshot — it does **not** hard-reject legacy snapshots. After the first post-#573 rebuild, releases enforce the full member-set proof and refuse (`release_source_incoherent` → 400) any snapshot whose served membership differs in member content from the validated reference.
   152
   153	External genomic proxy caches live under `/app/cache/external/{static,stable,dynamic}` by default and can be relocated with `EXTERNAL_PROXY_CACHE_DIR`. The proxy layer caches successful and true not-found responses, but transient upstream errors (`error = TRUE`, mapped to 503) are evicted immediately so a timeout does not poison the cache for the full 7/14/30-day source TTL.
   154
   155	External provider request budgets default to short fail-fast values: `EXTERNAL_PROXY_TIMEOUT_SECONDS=6`, `EXTERNAL_PROXY_MAX_SECONDS=10`, `EXTERNAL_PROXY_MAX_TRIES=2`, and `EXTERNAL_PROXY_AGGREGATE_MAX_SECONDS=12`. Override per source with names such as `EXTERNAL_PROXY_MGI_TIMEOUT_SECONDS`, `EXTERNAL_PROXY_MGI_MAX_SECONDS`, and `EXTERNAL_PROXY_MGI_MAX_TRIES`. The same per-source pattern covers the two-step and batch providers: `EXTERNAL_PROXY_UNIPROT_*` (its features fetch now uses the budget instead of a 30–120s window), `EXTERNAL_PROXY_GENEREVIEWS_*` (NCBI E-utilities), and `EXTERNAL_PROXY_GNOMAD_BATCH_*` (worker-only batch path, higher defaults of 20s timeout / 30s window / 3 tries). The aggregate external gene route remains serial and returns `partial = TRUE` with `skipped_sources` when the aggregate budget is exhausted.
   156
   157	Beyond the per-source and aggregate budgets, a **per-request external-time ceiling** caps the *total* time any single request may spend in external calls: `EXTERNAL_PROXY_REQUEST_MAX_SECONDS` (default 15s). Once a request crosses it, subsequent external fetches short-circuit to a degraded `503` (`request_budget_exceeded = TRUE`) without contacting the upstream, so even a request that touches several providers cannot occupy a worker indefinitely. This is independent of the 12s aggregate budget, which only governs the multi-source `/api/external/gene/<symbol>` route. Per-request timing is logged by the `postroute` hook as `[request-timing] method=<m> path=<p> status=<http> duration_ms=<n> external_ms=<n> slow=<bool>` (to the API log file); `external_ms` is the wall time that request spent in external providers (0 for cheap routes), and `slow=true` flags requests over `API_SLOW_REQUEST_MS` (default 2000). Use `external_ms` to confirm whether a slow request was slow because of an upstream provider.
   158
   159	Each external provider emits a structured timing line on stderr of the form `[external-proxy] source=<provider> event=complete status=<http> elapsed_ms=<n> cache=<hit|miss>` (transient failures additionally log `event=error_not_cached`). `gnomad`, `ensembl`, `uniprot`, and `alphafold` log this at the memoise chokepoint, while `mgi` and `rgd` log it from their inline timing wrapper. Use `elapsed_ms` to spot upstream slowdowns, `cache=hit`/`cache=miss` to confirm the disk caches are serving traffic, and `status` to track 404/503 rates per source. The log is cheap (one cache-key probe plus two clock reads) and adds no latency on the hot path. This per-request fast-fail plus observability bounds how long any single external request can occupy an API worker; true cross-request isolation between heavy and light routes (separate worker pools / queue) is tracked in issue #154. Until then, run the API with more than one replica and non-sticky routing so a worker held by a slow request does not stall cheap routes such as `/api/health/`, auth, and stats.
   160	The curator GeneReviews coverage feature (`/api/genereviews`, Curator+) resolves GeneReviews availability through NCBI E-utilities and caches it in the same success-only external cache (30-day static TTL). The API container therefore needs outbound egress to `eutils.ncbi.nlm.nih.gov` when curators run the live availability pass or attach a GeneReviews reference. NCBI credentials are optional: set `NCBI_API_KEY` and `NCBI_EUTILS_EMAIL` to raise NCBI rate limits; anonymous low-volume use works without them. The cheap (already-linked) coverage view and CSV export make no external calls.
   161
   162	### Public analysis snapshots
   163
   164	The `log-cleanup` Compose service prunes old rows from the operational request log table (`logging`) on a daily schedule so the table does not grow unbounded. It reuses the API image (so it shares the `renv` dependencies, `RMariaDB`, and the existing connection-pool/config helpers) and connects over the internal `backend` network only — it needs the database but no outbound egress. The service runs a small no-root scheduler loop that invokes `api/scripts/delete_old_jobs.R` (the fully-bounded `async_jobs` prune, run first) and then `api/scripts/delete_old_logs.R` once per day; the scripts delegate to the unit-tested helpers in `api/functions/async-job-retention.R` and `api/functions/log-cleanup.R`.
   165
   166	Configuration (environment variables, with defaults):
   167
   168	- `LOG_RETENTION_DAYS=30` — delete `logging` rows whose `timestamp` is older than this many days. Validated to a positive integer before it reaches SQL.
   169	- `ASYNC_JOB_RETENTION_DAYS=90` — delete **terminal, non-retryable** `async_jobs` rows (`status IN ('completed','failed','cancelled')` and `active_request_hash IS NULL`) older than this many days (by both `submitted_at` and `updated_at`, passed as **bound** parameters — never interpolated). Each batch reads up to N candidate PKs oldest-first with a non-locking snapshot query, then deletes them by primary key while re-checking the full predicate (so a single big scan never locks non-target rows, and a row that became active or was touched between read and delete is left alone). Capped per run by both a batch count (up to 1M rows) and a soft between-batch wall-clock budget (10 min; a single in-flight statement is bounded instead by the per-batch lock-wait timeout); any remainder is pruned on the next run. `async_job_events` cascades. `ASYNC_JOB_RETENTION_DRY_RUN=1` counts only — an **unrecognized** value fails safe to dry-run (no deletion) rather than deleting.
   170	- `ASYNC_JOB_RETENTION_BATCH_SIZE=1000` — candidate PKs read and deleted per batch. A smaller value proportionally shrinks each statement and the `async_job_events` FK cascade; lower it for job families that emit unusually many lifecycle events.
   171	- `ASYNC_JOB_RETENTION_LOCK_WAIT_SECONDS=10` — bounds each batch statement's InnoDB row-lock and metadata-lock waits (`innodb_lock_wait_timeout` + `lock_wait_timeout`) so a batch blocked by a worker fails fast instead of exceeding the run ceiling.
   172	- `LOG_CLEANUP_AT=04:00` — daily run time, `HH:MM` in container (UTC) time (validated strictly; an invalid value refuses to start rather than tight-looping the destructive scripts). The default is staggered off the 03:00 `mysql-cron-backup` dump so a first-run backlog does not add delete/undo I/O pressure during the backup; keep it clear of your backup window if you change either.
   173	- `LOG_CLEANUP_DRY_RUN=false` — when truthy (`1`/`true`/`yes`/`on`), count and log the candidate rows but delete nothing. Use this to verify scope before enabling deletion.
   174
   175	The high-volume `logging` table and the terminal `async_jobs` history are pruned (the latter cascades to `async_job_events`). `llm_generation_log` is intentionally left alone (lower volume; it warrants its own explicit retention policy since it holds prompts/responses). The script exits non-zero on failure and the scheduler logs and continues to the next cycle rather than crash-looping.
   176
   177	### PubtatorNDD nightly refresh (`pubtatornidd-cron`)
   178
   179	The `pubtatornidd-cron` Compose service keeps the PubtatorNDD analysis current automatically. It is a *dumb scheduler*: once per night it enqueues a single durable `pubtatornidd_nightly` async job (via `api/scripts/pubtatornidd_nightly_enqueue.R`) and exits the run. The existing `worker` service — which already has the PubTator/PubMed egress — claims and runs the actual refresh (orchestrator in `api/functions/pubtatornidd-nightly.R`), so all retries, single-flight locking, and history live there. Like `log-cleanup` it reuses the API image and connects over the internal `backend` network only (it needs the database to enqueue, not egress).
   180
   181	Each run, the worker-side orchestrator: single-flights via a non-blocking MySQL advisory lock (`GET_LOCK('pubtatornidd_nightly', 0)`) so overlapping runs skip cleanly; resolves the standing query (job payload → `PUBTATORNDD_NIGHTLY_QUERY` → most-recent cached query); incrementally fetches new publications (soft page-watermark, ≤3 req/s); refreshes the per-gene enrichment snapshot; and refreshes the precomputed gene-summary table when present. The structured run summary is persisted in the job `result_json` for observability; a failed refresh step marks the job failed.
   182
   183	Configuration (environment variables, with defaults):
   184
   185	- `PUBTATORNDD_NIGHTLY_AT=02:30` — daily enqueue time, `HH:MM` in container (UTC) time.
   186	- `PUBTATORNDD_NIGHTLY_QUERY=` — optional PubTator query override for the standing corpus. When empty, the worker refreshes the most-recently-cached query in `pubtator_query_cache`.
   187	- `PUBTATORNDD_NIGHTLY_MAX_PAGES=` — optional page cap for the incremental fetch (defaults to 50 inside the worker).
   188
   189	The worker resets the per-request external-time accumulator at the start of every job, and the enrichment batch additionally resets it per external call, so the per-request external ceiling (`EXTERNAL_PROXY_REQUEST_MAX_SECONDS`) — intended for public request paths — does not short-circuit this legitimately external-heavy nightly batch.
   190
   191	### Curation-comparison source refresh
   192
   193	The cross-database comparator (`/CurationComparisons`) is refreshed by the Administrator via `POST /api/jobs/comparisons_update/submit` (or the admin *Manage Annotations → Comparisons* card). Source URLs live in the `comparisons_config` table and are patched by migrations, so a redeploy that applies migrations picks up URL fixes automatically. Recent operator-relevant changes:
   194
   195	- **geisinger_DBD** was repointed from the retired `dbd.geisingeradmi.org` CSV (404) to NDD GeneHub (`https://nddgenehub.org/files/Full-Data.csv`) by migration `038`, then the source was renamed `geisinger_DBD` → `ndd_genehub` (migration `040`) so it reads **NDD GeneHub** everywhere (API `list` value, exports, and page columns). This was the single broken source that had been blocking every comparison refresh. Each gene's `category` is now the NDD GeneHub evidence tier (`AR` / `Tier 1`–`Tier 4` / `Missense`, else `Unclassified`), read from the sibling `Full-LoF-Table-Data.csv` / `Full-Missense-Table-Data.csv` tables.
   196	- The refresh is now **resilient**: a source that fails to download or parse no longer aborts the whole job. Failed sources keep their previously-imported rows (per-list replace) and are named in `comparisons_metadata.last_refresh_error`; the run reports status `partial` (some failed) or `success` (all OK). A refresh only fails outright when *every* source fails. The `GET /api/comparisons/metadata` badge on the page shows the status.
   197	- OMIM (`omim_ndd`) needs `OMIM_DOWNLOAD_KEY` (and outbound egress) in the environment that runs the refresh; without it that one source is skipped (`partial`) rather than aborting.
   198	- The OMIM-NDD NDD seed term is configurable via `OMIM_NDD_SEED_TERM` (default `HP:0012759`, "Neurodevelopmental abnormality"); it does not change the published default set.
   199	- The refresh runs as a **durable async job on the worker** (not the API's mirai pool), so **restart the `worker` container** — not the API — after deploying comparisons code changes before triggering a refresh (worker-executed code is sourced at worker startup). The write-path functions are loaded via `api/bootstrap/load_modules.R`, shared by the API and the worker.
   200	- On a database restored via `dbWriteTable`-style tooling, the `ndd_database_comparison` table can drift (narrow text columns, `comparison_id` recreated as `DOUBLE` without AUTO_INCREMENT, dropped `granularity`) and break the refresh; migration `039` idempotently re-asserts the intended schema at startup, so a normally-migrated deploy is unaffected.
   201	- The page's source-provenance popover is populated live from `GET /api/comparisons/sources` (source list, download URLs, and last-update date, from `comparisons_config` + `comparisons_metadata`), so it always reflects the deployed config instead of hardcoded text.
   202	- HPO term lookups (data-prep + outlinks) moved to the JAX ontology API (`https://ontology.jax.org/api/hp/terms`) and the rebuilt HPO site's `https://hpo.jax.org/browse/term/{id}` outlinks after the legacy `hpo.jax.org` term API / `/app/browse/` routes were retired.
   203
   204	### Database version (`DB_VERSION` / `DB_COMMIT`)
   205	The human-facing database version (issue #22) is tracked in the single-row `db_version` table (migration `028_add_db_version.sql`), separate from the migration runner's `schema_version` apply ledger and from `about_content.version`. The migration seeds a baseline semantic version, and the API exposes it in the `database` block of the public `GET /api/version` response (semantic `version`, last `db/`-folder git `commit`, optional `description`/`updated_at`, and an `available` flag). The App surfaces it on the About page. The endpoint degrades gracefully: if the DB or table is unreachable it reports `version`/`commit` as `"unknown"` and `available: false` instead of failing.
   206
   207	To stamp the deployed values at release time, set `DB_VERSION` (semantic `major.minor.patch`) and/or `DB_COMMIT` (last `db/`-folder git short hash) in the API container environment. The running container has no git checkout, so capture them on a host that has the repo:
   208
   209	```sh
   210	# Prints DB_VERSION=<semver> and DB_COMMIT=<short-hash> for the current checkout.
   211	./db/scripts/update-db-version.sh            # version from the seeded migration
   212	./db/scripts/update-db-version.sh 1.1.0      # pin a specific semantic version
   213	./db/scripts/update-db-version.sh 1.1.0 >> .env   # inject, then redeploy
   214	```
   215
   216	`docker-compose.yml` passes `DB_VERSION` and `DB_COMMIT` through to the `api` service. On startup, after migrations, `db_version_sync_from_env()` updates the `db_version` row (id = 1) when either variable is set; it is a non-fatal no-op otherwise. Bump the seeded version (in a new `NNN_*.sql` migration) when the DB schema or core seed data changes meaningfully.
   217
   218	### Public analysis snapshots
   219	Public analysis endpoints and MCP analysis tools read public-ready rows from `analysis_snapshot_manifest` and normalized snapshot payload tables. They do not compute STRING networks, phenotype clusters, correlations, fCoSE layouts, external provider calls, or Gemini summaries on request-path miss.
   220
   221	After curated public data changes, submit `analysis_snapshot_refresh` durable jobs for the supported presets and let the worker build and activate snapshots. Activation is scoped to one public-ready row per `(analysis_type, parameter_hash)`, so refreshing one preset does not replace another preset. Refresh jobs must use approved-public inputs only.
   222
   223	A fresh deploy bootstraps the snapshots automatically (#420): after migrations, `start_sysndd_api.R` runs `analysis_snapshot_bootstrap_on_startup()`, which enqueues a refresh job for any supported preset that has no active public-ready snapshot. It is idempotent (a restart with snapshots already present enqueues nothing), dedup-safe, never crashes boot, and is gated by `ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP` (default `true`; set to `false` to disable). The worker must be running to consume the jobs.
   224
   225	To reduce first-start contention on a small host (#447), the startup bootstrap **staggers heavy builds**: the heavy `functional_clusters` build is enqueued with a `scheduled_at` offset (`ANALYSIS_SNAPSHOT_BOOTSTRAP_STAGGER_SECONDS`, default `120`; set `0` to disable) so it is not claim-eligible at the same instant as the cheap presets, and the PubtatorNDD startup bootstrap is offset separately (`PUBTATORNIDD_BOOTSTRAP_STAGGER_SECONDS`, default `240`) so it does not co-launch with the snapshot bootstrap. Only the automatic startup path staggers — the admin `force` refresh and the operator script submit immediately, so a manual rebuild is never delayed. These knobs only affect scheduling; they require no DB schema change and no extra worker.
   226
   227	There are three ways to (re)build snapshots, all sharing one submit function:
   228
   229	- **Automatic** — the startup bootstrap above.
   230	- **Admin HTTP (no SSH/docker needed)** — `POST /api/admin/analysis/snapshots/refresh` (Administrator token) submits the jobs and returns the job ids; pass `{"force": true}` to rebuild even when a current snapshot exists, or `{"analysis_type": "gene_network_edges"}` to target one preset. `GET /api/admin/analysis/snapshots/status` reports per-preset state (missing / available / stale / source_version_mismatch) with timestamps and row counts so an operator can watch a rebuild progress. Example:
   231
   232	  ```bash
   233	  curl -X POST https://<host>/api/admin/analysis/snapshots/refresh \
   234	    -H "Authorization: Bearer <admin-token>" -H "Content-Type: application/json" -d '{}'
   235	  curl https://<host>/api/admin/analysis/snapshots/status -H "Authorization: Bearer <admin-token>"
   236	  ```
   237
   238	- **Operator script (SSH fallback)** — `make refresh-analysis-snapshots` (or `docker exec sysndd-api-1 Rscript /app/scripts/refresh-analysis-snapshots.R`) forces a rebuild of all presets.
   239
   240	While a snapshot is still building, the public GeneNetworks and PhenotypeClusters pages show a friendly "analysis is being prepared" panel (with a retry) instead of a raw error.
   241
   242	Snapshot status meanings:
   243
   244	- `unsupported_parameter`: the requested parameters are not in the fixed public preset matrix; change the request or predefine and refresh a new preset in code.
   245	- `snapshot_missing`: the preset is supported, but no public-ready snapshot is active yet; run the refresh job.
   246	- `snapshot_stale`: an active snapshot exists but is past `stale_after`; public REST reports stale while MCP collapses it to `snapshot_missing` until refresh.
   247	- `source_version_mismatch`: the stored source version no longer matches current public data; public REST reports the mismatch while MCP collapses it to `snapshot_missing`.
   248
   249	Available snapshot responses carry a `meta.snapshot` provenance block sourced from the public-ready manifest row: `snapshot_id`, `analysis_type`, `parameter_hash`, `schema_version`, `data_class`, `generated_at`, `stale_after`, `source_data_version`, `input_hash`, `payload_hash`, and `record_counts`. `input_hash` binds the snapshot to its supported parameter set plus the public source-data version; `payload_hash` binds it to the materialized result; `record_counts` reports the stored payload row counts (it excludes generated network metadata). These fields let operators and downstream clients audit lineage and completeness without a second query.
   250
   251	### Analysis-snapshot releases (#573)
   252
   253	Analysis-snapshot **releases** are immutable, content-addressed, independently-verifiable exports of the public-ready snapshots above (functional clusters, phenotype clusters, and the phenotype-functional correlation). A release freezes its own copies of every layer's payload plus (for the two cluster layers) the raw reproducibility bundle, a generated README, `manifest.json`, `checksums.sha256`, and a pre-built `bundle.tar.gz` — so it stays byte-identical across later snapshot refreshes and pruning. Migration `045_add_analysis_snapshot_release.sql` adds the three backing tables.
   254
   255	> **PRODUCTION PREREQUISITE — #572 lineage runbook.** Do this once, **before building the first production release**, and do it before any subsequent release build after a cluster-axis methodology change. A release built from a phenotype-functional correlation snapshot that predates PR #571 would lack the dependency lineage (`snapshot_id`/`payload_hash` for both cluster axes) the release format requires as a manifest anchor.
   256	>
   257	> 1. Deploy current `master`; restart `api`, `worker`, and `worker-maintenance` (worker-executed code is sourced at startup).
   258	> 2. As Administrator, force-refresh the correlation preset:
   259	>    ```bash
   260	>    curl -sS -X POST https://<host>/api/admin/analysis/snapshots/refresh \
   261	>      -H "Authorization: Bearer <admin-token>" -H "Content-Type: application/json" \
   262	>      -d '{"analysis_type": "phenotype_functional_correlations", "force": true}'
   263	>    ```
   264	> 3. Verify the resulting snapshot carries dependency lineage for **both** cluster axes:
   265	>    ```bash
   266	>    curl -sS https://<host>/api/analysis/phenotype_functional_cluster_correlation \
   267	>      | jq '.meta.snapshot.dependencies'
   268	>    ```
   269	>    Both `functional_clusters` and `phenotype_clusters` entries must report a `snapshot_id` and a `payload_hash`.
   270	> 4. Verify the gate fails closed: force-refresh only one cluster axis (e.g. `analysis_type=functional_clusters&force=true`) and confirm the correlation read now returns `503` `dependency_snapshot_mismatch` until the correlation preset is rebuilt against the new axis.
   271	> 5. Notify downstream analysis-release stakeholders that the verified live snapshot is ready to build a release from.
   272	> 6. **Gate:** do not run `POST /api/admin/analysis/releases` for the first production release until steps 2–4 pass. No new code ships with this step — PR #571 (dependency lineage) is already on `master`; this is purely an operational verification.
   273
   274	**Build a release** (Administrator; synchronous, DB-only — the worker does not need to be involved, only the currently active public-ready snapshots):
   275
   276	```bash
   277	curl -sS -X POST https://<host>/api/admin/analysis/releases \
   278	  -H "Authorization: Bearer <admin-token>" -H "Content-Type: application/json" \
   279	  -d '{"title": "SysNDD analysis-snapshot release 2026.07", "publish": true}'
   280	```
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
     1	# api/functions/nddscore-release-source.R
     2	#
     3	# NDDScore release acquisition - pure, unit-testable functions.
     4	# Fetch / download / verify / extract / parse a Zenodo release, plus
     5	# schema validation of the extracted content. No DB writes here; no
     6	# secrets are logged. See db/migrations/023 for the target schema.
     7	#
     8	# Extracted from nddscore-import.R (#346) to keep both files under the
     9	# repository's 600-line soft ceiling. nddscore-import.R keeps the
    10	# advisory lock, DB upserts/inserts/counts/activation/failure helpers,
    11	# and the `nddscore_run_import()` orchestrator, which calls back into
    12	# the functions defined here (fetch/download/verify/extract/parse/
    13	# load/validate) via its default `deps` list.
    14
    15	`%||%` <- function(a, b) {
    16	  if (is.null(a) || length(a) == 0) {
    17	    b
    18	  } else {
    19	    a
    20	  }
    21	}
    22
    23	.NDDSCORE_DEFAULT_ZENODO_API_BASE_URL <- "https://zenodo.org/api/records"
    24	.NDDSCORE_DEFAULT_ZENODO_RECORD_ID <- "20258027"
    25
    26	.nddscore_config <- function(config = NULL) {
    27	  if (!is.null(config)) {
    28	    return(config)
    29	  }
    30
    31	  tryCatch(
    32	    {
    33	      config_name <- Sys.getenv("API_CONFIG", "")
    34	      if (nzchar(config_name)) {
    35	        return(config::get(config_name))
    36	      }
    37	      config::get()
    38	    },
    39	    error = function(e) {
    40	      list()
    41	    }
    42	  )
    43	}
    44
    45	.nddscore_config_scalar <- function(config, name, default) {
    46	  value <- config[[name]]
    47	  if (is.null(value) || length(value) == 0L) {
    48	    return(default)
    49	  }
    50
    51	  value <- trimws(as.character(value[[1]]))
    52	  if (!nzchar(value)) {
    53	    return(default)
    54	  }
    55	  value
    56	}
    57
    58	nddscore_zenodo_api_base_url <- function(config = NULL) {
    59	  env_value <- trimws(Sys.getenv("NDDSCORE_ZENODO_API_BASE_URL", ""))
    60	  if (nzchar(env_value)) {
    61	    return(sub("/+$", "", env_value))
    62	  }
    63
    64	  config_value <- .nddscore_config_scalar(
    65	    .nddscore_config(config),
    66	    "nddscore_zenodo_api_base_url",
    67	    .NDDSCORE_DEFAULT_ZENODO_API_BASE_URL
    68	  )
    69	  sub("/+$", "", config_value)
    70	}
    71
    72	nddscore_default_zenodo_record_id <- function(config = NULL) {
    73	  env_value <- trimws(Sys.getenv("NDDSCORE_ZENODO_RECORD_ID", ""))
    74	  if (nzchar(env_value)) {
    75	    return(env_value)
    76	  }
    77
    78	  .nddscore_config_scalar(
    79	    .nddscore_config(config),
    80	    "nddscore_zenodo_record_id",
    81	    .NDDSCORE_DEFAULT_ZENODO_RECORD_ID
    82	  )
    83	}
    84
    85	#' Default HTTP JSON GET used by nddscore_fetch_zenodo_metadata.
    86	#' Separated out so tests inject a stub instead.
    87	.nddscore_http_get_json <- function(url) {
    88	  resp <- httr2::request(url) |>
    89	    httr2::req_retry(
    90	      max_tries = 4,
    91	      is_transient = ~ httr2::resp_status(.x) %in% c(429, 503, 504)
    92	    ) |>
    93	    httr2::req_timeout(30) |>
    94	    httr2::req_perform()
    95	  httr2::resp_body_json(resp, simplifyVector = FALSE)
    96	}
    97
    98	#' Fetch Zenodo record metadata and locate the release archive file entry.
    99	#'
   100	#' @param record_id Zenodo numeric record id (string or numeric).
   101	#' @param api_base_url Base URL for Zenodo record API requests.
   102	#' @param http_get Function(url) returning the parsed record JSON as a list.
   103	#' @return Named list: record_id, record_url, version, version_doi, concept_doi,
   104	#'   archive_name, archive_bytes, archive_md5, content_url.
   105	nddscore_fetch_zenodo_metadata <- function(
   106	    record_id = nddscore_default_zenodo_record_id(),
   107	    api_base_url = nddscore_zenodo_api_base_url(),
   108	    http_get = .nddscore_http_get_json) {
   109	  record_id <- as.character(record_id)[[1]]
   110	  api_base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
   111	  url <- paste0(api_base_url, "/", record_id)
   112	  record <- http_get(url)
   113
   114	  files <- record$files
   115	  if (is.null(files) || length(files) == 0) {
   116	    stop(
   117	      "Zenodo record has no files; cannot locate NDDScore archive",
   118	      call. = FALSE
   119	    )
   120	  }
   121
   122	  is_archive <- vapply(files, function(f) {
   123	    grepl("\\.tar\\.gz$", f$key %||% "", ignore.case = TRUE)
   124	  }, logical(1))
   125	  if (!any(is_archive)) {
   126	    stop("Zenodo record contains no .tar.gz archive file entry", call. = FALSE)
   127	  }
   128	  entry <- files[is_archive][[1]]
   129
   130	  checksum <- entry$checksum %||% ""
   131	  archive_md5 <- sub("^md5:", "", checksum)
   132
   133	  list(
   134	    record_id = record_id,
   135	    record_url = record$links$self_html %||%
   136	      paste0("https://zenodo.org/records/", record_id),
   137	    version = record$metadata$version %||% NA_character_,
   138	    version_doi = record$doi %||% NA_character_,
   139	    concept_doi = record$conceptdoi %||% NA_character_,
   140	    archive_name = entry$key,
   141	    archive_bytes = as.numeric(entry$size %||% NA),
   142	    archive_md5 = archive_md5,
   143	    content_url = entry$links$self
   144	  )
   145	}
   146
   147	#' Verify a downloaded archive against the Zenodo-published MD5.
   148	#' @return TRUE on match; stops with a clear error on mismatch.
   149	nddscore_verify_archive_checksum <- function(path, expected_md5) {
   150	  if (!file.exists(path)) {
   151	    stop("NDDScore archive not found for checksum verification", call. = FALSE)
   152	  }
   153	  actual <- digest::digest(file = path, algo = "md5")
   154	  expected <- tolower(sub("^md5:", "", expected_md5 %||% ""))
   155	  if (!identical(tolower(actual), expected)) {
   156	    stop(sprintf(
   157	      "NDDScore archive checksum mismatch (expected %s, got %s)",
   158	      expected, actual
   159	    ), call. = FALSE)
   160	  }
   161	  TRUE
   162	}
   163
   164	#' Default binary downloader; tests inject a stub.
   165	.nddscore_http_download <- function(url, destfile) {
   166	  resp <- httr2::request(url) |>
   167	    httr2::req_retry(max_tries = 4) |>
   168	    httr2::req_timeout(300) |>
   169	    httr2::req_perform(path = destfile)
   170	  invisible(destfile)
   171	}
   172
   173	#' Download the release archive to a destination path.
   174	#' @return The destination path.
   175	nddscore_download_archive <- function(
   176	    url,
   177	    dest,
   178	    http_download = .nddscore_http_download) {
   179	  if (is.null(url) || !nzchar(url)) {
   180	    stop("NDDScore archive download URL is missing", call. = FALSE)
   181	  }
   182	  http_download(url, dest)
   183	  if (!file.exists(dest) || file.size(dest) == 0) {
   184	    stop("NDDScore archive download produced an empty file", call. = FALSE)
   185	  }
   186	  dest
   187	}
   188
   189	#' Extract the release archive and verify the bundled inner checksums.sha256.
   190	#'
   191	#' @param archive_path Path to the .tar.gz.
   192	#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
   193	#' @return Path to the `sysndd_prediction_release` directory inside the extraction.
   194	nddscore_extract_and_verify <- function(archive_path, exdir = NULL) {
   195	  if (is.null(exdir)) {
   196	    exdir <- file.path(tempdir(), paste0("ndd_extract_", as.integer(runif(1, 1, 1e9))))
   197	  }
   198	  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
   199	  utils::untar(archive_path, exdir = exdir)
   200
   201	  rel_candidates <- list.files(exdir, pattern = "^sysndd_prediction_release$",
   202	                               recursive = TRUE, include.dirs = TRUE,
   203	                               full.names = TRUE)
   204	  if (length(rel_candidates) == 0) {
   205	    stop("Archive does not contain a sysndd_prediction_release directory", call. = FALSE)
   206	  }
   207	  rel_dir <- rel_candidates[[1]]
   208
   209	  sha_file <- file.path(rel_dir, "checksums.sha256")
   210	  if (!file.exists(sha_file)) {
   211	    stop("Archive release directory has no bundled checksums.sha256", call. = FALSE)
   212	  }
   213	  sha_lines <- readLines(sha_file, warn = FALSE)
   214	  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
   215	  for (line in sha_lines) {
   216	    parts <- strsplit(trimws(line), "\\s+")[[1]]
   217	    expected_sha <- parts[[1]]
   218	    rel_name <- parts[[length(parts)]]
   219	    target <- file.path(rel_dir, rel_name)
   220	    if (!file.exists(target)) {
   221	      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name),
   222	           call. = FALSE)
   223	    }
   224	    actual_sha <- digest::digest(file = target, algo = "sha256")
   225	    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
   226	      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name),
   227	           call. = FALSE)
   228	    }
   229	  }
   230	  rel_dir
   231	}
   232
   233	#' Parse NDDScore release metadata from nddscore_release.json.
   234	#'
   235	#' @param dir Path to the extracted sysndd_prediction_release directory.
   236	#' @return One-row metadata list with nested metric/version objects serialized
   237	#'   as compact JSON strings.
   238	nddscore_parse_release_json <- function(dir) {
   239	  path <- file.path(dir, "nddscore_release.json")
   240	  if (!file.exists(path)) {
   241	    stop("NDDScore release metadata file not found", call. = FALSE)
   242	  }
   243
   244	  release <- jsonlite::fromJSON(path, simplifyVector = FALSE)
   245	  json_fields <- grep("_json$", names(release), value = TRUE)
   246	  for (field in json_fields) {
   247	    release[[field]] <- jsonlite::toJSON(
   248	      release[[field]],
   249	      auto_unbox = TRUE,
   250	      null = "null",
   251	      digits = NA
   252	    )
   253	  }
   254
   255	  integer_fields <- c("n_genes", "n_hpo_predictions", "n_hpo_terms", "n_features")
   256	  for (field in intersect(integer_fields, names(release))) {
   257	    release[[field]] <- as.integer(release[[field]])
   258	  }
   259
   260	  release
   261	}
   262
   263	#' Load NDDScore release TSV files.
   264	#'
   265	#' @param dir Path to the extracted sysndd_prediction_release directory.
   266	#' @return Named list of tibbles: gene, hpo, and term.
   267	nddscore_load_tsvs <- function(dir) {
   268	  list(
   269	    gene = readr::read_tsv(
   270	      file.path(dir, "nddscore_gene_predictions.tsv"),
   271	      show_col_types = FALSE,
   272	      progress = FALSE
   273	    ),
   274	    hpo = readr::read_tsv(
   275	      file.path(dir, "nddscore_hpo_predictions.tsv"),
   276	      show_col_types = FALSE,
   277	      progress = FALSE
   278	    ),
   279	    term = readr::read_tsv(
   280	      file.path(dir, "nddscore_hpo_terms.tsv"),
   281	      show_col_types = FALSE,
   282	      progress = FALSE
   283	    )
   284	  )
   285	}
   286
   287	.nddscore_required_columns <- list(
   288	  gene = c(
   289	    "release_id", "hgnc_id", "gene_symbol", "ensembl_gene_id", "ndd_score",
   290	    "ndd_score_std", "ndd_score_iqr", "bag_agreement", "rank", "percentile",
   291	    "risk_tier", "confidence_tier", "known_sysndd_gene", "model_split",
   292	    "inheritance_ad_probability", "inheritance_ar_probability",
   293	    "inheritance_xld_probability", "inheritance_xlr_probability",
   294	    "top_inheritance_mode", "called_inheritance_modes", "n_predicted_hpo",
   295	    "top_hpo_predictions_json", "shap_clinical", "shap_constraint",
   296	    "shap_expression", "shap_network", "shap_conservation", "shap_other",
   297	    "dominant_shap_group", "top_features_json", "prediction_note"
   298	  ),
   299	  hpo = c(
   300	    "release_id", "hgnc_id", "gene_symbol", "phenotype_id",
   301	    "phenotype_name", "probability", "rank_for_gene",
   302	    "passes_default_threshold", "term_auc_roc", "term_auc_pr",
   303	    "term_training_support"
   304	  ),
   305	  term = c(
   306	    "release_id", "phenotype_id", "phenotype_name", "term_auc_roc",
   307	    "term_auc_pr", "term_training_support"
   308	  )
   309	)
   310
   311	.nddscore_frame_json_columns <- list(
   312	  gene = c(
   313	    "called_inheritance_modes", "top_hpo_predictions_json",
   314	    "top_features_json"
   315	  )
   316	)
   317
   318	.nddscore_release_json_columns <- c(
   319	  "ndd_performance_json", "phenotype_performance_json",
   320	  "inheritance_performance_json", "data_versions_json",
   321	  "artifact_hashes_json"
   322	)
   323
   324	#' Validate NDDScore release metadata and loaded TSV frames.
   325	#'
   326	#' @return list(ok = TRUE/FALSE, messages = character()) without stopping.
   327	nddscore_validate <- function(release, frames) {
   328	  messages <- character(0)
   329
   330	  add_message <- function(message) {
   331	    messages <<- c(messages, message)
   332	  }
   333
   334	  frame_names <- names(.nddscore_required_columns)
   335	  for (frame_name in frame_names) {
   336	    frame <- frames[[frame_name]]
   337	    if (is.null(frame) || !is.data.frame(frame)) {
   338	      add_message(sprintf("Missing %s frame", frame_name))
   339	      next
   340	    }
   341
   342	    missing_columns <- setdiff(
   343	      .nddscore_required_columns[[frame_name]],
   344	      names(frame)
   345	    )
   346	    if (length(missing_columns) > 0) {
   347	      add_message(sprintf(
   348	        "%s frame is missing required columns: %s",
   349	        frame_name,
   350	        paste(missing_columns, collapse = ", ")
   351	      ))
   352	    }
   353	  }
   354
   355	  row_count_checks <- list(
   356	    gene = "n_genes",
   357	    hpo = "n_hpo_predictions",
   358	    term = "n_hpo_terms"
   359	  )
   360	  for (frame_name in names(row_count_checks)) {

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-zenodo-package.R | sed -n '1,660p' && nl -ba api/functions/analysis-snapshot-release-zenodo-docs.R | sed -n '1,240p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
    35	# `analysis-snapshot-release-zenodo-docs.R` (guard-sourced below) to keep
    36	# this file under the repo's 600-line soft ceiling.
    37
    38	`%||%` <- function(a, b) {
    39	  if (is.null(a) || length(a) == 0) {
    40	    b
    41	  } else {
    42	    a
    43	  }
    44	}
    45
    46	if (!exists(".analysis_release_zenodo_docs_loaded", mode = "logical")) {
    47	  # Resolve this file's own directory from the active source() frame (the
    48	  # proven `helper-functions.R` / `async-job-repository.R` idiom) so the
    49	  # sibling docs file loads regardless of cwd or how this file was sourced.
    50	  .analysis_release_zenodo_self_dir <- local({
    51	    ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
    52	    if (length(ofiles) > 0) dirname(normalizePath(ofiles[[length(ofiles)]])) else NULL
    53	  })
    54	  .analysis_release_zenodo_docs_candidates <- c(
    55	    if (!is.null(.analysis_release_zenodo_self_dir)) {
    56	      file.path(.analysis_release_zenodo_self_dir, "analysis-snapshot-release-zenodo-docs.R")
    57	    },
    58	    "functions/analysis-snapshot-release-zenodo-docs.R",
    59	    "/app/functions/analysis-snapshot-release-zenodo-docs.R"
    60	  )
    61	  for (.analysis_release_zenodo_docs_path in .analysis_release_zenodo_docs_candidates) {
    62	    if (file.exists(.analysis_release_zenodo_docs_path)) {
    63	      # local = TRUE (not FALSE): evaluate into THIS call's parent frame, i.e.
    64	      # the same environment this main file is itself being sourced into
    65	      # (mirrors the working `async-job-repository.R` guard-source precedent).
    66	      # `local = FALSE` would instead always target globalenv() regardless of
    67	      # caller, splitting the two files' symbols across different
    68	      # environments whenever `source_api_file(local = FALSE)` sources this
    69	      # file into a non-global test environment.
    70	      source(.analysis_release_zenodo_docs_path, local = TRUE)
    71	      break
    72	    }
    73	  }
    74	  rm(.analysis_release_zenodo_self_dir, .analysis_release_zenodo_docs_candidates, .analysis_release_zenodo_docs_path)
    75	}
    76
    77	# --------------------------------------------------------------------------- #
    78	# Shared constants (forbidden files/dirs, sensitive text, expected layout)
    79	# --------------------------------------------------------------------------- #
    80
    81	.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES <- c(".env", ".env.local", ".envrc")
    82	.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS <- c(
    83	  ".git", ".planning", ".superpowers", ".venv", "__pycache__"
    84	)
    85	.ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS <- c(
    86	  "/home/", "/users/", "bernt-popp", "zenodo_token", "zenodo_access_token",
    87	  "bearer ", "development/sysndd", "development/nddscore", ".env", "git_sha"
    88	)
    89	.ANALYSIS_RELEASE_ZENODO_TEXT_SUFFIXES <- c(".md", ".json", ".sql", ".cff", ".sha256", ".txt")
    90	.ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL <- c(
    91	  "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
    92	  "datapackage.json", "zenodo_metadata.json", "checksums.sha256"
    93	)
    94	.ANALYSIS_RELEASE_ZENODO_NESTED_DIR <- "analysis_snapshot_release"
    95	.ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED <- c("manifest.json", "checksums.sha256")
    96
    97	# --------------------------------------------------------------------------- #
    98	# Fetch (DI seams: http_get_json / http_download)
    99	# --------------------------------------------------------------------------- #
   100
   101	#' Default JSON GET; tests inject a stub. Mirrors `.nddscore_http_get_json`.
   102	.analysis_release_zenodo_http_get_json <- function(url) {
   103	  resp <- httr2::request(url) |>
   104	    httr2::req_retry(
   105	      max_tries = 4,
   106	      is_transient = ~ httr2::resp_status(.x) %in% c(429, 503, 504)
   107	    ) |>
   108	    httr2::req_timeout(30) |>
   109	    httr2::req_perform()
   110	  httr2::resp_body_json(resp, simplifyVector = FALSE)
   111	}
   112
   113	#' Default streamed binary GET; tests inject a stub. Mirrors `.nddscore_http_download`.
   114	.analysis_release_zenodo_http_download <- function(url, destfile) {
   115	  httr2::request(url) |>
   116	    httr2::req_retry(max_tries = 4) |>
   117	    httr2::req_timeout(300) |>
   118	    httr2::req_perform(path = destfile)
   119	  invisible(destfile)
   120	}
   121
   122	#' Fetch a published release's head + parsed manifest over the public API.
   123	#'
   124	#' @param api_base_url Base URL of the SysNDD API (e.g. "http://localhost:7778").
   125	#' @param release_id "latest" (default) or an explicit `asr_<16 hex>` id.
   126	#' @param http_get_json Function(url) -> parsed JSON list. Injectable seam.
   127	#' @return The parsed head list (release_id, created_at, license,
   128	#'   source_data_version, bundle_sha256, manifest, ...).
   129	analysis_release_zenodo_fetch_head <- function(
   130	    api_base_url,
   131	    release_id = "latest",
   132	    http_get_json = .analysis_release_zenodo_http_get_json) {
   133	  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
   134	  release_id <- as.character(release_id)[[1]]
   135	  url <- paste0(base_url, "/api/analysis/releases/", release_id)
   136	  http_get_json(url)
   137	}
   138
   139	#' Download a published release's whole `bundle.tar.gz`, verbatim, to `destfile`.
   140	#'
   141	#' @param release_id An EXPLICIT `asr_<16 hex>` id (there is no
   142	#'   `/releases/latest/bundle` route -- callers must resolve the concrete id
   143	#'   via `analysis_release_zenodo_fetch_head()` first).
   144	#' @param http_download Function(url, destfile). Injectable seam.
   145	#' @return `destfile`, invisibly-compatible (returned for chaining).
   146	analysis_release_zenodo_download_bundle <- function(
   147	    api_base_url,
   148	    release_id,
   149	    destfile,
   150	    http_download = .analysis_release_zenodo_http_download) {
   151	  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
   152	  release_id <- as.character(release_id)[[1]]
   153	  url <- paste0(base_url, "/api/analysis/releases/", release_id, "/bundle")
   154	  http_download(url, destfile)
   155	  if (!file.exists(destfile) || file.size(destfile) == 0) {
   156	    stop("Analysis-snapshot release bundle download produced an empty file", call. = FALSE)
   157	  }
   158	  destfile
   159	}
   160
   161	#' Verify a downloaded bundle against the release head's `bundle_sha256`,
   162	#' extract it, then verify the bundle's OWN inner `checksums.sha256` against
   163	#' every extracted file. Mirrors `nddscore_extract_and_verify()`'s verify
   164	#' loop, but the outer digest is SHA-256 (not MD5), and the release bundle's
   165	#' files sit directly at the archive root (no named top-level subdirectory
   166	#' to search for).
   167	#'
   168	#' @param bundle_path Path to the downloaded `bundle.tar.gz`.
   169	#' @param expected_bundle_sha256 The release head's `bundle_sha256`.
   170	#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
   171	#' @return Path to the extraction directory (== `exdir`).
   172	analysis_release_zenodo_extract_and_verify <- function(
   173	    bundle_path, expected_bundle_sha256, exdir = NULL) {
   174	  if (!file.exists(bundle_path)) {
   175	    stop("Analysis-snapshot release bundle not found for verification", call. = FALSE)
   176	  }
   177	  actual_bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
   178	  expected <- tolower(as.character(expected_bundle_sha256 %||% "")[[1]])
   179	  if (!identical(tolower(actual_bundle_sha256), expected)) {
   180	    stop(sprintf(
   181	      "Analysis-snapshot release bundle checksum mismatch (expected %s, got %s)",
   182	      expected, actual_bundle_sha256
   183	    ), call. = FALSE)
   184	  }
   185
   186	  if (is.null(exdir)) {
   187	    exdir <- file.path(
   188	      tempdir(), paste0("analysis_release_zenodo_extract_", as.integer(stats::runif(1, 1, 1e9)))
   189	    )
   190	  }
   191	  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
   192	  utils::untar(bundle_path, exdir = exdir)
   193
   194	  sha_file <- file.path(exdir, "checksums.sha256")
   195	  if (!file.exists(sha_file)) {
   196	    stop("Extracted release bundle has no checksums.sha256", call. = FALSE)
   197	  }
   198	  sha_lines <- readLines(sha_file, warn = FALSE)
   199	  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
   200	  for (line in sha_lines) {
   201	    parts <- strsplit(trimws(line), "\\s+")[[1]]
   202	    expected_sha <- parts[[1]]
   203	    rel_name <- parts[[length(parts)]]
   204	    target <- file.path(exdir, rel_name)
   205	    if (!file.exists(target)) {
   206	      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name), call. = FALSE)
   207	    }
   208	    actual_sha <- digest::digest(file = target, algo = "sha256")
   209	    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
   210	      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name), call. = FALSE)
   211	    }
   212	  }
   213	  exdir
   214	}
   215
   216	# --------------------------------------------------------------------------- #
   217	# Shared public-file iterator -- filter-at-source, reused by every
   218	# builder/checksums/validator step (belt half of belt-and-suspenders).
   219	# --------------------------------------------------------------------------- #
   220
   221	#' Sorted, files-only, relative POSIX paths under `root_dir`, excluding
   222	#' forbidden filenames and any path with a forbidden dir-part segment.
   223	#'
   224	#' @return character vector of relative paths ("/"-separated).
   225	.analysis_release_zenodo_iter_public_files <- function(root_dir) {
   226	  all_files <- list.files(
   227	    root_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
   228	  )
   229	  keep <- vapply(all_files, function(rel_path) {
   230	    base <- basename(rel_path)
   231	    if (base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES) {
   232	      return(FALSE)
   233	    }
   234	    segments <- strsplit(rel_path, "/", fixed = TRUE)[[1]]
   235	    !any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
   236	  }, logical(1))
   237	  sort(all_files[keep])
   238	}
   239
   240	# --------------------------------------------------------------------------- #
   241	# Builders (pure)
   242	# --------------------------------------------------------------------------- #
   243
   244	.analysis_release_zenodo_created_at_date <- function(created_at) {
   245	  value <- as.character(created_at %||% "")[[1]]
   246	  if (!nzchar(value)) {
   247	    return("")
   248	  }
   249	  candidate <- substr(value, 1, 10)
   250	  if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", candidate)) candidate else value
   251	}
   252
   253	#' Build the Zenodo metadata list -- becomes `zenodo_metadata.json` AND the
   254	#' body `set_metadata()` PUTs (C2). Never includes a `doi` key: Zenodo mints
   255	#' the DOI on deposition creation.
   256	#'
   257	#' @param head The release head (from `analysis_release_zenodo_fetch_head()`).
   258	#' @param version Optional override; default `head$source_data_version` or
   259	#'   `head$release_id`.
   260	#' @param license_id Optional override; default `head$license` or `"cc-by-4.0"`.
   261	analysis_release_zenodo_build_metadata <- function(head, version = NULL, license_id = NULL) {
   262	  release_id <- as.character(head$release_id %||% "")[[1]]
   263	  release_date <- .analysis_release_zenodo_created_at_date(head$created_at)
   264	  title <- if (nzchar(release_date)) {
   265	    sprintf("SysNDD analysis-snapshot release %s, %s", release_id, release_date)
   266	  } else {
   267	    sprintf("SysNDD analysis-snapshot release %s", release_id)
   268	  }
   269
   270	  resolved_license <- license_id %||% head$license %||% "cc-by-4.0"
   271	  resolved_version <- as.character((version %||% head$source_data_version %||% release_id))[[1]]
   272
   273	  description <- paste0(
   274	    "<p>Immutable, content-addressed public export of a SysNDD analysis-snapshot ",
   275	    "release: the functional (STRING/Leiden) clusters, the phenotype (MCA/HCPC) ",
   276	    "clusters, and the phenotype-functional correlation layer, each derived from ",
   277	    "approved public SysNDD curation data.</p>",
   278	    "<p>Every layer and file is independently verifiable via the bundled ",
   279	    "manifest.json and checksums.sha256. This is a derived analysis product, not a ",
   280	    "copy of the primary curated evidence.</p>"
   281	  )
   282
   283	  list(
   284	    title = title,
   285	    upload_type = "dataset",
   286	    description = description,
   287	    creators = list(list(name = "Popp, Bernt", orcid = "0000-0002-3679-1081")),
   288	    keywords = list(
   289	      "SysNDD", "neurodevelopmental disorders", "gene-disease", "clustering",
   290	      "analysis snapshot"
   291	    ),
   292	    access_right = "open",
   293	    license = as.character(resolved_license)[[1]],
   294	    version = resolved_version,
   295	    language = "eng"
   296	  )
   297	}
   298
   299	#' Build a Frictionless Data Package describing the WHOLE staging tree.
   300	#'
   301	#' @param staging_dir Root of the staging directory (already populated).
   302	#' @param name Dataset machine name.
   303	#' @param version Dataset version string.
   304	#' @param release_id The release id (becomes the datapackage `id`).
   305	analysis_release_zenodo_build_datapackage <- function(staging_dir, name, version, release_id) {
   306	  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
   307	  rel_paths <- base::setdiff(rel_paths, c("checksums.sha256", "datapackage.json"))
   308
   309	  resources <- lapply(rel_paths, function(rel_path) {
   310	    full_path <- file.path(staging_dir, rel_path)
   311	    list(
   312	      name = gsub("\\.", "-", gsub("/", "-", rel_path)),
   313	      path = rel_path,
   314	      bytes = as.numeric(file.info(full_path)$size),
   315	      hash = digest::digest(file = full_path, algo = "sha256"),
   316	      mediatype = "application/octet-stream"
   317	    )
   318	  })
   319
   320	  list(
   321	    profile = "data-package",
   322	    name = as.character(name)[[1]],
   323	    title = "SysNDD analysis-snapshot release",
   324	    version = as.character(version)[[1]],
   325	    id = as.character(release_id)[[1]],
   326	    licenses = list(list(name = "CC-BY-4.0", path = "https://creativecommons.org/licenses/by/4.0/")),
   327	    resources = resources
   328	  )
   329	}
   330
   331	# --------------------------------------------------------------------------- #
   332	# Staging + checksums + tarball
   333	# --------------------------------------------------------------------------- #
   334
   335	.analysis_release_zenodo_write_text <- function(path, content) {
   336	  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
   337	  cat(content, file = path)
   338	  invisible(path)
   339	}
   340
   341	#' Write `checksums.sha256` at the staging root, covering every iterated file
   342	#' (excluding itself). Byte-identical format to
   343	#' `analysis_release_checksums_text()`: `"<sha256>  <path>\n"` lines.
   344	#'
   345	#' @return The written path.
   346	analysis_release_zenodo_write_checksums <- function(staging_dir) {
   347	  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
   348	  rel_paths <- rel_paths[rel_paths != "checksums.sha256"]
   349
   350	  content <- if (length(rel_paths) == 0L) {
   351	    ""
   352	  } else {
   353	    lines <- vapply(rel_paths, function(rel_path) {
   354	      full_path <- file.path(staging_dir, rel_path)
   355	      paste0(digest::digest(file = full_path, algo = "sha256"), "  ", rel_path)
   356	    }, character(1))
   357	    paste0(paste(lines, collapse = "\n"), "\n")
   358	  }
   359
   360	  out_path <- file.path(staging_dir, "checksums.sha256")
   361	  .analysis_release_zenodo_write_text(out_path, content)
   362	  out_path
   363	}
   364
   365	#' Deterministic gzip tarball with ONE top-level dir (`basename(staging_dir)`).
   366	#' Also writes `<archive_path>.sha256` (`"<sha256>  <basename>\n"`).
   367	#'
   368	#' @return list(archive_path, archive_sha256_path).
   369	analysis_release_zenodo_make_tarball <- function(staging_dir, archive_path) {
   370	  archive_dir <- dirname(archive_path)
   371	  dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
   372	  archive_path <- normalizePath(file.path(archive_dir, basename(archive_path)), mustWork = FALSE)
   373
   374	  staging_dir <- normalizePath(staging_dir, mustWork = TRUE)
   375	  parent_dir <- dirname(staging_dir)
   376	  base_name <- basename(staging_dir)
   377
   378	  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
   379	  entries <- sort(file.path(base_name, rel_paths))
   380
   381	  previous_wd <- setwd(parent_dir)
   382	  on.exit(setwd(previous_wd), add = TRUE)
   383	  # tar = "internal" forces R's built-in (pure-R) tar writer so the archive
   384	  # never depends on a system `tar` binary being present/compatible.
   385	  utils::tar(tarfile = archive_path, files = entries, compression = "gzip", tar = "internal")
   386
   387	  sha256 <- digest::digest(file = archive_path, algo = "sha256")
   388	  sha_path <- paste0(archive_path, ".sha256")
   389	  cat(paste0(sha256, "  ", basename(archive_path), "\n"), file = sha_path)
   390
   391	  list(archive_path = archive_path, archive_sha256_path = sha_path)
   392	}
   393
   394	# --------------------------------------------------------------------------- #
   395	# THE SAFETY VALIDATOR -- defense in depth, runs LAST before tarring.
   396	# Three independent checks; each collects offending paths and stops loudly.
   397	# --------------------------------------------------------------------------- #
   398
   399	.analysis_release_zenodo_validate_no_forbidden <- function(staging_dir) {
   400	  # Deliberately re-walks the tree directly (not via the shared iterator,
   401	  # which already excludes these) -- an independent re-check, not a
   402	  # tautology.
   403	  all_files <- list.files(
   404	    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
   405	  )
   406	  offenders <- Filter(function(rel_path) {
   407	    base <- basename(rel_path)
   408	    segments <- strsplit(rel_path, "/", fixed = TRUE)[[1]]
   409	    base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES ||
   410	      any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
   411	  }, all_files)
   412
   413	  if (length(offenders) > 0) {
   414	    stop(sprintf(
   415	      "Zenodo staging contains private files: %s",
   416	      paste(sort(offenders), collapse = ", ")
   417	    ), call. = FALSE)
   418	  }
   419	  invisible(TRUE)
   420	}
   421
   422	.analysis_release_zenodo_has_text_suffix <- function(rel_path) {
   423	  lower <- tolower(rel_path)
   424	  any(vapply(
   425	    .ANALYSIS_RELEASE_ZENODO_TEXT_SUFFIXES,
   426	    function(suffix) endsWith(lower, suffix), logical(1)
   427	  ))
   428	}
   429
   430	.analysis_release_zenodo_validate_no_sensitive_text <- function(staging_dir) {
   431	  offenders <- character(0)
   432	  for (rel_path in .analysis_release_zenodo_iter_public_files(staging_dir)) {
   433	    if (!.analysis_release_zenodo_has_text_suffix(rel_path)) {
   434	      next
   435	    }
   436	    full_path <- file.path(staging_dir, rel_path)
   437	    text <- tolower(paste(readLines(full_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
   438	    hit <- Find(function(pattern) grepl(pattern, text, fixed = TRUE),
   439	                .ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS)
   440	    if (!is.null(hit)) {
   441	      offenders <- c(offenders, sprintf("%s (matched '%s')", rel_path, hit))
   442	    }
   443	  }
   444	  if (length(offenders) > 0) {
   445	    stop(sprintf(
   446	      "Zenodo staging contains sensitive public text: %s",
   447	      paste(offenders, collapse = "; ")
   448	    ), call. = FALSE)
   449	  }
   450	  invisible(TRUE)
   451	}
   452
   453	.analysis_release_zenodo_validate_layout <- function(staging_dir) {
   454	  expected_top <- .ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL
   455	  expected_nested <- file.path(
   456	    .ANALYSIS_RELEASE_ZENODO_NESTED_DIR, .ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED
   457	  )
   458	  expected <- c(expected_top, expected_nested)
   459
   460	  missing <- Filter(function(rel_path) !file.exists(file.path(staging_dir, rel_path)), expected)
   461	  if (length(missing) > 0) {
   462	    stop(sprintf(
   463	      "Zenodo staging is missing expected members: %s",
   464	      paste(missing, collapse = ", ")
   465	    ), call. = FALSE)
   466	  }
   467	  invisible(TRUE)
   468	}
   469
   470	#' The safety validator. Three independent checks; stops with a clear message
   471	#' naming the offending relative paths on the first failing check.
   472	analysis_release_zenodo_validate_staging <- function(staging_dir) {
   473	  .analysis_release_zenodo_validate_no_forbidden(staging_dir)
   474	  .analysis_release_zenodo_validate_no_sensitive_text(staging_dir)
   475	  .analysis_release_zenodo_validate_layout(staging_dir)
   476	  invisible(TRUE)
   477	}
   478
   479	# --------------------------------------------------------------------------- #
   480	# Orchestrator
   481	# --------------------------------------------------------------------------- #
   482
   483	#' Recursively sort a named list's keys alphabetically (objects only --
   484	#' unnamed lists/arrays are recursed into without reordering). Used for
   485	#' `zenodo_metadata.json`'s "pretty JSON, sorted keys" contract, mirroring
   486	#' Python's `json.dumps(..., sort_keys=True)`.
   487	.analysis_release_zenodo_sort_keys <- function(x) {
   488	  if (is.list(x)) {
   489	    nms <- names(x)
   490	    if (!is.null(nms) && all(nzchar(nms))) {
   491	      x <- x[order(nms)]
   492	    }
   493	    x <- lapply(x, .analysis_release_zenodo_sort_keys)
   494	  }
   495	  x
   496	}
   497
   498	.analysis_release_zenodo_copy_tree <- function(src_dir, dest_dir) {
   499	  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
   500	  rel_paths <- list.files(src_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
   501	  for (rel_path in rel_paths) {
   502	    dest_path <- file.path(dest_dir, rel_path)
   503	    dir.create(dirname(dest_path), recursive = TRUE, showWarnings = FALSE)
   504	    file.copy(file.path(src_dir, rel_path), dest_path, overwrite = TRUE, copy.date = TRUE)
   505	  }
   506	  invisible(dest_dir)
   507	}
   508
   509	#' Fetch a published release over the public HTTP API and assemble a Zenodo
   510	#' staging directory + deterministic tarball. Mirrors nddscore's
   511	#' `build_zenodo_dataset_package()` top-to-bottom.
   512	#'
   513	#' @return list(staging_dir, archive_path, archive_sha256_path,
   514	#'   zenodo_metadata_path, release_id).
   515	analysis_release_zenodo_package <- function(
   516	    api_base_url,
   517	    release_id = "latest",
   518	    staging_dir,
   519	    archive_dir,
   520	    version = NULL,
   521	    doi = NULL,
   522	    http_get_json = .analysis_release_zenodo_http_get_json,
   523	    http_download = .analysis_release_zenodo_http_download) {
   524	  head <- analysis_release_zenodo_fetch_head(api_base_url, release_id, http_get_json = http_get_json)
   525	  resolved_release_id <- as.character(head$release_id)[[1]]
   526
   527	  bundle_path <- tempfile(fileext = ".tar.gz")
   528	  on.exit(unlink(bundle_path, force = TRUE), add = TRUE)
   529	  analysis_release_zenodo_download_bundle(
   530	    api_base_url, resolved_release_id, bundle_path, http_download = http_download
   531	  )
   532	  extracted_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, head$bundle_sha256)
   533	  on.exit(unlink(extracted_dir, recursive = TRUE, force = TRUE), add = TRUE)
   534
   535	  if (dir.exists(staging_dir)) {
   536	    unlink(staging_dir, recursive = TRUE, force = TRUE)
   537	  }
   538	  dir.create(staging_dir, recursive = TRUE)
   539
   540	  nested_dir <- file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_NESTED_DIR)
   541	  .analysis_release_zenodo_copy_tree(extracted_dir, nested_dir)
   542
   543	  resolved_version <- as.character(
   544	    (version %||% head$source_data_version %||% resolved_release_id)
   545	  )[[1]]
   546
   547	  .analysis_release_zenodo_write_text(
   548	    file.path(staging_dir, "README.md"), analysis_release_zenodo_build_readme(head, doi)
   549	  )
   550	  .analysis_release_zenodo_write_text(
   551	    file.path(staging_dir, "DATA_CARD.md"), analysis_release_zenodo_build_data_card(head)
   552	  )
   553	  .analysis_release_zenodo_write_text(
   554	    file.path(staging_dir, "SCHEMA.md"), analysis_release_zenodo_build_schema_doc(head)
   555	  )
   556	  .analysis_release_zenodo_write_text(
   557	    file.path(staging_dir, "CHANGELOG.md"),
   558	    analysis_release_zenodo_build_changelog(head, resolved_version)
   559	  )
   560	  .analysis_release_zenodo_write_text(
   561	    file.path(staging_dir, "CITATION.cff"),
   562	    analysis_release_zenodo_build_citation_cff(head, resolved_version, doi)
   563	  )
   564
   565	  metadata <- analysis_release_zenodo_build_metadata(head, version = resolved_version)
   566	  metadata_json <- jsonlite::toJSON(
   567	    .analysis_release_zenodo_sort_keys(metadata), auto_unbox = TRUE, pretty = TRUE, null = "null"
   568	  )
   569	  zenodo_metadata_path <- file.path(staging_dir, "zenodo_metadata.json")
   570	  .analysis_release_zenodo_write_text(zenodo_metadata_path, paste0(as.character(metadata_json), "\n"))
   571
   572	  datapackage <- analysis_release_zenodo_build_datapackage(
   573	    staging_dir,
   574	    name = "sysndd-analysis-snapshot-release",
   575	    version = resolved_version,
   576	    release_id = resolved_release_id
   577	  )
   578	  datapackage_json <- jsonlite::toJSON(datapackage, auto_unbox = TRUE, pretty = TRUE, null = "null")
   579	  .analysis_release_zenodo_write_text(
   580	    file.path(staging_dir, "datapackage.json"), paste0(as.character(datapackage_json), "\n")
   581	  )
   582
   583	  analysis_release_zenodo_write_checksums(staging_dir)
   584
   585	  analysis_release_zenodo_validate_staging(staging_dir)
   586
   587	  archive_path <- file.path(archive_dir, paste0(resolved_release_id, ".tar.gz"))
   588	  tar_result <- analysis_release_zenodo_make_tarball(staging_dir, archive_path)
   589
   590	  list(
   591	    staging_dir = staging_dir,
   592	    archive_path = tar_result$archive_path,
   593	    archive_sha256_path = tar_result$archive_sha256_path,
   594	    zenodo_metadata_path = zenodo_metadata_path,
   595	    release_id = resolved_release_id
   596	  )
   597	}
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

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-zenodo-package.R | sed -n '360,660p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
   360	  out_path <- file.path(staging_dir, "checksums.sha256")
   361	  .analysis_release_zenodo_write_text(out_path, content)
   362	  out_path
   363	}
   364
   365	#' Deterministic gzip tarball with ONE top-level dir (`basename(staging_dir)`).
   366	#' Also writes `<archive_path>.sha256` (`"<sha256>  <basename>\n"`).
   367	#'
   368	#' @return list(archive_path, archive_sha256_path).
   369	analysis_release_zenodo_make_tarball <- function(staging_dir, archive_path) {
   370	  archive_dir <- dirname(archive_path)
   371	  dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
   372	  archive_path <- normalizePath(file.path(archive_dir, basename(archive_path)), mustWork = FALSE)
   373
   374	  staging_dir <- normalizePath(staging_dir, mustWork = TRUE)
   375	  parent_dir <- dirname(staging_dir)
   376	  base_name <- basename(staging_dir)
   377
   378	  rel_paths <- .analysis_release_zenodo_iter_public_files(staging_dir)
   379	  entries <- sort(file.path(base_name, rel_paths))
   380
   381	  previous_wd <- setwd(parent_dir)
   382	  on.exit(setwd(previous_wd), add = TRUE)
   383	  # tar = "internal" forces R's built-in (pure-R) tar writer so the archive
   384	  # never depends on a system `tar` binary being present/compatible.
   385	  utils::tar(tarfile = archive_path, files = entries, compression = "gzip", tar = "internal")
   386
   387	  sha256 <- digest::digest(file = archive_path, algo = "sha256")
   388	  sha_path <- paste0(archive_path, ".sha256")
   389	  cat(paste0(sha256, "  ", basename(archive_path), "\n"), file = sha_path)
   390
   391	  list(archive_path = archive_path, archive_sha256_path = sha_path)
   392	}
   393
   394	# --------------------------------------------------------------------------- #
   395	# THE SAFETY VALIDATOR -- defense in depth, runs LAST before tarring.
   396	# Three independent checks; each collects offending paths and stops loudly.
   397	# --------------------------------------------------------------------------- #
   398
   399	.analysis_release_zenodo_validate_no_forbidden <- function(staging_dir) {
   400	  # Deliberately re-walks the tree directly (not via the shared iterator,
   401	  # which already excludes these) -- an independent re-check, not a
   402	  # tautology.
   403	  all_files <- list.files(
   404	    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
   405	  )
   406	  offenders <- Filter(function(rel_path) {
   407	    base <- basename(rel_path)
   408	    segments <- strsplit(rel_path, "/", fixed = TRUE)[[1]]
   409	    base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES ||
   410	      any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
   411	  }, all_files)
   412
   413	  if (length(offenders) > 0) {
   414	    stop(sprintf(
   415	      "Zenodo staging contains private files: %s",
   416	      paste(sort(offenders), collapse = ", ")
   417	    ), call. = FALSE)
   418	  }
   419	  invisible(TRUE)
   420	}
   421
   422	.analysis_release_zenodo_has_text_suffix <- function(rel_path) {
   423	  lower <- tolower(rel_path)
   424	  any(vapply(
   425	    .ANALYSIS_RELEASE_ZENODO_TEXT_SUFFIXES,
   426	    function(suffix) endsWith(lower, suffix), logical(1)
   427	  ))
   428	}
   429
   430	.analysis_release_zenodo_validate_no_sensitive_text <- function(staging_dir) {
   431	  offenders <- character(0)
   432	  for (rel_path in .analysis_release_zenodo_iter_public_files(staging_dir)) {
   433	    if (!.analysis_release_zenodo_has_text_suffix(rel_path)) {
   434	      next
   435	    }
   436	    full_path <- file.path(staging_dir, rel_path)
   437	    text <- tolower(paste(readLines(full_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
   438	    hit <- Find(function(pattern) grepl(pattern, text, fixed = TRUE),
   439	                .ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS)
   440	    if (!is.null(hit)) {
   441	      offenders <- c(offenders, sprintf("%s (matched '%s')", rel_path, hit))
   442	    }
   443	  }
   444	  if (length(offenders) > 0) {
   445	    stop(sprintf(
   446	      "Zenodo staging contains sensitive public text: %s",
   447	      paste(offenders, collapse = "; ")
   448	    ), call. = FALSE)
   449	  }
   450	  invisible(TRUE)
   451	}
   452
   453	.analysis_release_zenodo_validate_layout <- function(staging_dir) {
   454	  expected_top <- .ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL
   455	  expected_nested <- file.path(
   456	    .ANALYSIS_RELEASE_ZENODO_NESTED_DIR, .ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED
   457	  )
   458	  expected <- c(expected_top, expected_nested)
   459
   460	  missing <- Filter(function(rel_path) !file.exists(file.path(staging_dir, rel_path)), expected)
   461	  if (length(missing) > 0) {
   462	    stop(sprintf(
   463	      "Zenodo staging is missing expected members: %s",
   464	      paste(missing, collapse = ", ")
   465	    ), call. = FALSE)
   466	  }
   467	  invisible(TRUE)
   468	}
   469
   470	#' The safety validator. Three independent checks; stops with a clear message
   471	#' naming the offending relative paths on the first failing check.
   472	analysis_release_zenodo_validate_staging <- function(staging_dir) {
   473	  .analysis_release_zenodo_validate_no_forbidden(staging_dir)
   474	  .analysis_release_zenodo_validate_no_sensitive_text(staging_dir)
   475	  .analysis_release_zenodo_validate_layout(staging_dir)
   476	  invisible(TRUE)
   477	}
   478
   479	# --------------------------------------------------------------------------- #
   480	# Orchestrator
   481	# --------------------------------------------------------------------------- #
   482
   483	#' Recursively sort a named list's keys alphabetically (objects only --
   484	#' unnamed lists/arrays are recursed into without reordering). Used for
   485	#' `zenodo_metadata.json`'s "pretty JSON, sorted keys" contract, mirroring
   486	#' Python's `json.dumps(..., sort_keys=True)`.
   487	.analysis_release_zenodo_sort_keys <- function(x) {
   488	  if (is.list(x)) {
   489	    nms <- names(x)
   490	    if (!is.null(nms) && all(nzchar(nms))) {
   491	      x <- x[order(nms)]
   492	    }
   493	    x <- lapply(x, .analysis_release_zenodo_sort_keys)
   494	  }
   495	  x
   496	}
   497
   498	.analysis_release_zenodo_copy_tree <- function(src_dir, dest_dir) {
   499	  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
   500	  rel_paths <- list.files(src_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
   501	  for (rel_path in rel_paths) {
   502	    dest_path <- file.path(dest_dir, rel_path)
   503	    dir.create(dirname(dest_path), recursive = TRUE, showWarnings = FALSE)
   504	    file.copy(file.path(src_dir, rel_path), dest_path, overwrite = TRUE, copy.date = TRUE)
   505	  }
   506	  invisible(dest_dir)
   507	}
   508
   509	#' Fetch a published release over the public HTTP API and assemble a Zenodo
   510	#' staging directory + deterministic tarball. Mirrors nddscore's
   511	#' `build_zenodo_dataset_package()` top-to-bottom.
   512	#'
   513	#' @return list(staging_dir, archive_path, archive_sha256_path,
   514	#'   zenodo_metadata_path, release_id).
   515	analysis_release_zenodo_package <- function(
   516	    api_base_url,
   517	    release_id = "latest",
   518	    staging_dir,
   519	    archive_dir,
   520	    version = NULL,
   521	    doi = NULL,
   522	    http_get_json = .analysis_release_zenodo_http_get_json,
   523	    http_download = .analysis_release_zenodo_http_download) {
   524	  head <- analysis_release_zenodo_fetch_head(api_base_url, release_id, http_get_json = http_get_json)
   525	  resolved_release_id <- as.character(head$release_id)[[1]]
   526
   527	  bundle_path <- tempfile(fileext = ".tar.gz")
   528	  on.exit(unlink(bundle_path, force = TRUE), add = TRUE)
   529	  analysis_release_zenodo_download_bundle(
   530	    api_base_url, resolved_release_id, bundle_path, http_download = http_download
   531	  )
   532	  extracted_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, head$bundle_sha256)
   533	  on.exit(unlink(extracted_dir, recursive = TRUE, force = TRUE), add = TRUE)
   534
   535	  if (dir.exists(staging_dir)) {
   536	    unlink(staging_dir, recursive = TRUE, force = TRUE)
   537	  }
   538	  dir.create(staging_dir, recursive = TRUE)
   539
   540	  nested_dir <- file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_NESTED_DIR)
   541	  .analysis_release_zenodo_copy_tree(extracted_dir, nested_dir)
   542
   543	  resolved_version <- as.character(
   544	    (version %||% head$source_data_version %||% resolved_release_id)
   545	  )[[1]]
   546
   547	  .analysis_release_zenodo_write_text(
   548	    file.path(staging_dir, "README.md"), analysis_release_zenodo_build_readme(head, doi)
   549	  )
   550	  .analysis_release_zenodo_write_text(
   551	    file.path(staging_dir, "DATA_CARD.md"), analysis_release_zenodo_build_data_card(head)
   552	  )
   553	  .analysis_release_zenodo_write_text(
   554	    file.path(staging_dir, "SCHEMA.md"), analysis_release_zenodo_build_schema_doc(head)
   555	  )
   556	  .analysis_release_zenodo_write_text(
   557	    file.path(staging_dir, "CHANGELOG.md"),
   558	    analysis_release_zenodo_build_changelog(head, resolved_version)
   559	  )
   560	  .analysis_release_zenodo_write_text(
   561	    file.path(staging_dir, "CITATION.cff"),
   562	    analysis_release_zenodo_build_citation_cff(head, resolved_version, doi)
   563	  )
   564
   565	  metadata <- analysis_release_zenodo_build_metadata(head, version = resolved_version)
   566	  metadata_json <- jsonlite::toJSON(
   567	    .analysis_release_zenodo_sort_keys(metadata), auto_unbox = TRUE, pretty = TRUE, null = "null"
   568	  )
   569	  zenodo_metadata_path <- file.path(staging_dir, "zenodo_metadata.json")
   570	  .analysis_release_zenodo_write_text(zenodo_metadata_path, paste0(as.character(metadata_json), "\n"))
   571
   572	  datapackage <- analysis_release_zenodo_build_datapackage(
   573	    staging_dir,
   574	    name = "sysndd-analysis-snapshot-release",
   575	    version = resolved_version,
   576	    release_id = resolved_release_id
   577	  )
   578	  datapackage_json <- jsonlite::toJSON(datapackage, auto_unbox = TRUE, pretty = TRUE, null = "null")
   579	  .analysis_release_zenodo_write_text(
   580	    file.path(staging_dir, "datapackage.json"), paste0(as.character(datapackage_json), "\n")
   581	  )
   582
   583	  analysis_release_zenodo_write_checksums(staging_dir)
   584
   585	  analysis_release_zenodo_validate_staging(staging_dir)
   586
   587	  archive_path <- file.path(archive_dir, paste0(resolved_release_id, ".tar.gz"))
   588	  tar_result <- analysis_release_zenodo_make_tarball(staging_dir, archive_path)
   589
   590	  list(
   591	    staging_dir = staging_dir,
   592	    archive_path = tar_result$archive_path,
   593	    archive_sha256_path = tar_result$archive_sha256_path,
   594	    zenodo_metadata_path = zenodo_metadata_path,
   595	    release_id = resolved_release_id
   596	  )
   597	}

exec
/bin/bash -lc "nl -ba api/scripts/package-analysis-release-zenodo.R | sed -n '1,260p'; nl -ba api/scripts/upload-analysis-release-zenodo.R | sed -n '1,300p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
    19	#     [--token <ZENODO_TOKEN, defaults to env>] [--sandbox] \
    20	#     [--deposition-id <id>] [--publish --confirm-publish] \
    21	#     [--record-doi --release-id <asr_...>] [--api-base-url <SysNDD API base>]
    22	#
    23	# Publish safety interlock: `--publish` alone is REFUSED -- both `--publish`
    24	# AND `--confirm-publish` must be passed, or the run stops before any HTTP
    25	# call is made (`analysis_release_zenodo_require_publish_confirmation()`).
    26	# Without `--publish`, the archive is uploaded to a Zenodo DRAFT only, for
    27	# manual review before publishing.
    28	#
    29	# DOI record-back is OPT-IN and requires BOTH `--record-doi` AND the
    30	# `SYSNDD_ADMIN_TOKEN` env var (a pre-minted SysNDD Administrator bearer
    31	# token) to be set, plus `--release-id` and a successfully PUBLISHED Zenodo
    32	# DOI. Absent any of those, this script NEVER calls the SysNDD admin PATCH
    33	# endpoint automatically -- it prints the exact manual `curl` command instead
    34	# so the operator can record it by hand.
    35	#
    36	# Requires: httr2, jsonlite (api/renv.lock). No DB, no bootstrap, no
    37	# `external_proxy_budget()` -- see AGENTS.md "Analysis-snapshot releases
    38	# (#573)" and `.superpowers/sdd/slice-c-scout.md`.
    39	#
    40	# CWD note: resolves `api/functions/analysis-snapshot-release-zenodo-
    41	# upload.R` relative to ITS OWN file location (same idiom as
    42	# `package-analysis-release-zenodo.R` / `capture-external-fixtures.R`), so it
    43	# may be invoked from any working directory.
    44
    45	# --------------------------------------------------------------------------- #
    46	# Resolve this script's own directory, then source the upload/record-back
    47	# functions (function definitions only -- no top-level network calls in that
    48	# file, so this is safe to do unconditionally, even when this CLI script is
    49	# itself only `source()`d).
    50	# --------------------------------------------------------------------------- #
    51
    52	.upload_analysis_release_zenodo_script_dir <- function() {
    53	  script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
    54	  if (is.null(script_file) || !nzchar(script_file)) {
    55	    full_args <- commandArgs(trailingOnly = FALSE)
    56	    file_arg <- grep("^--file=", full_args, value = TRUE)
    57	    script_file <- if (length(file_arg) >= 1) sub("^--file=", "", file_arg[1]) else "."
    58	  }
    59	  dirname(normalizePath(script_file, mustWork = FALSE))
    60	}
    61
    62	.upload_analysis_release_zenodo_script_dir_value <- .upload_analysis_release_zenodo_script_dir()
    63	source(
    64	  file.path(
    65	    .upload_analysis_release_zenodo_script_dir_value, "..", "functions",
    66	    "analysis-snapshot-release-zenodo-upload.R"
    67	  ),
    68	  local = FALSE
    69	)
    70
    71	# --------------------------------------------------------------------------- #
    72	# CLI arg parsing -- manual commandArgs() flag loop (repo convention; no
    73	# optparse dependency, see `verify-endpoints.R`).
    74	# --------------------------------------------------------------------------- #
    75
    76	#' Parse + run the upload CLI. Wrapped in a function (rather than bare
    77	#' top-level code) so the file can be `source()`d for its function
    78	#' definitions alone -- see the `sys.nframe() == 0L` main-guard at the
    79	#' bottom of this file, which only calls this when the script is run
    80	#' directly (`Rscript upload-analysis-release-zenodo.R`), never when
    81	#' `source()`d (e.g. by a test).
    82	run_upload_analysis_release_zenodo_cli <- function() {
    83	  args <- commandArgs(trailingOnly = TRUE)
    84
    85	  archive <- NULL
    86	  metadata <- NULL
    87	  token <- Sys.getenv("ZENODO_TOKEN", "")
    88	  sandbox <- FALSE
    89	  deposition_id <- NULL
    90	  publish <- FALSE
    91	  confirm_publish <- FALSE
    92	  record_doi <- FALSE
    93	  release_id <- NULL
    94	  api_base_url <- Sys.getenv("SYSNDD_API_BASE_URL", "http://localhost:7778")
    95
    96	  if (length(args) > 0) {
    97	    for (i in seq_along(args)) {
    98	      if (args[i] == "--archive" && i < length(args)) {
    99	        archive <- args[i + 1]
   100	      } else if (args[i] == "--metadata" && i < length(args)) {
   101	        metadata <- args[i + 1]
   102	      } else if (args[i] == "--token" && i < length(args)) {
   103	        token <- args[i + 1]
   104	      } else if (args[i] == "--sandbox") {
   105	        sandbox <- TRUE
   106	      } else if (args[i] == "--deposition-id" && i < length(args)) {
   107	        deposition_id <- args[i + 1]
   108	      } else if (args[i] == "--publish") {
   109	        publish <- TRUE
   110	      } else if (args[i] == "--confirm-publish") {
   111	        confirm_publish <- TRUE
   112	      } else if (args[i] == "--record-doi") {
   113	        record_doi <- TRUE
   114	      } else if (args[i] == "--release-id" && i < length(args)) {
   115	        release_id <- args[i + 1]
   116	      } else if (args[i] == "--api-base-url" && i < length(args)) {
   117	        api_base_url <- args[i + 1]
   118	      }
   119	    }
   120	  }
   121
   122	  if (is.null(archive) || !nzchar(archive)) {
   123	    stop("--archive is required", call. = FALSE)
   124	  }
   125	  if (is.null(metadata) || !nzchar(metadata)) {
   126	    stop("--metadata is required", call. = FALSE)
   127	  }
   128
   129	  result <- analysis_release_zenodo_upload(
   130	    archive_path = archive,
   131	    metadata_path = metadata,
   132	    token = token,
   133	    sandbox = sandbox,
   134	    deposition_id = deposition_id,
   135	    publish = publish,
   136	    confirm_publish = confirm_publish
   137	  )
   138
   139	  cat(sprintf("Zenodo deposition id: %s\n", result$deposition_id))
   140	  cat(sprintf(
   141	    "Zenodo reserved DOI:  %s\n",
   142	    if (is.na(result$reserved_doi)) "not returned" else result$reserved_doi
   143	  ))
   144	  cat(sprintf(
   145	    "Zenodo draft URL:     %s\n",
   146	    if (is.na(result$draft_url)) "not returned" else result$draft_url
   147	  ))
   148
   149	  if (isTRUE(result$published)) {
   150	    cat(sprintf("Published Zenodo DOI: %s\n", result$version_doi))
   151	    cat(sprintf("Published Zenodo URL: %s\n", result$record_url))
   152	  } else {
   153	    cat("Draft uploaded only. Review in Zenodo before publishing.\n")
   154	  }
   155
   156	  .print_doi_record_back(result, release_id, api_base_url, record_doi)
   157
   158	  invisible(result)
   159	}
   160
   161	#' The opt-in DOI record-back step. Never calls the SysNDD admin endpoint
   162	#' unless the operator explicitly asked for it (`--record-doi`) AND supplied
   163	#' credentials (`SYSNDD_ADMIN_TOKEN`) AND the run reached a real, published
   164	#' DOI -- a draft's "reserved" DOI is not final and is deliberately NOT
   165	#' recorded automatically. Otherwise prints the exact manual command.
   166	.print_doi_record_back <- function(result, release_id, api_base_url, record_doi) {
   167	  doi_fields <- list(
   168	    zenodo_record_id = as.character(result$deposition_id),
   169	    zenodo_record_url = if (isTRUE(result$published)) result$record_url else result$draft_url,
   170	    version_doi = if (isTRUE(result$published)) result$version_doi else NA_character_,
   171	    concept_doi = if (isTRUE(result$published)) result$concept_doi else NA_character_
   172	  )
   173
   174	  have_release_id <- !is.null(release_id) && nzchar(release_id)
   175	  have_published_doi <- isTRUE(result$published) &&
   176	    !is.na(result$version_doi) && nzchar(as.character(result$version_doi))
   177	  admin_token <- Sys.getenv("SYSNDD_ADMIN_TOKEN", "")
   178
   179	  if (!have_release_id) {
   180	    cat("\nNo --release-id supplied -- pass one to record or print a DOI record-back command.\n")
   181	    return(invisible(NULL))
   182	  }
   183
   184	  if (isTRUE(record_doi) && nzchar(admin_token) && have_published_doi) {
   185	    updated <- analysis_release_zenodo_record_doi(
   186	      sysndd_api_base_url = api_base_url,
   187	      admin_token = admin_token,
   188	      release_id = release_id,
   189	      doi_fields = doi_fields
   190	    )
   191	    cat("\nDOI recorded on the SysNDD release head:\n")
   192	    cat(sprintf("  release_id:        %s\n", updated$release_id %||% release_id))
   193	    cat(sprintf("  version_doi:       %s\n", updated$version_doi %||% doi_fields$version_doi))
   194	    cat(sprintf("  zenodo_record_url: %s\n", updated$zenodo_record_url %||% doi_fields$zenodo_record_url))
   195	  } else {
   196	    cat(
   197	      "\nDOI not recorded automatically",
   198	      if (!have_published_doi) " (deposition not published yet)" else "",
   199	      ". Run with --record-doi and SYSNDD_ADMIN_TOKEN set after publishing, ",
   200	      "or record it by hand:\n",
   201	      sep = ""
   202	    )
   203	    cat(analysis_release_zenodo_manual_doi_command(api_base_url, release_id, doi_fields), "\n")
   204	  }
   205	  invisible(NULL)
   206	}
   207
   208	# Main guard: `sys.nframe()` is 0 only at the true top level of a directly
   209	# `Rscript`-invoked file; a `source()`d file (e.g. from a test) always adds
   210	# at least one frame, so this line never fires under `source()`. This check
   211	# MUST stay at top level (not inside a function).
   212	if (sys.nframe() == 0L) run_upload_analysis_release_zenodo_cli()

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-zenodo-upload.R | sed -n '1,380p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
   273	    stop("ZENODO_TOKEN not set and --token not provided", call. = FALSE)
   274	  }
   275	  if (!file.exists(archive_path)) {
   276	    stop(sprintf("Archive does not exist: %s", archive_path), call. = FALSE)
   277	  }
   278	  if (!file.exists(metadata_path)) {
   279	    stop(sprintf("Metadata does not exist: %s", metadata_path), call. = FALSE)
   280	  }
   281
   282	  api <- analysis_release_zenodo_resolve_api(sandbox)
   283	  metadata <- jsonlite::fromJSON(metadata_path, simplifyVector = FALSE)
   284
   285	  deposition <- get_or_create_deposition(api, token, deposition_id = deposition_id)
   286	  resolved_deposition_id <- deposition$id
   287	  bucket_url <- deposition$links$bucket
   288	  reserved_doi <- deposition$metadata$prereserve_doi$doi
   289
   290	  set_metadata(api, token, resolved_deposition_id, metadata)
   291	  upload_bucket(bucket_url, token, archive_path)
   292
   293	  result <- list(
   294	    deposition_id = resolved_deposition_id,
   295	    reserved_doi = reserved_doi %||% NA_character_,
   296	    draft_url = deposition$links$html %||% NA_character_,
   297	    published = FALSE,
   298	    version_doi = NA_character_,
   299	    concept_doi = NA_character_,
   300	    record_url = NA_character_
   301	  )
   302
   303	  if (isTRUE(publish)) {
   304	    published_deposition <- publish_deposition(api, token, resolved_deposition_id)
   305	    result$published <- TRUE
   306	    result$version_doi <- published_deposition$doi %||% NA_character_
   307	    result$concept_doi <- published_deposition$conceptdoi %||% NA_character_
   308	    result$record_url <- published_deposition$links$html %||% NA_character_
   309	  }
   310
   311	  result
   312	}

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-zenodo-docs.R | sed -n '1,260p'; nl -ba Makefile | sed -n '570,680p'; rg -n -C 3 'analysis-release-zenodo|Zenodo|record-doi|confirm-publish' documentation/09-deployment.qmd CHANGELOG.md AGENTS.md .gitignore api/version_spec.json app/package.json" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
   570	PLAYWRIGHT_ENV := \
   571		PLAYWRIGHT_HOST_PORT=$(PLAYWRIGHT_HOST_PORT) \
   572		MYSQL_DATABASE=$(PLAYWRIGHT_DB_NAME) \
   573		MYSQL_USER=$(PLAYWRIGHT_DB_USER) \
   574		MYSQL_PASSWORD=$(PLAYWRIGHT_DB_PASSWORD) \
   575		MYSQL_ROOT_PASSWORD=$(PLAYWRIGHT_DB_ROOT_PASSWORD) \
   576		PASSWORD=$(PLAYWRIGHT_API_PASSWORD) \
   577		SMTP_PASSWORD=playwright_smtp \
   578		OMIM_DOWNLOAD_KEY=playwright_omim \
   579		CORS_ALLOWED_ORIGINS=$(PLAYWRIGHT_BASE_URL) \
   580		CACHE_VERSION=2
   581
   582	_playwright-seed-templates:
   583		@# Seed .env from template if missing — needed because docker-compose.yml
   584		@# interpolates MYSQL_*, PASSWORD, and OMIM_DOWNLOAD_KEY at parse time.
   585		@# The PLAYWRIGHT_ENV exports below also set these inline, so the .env file
   586		@# only matters as a fallback for compose's own variable substitution.
   587		@if [ ! -f $(ROOT_DIR)/.env ]; then \
   588			printf "$(YELLOW)⚠ Seeding .env from .env.example$(RESET)\n"; \
   589			cp $(ROOT_DIR)/.env.example $(ROOT_DIR)/.env; \
   590		fi
   591		@# Swap in api/config.yml.playwright as api/config.yml so the API container
   592		@# connects to the playwright DB with the credentials in PLAYWRIGHT_ENV.
   593		@# Preserve any existing dev config to api/config.yml.devbackup. Restore
   594		@# happens via `make playwright-stack-down`.
   595		@if [ -f $(ROOT_DIR)/api/config.yml ] && \
   596		   ! cmp -s $(ROOT_DIR)/api/config.yml $(ROOT_DIR)/api/config.yml.playwright && \
   597		   [ ! -f $(ROOT_DIR)/api/config.yml.devbackup ]; then \
   598			printf "$(YELLOW)⚠ Backing up api/config.yml to api/config.yml.devbackup (will be restored on playwright-stack-down)$(RESET)\n"; \
   599			cp $(ROOT_DIR)/api/config.yml $(ROOT_DIR)/api/config.yml.devbackup; \
   600		fi
   601		@cp $(ROOT_DIR)/api/config.yml.playwright $(ROOT_DIR)/api/config.yml
   602		@printf "$(GREEN)✓ Active api/config.yml is the Playwright config$(RESET)\n"
   603
   604	_playwright-seed-users:
   605		@printf "$(CYAN)==> Seeding Playwright test users...$(RESET)\n"
   606		@cd $(ROOT_DIR) && $(PLAYWRIGHT_ENV) $(COMPOSE_PLAYWRIGHT) exec -T mysql \
   607			mysql -u root -p$(PLAYWRIGHT_DB_ROOT_PASSWORD) $(PLAYWRIGHT_DB_NAME) \
   608			< $(ROOT_DIR)/db/fixtures/playwright_users.sql && \
   609			printf "$(GREEN)✓ Test users seeded$(RESET)\n" || \
   610			(printf "$(RED)✗ Failed to seed test users$(RESET)\n" && exit 1)
   611
   612	_playwright-seed-docs-data:
   613		@printf "$(CYAN)==> Seeding Playwright documentation screenshot data...$(RESET)\n"
   614		@cd $(ROOT_DIR) && $(PLAYWRIGHT_ENV) $(COMPOSE_PLAYWRIGHT) exec -T mysql \
   615			mysql -u root -p$(PLAYWRIGHT_DB_ROOT_PASSWORD) $(PLAYWRIGHT_DB_NAME) \
   616			< $(ROOT_DIR)/db/fixtures/playwright_docs_screenshots.sql && \
   617			printf "$(GREEN)✓ Documentation screenshot data seeded$(RESET)\n" || \
   618			(printf "$(RED)✗ Failed to seed documentation screenshot data$(RESET)\n" && exit 1)
   619
   620	playwright-stack: check-docker _playwright-seed-templates ## [test] Bring up Playwright E2E stack (CI-only fixtures)
   621		@printf "$(CYAN)==> Bringing up Playwright E2E stack...$(RESET)\n"
   622		@cd $(ROOT_DIR) && $(PLAYWRIGHT_ENV) $(COMPOSE_PLAYWRIGHT) up -d --build --wait \
   623			traefik mysql mailpit api app && \
   624			printf "$(GREEN)✓ Playwright stack started$(RESET)\n" || \
   625			(printf "$(RED)✗ playwright-stack up failed$(RESET)\n" && exit 1)
   626		@printf "$(CYAN)Waiting for /api/health/ready (timeout: $(PLAYWRIGHT_HEALTH_TIMEOUT)s)...$(RESET)\n"
   627		@SECONDS_ELAPSED=0; HEALTH_OK=0; \
   628		while [ $$SECONDS_ELAPSED -lt $(PLAYWRIGHT_HEALTH_TIMEOUT) ]; do \
   629			if curl -sf -H "Host: localhost" $(PLAYWRIGHT_HEALTH_ENDPOINT) >/dev/null 2>&1; then \
   630				HEALTH_OK=1; break; \
   631			fi; \
   632			printf "."; sleep 2; SECONDS_ELAPSED=$$((SECONDS_ELAPSED+2)); \
   633		done; \
   634		if [ "$$HEALTH_OK" -eq 0 ]; then \
   635			printf "\n$(RED)Health check timed out — Playwright stack failed to come up$(RESET)\n"; \
   636			printf "\n$(YELLOW)Last 50 lines of API logs:$(RESET)\n"; \
   637			$(PLAYWRIGHT_ENV) $(COMPOSE_PLAYWRIGHT) logs api --tail=50; \
   638			exit 1; \
   639		fi; \
   640		printf "\n$(GREEN)✓ API ready$(RESET)\n"
   641		@if [ -f $(ROOT_DIR)/db/fixtures/playwright_users.sql ]; then \
   642			$(MAKE) _playwright-seed-users; \
   643		else \
   644			printf "$(YELLOW)⚠ db/fixtures/playwright_users.sql missing — skipping user seed$(RESET)\n"; \
   645		fi
   646		@printf "\n$(CYAN)Playwright stack ready:$(RESET)\n"
   647		@printf "  App + API: $(PLAYWRIGHT_BASE_URL)\n"
   648		@printf "  API direct: $(PLAYWRIGHT_API_BASE_URL)/api\n"
   649		@printf "  Run tests: cd app && PLAYWRIGHT_BASE_URL=$(PLAYWRIGHT_BASE_URL) npx playwright test\n"
   650		@printf "  Tear down: make playwright-stack-down\n"
   651
   652	playwright-stack-down: check-docker ## [test] Tear down Playwright E2E stack and remove volumes
   653		@printf "$(CYAN)==> Tearing down Playwright E2E stack...$(RESET)\n"
   654		@cd $(ROOT_DIR) && $(PLAYWRIGHT_ENV) $(COMPOSE_PLAYWRIGHT) down -v && \
   655			printf "$(GREEN)✓ Playwright stack torn down$(RESET)\n" || \
   656			(printf "$(RED)✗ playwright-stack-down failed$(RESET)\n" && exit 1)
   657		@# Restore the dev's api/config.yml if a backup was taken at stack-up time
   658		@if [ -f $(ROOT_DIR)/api/config.yml.devbackup ]; then \
   659			printf "$(YELLOW)Restoring api/config.yml from api/config.yml.devbackup$(RESET)\n"; \
   660			mv $(ROOT_DIR)/api/config.yml.devbackup $(ROOT_DIR)/api/config.yml; \
   661			printf "$(GREEN)✓ api/config.yml restored$(RESET)\n"; \
   662		fi
   663
   664	playwright-stack-logs: check-docker ## [test] Tail Playwright E2E stack logs
   665		@cd $(ROOT_DIR) && $(PLAYWRIGHT_ENV) $(COMPOSE_PLAYWRIGHT) logs -f --tail=50
   666
   667	docs-screenshots: playwright-stack _playwright-seed-docs-data ## [docs] Generate documentation screenshots and provenance
   668		@printf "$(CYAN)==> Generating documentation screenshots...$(RESET)\n"
   669		@(cd $(ROOT_DIR)/app && \
   670			PLAYWRIGHT_BASE_URL=$(PLAYWRIGHT_BASE_URL) PLAYWRIGHT_API_BASE_URL=$(PLAYWRIGHT_API_BASE_URL) \
   671			npm run docs:screenshots && \
   672			printf "$(GREEN)✓ Documentation screenshots generated$(RESET)\n") || \
   673			(printf "$(RED)✗ docs screenshot generation failed$(RESET)\n" && exit 1)
   674		@$(MAKE) verify-doc-screenshots
   675		@printf "\n$(CYAN)Documentation screenshots written to:$(RESET) documentation/static/img/generated/\n"
   676		@printf "$(YELLOW)Tear down the Playwright stack with: make docs-screenshots-down$(RESET)\n"
   677
   678	docs-screenshots-down: playwright-stack-down ## [docs] Tear down the docs screenshot Playwright stack
   679
   680	verify-doc-screenshots: ## [docs] Verify documentation screenshot references and provenance
.gitignore-88-# Superpowers SDD scratch (ledger, task briefs, review packages)
.gitignore-89-.superpowers/
.gitignore-90-
.gitignore:91:# Analysis-snapshot release Zenodo packaging output (#573 Slice C): staging
.gitignore:92:# trees + archives generated by `make analysis-release-zenodo-package`.
.gitignore:93:outputs/analysis-release-zenodo/
--
AGENTS.md-112-
AGENTS.md-113-### Analysis-snapshot releases (#573)
AGENTS.md-114-
AGENTS.md:115:Analysis-snapshot **releases** are immutable, content-addressed, frozen exports of the public-ready snapshots above (functional clusters, phenotype clusters, phenotype-functional correlation) — the same durable-artifact pattern as the NDDScore/Zenodo release layer, applied to derived analysis. Migration `045_add_analysis_snapshot_release.sql` adds three tables (`analysis_snapshot_release` head + `_member` pinned-snapshot lineage + `_file` per-file gzipped content) and bumped `EXPECTED_LATEST_MIGRATION`/`EXPECTED_MIGRATION_COUNT` in `api/functions/migration-manifest.R`. A release stores its **own** frozen copies (canonical-JSON payloads, raw reproducibility bytes, README, manifest, checksums, a pre-built `bundle.tar.gz`) — never a reference to the source snapshot rows — so it survives snapshot pruning/refresh byte-identically.
AGENTS.md-116-
AGENTS.md-117-- **Content-addressing.** `content_digest` (`analysis_release_content_digest()`, `analysis-snapshot-release-manifest.R`) is a SHA-256 over the invariant scientific content only — `manifest_schema_version`, `source_data_version`, and each layer's `{analysis_type, input_hash, payload_hash, reproducibility_hash, dependencies}` — and deliberately **excludes** `created_at`, `title`, and DOI, so recording provenance metadata never changes release identity. `release_id = "asr_" + content_digest[:16]`; the full 64-char digest is stored and insert is guarded against a same-id/different-digest collision (fails loudly rather than colliding).
AGENTS.md-118-- **Public surface is retrieval-only and DB-only.** `GET /api/analysis/releases`, `.../releases/latest`, `.../releases/<release_id>`, `.../releases/<release_id>/manifest.json`, `.../releases/<release_id>/file?path=<file_path>`, and `.../releases/<release_id>/bundle` are unauthenticated, make no external calls, and are covered by the same cheap-route/external-budget isolation guards as the rest of `/api/analysis`. `.../file` resolves by an **exact `(release_id, file_path)` primary-key lookup** — there is no filesystem access and no path-traversal surface; anything not in `analysis_snapshot_release_file` is a 404. Every public read is pinned to `status = 'published'`, so an unknown release id and a draft release id are indistinguishable (both 404) — drafts are never public. `latest` is declared **before** the dynamic `<release_id>` route (the `/status/_list` shadowing lesson applies here too).
--
AGENTS.md-122-- **Never pruned.** A published release is permanent; `DELETE /api/admin/analysis/releases/<id>` only works on a `draft`. `analysis_snapshot_prune()` (`analysis-snapshot-repository.R`) now skips any `snapshot_id` still referenced by an `analysis_snapshot_release_member` row (`analysis_release_referenced_snapshot_ids()`), so a snapshot pinned by a release keeps serving its live reproducibility endpoint too — even though release integrity never depends on the source snapshot surviving (each release is self-contained).
AGENTS.md-123-- **Build is synchronous, admin, DB-only — the worker is NOT required.** Unlike snapshot refresh, `POST /api/admin/analysis/releases` runs inline on the API request (`analysis_snapshot_release_build()` is called directly from the endpoint, not submitted as an async job): no clustering recompute, no external calls, no LLM, no cache writes. A release can be built even if the worker is down, as long as public-ready snapshots already exist.
AGENTS.md-124-- **`GET .../releases/<release_id>/file?path=<file_path>` uses a query param, not a nested path segment**, because Plumber 1.3.2 has no `<path:.*>` wildcard — only named, typed, single-segment path params (`<id>`, `<id:int>`) exist, so a nested archive path (e.g. `functional_clusters/payload.json`) cannot be expressed as a URL path segment. The manifest's `files[].path` values are the caller's index into this route.
AGENTS.md:125:- **Zenodo operator scripts (#573 Slice C).** `api/scripts/{package,upload}-analysis-release-zenodo.R` (+ helpers `api/functions/analysis-snapshot-release-zenodo-{package,upload,docs}.R`) archive a published release to Zenodo. They are HOST-RUN, HTTP-only (read a published release via the public API only — no DB/worker involvement), draft-only by default behind a `--publish --confirm-publish` double-gate, and support an opt-in `--record-doi` record-back to the additive DOI PATCH endpoint above. `make analysis-release-zenodo-package` / `make analysis-release-zenodo-upload-draft` wrap them for local operator use (the package step also writes a `outputs/analysis-release-zenodo/latest.env` pointer file so the upload step can find the content-addressed archive without a hardcoded filename); the Makefile never passes `--publish`. These scripts are operator-only — NOT sourced by `bootstrap/load_modules.R` — and are exempt from the external-budget guard (one-shot scripts, not request-path code), covered by `test-unit-analysis-release-zenodo-{package,upload}.R`.
AGENTS.md-126-
AGENTS.md-127-### Cluster-analysis statistical soundness (#508–#512)
AGENTS.md-128-
--
AGENTS.md-165-
AGENTS.md-166-NDDScore lives in the four `nddscore_*` tables and three current-release views added by migration `023_add_nddscore_prediction_release.sql`. It is a model-derived prediction layer, separate from curated SysNDD evidence. It must never be represented as a curation status or as changing curated SysNDD classifications; use copy such as `ML prediction`, `Model-derived`, `Prediction layer`, `Separate from curated SysNDD evidence`, and `Not an evidence tier`.
AGENTS.md-167-
AGENTS.md:168:NDDScore imports run through the durable `nddscore_import` System B async job registered in `async_job_handler_registry`. The worker executes the job and needs outbound egress for Zenodo. Imports are serialized with the `nddscore_import` MySQL advisory lock, and activation switches atomically through the generated-column unique key on `active_release_slot`; a currently active release cannot be re-imported as active. The upstream `nddscore_release.json` `is_active` value is ignored because active release state is SysNDD-controlled.
AGENTS.md-169-
AGENTS.md:170:The default NDDScore Zenodo source is deployment-configurable. Prefer `NDDSCORE_ZENODO_RECORD_ID` and `NDDSCORE_ZENODO_API_BASE_URL` in the deployed `.env`; `api/config.yml` carries the same defaults for local/test fallback. Do not reintroduce independent frontend defaults for the record ID.
AGENTS.md-171-
AGENTS.md-172-### Read-only MCP sidecar
AGENTS.md-173-
--
documentation/09-deployment.qmd-279-  -d '{"title": "SysNDD analysis-snapshot release 2026.07", "publish": true}'
documentation/09-deployment.qmd-280-```
documentation/09-deployment.qmd-281-
documentation/09-deployment.qmd:282:The body is optional in every field: `layers` overrides the default registry (functional clusters, phenotype clusters, phenotype-functional correlation), `title`/`scope_statement`/`license` are presentation metadata, and `publish` (default `true`) either publishes immediately or stages a `draft` for review before a Zenodo run. The response is **201** for a genuinely new release, **200** with the existing head for an idempotent rebuild of identical content (no duplicate row), or **400** naming the specific failing layer and reason when a source snapshot is not `available`, fails the hard coherence re-check, is missing its reproducibility bundle, disagrees on source-data version, or has stale dependency lineage.
documentation/09-deployment.qmd-283-
documentation/09-deployment.qmd-284-**Inspect releases:**
documentation/09-deployment.qmd-285-
--
documentation/09-deployment.qmd-299-  -H "Authorization: Bearer <admin-token>"
documentation/09-deployment.qmd-300-```
documentation/09-deployment.qmd-301-
documentation/09-deployment.qmd:302:**Record a DOI** after an out-of-band Zenodo archival run (additive; never changes the release's `content_digest`/`manifest_sha256` — the bytes a consumer already downloaded stay valid):
documentation/09-deployment.qmd-303-
documentation/09-deployment.qmd-304-```bash
documentation/09-deployment.qmd-305-curl -sS -X PATCH https://<host>/api/admin/analysis/releases/<release_id>/doi \
--
documentation/09-deployment.qmd-313-
documentation/09-deployment.qmd-314-**Public download surface** (no auth): `GET /api/analysis/releases/<release_id>/manifest.json` returns the exact stored manifest bytes (`sha256(bytes) == manifest_sha256` on the release head); `GET /api/analysis/releases/<release_id>/file?path=<file_path>` returns one content-addressed file by its exact manifest path (e.g. `path=functional_clusters/payload.json`); `GET /api/analysis/releases/<release_id>/bundle` streams the whole frozen `bundle.tar.gz`.
documentation/09-deployment.qmd-315-
documentation/09-deployment.qmd:316:#### Zenodo archival (operator scripts, #573 Slice C)
documentation/09-deployment.qmd-317-
documentation/09-deployment.qmd:318:Once a release is published (above), an operator can archive it to Zenodo with two host-run scripts (`api/scripts/package-analysis-release-zenodo.R` + `api/scripts/upload-analysis-release-zenodo.R`, mirroring the existing NDDScore/Zenodo release scripts in `../nddscore`). Both are plain HTTP clients: the packager reads the release only through the public `/api/analysis/releases/*` routes above (no DB, no `docker exec`), and the uploader only talks to the Zenodo REST API and (optionally) the admin DOI PATCH endpoint. Neither is wired into `docker-compose.yml`, `bootstrap/load_modules.R`, or the worker — run them on the host (or CI) where a published release is reachable over HTTP.
documentation/09-deployment.qmd-319-
documentation/09-deployment.qmd-320-**Prerequisites:**
documentation/09-deployment.qmd-321-
documentation/09-deployment.qmd-322-- Host R with `httr2`, `jsonlite`, and `digest` (all already in `api/renv.lock`).
documentation/09-deployment.qmd:323:- `ZENODO_TOKEN` — a Zenodo personal access token (`https://zenodo.org/account/settings/applications/tokens/new/`, scope `deposit:write` + `deposit:actions`). Set it in your shell or a git-ignored `.env`; it is **never** committed and the Makefile never bakes it in as a literal.
documentation/09-deployment.qmd-324-- `SYSNDD_API_BASE_URL` (optional) — the public API base to read the release from; defaults to `http://localhost:7778`.
documentation/09-deployment.qmd-325-- `SYSNDD_ADMIN_TOKEN` (optional) — a pre-minted SysNDD Administrator bearer token, only needed for the automated DOI record-back in step 6.
documentation/09-deployment.qmd-326-
--
documentation/09-deployment.qmd-328-
documentation/09-deployment.qmd-329-1. **Package.**
documentation/09-deployment.qmd-330-   ```bash
documentation/09-deployment.qmd:331:   make analysis-release-zenodo-package
documentation/09-deployment.qmd-332-   # or, for an explicit release rather than the current `latest`:
documentation/09-deployment.qmd:333:   ARGS="--release-id asr_<16 hex>" make analysis-release-zenodo-package
documentation/09-deployment.qmd-334-   ```
documentation/09-deployment.qmd:335:   Downloads the release's `bundle.tar.gz`, verifies its checksum, re-stages the files under `analysis_snapshot_release/`, adds Zenodo-facing `README.md`/`DATA_CARD.md`/`SCHEMA.md`/`CHANGELOG.md`/`CITATION.cff`/`zenodo_metadata.json`/`datapackage.json`, runs the packaging safety validator (rejects any planted `.env`/`.git`/sensitive-text content — defense-in-depth; a release payload has no such content by construction), and writes `outputs/analysis-release-zenodo/<release_id>.tar.gz` + `.sha256` plus a `outputs/analysis-release-zenodo/latest.env` pointer file (`ARCHIVE_PATH`/`METADATA_PATH`/`RELEASE_ID`) so the next step can find the content-addressed archive without a hardcoded, drift-prone filename.
documentation/09-deployment.qmd:336:2. **Review** the staging directory (`outputs/analysis-release-zenodo/staging/`) by eye before uploading anything — the validator is a safety net, not a substitute for a human look.
documentation/09-deployment.qmd-337-3. **Upload a draft.**
documentation/09-deployment.qmd-338-   ```bash
documentation/09-deployment.qmd:339:   make analysis-release-zenodo-upload-draft
documentation/09-deployment.qmd:340:   # against the Zenodo sandbox instead of production, for a dry run:
documentation/09-deployment.qmd:341:   UPLOAD_ARGS="--sandbox" make analysis-release-zenodo-upload-draft
documentation/09-deployment.qmd-342-   ```
documentation/09-deployment.qmd:343:   Requires `ZENODO_TOKEN` (the target fails fast with a clear message if it is unset) and `outputs/analysis-release-zenodo/latest.env` (fails fast with "run analysis-release-zenodo-package first" if absent). Creates (or reuses, via `--deposition-id`) a Zenodo deposition, sets its metadata, and streams the archive to the deposition bucket — **always a DRAFT**, never published. Prints the reserved DOI and the draft's Zenodo web URL.
documentation/09-deployment.qmd:344:4. **Review the draft** in the Zenodo web UI (metadata, file listing, reserved DOI) before publishing.
documentation/09-deployment.qmd-345-5. **Publish — deliberately, by hand.** There is no Make target for this on purpose: publishing is a one-way action, so it stays a manual `Rscript` invocation behind a double gate (`analysis_release_zenodo_require_publish_confirmation()` refuses to make any HTTP call unless **both** flags are present):
documentation/09-deployment.qmd-346-   ```bash
documentation/09-deployment.qmd:347:   Rscript api/scripts/upload-analysis-release-zenodo.R \
documentation/09-deployment.qmd:348:     --archive outputs/analysis-release-zenodo/<release_id>.tar.gz \
documentation/09-deployment.qmd:349:     --metadata outputs/analysis-release-zenodo/staging/zenodo_metadata.json \
documentation/09-deployment.qmd:350:     --deposition-id <id-from-step-3> --publish --confirm-publish
documentation/09-deployment.qmd-351-   ```
documentation/09-deployment.qmd:352:6. **Record the DOI** back onto the SysNDD release head — additive only; it never touches `content_digest`/`manifest_sha256`, so the bytes a consumer already downloaded stay valid. Either automatically, by adding `--record-doi` (with `SYSNDD_ADMIN_TOKEN` set) to the publish command in step 5, or by running the manual `curl` command the script prints when `--record-doi` is omitted (equivalent to the `PATCH .../releases/<release_id>/doi` call documented above).
documentation/09-deployment.qmd-353-
documentation/09-deployment.qmd:354:**Defaults and safety.** Every upload is a DRAFT unless step 5's double gate is satisfied explicitly. The archive itself is a self-contained, independently-verifiable copy (its own `manifest.json`, `checksums.sha256`, and — for the two cluster layers — reproducibility bundles), so a Zenodo consumer never depends on SysNDD staying reachable. No manuscript or paper references appear anywhere in the packaged output.
documentation/09-deployment.qmd-355-
documentation/09-deployment.qmd-356-### Disease cross-ontology mapping refresh (`ontology-mapping-cron`)
documentation/09-deployment.qmd-357-
--
documentation/09-deployment.qmd-523-- Run the worker service alongside the API service; `mirai` daemons live in the worker service and jobs are executed by the worker entrypoint, not the web process.
documentation/09-deployment.qmd-524-- The worker service healthcheck should verify the worker process is alive, not probe an HTTP endpoint from the worker container.
documentation/09-deployment.qmd-525-- The worker service needs both internal database access and outbound provider access. In Compose it should stay on `backend` for MySQL/API internals and on the egress-capable `proxy` network for Gemini, PubMed, PubTator, and other external calls. Do not attach it only to the internal `backend` network.
documentation/09-deployment.qmd:526:- Durable jobs run on two lanes so heavy maintenance jobs never head-of-line block interactive work (#486). Production Compose runs two worker containers: `worker` (`ASYNC_JOB_QUEUES=default`) drains latency-sensitive interactive jobs (clustering, phenotype clustering, `llm_generation`, `analysis_snapshot_refresh`, `network_layout_prewarm`), and `worker-maintenance` (`ASYNC_JOB_QUEUES=maintenance`) drains heavy/bulk/external jobs (`publication_date_backfill`, `publication_refresh`, `omim_update`, `hgnc_update`, `comparisons_update`, `ontology_update`, `force_apply_ontology`, `disease_ontology_mapping_refresh`, `nddscore_import`, PubTator refreshes, backups). `worker-maintenance` is a deliberate mirror of `worker` — same image, volumes, env, restart policy, and **both** the `backend` and `proxy` networks (it makes the external PubMed/OMIM/Zenodo/MONDO calls). Routing and priority come from `async_job_queue_for_type()` / `async_job_priority_for_type()` in `api/functions/async-job-service.R` (interactive priority 10 < maintenance 50 < default 100; the claim query orders `priority ASC`). Both containers must be deployed for maintenance jobs to run; scale either lane independently. Local dev runs a single combined `worker` (`ASYNC_JOB_QUEUES=default,maintenance` via `docker-compose.override.yml`, which also profile-gates `worker-maintenance` out of the dev stack), so no second container is needed for development. Override `ASYNC_JOB_MAINTENANCE_QUEUES` to widen the maintenance worker's lanes.
documentation/09-deployment.qmd-527-- Keep the MCP service on internal/private access unless a protected route is deliberately configured. MCP tools and prompts are read-only and must not call Gemini/LLM generation, live external providers, raw SQL/R execution, write routes, admin/user/log/job routes, draft reviews, or re-review data. Analysis tools may read only validated stored summary projections and remain bounded by compact defaults plus `max_response_chars`.
documentation/09-deployment.qmd-528-- Refresh public analysis snapshots after curated data changes or analysis algorithm changes. Submit `analysis_snapshot_refresh` jobs for each supported preset, watch `/api/jobs/<job_id>/status`, and run `make test-mcp-smoke` against the MCP sidecar after activation.
documentation/09-deployment.qmd:529:- Run NDDScore updates from the administrator `/ManageNDDScore` page: **Check Zenodo**, **Download & validate**, then **Import & activate latest release**. The worker needs outbound egress to Zenodo. The previous active release keeps serving until the new release validates and activates successfully. All imported releases are retained for history; there is no automatic pruning. On failure, inspect the release `import_status` and `last_error_message` in the admin view or database.
documentation/09-deployment.qmd:530:- Configure the default NDDScore Zenodo source in the production `.env` file. `NDDSCORE_ZENODO_RECORD_ID` defaults to `20258027`, and `NDDSCORE_ZENODO_API_BASE_URL` defaults to `https://zenodo.org/api/records`. The API and worker containers both receive these variables; if they are missing, `api/config.yml` provides the same defaults.
documentation/09-deployment.qmd-531-- `publication.publication_date_source` records how each `Publication_date` was derived (`pubmed`, `pubmed_partial`, `medline_date`, `unknown`). New ingestions set it automatically, and the `publication_refresh` async job now persists it too. To verify historical rows, run the one-time backfill once after deploy (needs PubMed egress from the **worker**, which fetches on the durable job path):
documentation/09-deployment.qmd-532-  - **Preferred — Administrator HTTP triggers** (no SSH/`docker exec`): `POST /api/admin/publications/verify-dates` enqueues the durable `publication_date_backfill` job (optional JSON `{ "limit": <int>, "dry_run": <bool> }` for a rehearsal); poll `GET /api/admin/publications/verify-dates/status` for the last run's status/summary and confirm `verified + partial` rose. Both routes are Administrator-only. The backfill runs on the `maintenance` lane (the `worker-maintenance` container, which must retain outbound egress to `eutils.ncbi.nlm.nih.gov` on the `proxy` network), so it no longer blocks interactive summary jobs (#486). Its writes now commit in idempotent batches (default 200 rows/batch) so partial progress persists across an interruption, and it is submitted with `max_attempts=2` — a retry resumes from where it left off instead of re-fetching everything (#489).
documentation/09-deployment.qmd-533-  - **Fallback — operator CLI wrapper** (thin wrapper over the same `backfill_publication_dates_run()`): `Rscript db/updates/backfill_publication_dates.R --dry-run --limit=25` for a small rehearsal, `--dry-run` to preview the full run, then `--apply` to write. Dry-run by default; single-flighted via a MySQL advisory lock; chunks at 200 PMIDs/request with a fixed NCBI rate-gate and a per-PMID fallback so one bad PMID does not fail the run (the earlier `NCBI_REQUEST_DELAY_SECONDS` / `BACKFILL_UPDATE_BATCH_SIZE` knobs no longer exist).
--
CHANGELOG.md-8-
CHANGELOG.md-9-## [0.30.3] — 2026-07-19
CHANGELOG.md-10-
CHANGELOG.md:11:Zenodo archival operator scripts for analysis-snapshot releases (#573, Slice C). A published analysis-snapshot release (Slice A) can now be archived to Zenodo with two host-run, HTTP-only scripts — no DB, no worker, no docker exec. Note: 0.30.1 (#574 category clustering) and 0.30.2 (#573 Slice B UI) are reserved for those PRs, which this assumes land first.
CHANGELOG.md-12-
CHANGELOG.md-13-### Added
CHANGELOG.md-14-
CHANGELOG.md:15:- **`api/scripts/package-analysis-release-zenodo.R`**: fetches a published release over the public `/api/analysis/releases/*` API, verifies its bundle checksum, re-stages the files under `analysis_snapshot_release/`, adds Zenodo-facing docs/metadata (`README.md`, `DATA_CARD.md`, `SCHEMA.md`, `CHANGELOG.md`, `CITATION.cff`, `zenodo_metadata.json`, `datapackage.json`), runs a packaging safety validator, and produces a deterministic `<release_id>.tar.gz` + checksum. Writes a `outputs/analysis-release-zenodo/latest.env` pointer file so downstream tooling can find the content-addressed archive without a hardcoded filename.
CHANGELOG.md:16:- **`api/scripts/upload-analysis-release-zenodo.R`**: uploads a packaged archive to a Zenodo deposition (get-or-create, set metadata, stream file to bucket), with an optional, doubly-gated `--publish --confirm-publish` step and an opt-in `--record-doi` record-back to the additive `PATCH /api/admin/analysis/releases/<id>/doi` endpoint. Draft-only by default; publishing is always a deliberate, explicit action.
CHANGELOG.md:17:- Two Make targets, `analysis-release-zenodo-package` and `analysis-release-zenodo-upload-draft`, wrap the scripts for local operator use; the Makefile itself never passes `--publish`.
CHANGELOG.md:18:- Operator runbook documented in `documentation/09-deployment.qmd` under "Zenodo archival (operator scripts, #573 Slice C)".
CHANGELOG.md-19-
CHANGELOG.md-20-## [0.30.0] — 2026-07-18
CHANGELOG.md-21-
--
CHANGELOG.md-23-cluster analyses (functional STRING/Leiden clusters, phenotype MCA/HCPC
CHANGELOG.md-24-clusters, and the phenotype-functional cross-cluster correlation) can now be
CHANGELOG.md-25-frozen into content-addressed, independently-verifiable releases — the same
CHANGELOG.md:26:"immutable dataset release" pattern already used for NDDScore/Zenodo, applied
CHANGELOG.md-27-to the analysis layer.
CHANGELOG.md-28-
CHANGELOG.md-29-### Added
--
CHANGELOG.md-50-  201 for a genuinely new release, 200 for an idempotent rebuild of
CHANGELOG.md-51-  identical content, 400 naming the failing layer/reason otherwise; `GET
CHANGELOG.md-52-  /releases` (including drafts), `GET /releases/<id>`, `POST
CHANGELOG.md:53:  /releases/<id>/publish`, `PATCH /releases/<id>/doi` (additive Zenodo/DOI
CHANGELOG.md-54-  provenance, outside the content hash), and `DELETE /releases/<id>`
CHANGELOG.md-55-  (draft-only — a published release can never be deleted).
CHANGELOG.md-56-- **Fail-closed build gate**: a release is only ever minted from sources that

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-zenodo-upload.R | sed -n '160,360p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
   273	    stop("ZENODO_TOKEN not set and --token not provided", call. = FALSE)
   274	  }
   275	  if (!file.exists(archive_path)) {
   276	    stop(sprintf("Archive does not exist: %s", archive_path), call. = FALSE)
   277	  }
   278	  if (!file.exists(metadata_path)) {
   279	    stop(sprintf("Metadata does not exist: %s", metadata_path), call. = FALSE)
   280	  }
   281
   282	  api <- analysis_release_zenodo_resolve_api(sandbox)
   283	  metadata <- jsonlite::fromJSON(metadata_path, simplifyVector = FALSE)
   284
   285	  deposition <- get_or_create_deposition(api, token, deposition_id = deposition_id)
   286	  resolved_deposition_id <- deposition$id
   287	  bucket_url <- deposition$links$bucket
   288	  reserved_doi <- deposition$metadata$prereserve_doi$doi
   289
   290	  set_metadata(api, token, resolved_deposition_id, metadata)
   291	  upload_bucket(bucket_url, token, archive_path)
   292
   293	  result <- list(
   294	    deposition_id = resolved_deposition_id,
   295	    reserved_doi = reserved_doi %||% NA_character_,
   296	    draft_url = deposition$links$html %||% NA_character_,
   297	    published = FALSE,
   298	    version_doi = NA_character_,
   299	    concept_doi = NA_character_,
   300	    record_url = NA_character_
   301	  )
   302
   303	  if (isTRUE(publish)) {
   304	    published_deposition <- publish_deposition(api, token, resolved_deposition_id)
   305	    result$published <- TRUE
   306	    result$version_doi <- published_deposition$doi %||% NA_character_
   307	    result$concept_doi <- published_deposition$conceptdoi %||% NA_character_
   308	    result$record_url <- published_deposition$links$html %||% NA_character_
   309	  }
   310
   311	  result
   312	}

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-zenodo-docs.R | sed -n '1,220p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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

exec
/bin/bash -lc "nl -ba api/scripts/package-analysis-release-zenodo.R | sed -n '1,240p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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

exec
/bin/bash -lc "nl -ba api/scripts/upload-analysis-release-zenodo.R | sed -n '1,280p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
    19	#     [--token <ZENODO_TOKEN, defaults to env>] [--sandbox] \
    20	#     [--deposition-id <id>] [--publish --confirm-publish] \
    21	#     [--record-doi --release-id <asr_...>] [--api-base-url <SysNDD API base>]
    22	#
    23	# Publish safety interlock: `--publish` alone is REFUSED -- both `--publish`
    24	# AND `--confirm-publish` must be passed, or the run stops before any HTTP
    25	# call is made (`analysis_release_zenodo_require_publish_confirmation()`).
    26	# Without `--publish`, the archive is uploaded to a Zenodo DRAFT only, for
    27	# manual review before publishing.
    28	#
    29	# DOI record-back is OPT-IN and requires BOTH `--record-doi` AND the
    30	# `SYSNDD_ADMIN_TOKEN` env var (a pre-minted SysNDD Administrator bearer
    31	# token) to be set, plus `--release-id` and a successfully PUBLISHED Zenodo
    32	# DOI. Absent any of those, this script NEVER calls the SysNDD admin PATCH
    33	# endpoint automatically -- it prints the exact manual `curl` command instead
    34	# so the operator can record it by hand.
    35	#
    36	# Requires: httr2, jsonlite (api/renv.lock). No DB, no bootstrap, no
    37	# `external_proxy_budget()` -- see AGENTS.md "Analysis-snapshot releases
    38	# (#573)" and `.superpowers/sdd/slice-c-scout.md`.
    39	#
    40	# CWD note: resolves `api/functions/analysis-snapshot-release-zenodo-
    41	# upload.R` relative to ITS OWN file location (same idiom as
    42	# `package-analysis-release-zenodo.R` / `capture-external-fixtures.R`), so it
    43	# may be invoked from any working directory.
    44
    45	# --------------------------------------------------------------------------- #
    46	# Resolve this script's own directory, then source the upload/record-back
    47	# functions (function definitions only -- no top-level network calls in that
    48	# file, so this is safe to do unconditionally, even when this CLI script is
    49	# itself only `source()`d).
    50	# --------------------------------------------------------------------------- #
    51
    52	.upload_analysis_release_zenodo_script_dir <- function() {
    53	  script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
    54	  if (is.null(script_file) || !nzchar(script_file)) {
    55	    full_args <- commandArgs(trailingOnly = FALSE)
    56	    file_arg <- grep("^--file=", full_args, value = TRUE)
    57	    script_file <- if (length(file_arg) >= 1) sub("^--file=", "", file_arg[1]) else "."
    58	  }
    59	  dirname(normalizePath(script_file, mustWork = FALSE))
    60	}
    61
    62	.upload_analysis_release_zenodo_script_dir_value <- .upload_analysis_release_zenodo_script_dir()
    63	source(
    64	  file.path(
    65	    .upload_analysis_release_zenodo_script_dir_value, "..", "functions",
    66	    "analysis-snapshot-release-zenodo-upload.R"
    67	  ),
    68	  local = FALSE
    69	)
    70
    71	# --------------------------------------------------------------------------- #
    72	# CLI arg parsing -- manual commandArgs() flag loop (repo convention; no
    73	# optparse dependency, see `verify-endpoints.R`).
    74	# --------------------------------------------------------------------------- #
    75
    76	#' Parse + run the upload CLI. Wrapped in a function (rather than bare
    77	#' top-level code) so the file can be `source()`d for its function
    78	#' definitions alone -- see the `sys.nframe() == 0L` main-guard at the
    79	#' bottom of this file, which only calls this when the script is run
    80	#' directly (`Rscript upload-analysis-release-zenodo.R`), never when
    81	#' `source()`d (e.g. by a test).
    82	run_upload_analysis_release_zenodo_cli <- function() {
    83	  args <- commandArgs(trailingOnly = TRUE)
    84
    85	  archive <- NULL
    86	  metadata <- NULL
    87	  token <- Sys.getenv("ZENODO_TOKEN", "")
    88	  sandbox <- FALSE
    89	  deposition_id <- NULL
    90	  publish <- FALSE
    91	  confirm_publish <- FALSE
    92	  record_doi <- FALSE
    93	  release_id <- NULL
    94	  api_base_url <- Sys.getenv("SYSNDD_API_BASE_URL", "http://localhost:7778")
    95
    96	  if (length(args) > 0) {
    97	    for (i in seq_along(args)) {
    98	      if (args[i] == "--archive" && i < length(args)) {
    99	        archive <- args[i + 1]
   100	      } else if (args[i] == "--metadata" && i < length(args)) {
   101	        metadata <- args[i + 1]
   102	      } else if (args[i] == "--token" && i < length(args)) {
   103	        token <- args[i + 1]
   104	      } else if (args[i] == "--sandbox") {
   105	        sandbox <- TRUE
   106	      } else if (args[i] == "--deposition-id" && i < length(args)) {
   107	        deposition_id <- args[i + 1]
   108	      } else if (args[i] == "--publish") {
   109	        publish <- TRUE
   110	      } else if (args[i] == "--confirm-publish") {
   111	        confirm_publish <- TRUE
   112	      } else if (args[i] == "--record-doi") {
   113	        record_doi <- TRUE
   114	      } else if (args[i] == "--release-id" && i < length(args)) {
   115	        release_id <- args[i + 1]
   116	      } else if (args[i] == "--api-base-url" && i < length(args)) {
   117	        api_base_url <- args[i + 1]
   118	      }
   119	    }
   120	  }
   121
   122	  if (is.null(archive) || !nzchar(archive)) {
   123	    stop("--archive is required", call. = FALSE)
   124	  }
   125	  if (is.null(metadata) || !nzchar(metadata)) {
   126	    stop("--metadata is required", call. = FALSE)
   127	  }
   128
   129	  result <- analysis_release_zenodo_upload(
   130	    archive_path = archive,
   131	    metadata_path = metadata,
   132	    token = token,
   133	    sandbox = sandbox,
   134	    deposition_id = deposition_id,
   135	    publish = publish,
   136	    confirm_publish = confirm_publish
   137	  )
   138
   139	  cat(sprintf("Zenodo deposition id: %s\n", result$deposition_id))
   140	  cat(sprintf(
   141	    "Zenodo reserved DOI:  %s\n",
   142	    if (is.na(result$reserved_doi)) "not returned" else result$reserved_doi
   143	  ))
   144	  cat(sprintf(
   145	    "Zenodo draft URL:     %s\n",
   146	    if (is.na(result$draft_url)) "not returned" else result$draft_url
   147	  ))
   148
   149	  if (isTRUE(result$published)) {
   150	    cat(sprintf("Published Zenodo DOI: %s\n", result$version_doi))
   151	    cat(sprintf("Published Zenodo URL: %s\n", result$record_url))
   152	  } else {
   153	    cat("Draft uploaded only. Review in Zenodo before publishing.\n")
   154	  }
   155
   156	  .print_doi_record_back(result, release_id, api_base_url, record_doi)
   157
   158	  invisible(result)
   159	}
   160
   161	#' The opt-in DOI record-back step. Never calls the SysNDD admin endpoint
   162	#' unless the operator explicitly asked for it (`--record-doi`) AND supplied
   163	#' credentials (`SYSNDD_ADMIN_TOKEN`) AND the run reached a real, published
   164	#' DOI -- a draft's "reserved" DOI is not final and is deliberately NOT
   165	#' recorded automatically. Otherwise prints the exact manual command.
   166	.print_doi_record_back <- function(result, release_id, api_base_url, record_doi) {
   167	  doi_fields <- list(
   168	    zenodo_record_id = as.character(result$deposition_id),
   169	    zenodo_record_url = if (isTRUE(result$published)) result$record_url else result$draft_url,
   170	    version_doi = if (isTRUE(result$published)) result$version_doi else NA_character_,
   171	    concept_doi = if (isTRUE(result$published)) result$concept_doi else NA_character_
   172	  )
   173
   174	  have_release_id <- !is.null(release_id) && nzchar(release_id)
   175	  have_published_doi <- isTRUE(result$published) &&
   176	    !is.na(result$version_doi) && nzchar(as.character(result$version_doi))
   177	  admin_token <- Sys.getenv("SYSNDD_ADMIN_TOKEN", "")
   178
   179	  if (!have_release_id) {
   180	    cat("\nNo --release-id supplied -- pass one to record or print a DOI record-back command.\n")
   181	    return(invisible(NULL))
   182	  }
   183
   184	  if (isTRUE(record_doi) && nzchar(admin_token) && have_published_doi) {
   185	    updated <- analysis_release_zenodo_record_doi(
   186	      sysndd_api_base_url = api_base_url,
   187	      admin_token = admin_token,
   188	      release_id = release_id,
   189	      doi_fields = doi_fields
   190	    )
   191	    cat("\nDOI recorded on the SysNDD release head:\n")
   192	    cat(sprintf("  release_id:        %s\n", updated$release_id %||% release_id))
   193	    cat(sprintf("  version_doi:       %s\n", updated$version_doi %||% doi_fields$version_doi))
   194	    cat(sprintf("  zenodo_record_url: %s\n", updated$zenodo_record_url %||% doi_fields$zenodo_record_url))
   195	  } else {
   196	    cat(
   197	      "\nDOI not recorded automatically",
   198	      if (!have_published_doi) " (deposition not published yet)" else "",
   199	      ". Run with --record-doi and SYSNDD_ADMIN_TOKEN set after publishing, ",
   200	      "or record it by hand:\n",
   201	      sep = ""
   202	    )
   203	    cat(analysis_release_zenodo_manual_doi_command(api_base_url, release_id, doi_fields), "\n")
   204	  }
   205	  invisible(NULL)
   206	}
   207
   208	# Main guard: `sys.nframe()` is 0 only at the true top level of a directly
   209	# `Rscript`-invoked file; a `source()`d file (e.g. from a test) always adds
   210	# at least one frame, so this line never fires under `source()`. This check
   211	# MUST stay at top level (not inside a function).
   212	if (sys.nframe() == 0L) run_upload_analysis_release_zenodo_cli()

codex
I’ve confirmed the scripts keep the intended host-only separation and draft-default flow. I’m now probing the fail-closed boundaries—archive extraction, staging validation, and the behavior tests—where small R I/O assumptions can undermine the stated safety guarantees.
exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-upload.R | sed -n '1,520p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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

exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-package.R | sed -n '1,520p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
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
    11
    12	library(testthat)
    13
    14	source_api_file("functions/analysis-snapshot-release-zenodo-package.R", local = FALSE)
    15
    16	# --------------------------------------------------------------------------- #
    17	# Shared fixture helpers
    18	# --------------------------------------------------------------------------- #
    19
    20	# A well-formed Zenodo staging directory: the expected top-level docs plus the
    21	# nested analysis_snapshot_release/ subdir with its own manifest+checksums.
    22	#
    23	# Deliberately uses plain `tempfile()`, NOT `withr::local_tempdir()`: the
    24	# latter schedules cleanup via `withr::defer(..., envir = parent.frame())`,
    25	# and `parent.frame()` evaluated INSIDE this helper resolves to this
    26	# function's own (short-lived) call frame, not the calling `test_that()`
    27	# block -- so the directory would be deleted the instant this helper
    28	# returns, before the caller can use it. Session tempdir cleanup at process
    29	# exit is sufficient for a short-lived test run.
    30	make_well_formed_staging <- function() {
    31	  staging <- file.path(tempdir(), paste0("zenodo_staging_", as.integer(stats::runif(1, 1, 1e9))))
    32	  dir.create(staging, recursive = TRUE)
    33	  for (name in c(
    34	    "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
    35	    "datapackage.json", "zenodo_metadata.json", "checksums.sha256"
    36	  )) {
    37	    writeLines("placeholder content", file.path(staging, name))
    38	  }
    39	  dir.create(file.path(staging, "analysis_snapshot_release"))
    40	  writeLines('{"release_id":"asr_test"}', file.path(staging, "analysis_snapshot_release", "manifest.json"))
    41	  writeLines("deadbeef  manifest.json", file.path(staging, "analysis_snapshot_release", "checksums.sha256"))
    42	  staging
    43	}
    44
    45	# Builds a tiny tar.gz with two files + a matching (or deliberately wrong)
    46	# inner checksums.sha256, mirroring the shape of a real release bundle (files
    47	# directly at the archive root -- NOT nested under a named subdirectory,
    48	# unlike the sibling nddscore archive).
    49	build_fixture_bundle <- function(dir, a_sha_override = NULL, b_sha_override = NULL) {
    50	  src <- file.path(dir, paste0("src_", as.integer(stats::runif(1, 1, 1e9))))
    51	  dir.create(src, recursive = TRUE)
    52	  writeLines("file A content", file.path(src, "a.txt"))
    53	  writeLines("file B content", file.path(src, "b.txt"))
    54	  a_sha <- a_sha_override %||% digest::digest(file = file.path(src, "a.txt"), algo = "sha256")
    55	  b_sha <- b_sha_override %||% digest::digest(file = file.path(src, "b.txt"), algo = "sha256")
    56	  cat(
    57	    paste0(a_sha, "  a.txt\n", b_sha, "  b.txt\n"),
    58	    file = file.path(src, "checksums.sha256")
    59	  )
    60
    61	  bundle_path <- file.path(dir, paste0("bundle_", basename(src), ".tar.gz"))
    62	  withr::with_dir(src, {
    63	    utils::tar(
    64	      tarfile = bundle_path, files = c("a.txt", "b.txt", "checksums.sha256"),
    65	      compression = "gzip", tar = "internal"
    66	    )
    67	  })
    68	  bundle_path
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
   188	# validate_staging -- THE SAFETY VALIDATOR
   189	# --------------------------------------------------------------------------- #
   190
   191	test_that("validate_staging: passes on a well-formed staging dir", {
   192	  staging <- make_well_formed_staging()
   193	  expect_no_error(analysis_release_zenodo_validate_staging(staging))
   194	})
   195
   196	test_that("validate_staging: FAILS when a .env file is planted", {
   197	  staging <- make_well_formed_staging()
   198	  writeLines("SECRET=1", file.path(staging, "analysis_snapshot_release", ".env"))
   199	  expect_error(analysis_release_zenodo_validate_staging(staging), "private files")
   200	})
   201
   202	test_that("validate_staging: FAILS when a doc contains an absolute host path + dev username", {
   203	  staging <- make_well_formed_staging()
   204	  writeLines("built at /home/bernt-popp/development/sysndd on this host", file.path(staging, "README.md"))
   205	  expect_error(analysis_release_zenodo_validate_staging(staging), "sensitive")
   206	})
   207
   208	test_that("validate_staging: FAILS when a doc contains a token-shaped string", {
   209	  staging <- make_well_formed_staging()
   210	  writeLines("ZENODO_TOKEN=abc123", file.path(staging, "DATA_CARD.md"))
   211	  expect_error(analysis_release_zenodo_validate_staging(staging), "sensitive")
   212	})
   213
   214	test_that("validate_staging: FAILS when an expected top-level doc is missing", {
   215	  staging <- make_well_formed_staging()
   216	  file.remove(file.path(staging, "SCHEMA.md"))
   217	  expect_error(analysis_release_zenodo_validate_staging(staging), "missing")
   218	})
   219
   220	test_that("validate_staging: FAILS when the nested manifest.json is missing", {
   221	  staging <- make_well_formed_staging()
   222	  file.remove(file.path(staging, "analysis_snapshot_release", "manifest.json"))
   223	  expect_error(analysis_release_zenodo_validate_staging(staging), "missing")
   224	})
   225
   226	# --------------------------------------------------------------------------- #
   227	# extract_and_verify
   228	# --------------------------------------------------------------------------- #
   229
   230	test_that("extract_and_verify: passes with a matching bundle_sha256 and matching inner checksums", {
   231	  work_dir <- withr::local_tempdir()
   232	  bundle_path <- build_fixture_bundle(work_dir)
   233	  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
   234
   235	  exdir <- file.path(work_dir, "extracted")
   236	  result_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, expected_sha, exdir = exdir)
   237
   238	  expect_identical(normalizePath(result_dir), normalizePath(exdir))
   239	  expect_true(file.exists(file.path(result_dir, "a.txt")))
   240	  expect_true(file.exists(file.path(result_dir, "b.txt")))
   241	})
   242
   243	test_that("extract_and_verify: FAILS when the inner checksums.sha256 doesn't match file content", {
   244	  work_dir <- withr::local_tempdir()
   245	  bad_sha <- strrep("0", 64L)
   246	  bundle_path <- build_fixture_bundle(work_dir, a_sha_override = bad_sha)
   247	  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")
   248
   249	  expect_error(
   250	    analysis_release_zenodo_extract_and_verify(
   251	      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_bad_inner")
   252	    ),
   253	    "mismatch"
   254	  )
   255	})
   256
   257	test_that("extract_and_verify: FAILS with a wrong expected_bundle_sha256 (outer verification)", {
   258	  work_dir <- withr::local_tempdir()
   259	  bundle_path <- build_fixture_bundle(work_dir)
   260
   261	  expect_error(
   262	    analysis_release_zenodo_extract_and_verify(
   263	      bundle_path, strrep("f", 64L), exdir = file.path(work_dir, "extracted_bad_outer")
   264	    ),
   265	    "checksum mismatch"
   266	  )
   267	})
   268
   269	# --------------------------------------------------------------------------- #
   270	# fetch_head / download_bundle -- DI seams, no real network
   271	# --------------------------------------------------------------------------- #
   272
   273	test_that("fetch_head: builds the /releases/latest URL and passes the stub's JSON through", {
   274	  captured_url <- NULL
   275	  stub_get_json <- function(url) {
   276	    captured_url <<- url
   277	    list(release_id = "asr_abcdef0123456789", bundle_sha256 = "deadbeef")
   278	  }
   279	  head <- analysis_release_zenodo_fetch_head("http://localhost:7778", "latest", http_get_json = stub_get_json)
   280	  expect_identical(captured_url, "http://localhost:7778/api/analysis/releases/latest")
   281	  expect_identical(head$release_id, "asr_abcdef0123456789")
   282	})
   283
   284	test_that("fetch_head: builds the /releases/<id> URL for an explicit release_id (trailing slash tolerated)", {
   285	  captured_url <- NULL
   286	  stub_get_json <- function(url) {
   287	    captured_url <<- url
   288	    list(release_id = "asr_0000000000000000")
   289	  }
   290	  head <- analysis_release_zenodo_fetch_head(
   291	    "http://localhost:7778/", "asr_0000000000000000", http_get_json = stub_get_json
   292	  )
   293	  expect_identical(captured_url, "http://localhost:7778/api/analysis/releases/asr_0000000000000000")
   294	  expect_identical(head$release_id, "asr_0000000000000000")
   295	})
   296
   297	test_that("download_bundle: builds the /releases/<id>/bundle URL and streams the stub's content through", {
   298	  captured <- new.env()
   299	  work_dir <- withr::local_tempdir()
   300	  dest <- file.path(work_dir, "bundle.tar.gz")
   301	  stub_download <- function(url, destfile) {
   302	    assign("url", url, envir = captured)
   303	    assign("destfile", destfile, envir = captured)
   304	    writeBin(as.raw(c(1, 2, 3)), destfile)
   305	  }
   306	  result <- analysis_release_zenodo_download_bundle(
   307	    "http://localhost:7778", "asr_0000000000000000", dest, http_download = stub_download
   308	  )
   309	  expect_identical(get("url", envir = captured), "http://localhost:7778/api/analysis/releases/asr_0000000000000000/bundle")
   310	  expect_identical(get("destfile", envir = captured), dest)
   311	  expect_identical(result, dest)
   312	  expect_true(file.exists(dest))
   313	})
   314
   315	test_that("download_bundle: errors when the injected downloader produces an empty file", {
   316	  work_dir <- withr::local_tempdir()
   317	  dest <- file.path(work_dir, "empty.tar.gz")
   318	  stub_download <- function(url, destfile) {
   319	    file.create(destfile)
   320	  }
   321	  expect_error(
   322	    analysis_release_zenodo_download_bundle(
   323	      "http://localhost:7778", "asr_x", dest, http_download = stub_download
   324	    ),
   325	    "empty"
   326	  )
   327	})
   328
   329	# --------------------------------------------------------------------------- #
   330	# make_tarball
   331	# --------------------------------------------------------------------------- #
   332
   333	test_that("make_tarball: single top-level dir, plus a sibling .sha256 file with the correct digest", {
   334	  staging <- withr::local_tempdir()
   335	  writeLines("hello", file.path(staging, "README.md"))
   336
   337	  archive_dir <- file.path(withr::local_tempdir(), "archive")
   338	  archive_path <- file.path(archive_dir, "asr_test.tar.gz")
   339	  result <- analysis_release_zenodo_make_tarball(staging, archive_path)
   340
   341	  expect_true(file.exists(result$archive_path))
   342	  expect_true(file.exists(result$archive_sha256_path))
   343	  expect_identical(result$archive_sha256_path, paste0(result$archive_path, ".sha256"))
   344
   345	  sha_line <- readLines(result$archive_sha256_path)
   346	  actual_sha <- digest::digest(file = result$archive_path, algo = "sha256")
   347	  expect_identical(sha_line, paste0(actual_sha, "  ", basename(result$archive_path)))
   348
   349	  entries <- utils::untar(result$archive_path, list = TRUE)
   350	  # utils::untar(list = TRUE) reports entries with a trailing "/" for dirs.
   351	  top_level_dirs <- unique(sub("^([^/]+)/.*$", "\\1", entries))
   352	  expect_length(top_level_dirs, 1L)
   353	  expect_identical(top_level_dirs, basename(staging))
   354	})
   355
   356	# --------------------------------------------------------------------------- #
   357	# package(): full orchestration with stubbed HTTP
   358	# --------------------------------------------------------------------------- #
   359
   360	test_that("package(): fetches, verifies, re-stages, validates, and tars a fake published release", {
   361	  work_dir <- withr::local_tempdir()
   362
   363	  bundle_src <- file.path(work_dir, "bundle_src")
   364	  dir.create(bundle_src)
   365	  writeLines("# SysNDD analysis-snapshot release", file.path(bundle_src, "README.md"))
   366	  writeLines('{"release_id":"asr_deadbeefcafebabe"}', file.path(bundle_src, "manifest.json"))
   367	  readme_sha <- digest::digest(file = file.path(bundle_src, "README.md"), algo = "sha256")
   368	  manifest_sha <- digest::digest(file = file.path(bundle_src, "manifest.json"), algo = "sha256")
   369	  cat(
   370	    paste0(readme_sha, "  README.md\n", manifest_sha, "  manifest.json\n"),
   371	    file = file.path(bundle_src, "checksums.sha256")
   372	  )
   373
   374	  bundle_path <- file.path(work_dir, "bundle.tar.gz")
   375	  withr::with_dir(bundle_src, {
   376	    utils::tar(
   377	      tarfile = bundle_path, files = c("README.md", "manifest.json", "checksums.sha256"),
   378	      compression = "gzip", tar = "internal"
   379	    )
   380	  })
   381	  bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
   382
   383	  fake_head <- list(
   384	    release_id = "asr_deadbeefcafebabe",
   385	    created_at = "2026-07-15T10:00:00Z",
   386	    license = "CC-BY-4.0",
   387	    source_data_version = "v42",
   388	    bundle_sha256 = bundle_sha256
   389	  )
   390	  stub_get_json <- function(url) fake_head
   391	  stub_download <- function(url, destfile) file.copy(bundle_path, destfile, overwrite = TRUE)
   392
   393	  staging_dir <- file.path(work_dir, "staging")
   394	  archive_dir <- file.path(work_dir, "archive")
   395
   396	  result <- analysis_release_zenodo_package(
   397	    api_base_url = "http://localhost:7778",
   398	    release_id = "latest",
   399	    staging_dir = staging_dir,
   400	    archive_dir = archive_dir,
   401	    http_get_json = stub_get_json,
   402	    http_download = stub_download
   403	  )
   404
   405	  expect_identical(result$release_id, "asr_deadbeefcafebabe")
   406	  expect_identical(result$staging_dir, staging_dir)
   407	  expect_true(file.exists(result$archive_path))
   408	  expect_true(file.exists(result$archive_sha256_path))
   409	  expect_true(file.exists(result$zenodo_metadata_path))
   410
   411	  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "README.md")))
   412	  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "manifest.json")))
   413	  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "checksums.sha256")))
   414	  expect_true(file.exists(file.path(staging_dir, "checksums.sha256")))
   415	  expect_true(file.exists(file.path(staging_dir, "datapackage.json")))
   416
   417	  metadata <- jsonlite::fromJSON(result$zenodo_metadata_path, simplifyVector = TRUE)
   418	  expect_identical(metadata$license, "CC-BY-4.0")
   419	  expect_identical(metadata$version, "v42")
   420	  expect_false("doi" %in% names(metadata))
   421
   422	  recorded_sha_line <- readLines(result$archive_sha256_path)
   423	  actual_sha <- digest::digest(file = result$archive_path, algo = "sha256")
   424	  expect_identical(recorded_sha_line, paste0(actual_sha, "  ", basename(result$archive_path)))
   425	})
   426
   427	test_that("package(): rejects when the downloaded bundle fails checksum verification", {
   428	  work_dir <- withr::local_tempdir()
   429	  bundle_path <- build_fixture_bundle(work_dir)
   430
   431	  fake_head <- list(
   432	    release_id = "asr_badbundle00000000",
   433	    created_at = "2026-07-15T10:00:00Z",
   434	    bundle_sha256 = strrep("f", 64L)
   435	  )
   436	  stub_get_json <- function(url) fake_head
   437	  stub_download <- function(url, destfile) file.copy(bundle_path, destfile, overwrite = TRUE)
   438
   439	  expect_error(
   440	    analysis_release_zenodo_package(
   441	      api_base_url = "http://localhost:7778",
   442	      release_id = "latest",
   443	      staging_dir = file.path(work_dir, "staging2"),
   444	      archive_dir = file.path(work_dir, "archive2"),
   445	      http_get_json = stub_get_json,
   446	      http_download = stub_download
   447	    ),
   448	    "checksum mismatch"
   449	  )
   450	})

exec
/bin/bash -lc "rg -n \"analysis_release_(checksums|bundle|file)|tar\\(|untar\\(|checksums.sha256\" api/functions/analysis-snapshot-release* api/tests/testthat/test-unit-analysis-snapshot-release* | head -n 240 && rg -n \"analysis_release_zenodo\" api/tests/testthat | sort" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
api/functions/analysis-snapshot-release.R:442:  # --- Step 8: checksums.sha256 (all files incl. manifest, excl. checksums)-
api/functions/analysis-snapshot-release.R:444:  checksums_bytes <- charToRaw(enc2utf8(analysis_release_checksums_text(checksum_files)))
api/functions/analysis-snapshot-release.R:446:    "checksums.sha256", checksums_bytes, "text/plain"
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:5:# produce the release manifest.json, checksums.sha256 text, and tar.gz
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:79:  expect_true(exists("analysis_release_checksums_text", mode = "function"))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:132:test_that("analysis_release_build_manifest excludes manifest.json and checksums.sha256 from files[]", {
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:136:    list(path = "checksums.sha256", sha256 = "333", bytes = 9L)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:158:test_that("checksums text lists every file except checksums.sha256", {
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:162:    list(path = "checksums.sha256", sha256 = "333", bytes = 9L)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:164:  txt <- analysis_release_checksums_text(files)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:167:  expect_false(grepl("checksums.sha256", txt, fixed = TRUE))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:177:  utils::untar(tarfile, exdir = d)
api/functions/analysis-snapshot-release-zenodo-package.R:17:# a staging-wide checksums.sha256, run the safety validator, then tar.
api/functions/analysis-snapshot-release-zenodo-package.R:92:  "datapackage.json", "zenodo_metadata.json", "checksums.sha256"
api/functions/analysis-snapshot-release-zenodo-package.R:95:.ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED <- c("manifest.json", "checksums.sha256")
api/functions/analysis-snapshot-release-zenodo-package.R:162:#' extract it, then verify the bundle's OWN inner `checksums.sha256` against
api/functions/analysis-snapshot-release-zenodo-package.R:192:  utils::untar(bundle_path, exdir = exdir)
api/functions/analysis-snapshot-release-zenodo-package.R:194:  sha_file <- file.path(exdir, "checksums.sha256")
api/functions/analysis-snapshot-release-zenodo-package.R:196:    stop("Extracted release bundle has no checksums.sha256", call. = FALSE)
api/functions/analysis-snapshot-release-zenodo-package.R:206:      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name), call. = FALSE)
api/functions/analysis-snapshot-release-zenodo-package.R:279:    "manifest.json and checksums.sha256. This is a derived analysis product, not a ",
api/functions/analysis-snapshot-release-zenodo-package.R:307:  rel_paths <- base::setdiff(rel_paths, c("checksums.sha256", "datapackage.json"))
api/functions/analysis-snapshot-release-zenodo-package.R:341:#' Write `checksums.sha256` at the staging root, covering every iterated file
api/functions/analysis-snapshot-release-zenodo-package.R:343:#' `analysis_release_checksums_text()`: `"<sha256>  <path>\n"` lines.
api/functions/analysis-snapshot-release-zenodo-package.R:348:  rel_paths <- rel_paths[rel_paths != "checksums.sha256"]
api/functions/analysis-snapshot-release-zenodo-package.R:360:  out_path <- file.path(staging_dir, "checksums.sha256")
api/functions/analysis-snapshot-release-zenodo-package.R:385:  utils::tar(tarfile = archive_path, files = entries, compression = "gzip", tar = "internal")
api/functions/analysis-snapshot-release-materialize.R:411:    "1. `sha256sum -c checksums.sha256` verifies every file against its recorded digest.",
api/functions/analysis-snapshot-release-manifest.R:3:# (content_digest / release_id), the manifest.json / checksums.sha256
api/functions/analysis-snapshot-release-manifest.R:190:#' `manifest.json` nor `checksums.sha256` can describe their own checksum, so
api/functions/analysis-snapshot-release-manifest.R:198:  self_describing_paths <- c("manifest.json", "checksums.sha256")
api/functions/analysis-snapshot-release-manifest.R:216:#' Build the `checksums.sha256` file content.
api/functions/analysis-snapshot-release-manifest.R:219:#' excluding `checksums.sha256` itself since a file cannot list its own
api/functions/analysis-snapshot-release-manifest.R:225:analysis_release_checksums_text <- function(files) {
api/functions/analysis-snapshot-release-manifest.R:226:  files <- Filter(function(f) f$path != "checksums.sha256", files)
api/functions/analysis-snapshot-release-manifest.R:240:#' is NOT required here — per-file `checksums.sha256` entries plus the
api/functions/analysis-snapshot-release-manifest.R:276:  utils::tar(tarfile = tar_file, files = paths, compression = "none", tar = "internal")
api/functions/analysis-snapshot-release-zenodo-docs.R:40:    "2. Verify `checksums.sha256` at the archive root (and the nested ",
api/functions/analysis-snapshot-release-zenodo-docs.R:41:    "`analysis_snapshot_release/checksums.sha256`).\n",
api/functions/analysis-snapshot-release-zenodo-docs.R:81:    "size and sha256; `checksums.sha256` (both at the archive root and inside ",
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:105:  metadata <- analysis_release_zenodo_build_metadata(head)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:112:  metadata <- analysis_release_zenodo_build_metadata(head, version = "9.9.9", license_id = "cc0-1.0")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:129:  dp <- analysis_release_zenodo_build_datapackage(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:166:  out_path <- analysis_release_zenodo_write_checksums(staging)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:182:  analysis_release_zenodo_write_checksums(staging)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:193:  expect_no_error(analysis_release_zenodo_validate_staging(staging))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:199:  expect_error(analysis_release_zenodo_validate_staging(staging), "private files")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:205:  expect_error(analysis_release_zenodo_validate_staging(staging), "sensitive")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:211:  expect_error(analysis_release_zenodo_validate_staging(staging), "sensitive")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:217:  expect_error(analysis_release_zenodo_validate_staging(staging), "missing")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:223:  expect_error(analysis_release_zenodo_validate_staging(staging), "missing")
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:236:  result_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, expected_sha, exdir = exdir)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:250:    analysis_release_zenodo_extract_and_verify(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:262:    analysis_release_zenodo_extract_and_verify(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:279:  head <- analysis_release_zenodo_fetch_head("http://localhost:7778", "latest", http_get_json = stub_get_json)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:290:  head <- analysis_release_zenodo_fetch_head(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:306:  result <- analysis_release_zenodo_download_bundle(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:322:    analysis_release_zenodo_download_bundle(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:339:  result <- analysis_release_zenodo_make_tarball(staging, archive_path)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:396:  result <- analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:440:    analysis_release_zenodo_package(
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:82:  metadata <- analysis_release_zenodo_build_metadata(head)
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:99:  metadata <- analysis_release_zenodo_build_metadata(head)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:114:  result <- analysis_release_zenodo_get_or_create_deposition(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:138:  analysis_release_zenodo_set_metadata(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:159:  result <- analysis_release_zenodo_publish_deposition(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:184:  result <- analysis_release_zenodo_record_doi(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:21:    analysis_release_zenodo_require_publish_confirmation(TRUE, FALSE),
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:220:  analysis_release_zenodo_record_doi(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:236:  analysis_release_zenodo_record_doi(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:251:  command <- analysis_release_zenodo_manual_doi_command(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:275:  command <- analysis_release_zenodo_manual_doi_command(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:27:  expect_no_error(analysis_release_zenodo_require_publish_confirmation(FALSE, FALSE))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:283:  command <- analysis_release_zenodo_manual_doi_command(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:31:  expect_no_error(analysis_release_zenodo_require_publish_confirmation(TRUE, TRUE))
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:336:  result <- analysis_release_zenodo_upload(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:372:  result <- analysis_release_zenodo_upload(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:399:    analysis_release_zenodo_upload(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:39:  expect_identical(analysis_release_zenodo_resolve_api(TRUE), "https://sandbox.zenodo.org/api")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:40:  expect_identical(analysis_release_zenodo_resolve_api(FALSE), "https://zenodo.org/api")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:415:    analysis_release_zenodo_upload(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:41:  expect_identical(analysis_release_zenodo_resolve_api(), "https://zenodo.org/api")
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:425:    analysis_release_zenodo_upload(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:437:    analysis_release_zenodo_upload(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:59:  result <- analysis_release_zenodo_upload_bucket(
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:75:  analysis_release_zenodo_upload_bucket("https://zenodo.example/bucket/", "token", archive, put = stub_put)
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:94:  result <- analysis_release_zenodo_get_or_create_deposition(

exec
/bin/bash -lc "git diff --check origin/master...HEAD -- ':(exclude).planning/**'; find api/functions api/scripts -maxdepth 1 -type f -name '*.R' -printf '%p\\n' | while IFS= read -r f; do wc -l \""'$f"; done | sort -nr | head -n 25; rg -n "analysis-release-zenodo" Makefile -C 10; git diff origin/master...HEAD -- .gitignore Makefile documentation/09-deployment.qmd api/version_spec.json app/package.json' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 150ms:
600 api/functions/llm-judge-prompts.R
600 api/functions/analysis-snapshot-builder.R
597 api/functions/analysis-snapshot-release-zenodo-package.R
596 api/functions/async-job-repository.R
581 api/functions/external-proxy-functions.R
578 api/functions/analysis-network-layout-functions.R
577 api/functions/llm-types.R
573 api/functions/backup-functions.R
573 api/functions/async-job-worker.R
571 api/functions/response-helpers.R
556 api/functions/ontology-functions.R
556 api/functions/mcp-readonly-provisioner.R
556 api/functions/comparisons-functions.R
555 api/functions/pubtator-functions.R
550 api/functions/analysis-snapshot-repository.R
540 api/functions/analysis-snapshot-release.R
537 api/functions/llm-cache-repository.R
536 api/functions/logging-query-builders.R
534 api/scripts/verify-mcp-select-principal-live.R
528 api/functions/external-proxy-gnomad.R
519 api/functions/comparisons-parsers.R
511 api/scripts/validate-jax-api.R
505 api/scripts/mcp-smoke.R
505 api/functions/nddscore-repository.R
503 api/functions/llm-batch-generator.R
34-RESET := \033[0m
35-
36-# =============================================================================
37-# Default Goal
38-# =============================================================================
39-.DEFAULT_GOAL := help
40-
41-# =============================================================================
42-# PHONY Declarations
43-# =============================================================================
44:.PHONY: help check-r check-npm check-docker install-api install-app dev serve-app build-app verify-app-bundle-budget watch-app test-api test-api-fast test-api-full mcp-transport-spike test-mcp-smoke coverage lint-api lint-app format-api format-app verify-seo-app code-quality-audit pre-commit ci-local _ci-cleanup preflight docker-build docker-up docker-down docker-dev docker-dev-db docker-logs docker-status cache-clear refresh-analysis-snapshots install-dev doctor worktree-setup worktree-prune refresh-fixtures test-ci-scripts verify-gate playwright-stack playwright-stack-down playwright-stack-logs docs-screenshots docs-screenshots-down verify-doc-screenshots _playwright-seed-templates _playwright-seed-users _playwright-seed-docs-data analysis-release-zenodo-package analysis-release-zenodo-upload-draft
45-
46-# =============================================================================
47-# Help Target (Self-documenting)
48-# =============================================================================
49-help: ## Show this help message
50-	@printf "SysNDD Development Commands\n\n"
51-	@printf "$(CYAN)Environment:$(RESET)\n"
52-	@grep -E '^[a-zA-Z_-]+:.*?## \[env\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[env\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
53-	@printf "\n$(CYAN)Development:$(RESET)\n"
54-	@grep -E '^[a-zA-Z_-]+:.*?## \[dev\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[dev\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
--
374-	@printf "  - Containers start without errors\n"
375-	@printf "  - /api/health/ready returns 200\n"
376-	@printf "  - Database connectivity verified\n"
377-
378-# ARGS/UPLOAD_ARGS are passed through to the analysis-release Zenodo operator
379-# scripts below (e.g. ARGS="--release-id asr_..." or UPLOAD_ARGS="--sandbox");
380-# default empty so --warn-undefined-variables stays quiet.
381-ARGS ?=
382-UPLOAD_ARGS ?=
383-
384:analysis-release-zenodo-package: check-r ## [quality] Package a published analysis-snapshot release into a Zenodo staging dir + tarball
385-	@printf "$(CYAN)==> Packaging analysis-snapshot release for Zenodo...$(RESET)\n"
386:	@cd $(ROOT_DIR) && $(HOST_RSCRIPT) api/scripts/package-analysis-release-zenodo.R $(ARGS) && \
387:		printf "$(GREEN)✓ analysis-release-zenodo-package complete (see outputs/analysis-release-zenodo/latest.env)$(RESET)\n" || \
388:		(printf "$(RED)✗ analysis-release-zenodo-package failed$(RESET)\n" && exit 1)
389-
390:analysis-release-zenodo-upload-draft: check-r ## [quality] Upload the last-packaged release to a Zenodo DRAFT (never publishes)
391-	@if [ -z "$${ZENODO_TOKEN:-}" ]; then \
392-		printf "$(RED)✗ ZENODO_TOKEN is not set (export it in your shell or .env before running this target)$(RESET)\n"; \
393-		exit 1; \
394-	fi
395:	@if [ ! -f "$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env" ]; then \
396:		printf "$(RED)✗ outputs/analysis-release-zenodo/latest.env not found -- run 'make analysis-release-zenodo-package' first$(RESET)\n"; \
397-		exit 1; \
398-	fi
399-	@printf "$(CYAN)==> Uploading last-packaged analysis-snapshot release to a Zenodo DRAFT (never publishes)...$(RESET)\n"
400:	@. "$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env" && \
401:		cd $(ROOT_DIR) && $(HOST_RSCRIPT) api/scripts/upload-analysis-release-zenodo.R \
402-			--archive "$$ARCHIVE_PATH" --metadata "$$METADATA_PATH" --release-id "$$RELEASE_ID" $(UPLOAD_ARGS) && \
403:		printf "$(GREEN)✓ analysis-release-zenodo-upload-draft complete -- DRAFT only; publishing is a deliberate manual step (see documentation/09-deployment.qmd)$(RESET)\n" || \
404:		(printf "$(RED)✗ analysis-release-zenodo-upload-draft failed$(RESET)\n" && exit 1)
405-
406-# =============================================================================
407-# Docker Targets
408-# =============================================================================
409-# Compose file sets:
410-#   Production:  docker-compose.yml
411-#   Development: docker-compose.yml + docker-compose.override.yml (auto-loaded)
412-#   Full dev:    docker-compose.yml + docker-compose.override.yml + docker-compose.dev.yml
413-COMPOSE_DEV := docker compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.dev.yml
414-COMPOSE_DB_DEV := docker compose -p sysndd -f docker-compose.dev.yml
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
diff --git a/Makefile b/Makefile
index f6a2865c..85dae147 100644
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
@@ -375,6 +375,34 @@ preflight: check-docker ## [quality] Run production preflight validation
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
+	@. "$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env" && \
+		cd $(ROOT_DIR) && $(HOST_RSCRIPT) api/scripts/upload-analysis-release-zenodo.R \
+			--archive "$$ARCHIVE_PATH" --metadata "$$METADATA_PATH" --release-id "$$RELEASE_ID" $(UPLOAD_ARGS) && \
+		printf "$(GREEN)✓ analysis-release-zenodo-upload-draft complete -- DRAFT only; publishing is a deliberate manual step (see documentation/09-deployment.qmd)$(RESET)\n" || \
+		(printf "$(RED)✗ analysis-release-zenodo-upload-draft failed$(RESET)\n" && exit 1)
+
 # =============================================================================
 # Docker Targets
 # =============================================================================
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
index ff2dc9b5..e5cda099 100644
--- a/documentation/09-deployment.qmd
+++ b/documentation/09-deployment.qmd
@@ -313,7 +313,45 @@ curl -sS -X PATCH https://<host>/api/admin/analysis/releases/<release_id>/doi \

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
+   Downloads the release's `bundle.tar.gz`, verifies its checksum, re-stages the files under `analysis_snapshot_release/`, adds Zenodo-facing `README.md`/`DATA_CARD.md`/`SCHEMA.md`/`CHANGELOG.md`/`CITATION.cff`/`zenodo_metadata.json`/`datapackage.json`, runs the packaging safety validator (rejects any planted `.env`/`.git`/sensitive-text content — defense-in-depth; a release payload has no such content by construction), and writes `outputs/analysis-release-zenodo/<release_id>.tar.gz` + `.sha256` plus a `outputs/analysis-release-zenodo/latest.env` pointer file (`ARCHIVE_PATH`/`METADATA_PATH`/`RELEASE_ID`) so the next step can find the content-addressed archive without a hardcoded, drift-prone filename.
+2. **Review** the staging directory (`outputs/analysis-release-zenodo/staging/`) by eye before uploading anything — the validator is a safety net, not a substitute for a human look.
+3. **Upload a draft.**
+   ```bash
+   make analysis-release-zenodo-upload-draft
+   # against the Zenodo sandbox instead of production, for a dry run:
+   UPLOAD_ARGS="--sandbox" make analysis-release-zenodo-upload-draft
+   ```
+   Requires `ZENODO_TOKEN` (the target fails fast with a clear message if it is unset) and `outputs/analysis-release-zenodo/latest.env` (fails fast with "run analysis-release-zenodo-package first" if absent). Creates (or reuses, via `--deposition-id`) a Zenodo deposition, sets its metadata, and streams the archive to the deposition bucket — **always a DRAFT**, never published. Prints the reserved DOI and the draft's Zenodo web URL.
+4. **Review the draft** in the Zenodo web UI (metadata, file listing, reserved DOI) before publishing.
+5. **Publish — deliberately, by hand.** There is no Make target for this on purpose: publishing is a one-way action, so it stays a manual `Rscript` invocation behind a double gate (`analysis_release_zenodo_require_publish_confirmation()` refuses to make any HTTP call unless **both** flags are present):
+   ```bash
+   Rscript api/scripts/upload-analysis-release-zenodo.R \
+     --archive outputs/analysis-release-zenodo/<release_id>.tar.gz \
+     --metadata outputs/analysis-release-zenodo/staging/zenodo_metadata.json \
+     --deposition-id <id-from-step-3> --publish --confirm-publish
+   ```
+6. **Record the DOI** back onto the SysNDD release head — additive only; it never touches `content_digest`/`manifest_sha256`, so the bytes a consumer already downloaded stay valid. Either automatically, by adding `--record-doi` (with `SYSNDD_ADMIN_TOKEN` set) to the publish command in step 5, or by running the manual `curl` command the script prints when `--record-doi` is omitted (equivalent to the `PATCH .../releases/<release_id>/doi` call documented above).
+
+**Defaults and safety.** Every upload is a DRAFT unless step 5's double gate is satisfied explicitly. The archive itself is a self-contained, independently-verifiable copy (its own `manifest.json`, `checksums.sha256`, and — for the two cluster layers — reproducibility bundles), so a Zenodo consumer never depends on SysNDD staying reachable. No manuscript or paper references appear anywhere in the packaged output.

 ### Disease cross-ontology mapping refresh (`ontology-mapping-cron`)


exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-upload.R | sed -n '235,500p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-upload.R | sed -n '1,235p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
exec
/bin/bash -lc "nl -ba api/tests/testthat/test-unit-analysis-release-zenodo-package.R | sed -n '350,500p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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

 succeeded in 0ms:
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

 succeeded in 0ms:
   350	  # utils::untar(list = TRUE) reports entries with a trailing "/" for dirs.
   351	  top_level_dirs <- unique(sub("^([^/]+)/.*$", "\\1", entries))
   352	  expect_length(top_level_dirs, 1L)
   353	  expect_identical(top_level_dirs, basename(staging))
   354	})
   355
   356	# --------------------------------------------------------------------------- #
   357	# package(): full orchestration with stubbed HTTP
   358	# --------------------------------------------------------------------------- #
   359
   360	test_that("package(): fetches, verifies, re-stages, validates, and tars a fake published release", {
   361	  work_dir <- withr::local_tempdir()
   362
   363	  bundle_src <- file.path(work_dir, "bundle_src")
   364	  dir.create(bundle_src)
   365	  writeLines("# SysNDD analysis-snapshot release", file.path(bundle_src, "README.md"))
   366	  writeLines('{"release_id":"asr_deadbeefcafebabe"}', file.path(bundle_src, "manifest.json"))
   367	  readme_sha <- digest::digest(file = file.path(bundle_src, "README.md"), algo = "sha256")
   368	  manifest_sha <- digest::digest(file = file.path(bundle_src, "manifest.json"), algo = "sha256")
   369	  cat(
   370	    paste0(readme_sha, "  README.md\n", manifest_sha, "  manifest.json\n"),
   371	    file = file.path(bundle_src, "checksums.sha256")
   372	  )
   373
   374	  bundle_path <- file.path(work_dir, "bundle.tar.gz")
   375	  withr::with_dir(bundle_src, {
   376	    utils::tar(
   377	      tarfile = bundle_path, files = c("README.md", "manifest.json", "checksums.sha256"),
   378	      compression = "gzip", tar = "internal"
   379	    )
   380	  })
   381	  bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
   382
   383	  fake_head <- list(
   384	    release_id = "asr_deadbeefcafebabe",
   385	    created_at = "2026-07-15T10:00:00Z",
   386	    license = "CC-BY-4.0",
   387	    source_data_version = "v42",
   388	    bundle_sha256 = bundle_sha256
   389	  )
   390	  stub_get_json <- function(url) fake_head
   391	  stub_download <- function(url, destfile) file.copy(bundle_path, destfile, overwrite = TRUE)
   392
   393	  staging_dir <- file.path(work_dir, "staging")
   394	  archive_dir <- file.path(work_dir, "archive")
   395
   396	  result <- analysis_release_zenodo_package(
   397	    api_base_url = "http://localhost:7778",
   398	    release_id = "latest",
   399	    staging_dir = staging_dir,
   400	    archive_dir = archive_dir,
   401	    http_get_json = stub_get_json,
   402	    http_download = stub_download
   403	  )
   404
   405	  expect_identical(result$release_id, "asr_deadbeefcafebabe")
   406	  expect_identical(result$staging_dir, staging_dir)
   407	  expect_true(file.exists(result$archive_path))
   408	  expect_true(file.exists(result$archive_sha256_path))
   409	  expect_true(file.exists(result$zenodo_metadata_path))
   410
   411	  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "README.md")))
   412	  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "manifest.json")))
   413	  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "checksums.sha256")))
   414	  expect_true(file.exists(file.path(staging_dir, "checksums.sha256")))
   415	  expect_true(file.exists(file.path(staging_dir, "datapackage.json")))
   416
   417	  metadata <- jsonlite::fromJSON(result$zenodo_metadata_path, simplifyVector = TRUE)
   418	  expect_identical(metadata$license, "CC-BY-4.0")
   419	  expect_identical(metadata$version, "v42")
   420	  expect_false("doi" %in% names(metadata))
   421
   422	  recorded_sha_line <- readLines(result$archive_sha256_path)
   423	  actual_sha <- digest::digest(file = result$archive_path, algo = "sha256")
   424	  expect_identical(recorded_sha_line, paste0(actual_sha, "  ", basename(result$archive_path)))
   425	})
   426
   427	test_that("package(): rejects when the downloaded bundle fails checksum verification", {
   428	  work_dir <- withr::local_tempdir()
   429	  bundle_path <- build_fixture_bundle(work_dir)
   430
   431	  fake_head <- list(
   432	    release_id = "asr_badbundle00000000",
   433	    created_at = "2026-07-15T10:00:00Z",
   434	    bundle_sha256 = strrep("f", 64L)
   435	  )
   436	  stub_get_json <- function(url) fake_head
   437	  stub_download <- function(url, destfile) file.copy(bundle_path, destfile, overwrite = TRUE)
   438
   439	  expect_error(
   440	    analysis_release_zenodo_package(
   441	      api_base_url = "http://localhost:7778",
   442	      release_id = "latest",
   443	      staging_dir = file.path(work_dir, "staging2"),
   444	      archive_dir = file.path(work_dir, "archive2"),
   445	      http_get_json = stub_get_json,
   446	      http_download = stub_download
   447	    ),
   448	    "checksum mismatch"
   449	  )
   450	})

exec
/bin/bash -lc "rg -n \"analysis_release_bundle|analysis_release_checksums|analysis_snapshot_release_file|bundle_sha256\" api/functions/analysis-snapshot-release.R api/functions/analysis-snapshot-release-* api/endpoints/analysis_snapshot_endpoints.R api/services -g '*.R' | head -n 250" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
rg: api/endpoints/analysis_snapshot_endpoints.R: No such file or directory (os error 2)
api/functions/analysis-snapshot-release-zenodo-package.R:22:# checksum is SHA-256 (`bundle_sha256` on the release head), not the MD5
api/functions/analysis-snapshot-release-zenodo-package.R:128:#'   source_data_version, bundle_sha256, manifest, ...).
api/functions/analysis-snapshot-release-zenodo-package.R:161:#' Verify a downloaded bundle against the release head's `bundle_sha256`,
api/functions/analysis-snapshot-release-zenodo-package.R:169:#' @param expected_bundle_sha256 The release head's `bundle_sha256`.
api/functions/analysis-snapshot-release-zenodo-package.R:173:    bundle_path, expected_bundle_sha256, exdir = NULL) {
api/functions/analysis-snapshot-release-zenodo-package.R:177:  actual_bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
api/functions/analysis-snapshot-release-zenodo-package.R:178:  expected <- tolower(as.character(expected_bundle_sha256 %||% "")[[1]])
api/functions/analysis-snapshot-release-zenodo-package.R:179:  if (!identical(tolower(actual_bundle_sha256), expected)) {
api/functions/analysis-snapshot-release-zenodo-package.R:182:      expected, actual_bundle_sha256
api/functions/analysis-snapshot-release-zenodo-package.R:343:#' `analysis_release_checksums_text()`: `"<sha256>  <path>\n"` lines.
api/functions/analysis-snapshot-release-zenodo-package.R:532:  extracted_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, head$bundle_sha256)
api/functions/analysis-snapshot-release-manifest.R:225:analysis_release_checksums_text <- function(files) {
api/functions/analysis-snapshot-release-repository.R:7:# `analysis_snapshot_release_file` (per-archive-file blob + checksum).
api/functions/analysis-snapshot-release-repository.R:64:  "content_digest, manifest_sha256, bundle_sha256, bundle_bytes,",
api/functions/analysis-snapshot-release-repository.R:86:#' `bundle_sha256`, `bundle_gzip` (raw), plus optional `release_version`,
api/functions/analysis-snapshot-release-repository.R:124:         content_digest, manifest_sha256, bundle_sha256, bundle_gzip, bundle_bytes,
api/functions/analysis-snapshot-release-repository.R:135:        .analysis_release_chr(release_head$bundle_sha256),
api/functions/analysis-snapshot-release-repository.R:173:        "INSERT INTO analysis_snapshot_release_file (
api/functions/analysis-snapshot-release-repository.R:217:    "bundle_sha256", "license", "file_count", "total_bytes"
api/functions/analysis-snapshot-release-repository.R:348:       FROM analysis_snapshot_release_file f
api/functions/analysis-snapshot-release-repository.R:382:    "SELECT bundle_gzip, bundle_sha256
api/functions/analysis-snapshot-release-repository.R:394:    sha256 = as.character(rows$bundle_sha256[[1]]),
api/functions/analysis-snapshot-release.R:444:  checksums_bytes <- charToRaw(enc2utf8(analysis_release_checksums_text(checksum_files)))
api/functions/analysis-snapshot-release.R:455:  bundle_sha256 <- analysis_release_sha256(bundle_gzip)
api/functions/analysis-snapshot-release.R:472:    bundle_sha256 = bundle_sha256,

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release.R | sed -n '390,490p'; nl -ba api/functions/analysis-snapshot-release-manifest.R | sed -n '190,250p'; nl -ba api/functions/analysis-snapshot-release-repository.R | sed -n '360,410p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
exec
/bin/bash -lc 'git log --oneline --decorate origin/master..HEAD && git diff --unified=80 origin/master...HEAD -- api/functions/analysis-snapshot-release-zenodo-package.R api/functions/analysis-snapshot-release-zenodo-upload.R api/scripts/package-analysis-release-zenodo.R api/scripts/upload-analysis-release-zenodo.R' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
   390	      release_id
   391	    ), call. = FALSE)
   392	  }
   393
   394	  # README carries the resolved release_id now that it is known.
   395	  readme_bytes <- .analysis_release_readme_bytes(
   396	    release_id, title, scope_statement, license, shared_source_version, layer_entries
   397	  )
   398	  artifacts <- c(
   399	    list(.analysis_release_artifact("README.md", readme_bytes, "text/markdown")),
   400	    artifacts
   401	  )
   402
   403	  created_at <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
   404
   405	  # --- Step 7: manifest.json (files[] excludes manifest + checksums) -------
   406	  content_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256, bytes = a$byte_size))
   407	  manifest_obj <- analysis_release_build_manifest(list(
   408	    release_id = release_id,
   409	    release_version = NULL,
   410	    title = title,
   411	    created_at = created_at,
   412	    license = license %||% "CC-BY-4.0",
   413	    scope_statement = scope_statement,
   414	    generator = list(
   415	      name = "sysndd-analysis-snapshot-release-build",
   416	      manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
   417	      reproducibility_schema_version = if (exists("ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION")) {
   418	        ANALYSIS_REPRODUCIBILITY_SCHEMA_VERSION
   419	      } else {
   420	        NULL
   421	      }
   422	    ),
   423	    source = list(
   424	      source_data_version = shared_source_version,
   425	      db_release = list(
   426	        version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
   427	        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
   428	      ),
   429	      snapshots = lapply(layer_entries, function(e) {
   430	        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
   431	      })
   432	    ),
   433	    layers = layer_entries,
   434	    files = content_files,
   435	    content_digest = content_digest
   436	  ))
   437	  manifest_bytes <- analysis_release_canonical_bytes(manifest_obj)
   438	  manifest_artifact <- .analysis_release_artifact("manifest.json", manifest_bytes, "application/json")
   439	  manifest_sha256 <- manifest_artifact$sha256
   440	  artifacts[[length(artifacts) + 1L]] <- manifest_artifact
   441
   442	  # --- Step 8: checksums.sha256 (all files incl. manifest, excl. checksums)-
   443	  checksum_files <- lapply(artifacts, function(a) list(path = a$path, sha256 = a$sha256))
   444	  checksums_bytes <- charToRaw(enc2utf8(analysis_release_checksums_text(checksum_files)))
   445	  artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   446	    "checksums.sha256", checksums_bytes, "text/plain"
   447	  )
   448
   449	  # --- Step 9: bundle.tar.gz (all files) -----------------------------------
   450	  named_raw <- stats::setNames(
   451	    lapply(artifacts, function(a) a$bytes),
   452	    vapply(artifacts, function(a) a$path, character(1))
   453	  )
   454	  bundle_gzip <- analysis_release_build_tar_gz(named_raw)
   455	  bundle_sha256 <- analysis_release_sha256(bundle_gzip)
   456
   457	  # --- Step 2 (re-assert immediately before insert) ------------------------
   458	  # A FRESH DB re-read via the loader seam (not the cached `loaded`) so a source
   459	  # snapshot that was refreshed between the first read and now is caught. Combined
   460	  # with the per-preset locks above, this closes the TOCTOU window.
   461	  .analysis_release_assert_lineage(loaded)
   462	  .analysis_release_verify_lineage_unchanged(layer_specs, loaded, loader, conn)
   463
   464	  # --- Step 10: persist ----------------------------------------------------
   465	  release_head <- list(
   466	    release_id = release_id,
   467	    release_version = NULL,
   468	    title = title,
   469	    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
   470	    content_digest = content_digest,
   471	    manifest_sha256 = manifest_sha256,
   472	    bundle_sha256 = bundle_sha256,
   473	    bundle_gzip = bundle_gzip,
   474	    source_data_version = shared_source_version,
   475	    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
   476	    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
   477	    scope_statement = scope_statement,
   478	    license = license %||% "CC-BY-4.0",
   479	    created_by_user_id = created_by
   480	  )
   481
   482	  members <- lapply(layer_entries, function(e) {
   483	    list(
   484	      analysis_type = e$analysis_type,
   485	      parameter_hash = e$parameter_hash,
   486	      snapshot_id = e$snapshot_id,
   487	      input_hash = e$input_hash,
   488	      payload_hash = e$payload_hash,
   489	      schema_version = e$schema_version,
   490	      reproducibility_hash = e$reproducibility_hash,
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

 succeeded in 0ms:
1ddd085d (HEAD -> feat/analysis-snapshot-releases-573-slice-c) chore(release): v0.30.3
10d830cc docs(deployment): Zenodo archival operator runbook for analysis releases (#573)
c60a7b03 feat(api): Make targets + marker file for Zenodo release archival (#573)
9139f48c fix(api): drop NA DOI fields instead of emitting null (#573)
443f2f62 feat(api): Zenodo upload/DOI record-back logic + CLI scripts (#573)
ab4d16a2 fix(api): namespace base::setdiff in zenodo datapackage builder (#573)
17e1f0e3 feat(api): analysis-release Zenodo packager logic + tests (#573)
diff --git a/api/functions/analysis-snapshot-release-zenodo-package.R b/api/functions/analysis-snapshot-release-zenodo-package.R
new file mode 100644
index 00000000..37690ff4
--- /dev/null
+++ b/api/functions/analysis-snapshot-release-zenodo-package.R
@@ -0,0 +1,597 @@
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
+# `analysis-snapshot-release-zenodo-docs.R` (guard-sourced below) to keep
+# this file under the repo's 600-line soft ceiling.
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
+# --------------------------------------------------------------------------- #
+# Shared constants (forbidden files/dirs, sensitive text, expected layout)
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
+.ANALYSIS_RELEASE_ZENODO_TEXT_SUFFIXES <- c(".md", ".json", ".sql", ".cff", ".sha256", ".txt")
+.ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL <- c(
+  "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
+  "datapackage.json", "zenodo_metadata.json", "checksums.sha256"
+)
+.ANALYSIS_RELEASE_ZENODO_NESTED_DIR <- "analysis_snapshot_release"
+.ANALYSIS_RELEASE_ZENODO_NESTED_EXPECTED <- c("manifest.json", "checksums.sha256")
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
+#' @param http_get_json Function(url) -> parsed JSON list. Injectable seam.
+#' @return The parsed head list (release_id, created_at, license,
+#'   source_data_version, bundle_sha256, manifest, ...).
+analysis_release_zenodo_fetch_head <- function(
+    api_base_url,
+    release_id = "latest",
+    http_get_json = .analysis_release_zenodo_http_get_json) {
+  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
+  release_id <- as.character(release_id)[[1]]
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
+#' Verify a downloaded bundle against the release head's `bundle_sha256`,
+#' extract it, then verify the bundle's OWN inner `checksums.sha256` against
+#' every extracted file. Mirrors `nddscore_extract_and_verify()`'s verify
+#' loop, but the outer digest is SHA-256 (not MD5), and the release bundle's
+#' files sit directly at the archive root (no named top-level subdirectory
+#' to search for).
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
+  for (line in sha_lines) {
+    parts <- strsplit(trimws(line), "\\s+")[[1]]
+    expected_sha <- parts[[1]]
+    rel_name <- parts[[length(parts)]]
+    target <- file.path(exdir, rel_name)
+    if (!file.exists(target)) {
+      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name), call. = FALSE)
+    }
+    actual_sha <- digest::digest(file = target, algo = "sha256")
+    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
+      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name), call. = FALSE)
+    }
+  }
+  exdir
+}
+
+# --------------------------------------------------------------------------- #
+# Shared public-file iterator -- filter-at-source, reused by every
+# builder/checksums/validator step (belt half of belt-and-suspenders).
+# --------------------------------------------------------------------------- #
+
+#' Sorted, files-only, relative POSIX paths under `root_dir`, excluding
+#' forbidden filenames and any path with a forbidden dir-part segment.
+#'
+#' @return character vector of relative paths ("/"-separated).
+.analysis_release_zenodo_iter_public_files <- function(root_dir) {
+  all_files <- list.files(
+    root_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
+  )
+  keep <- vapply(all_files, function(rel_path) {
+    base <- basename(rel_path)
+    if (base %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES) {
+      return(FALSE)
+    }
+    segments <- strsplit(rel_path, "/", fixed = TRUE)[[1]]
+    !any(segments %in% .ANALYSIS_RELEASE_ZENODO_FORBIDDEN_DIR_PARTS)
+  }, logical(1))
+  sort(all_files[keep])
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
+# THE SAFETY VALIDATOR -- defense in depth, runs LAST before tarring.
+# Three independent checks; each collects offending paths and stops loudly.
+# --------------------------------------------------------------------------- #
+
+.analysis_release_zenodo_validate_no_forbidden <- function(staging_dir) {
+  # Deliberately re-walks the tree directly (not via the shared iterator,
+  # which already excludes these) -- an independent re-check, not a
+  # tautology.
+  all_files <- list.files(
+    staging_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE
+  )
+  offenders <- Filter(function(rel_path) {
+    base <- basename(rel_path)
+    segments <- strsplit(rel_path, "/", fixed = TRUE)[[1]]
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
+.analysis_release_zenodo_has_text_suffix <- function(rel_path) {
+  lower <- tolower(rel_path)
+  any(vapply(
+    .ANALYSIS_RELEASE_ZENODO_TEXT_SUFFIXES,
+    function(suffix) endsWith(lower, suffix), logical(1)
+  ))
+}
+
+.analysis_release_zenodo_validate_no_sensitive_text <- function(staging_dir) {
+  offenders <- character(0)
+  for (rel_path in .analysis_release_zenodo_iter_public_files(staging_dir)) {
+    if (!.analysis_release_zenodo_has_text_suffix(rel_path)) {
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
+#' The safety validator. Three independent checks; stops with a clear message
+#' naming the offending relative paths on the first failing check.
+analysis_release_zenodo_validate_staging <- function(staging_dir) {
+  .analysis_release_zenodo_validate_no_forbidden(staging_dir)
+  .analysis_release_zenodo_validate_no_sensitive_text(staging_dir)
+  .analysis_release_zenodo_validate_layout(staging_dir)
+  invisible(TRUE)
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
+
+  bundle_path <- tempfile(fileext = ".tar.gz")
+  on.exit(unlink(bundle_path, force = TRUE), add = TRUE)
+  analysis_release_zenodo_download_bundle(
+    api_base_url, resolved_release_id, bundle_path, http_download = http_download
+  )
+  extracted_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, head$bundle_sha256)
+  on.exit(unlink(extracted_dir, recursive = TRUE, force = TRUE), add = TRUE)
+
+  if (dir.exists(staging_dir)) {
+    unlink(staging_dir, recursive = TRUE, force = TRUE)
+  }
+  dir.create(staging_dir, recursive = TRUE)
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
index 00000000..cc65b88a
--- /dev/null
+++ b/api/functions/analysis-snapshot-release-zenodo-upload.R
@@ -0,0 +1,312 @@
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
+    stop("ZENODO_TOKEN not set and --token not provided", call. = FALSE)
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
index 00000000..0b15a855
--- /dev/null
+++ b/api/scripts/upload-analysis-release-zenodo.R
@@ -0,0 +1,212 @@
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
+#     [--token <ZENODO_TOKEN, defaults to env>] [--sandbox] \
+#     [--deposition-id <id>] [--publish --confirm-publish] \
+#     [--record-doi --release-id <asr_...>] [--api-base-url <SysNDD API base>]
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
+      } else if (args[i] == "--token" && i < length(args)) {
+        token <- args[i + 1]
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
/bin/bash -lc "nl -ba api/endpoints/admin_analysis_snapshot_endpoints.R | sed -n '246,340p'; rg -n -C 3 '@get /releases|@get /releases/<release_id>/bundle|bundle' api/endpoints api/services api/functions | rg -C 2 'release|bundle' | head -n 300" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
api/endpoints/analysis_endpoints.R-328-#* - DB-only read from the current public snapshot's reproducibility row.
api/endpoints/analysis_endpoints.R-329-#* - Approved-public data only (the snapshot is built from approved public data).
api/endpoints/analysis_endpoints.R:330:#* - The `bundle` is the decompressed, parsed JSON of the stored gzip blob.
api/endpoints/analysis_endpoints.R-331-#*
api/endpoints/analysis_endpoints.R-332-#* NOTE: These reproducibility routes live in this file (not a separate mounted
--
api/endpoints/analysis_endpoints.R-341-#* @serializer json list(na="string", auto_unbox=TRUE)
api/endpoints/analysis_endpoints.R-342-#*
api/endpoints/analysis_endpoints.R:343:#* @response 200 OK. Returns { reproducibility_hash, kind, byte_size, snapshot_id, bundle }.
api/endpoints/analysis_endpoints.R:344:#* @response 404 Not Found. No public snapshot or no reproducibility bundle yet.
api/endpoints/analysis_endpoints.R-345-#*
api/endpoints/analysis_endpoints.R-346-#* @get functional_clustering/reproducibility
--
api/endpoints/analysis_endpoints.R-365-#* @serializer json list(na="string", auto_unbox=TRUE)
api/endpoints/analysis_endpoints.R-366-#*
api/endpoints/analysis_endpoints.R:367:#* @response 200 OK. Returns { reproducibility_hash, kind, byte_size, snapshot_id, bundle }.
api/endpoints/analysis_endpoints.R:368:#* @response 404 Not Found. No public snapshot or no reproducibility bundle yet.
api/endpoints/analysis_endpoints.R-369-#*
api/endpoints/analysis_endpoints.R-370-#* @get phenotype_clustering/reproducibility
--
api/endpoints/analysis_endpoints.R-515-
api/endpoints/analysis_endpoints.R-516-
api/endpoints/analysis_endpoints.R:517:#* Download a published release's whole archive (`bundle.tar.gz`) verbatim
api/endpoints/analysis_endpoints.R-518-#*
api/endpoints/analysis_endpoints.R-519-#* @tag analysis
--
--
api/endpoints/analysis_endpoints.R-523-#* @response 200 OK. Raw gzip tar bytes, served as an attachment download.
api/endpoints/analysis_endpoints.R-524-#* @response 404 Not Found. Unknown release id, or the release is still a draft.
api/endpoints/analysis_endpoints.R-525-#*
api/endpoints/analysis_endpoints.R:526:#* @get releases/<release_id>/bundle
api/endpoints/analysis_endpoints.R-527-function(release_id, res) {
api/endpoints/analysis_endpoints.R:528:  bundle <- svc_release_bundle(release_id, conn = pool)
api/endpoints/analysis_endpoints.R-529-  # Content-Type (application/gzip) is set by the octet serializer -- do NOT also
api/endpoints/analysis_endpoints.R-530-  # res$setHeader() it (duplicate header). Content-Disposition/Length are distinct.
api/endpoints/analysis_endpoints.R:531:  res$setHeader("Content-Disposition", sprintf('attachment; filename="%s"', bundle$filename))
api/endpoints/analysis_endpoints.R:532:  res$setHeader("Content-Length", as.character(length(bundle$bytes)))
api/endpoints/analysis_endpoints.R:533:  bundle$bytes
api/endpoints/analysis_endpoints.R-534-}
api/endpoints/analysis_endpoints.R-535-
api/endpoints/analysis_endpoints.R-536-## Analyses endpoints
--
api/endpoints/admin_analysis_snapshot_endpoints.R-142-#* A rebuild whose content is IDENTICAL to an existing release is idempotent
api/endpoints/admin_analysis_snapshot_endpoints.R-143-#* (200, same release_id, no duplicate row); a genuinely new content set is
api/endpoints/admin_analysis_snapshot_endpoints.R-144-#* 201. A gate failure (a layer not available / incoherent / missing its
api/endpoints/admin_analysis_snapshot_endpoints.R:145:#* reproducibility bundle / mismatched source version or dependency lineage)
api/endpoints/admin_analysis_snapshot_endpoints.R-146-#* is 400, naming the failing layer.
api/endpoints/admin_analysis_snapshot_endpoints.R-147-#*
--
api/endpoints/admin_analysis_snapshot_endpoints.R-197-#* @param offset:int Optional page offset. Default 0.
api/endpoints/admin_analysis_snapshot_endpoints.R-198-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:199:#* @get /releases
api/endpoints/admin_analysis_snapshot_endpoints.R-200-function(req, res, limit = NULL, offset = NULL) {
api/endpoints/admin_analysis_snapshot_endpoints.R-201-  require_role(req, res, "Administrator")
--
api/endpoints/admin_analysis_snapshot_endpoints.R-219-#* @serializer unboxedJSON
api/endpoints/admin_analysis_snapshot_endpoints.R-220-#*
api/endpoints/admin_analysis_snapshot_endpoints.R:221:#* @get /releases/<release_id>
api/endpoints/admin_analysis_snapshot_endpoints.R-222-function(req, res, release_id) {
api/endpoints/admin_analysis_snapshot_endpoints.R-223-  require_role(req, res, "Administrator")
api/endpoints/admin_analysis_snapshot_endpoints.R-224-
--
api/functions/analysis-snapshot-release.R-273-      parameter_hash = parameter_hash,
api/functions/analysis-snapshot-release.R-274-      reproducibility_hash = NULL,
api/functions/analysis-snapshot-release.R-275-      dependencies = NULL,
api/functions/analysis-snapshot-release.R:276:      reproducibility_bundle = NULL
api/functions/analysis-snapshot-release.R-277-    )
api/functions/analysis-snapshot-release.R-278-
api/functions/analysis-snapshot-release.R-279-    if (isTRUE(layer$has_reproducibility)) {
--
api/functions/analysis-snapshot-release.R-290-        }
api/functions/analysis-snapshot-release.R-291-      )
api/functions/analysis-snapshot-release.R-292-
api/functions/analysis-snapshot-release.R:293:      # 1c: reproducibility bundle presence.
api/functions/analysis-snapshot-release.R-294-      repro <- reproducibility_loader(entry$snapshot_id, conn = conn)
api/functions/analysis-snapshot-release.R-295-      repro_hash <- .analysis_release_repro_hash(repro)
api/functions/analysis-snapshot-release.R-296-      if (is.na(repro_hash) || !nzchar(repro_hash)) {
api/functions/analysis-snapshot-release.R-297-        stop(.analysis_release_condition(
api/functions/analysis-snapshot-release.R-298-          "release_reproducibility_missing",
api/functions/analysis-snapshot-release.R:299:          sprintf("layer %s has no reproducibility bundle; the release requires one", at),
api/functions/analysis-snapshot-release.R-300-          analysis_type = at
api/functions/analysis-snapshot-release.R-301-        ))
api/functions/analysis-snapshot-release.R-302-      }
api/functions/analysis-snapshot-release.R-303-      entry$reproducibility_hash <- repro_hash
api/functions/analysis-snapshot-release.R:304:      entry$reproducibility_bundle <- repro$bundle_gzip_json
api/functions/analysis-snapshot-release.R-305-    }
api/functions/analysis-snapshot-release.R-306-
api/functions/analysis-snapshot-release.R-307-    loaded[[at]] <- entry
--
api/functions/analysis-snapshot-release.R-341-    )
api/functions/analysis-snapshot-release.R-342-
api/functions/analysis-snapshot-release.R-343-    if (isTRUE(layer$has_reproducibility)) {
api/functions/analysis-snapshot-release.R:344:      repro_bytes <- charToRaw(analysis_reproducibility_decode_raw(entry$reproducibility_bundle))
api/functions/analysis-snapshot-release.R-345-      # H2: the LOCKED equality `sha256(reproducibility.json) == reproducibility_hash`
api/functions/analysis-snapshot-release.R-346-      # must HOLD, not merely be present — verify the decoded bytes hash to the
api/functions/analysis-snapshot-release.R:347:      # stored hash (a corrupt/restored bundle whose bytes drifted from its hash
api/functions/analysis-snapshot-release.R-348-      # is rejected, not published).
api/functions/analysis-snapshot-release.R-349-      computed_repro_hash <- analysis_release_sha256(repro_bytes)
api/functions/analysis-snapshot-release.R-350-      if (!identical(computed_repro_hash, entry$reproducibility_hash)) {
api/functions/analysis-snapshot-release.R-351-        stop(.analysis_release_condition(
api/functions/analysis-snapshot-release.R-352-          "release_reproducibility_missing",
api/functions/analysis-snapshot-release.R-353-          sprintf(
api/functions/analysis-snapshot-release.R:354:            "layer %s reproducibility bytes do not hash to the stored reproducibility_hash (bundle corrupt)",
api/functions/analysis-snapshot-release.R-355-            at
api/functions/analysis-snapshot-release.R-356-          ),
api/functions/analysis-snapshot-release.R-357-          analysis_type = at
--
api/functions/analysis-snapshot-release.R-446-    "checksums.sha256", checksums_bytes, "text/plain"
api/functions/analysis-snapshot-release.R-447-  )
api/functions/analysis-snapshot-release.R-448-
api/functions/analysis-snapshot-release.R:449:  # --- Step 9: bundle.tar.gz (all files) -----------------------------------
api/functions/analysis-snapshot-release.R-450-  named_raw <- stats::setNames(
api/functions/analysis-snapshot-release.R-451-    lapply(artifacts, function(a) a$bytes),
api/functions/analysis-snapshot-release.R-452-    vapply(artifacts, function(a) a$path, character(1))
api/functions/analysis-snapshot-release.R-453-  )
api/functions/analysis-snapshot-release.R:454:  bundle_gzip <- analysis_release_build_tar_gz(named_raw)
api/functions/analysis-snapshot-release.R:455:  bundle_sha256 <- analysis_release_sha256(bundle_gzip)
api/functions/analysis-snapshot-release.R-456-
api/functions/analysis-snapshot-release.R-457-  # --- Step 2 (re-assert immediately before insert) ------------------------
api/functions/analysis-snapshot-release.R-458-  # A FRESH DB re-read via the loader seam (not the cached `loaded`) so a source
--
api/functions/analysis-snapshot-release.R-469-    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
api/functions/analysis-snapshot-release.R-470-    content_digest = content_digest,
api/functions/analysis-snapshot-release.R-471-    manifest_sha256 = manifest_sha256,
api/functions/analysis-snapshot-release.R:472:    bundle_sha256 = bundle_sha256,
api/functions/analysis-snapshot-release.R:473:    bundle_gzip = bundle_gzip,
api/functions/analysis-snapshot-release.R-474-    source_data_version = shared_source_version,
api/functions/analysis-snapshot-release.R-475-    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
api/functions/analysis-snapshot-release.R-476-    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
--
api/services/analysis-snapshot-release-service.R-27-# DUPLICATE/idempotent build (`created = FALSE`) is NOT an error: the caller
api/services/analysis-snapshot-release-service.R-28-# gets 200 + the existing head instead of 201 + the new head.
api/services/analysis-snapshot-release-service.R-29-#
api/services/analysis-snapshot-release-service.R:30:# PUBLIC SURFACE. `svc_release_list/get/manifest/file/bundle()` are the
api/services/analysis-snapshot-release-service.R-31-# published-only public read surface: every repository call is pinned to
api/services/analysis-snapshot-release-service.R-32-# `status = "published"` / `include_draft = FALSE`, so a draft release (or an
api/services/analysis-snapshot-release-service.R-33-# unknown release id, or an unknown archive file path) is indistinguishable
--
api/services/analysis-snapshot-release-service.R-273-  list(bytes = file$bytes, media_type = file$media_type, content_sha256 = file$content_sha256)
api/services/analysis-snapshot-release-service.R-274-}
api/services/analysis-snapshot-release-service.R-275-
api/services/analysis-snapshot-release-service.R:276:#' Fetch a published release's whole archive (`bundle.tar.gz`) verbatim.
api/services/analysis-snapshot-release-service.R-277-#'
api/services/analysis-snapshot-release-service.R-278-#' @param release_id Release id.
api/services/analysis-snapshot-release-service.R-279-#' @param conn A real DBIConnection.
api/services/analysis-snapshot-release-service.R-280-#' @return `list(bytes, sha256, filename)`.
api/services/analysis-snapshot-release-service.R-281-#' @export
api/services/analysis-snapshot-release-service.R:282:svc_release_bundle <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R:283:  bundle <- analysis_release_get_bundle(release_id, include_draft = FALSE, conn = conn)
api/services/analysis-snapshot-release-service.R:284:  if (is.null(bundle)) {
api/services/analysis-snapshot-release-service.R-285-    stop_for_not_found("Release not found")
api/services/analysis-snapshot-release-service.R-286-  }
api/services/analysis-snapshot-release-service.R:287:  list(bytes = bundle$bytes, sha256 = bundle$sha256, filename = bundle$filename)
api/services/analysis-snapshot-release-service.R-288-}
--
api/functions/analysis-snapshot-release-repository.R-13-# scalar params, but for a LONGBLOB param (`list(<raw>)`) that would deparse
api/functions/analysis-snapshot-release-repository.R-14-# the whole multi-MB blob on every call, mirroring the exact trap already
api/functions/analysis-snapshot-release-repository.R-15-# documented in `analysis-reproducibility.R`'s
api/functions/analysis-snapshot-release-repository.R:16:# `analysis_snapshot_insert_reproducibility()`. Blob columns (`bundle_gzip`,
api/functions/analysis-snapshot-release-repository.R-17-# `content_gzip`) are always bound as `list(<raw vector>)`, per DBI's blob
api/functions/analysis-snapshot-release-repository.R-18-# binding convention (verified against RMariaDB).
api/functions/analysis-snapshot-release-repository.R-19-#
--
api/functions/analysis-snapshot-release-repository.R-55-  as.character(x[[1]])
api/functions/analysis-snapshot-release-repository.R-56-}
api/functions/analysis-snapshot-release-repository.R-57-
api/functions/analysis-snapshot-release-repository.R:58:#' Head-table column list shared by SELECTs (excludes the `bundle_gzip` blob
api/functions/analysis-snapshot-release-repository.R:59:#' so metadata reads never pull the multi-MB bundle unless explicitly asked
api/functions/analysis-snapshot-release-repository.R:60:#' for via `analysis_release_get_bundle()`).
api/functions/analysis-snapshot-release-repository.R-61-#' @noRd
api/functions/analysis-snapshot-release-repository.R-62-.analysis_release_head_columns <- paste(
api/functions/analysis-snapshot-release-repository.R-63-  "release_id, release_version, title, status, manifest_schema_version,",
api/functions/analysis-snapshot-release-repository.R:64:  "content_digest, manifest_sha256, bundle_sha256, bundle_bytes,",
api/functions/analysis-snapshot-release-repository.R-65-  "source_data_version, db_release_version, db_release_commit, scope_statement,",
api/functions/analysis-snapshot-release-repository.R-66-  "license, file_count, total_bytes, created_by_user_id, created_at,",
api/functions/analysis-snapshot-release-repository.R-67-  "published_at, updated_at, zenodo_record_id, zenodo_record_url,",
--
api/functions/analysis-snapshot-release-repository.R-83-#'
api/functions/analysis-snapshot-release-repository.R-84-#' `release_head` is a named list with (at least) `release_id`,
api/functions/analysis-snapshot-release-repository.R-85-#' `manifest_schema_version`, `content_digest`, `manifest_sha256`,
api/functions/analysis-snapshot-release-repository.R:86:#' `bundle_sha256`, `bundle_gzip` (raw), plus optional `release_version`,
api/functions/analysis-snapshot-release-repository.R-87-#' `title`, `source_data_version`, `db_release_version`, `db_release_commit`,
api/functions/analysis-snapshot-release-repository.R-88-#' `scope_statement`, `license` (defaults `"CC-BY-4.0"`),
api/functions/analysis-snapshot-release-repository.R-89-#' `created_by_user_id`. Always inserted with `status = 'draft'` —
api/functions/analysis-snapshot-release-repository.R-90-#' `analysis_release_publish()` is the only way to flip it.
api/functions/analysis-snapshot-release-repository.R-91-#'
api/functions/analysis-snapshot-release-repository.R:92:#' `bundle_bytes`, `file_count`, `total_bytes` are derived here (not trusted
api/functions/analysis-snapshot-release-repository.R:93:#' from the caller) from `bundle_gzip`/`files` directly, so they can never
api/functions/analysis-snapshot-release-repository.R-94-#' drift from the actual stored bytes.
api/functions/analysis-snapshot-release-repository.R-95-#'
api/functions/analysis-snapshot-release-repository.R-96-#' `members` is a list of `list(analysis_type, parameter_hash, snapshot_id,
--
api/functions/analysis-snapshot-release-repository.R-108-  if (is.na(release_id) || !nzchar(release_id)) {
api/functions/analysis-snapshot-release-repository.R-109-    stop("release_head$release_id is required", call. = FALSE)
api/functions/analysis-snapshot-release-repository.R-110-  }
api/functions/analysis-snapshot-release-repository.R:111:  bundle_gzip <- release_head$bundle_gzip
api/functions/analysis-snapshot-release-repository.R:112:  if (!is.raw(bundle_gzip)) {
api/functions/analysis-snapshot-release-repository.R:113:    stop("release_head$bundle_gzip must be a raw vector", call. = FALSE)
api/functions/analysis-snapshot-release-repository.R-114-  }
api/functions/analysis-snapshot-release-repository.R-115-
api/functions/analysis-snapshot-release-repository.R-116-  file_count <- length(files)
--
api/functions/analysis-snapshot-release-repository.R-121-      conn,
api/functions/analysis-snapshot-release-repository.R-122-      "INSERT INTO analysis_snapshot_release (
api/functions/analysis-snapshot-release-repository.R-123-         release_id, release_version, title, status, manifest_schema_version,
api/functions/analysis-snapshot-release-repository.R:124:         content_digest, manifest_sha256, bundle_sha256, bundle_gzip, bundle_bytes,
api/functions/analysis-snapshot-release-repository.R-125-         source_data_version, db_release_version, db_release_commit, scope_statement,
api/functions/analysis-snapshot-release-repository.R-126-         license, file_count, total_bytes, created_by_user_id
api/functions/analysis-snapshot-release-repository.R-127-       ) VALUES (?, ?, ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
--
api/functions/analysis-snapshot-release-repository.R-132-        .analysis_release_chr(release_head$manifest_schema_version),
api/functions/analysis-snapshot-release-repository.R-133-        .analysis_release_chr(release_head$content_digest),
api/functions/analysis-snapshot-release-repository.R-134-        .analysis_release_chr(release_head$manifest_sha256),
api/functions/analysis-snapshot-release-repository.R:135:        .analysis_release_chr(release_head$bundle_sha256),
api/functions/analysis-snapshot-release-repository.R:136:        list(bundle_gzip),
api/functions/analysis-snapshot-release-repository.R:137:        length(bundle_gzip),
api/functions/analysis-snapshot-release-repository.R-138-        .analysis_release_chr(release_head$source_data_version),
api/functions/analysis-snapshot-release-repository.R-139-        .analysis_release_chr(release_head$db_release_version),
api/functions/analysis-snapshot-release-repository.R-140-        .analysis_release_chr(release_head$db_release_commit),
--
api/functions/analysis-snapshot-release-repository.R-214-    "release_id", "release_version", "title", "status", "content_digest",
api/functions/analysis-snapshot-release-repository.R-215-    "created_at", "published_at", "source_data_version",
api/functions/analysis-snapshot-release-repository.R-216-    "db_release_version", "db_release_commit", "manifest_sha256",
api/functions/analysis-snapshot-release-repository.R:217:    "bundle_sha256", "license", "file_count", "total_bytes"
api/functions/analysis-snapshot-release-repository.R-218-  )
api/functions/analysis-snapshot-release-repository.R-219-  projected <- head[intersect(allowlist, names(head))]
api/functions/analysis-snapshot-release-repository.R-220-  projected$zenodo <- list(
--
api/functions/analysis-snapshot-release-repository.R-366-  )
api/functions/analysis-snapshot-release-repository.R-367-}
api/functions/analysis-snapshot-release-repository.R-368-
api/functions/analysis-snapshot-release-repository.R:369:#' Fetch the whole release archive (`bundle_gzip`) verbatim.
api/functions/analysis-snapshot-release-repository.R-370-#'
api/functions/analysis-snapshot-release-repository.R:371:#' `bundle_gzip` is stored already-gzipped and served as-is — this does NOT
api/functions/analysis-snapshot-release-repository.R-372-#' decompress it (unlike `analysis_release_get_file()`, which stores each
api/functions/analysis-snapshot-release-repository.R-373-#' file's gzip as a transport-only encoding of JSON content). Draft releases
api/functions/analysis-snapshot-release-repository.R-374-#' are hidden unless `include_draft = TRUE`, filtered in SQL.
--
api/functions/analysis-snapshot-release-repository.R-376-#' @return `list(bytes = <raw, verbatim gzip tar>, sha256 = chr, filename =
api/functions/analysis-snapshot-release-repository.R-377-#'   "<release_id>.tar.gz")`, or `NULL` if no matching (visible) row exists.
api/functions/analysis-snapshot-release-repository.R-378-#' @export
api/functions/analysis-snapshot-release-repository.R:379:analysis_release_get_bundle <- function(release_id, include_draft = FALSE, conn) {
api/functions/analysis-snapshot-release-repository.R-380-  status_clause <- if (isTRUE(include_draft)) "" else " AND status = 'published'"
api/functions/analysis-snapshot-release-repository.R-381-  sql <- paste0(
api/functions/analysis-snapshot-release-repository.R:382:    "SELECT bundle_gzip, bundle_sha256
api/functions/analysis-snapshot-release-repository.R-383-       FROM analysis_snapshot_release
api/functions/analysis-snapshot-release-repository.R-384-      WHERE release_id = ?", status_clause, "
api/functions/analysis-snapshot-release-repository.R-385-      LIMIT 1"
--
api/functions/analysis-snapshot-release-repository.R-390-  }
api/functions/analysis-snapshot-release-repository.R-391-
api/functions/analysis-snapshot-release-repository.R-392-  list(
api/functions/analysis-snapshot-release-repository.R:393:    bytes = .analysis_release_blob(rows$bundle_gzip[[1]]),
api/functions/analysis-snapshot-release-repository.R:394:    sha256 = as.character(rows$bundle_sha256[[1]]),
api/functions/analysis-snapshot-release-repository.R-395-    filename = paste0(as.character(release_id), ".tar.gz")
api/functions/analysis-snapshot-release-repository.R-396-  )
api/functions/analysis-snapshot-release-repository.R-397-}
--
api/functions/nddscore-release-source.R-186-  dest
api/functions/nddscore-release-source.R-187-}
api/functions/nddscore-release-source.R-188-
api/functions/nddscore-release-source.R:189:#' Extract the release archive and verify the bundled inner checksums.sha256.
api/functions/nddscore-release-source.R-190-#'
api/functions/nddscore-release-source.R-191-#' @param archive_path Path to the .tar.gz.
api/functions/nddscore-release-source.R-192-#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
--
api/functions/nddscore-release-source.R-208-
api/functions/nddscore-release-source.R-209-  sha_file <- file.path(rel_dir, "checksums.sha256")
api/functions/nddscore-release-source.R-210-  if (!file.exists(sha_file)) {
api/functions/nddscore-release-source.R:211:    stop("Archive release directory has no bundled checksums.sha256", call. = FALSE)
api/functions/nddscore-release-source.R-212-  }
api/functions/nddscore-release-source.R-213-  sha_lines <- readLines(sha_file, warn = FALSE)
api/functions/nddscore-release-source.R-214-  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
--
api/functions/analysis-snapshot-release-zenodo-package.R-9-#
api/functions/analysis-snapshot-release-zenodo-package.R-10-# Read path: the PUBLIC HTTP API only (no DB, no docker exec) --
api/functions/analysis-snapshot-release-zenodo-package.R-11-#   GET {api_base_url}/api/analysis/releases/{latest|<release_id>}
api/functions/analysis-snapshot-release-zenodo-package.R:12:#   GET {api_base_url}/api/analysis/releases/<release_id>/bundle
api/functions/analysis-snapshot-release-zenodo-package.R-13-# A release is already a complete, self-verifying, content-addressed export
api/functions/analysis-snapshot-release-zenodo-package.R-14-# (see AGENTS.md "Analysis-snapshot releases (#573)"), so the packager's job
api/functions/analysis-snapshot-release-zenodo-package.R:15:# is narrow: download + verify the bundle, re-stage its files UNMODIFIED
api/functions/analysis-snapshot-release-zenodo-package.R-16-# under `analysis_snapshot_release/`, add Zenodo-facing docs/metadata, write
api/functions/analysis-snapshot-release-zenodo-package.R-17-# a staging-wide checksums.sha256, run the safety validator, then tar.
api/functions/analysis-snapshot-release-zenodo-package.R-18-#
api/functions/analysis-snapshot-release-zenodo-package.R-19-# Mirrors the sibling `../nddscore/src/models/sysndd_export.py` builders
api/functions/analysis-snapshot-release-zenodo-package.R-20-# (translated Python -> R) and reuses the fetch/extract/verify idioms from
api/functions/analysis-snapshot-release-zenodo-package.R:21:# `functions/nddscore-release-source.R` -- except the release bundle's own
api/functions/analysis-snapshot-release-zenodo-package.R:22:# checksum is SHA-256 (`bundle_sha256` on the release head), not the MD5
api/functions/analysis-snapshot-release-zenodo-package.R-23-# Zenodo's OWN file listing uses for the (unrelated) inbound nddscore fetch.
api/functions/analysis-snapshot-release-zenodo-package.R-24-#
api/functions/analysis-snapshot-release-zenodo-package.R-25-# Every HTTP/file-IO boundary is an injectable parameter with a real default
--
api/functions/analysis-snapshot-release-zenodo-package.R-125-#' @param release_id "latest" (default) or an explicit `asr_<16 hex>` id.
api/functions/analysis-snapshot-release-zenodo-package.R-126-#' @param http_get_json Function(url) -> parsed JSON list. Injectable seam.
api/functions/analysis-snapshot-release-zenodo-package.R-127-#' @return The parsed head list (release_id, created_at, license,
api/functions/analysis-snapshot-release-zenodo-package.R:128:#'   source_data_version, bundle_sha256, manifest, ...).
api/functions/analysis-snapshot-release-zenodo-package.R-129-analysis_release_zenodo_fetch_head <- function(
api/functions/analysis-snapshot-release-zenodo-package.R-130-    api_base_url,
api/functions/analysis-snapshot-release-zenodo-package.R-131-    release_id = "latest",
--

exec
/bin/bash -lc "git ls-tree -r --name-only HEAD api/functions/analysis-snapshot-release-zenodo-package.R api/functions/analysis-snapshot-release-zenodo-docs.R api/functions/analysis-snapshot-release-zenodo-upload.R api/scripts/package-analysis-release-zenodo.R api/scripts/upload-analysis-release-zenodo.R | xargs -r -n1 sh -c 'printf \"%s \" \""'$0"; wc -l < "$0"'"'; rg -n \"library\\(|require\\(\" api/functions/analysis-snapshot-release-zenodo-*.R api/scripts/{package,upload}-analysis-release-zenodo.R; rg -n \"\\b(get|setdiff|merge)\\(\" api/functions/analysis-snapshot-release-zenodo-*.R api/scripts/{package,upload}-analysis-release-zenodo.R" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
api/functions/analysis-snapshot-release-zenodo-docs.R 163
api/functions/analysis-snapshot-release-zenodo-package.R 597
api/functions/analysis-snapshot-release-zenodo-upload.R 312
api/scripts/package-analysis-release-zenodo.R 157
api/scripts/upload-analysis-release-zenodo.R 212
api/functions/analysis-snapshot-release-zenodo-package.R:307:  rel_paths <- base::setdiff(rel_paths, c("checksums.sha256", "datapackage.json"))

exec
/bin/bash -lc "rg -n -C 3 \"analysis_release_build_tar_gz|tar_path|file\\.path\\(|unsafe|path traversal\" api/functions/analysis-snapshot-release-manifest.R api/tests/testthat/test-unit-analysis-snapshot-release*.R | head -n 360" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-13-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-14-analysis_snapshot_release_migration_path <- function() {
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-15-  candidates <- c(
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:16:    file.path(get_api_dir(), "..", "db", "migrations", "045_add_analysis_snapshot_release.sql"),
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R:17:    file.path(get_api_dir(), "db", "migrations", "045_add_analysis_snapshot_release.sql")
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-18-  )
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-19-
api/tests/testthat/test-unit-analysis-snapshot-release-migration.R-20-  for (candidate in candidates) {
--
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-10-setwd(get_api_dir())
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-11-withr::defer(setwd(analysis_release_manifest_test_wd), testthat::teardown_env())
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-12-
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:13:source(file.path("core", "errors.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:14:source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:15:source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = TRUE)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-16-
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-17-# --------------------------------------------------------------------------- #
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-18-# B1: `layers` is a SELECTION, never a policy redefinition.
--
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-58-
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-59-test_that("build_tar_gz rejects a path-traversal archive path", {
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-60-  expect_error(
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:61:    analysis_release_build_tar_gz(list("../x.json" = charToRaw("{}"))),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:62:    "unsafe release file path"
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-63-  )
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-64-  expect_error(
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:65:    analysis_release_build_tar_gz(list("/etc/passwd" = charToRaw("x"))),
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:66:    "unsafe release file path"
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-67-  )
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-68-})
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-69-
--
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-77-  expect_true(exists("analysis_release_id", mode = "function"))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-78-  expect_true(exists("analysis_release_build_manifest", mode = "function"))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-79-  expect_true(exists("analysis_release_checksums_text", mode = "function"))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:80:  expect_true(exists("analysis_release_build_tar_gz", mode = "function"))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-81-})
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-82-
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-83-test_that("analysis_snapshot_release_layers() registers the 3 default analysis layers", {
--
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-169-
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-170-test_that("tar.gz round-trips: untar yields exactly the input files/bytes", {
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-171-  payload <- list("a/x.json" = charToRaw("{\"k\":1}"), "manifest.json" = charToRaw("{}"))
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:172:  gz <- analysis_release_build_tar_gz(payload)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-173-  d <- tempfile()
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-174-  dir.create(d)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:175:  tarfile <- file.path(d, "b.tar")
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-176-  writeBin(memDecompress(gz, type = "gzip"), tarfile)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-177-  utils::untar(tarfile, exdir = d)
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:178:  expect_identical(readBin(file.path(d, "a/x.json"), "raw", 64L), payload[["a/x.json"]])
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R:179:  expect_identical(readBin(file.path(d, "manifest.json"), "raw", 64L), payload[["manifest.json"]])
api/tests/testthat/test-unit-analysis-snapshot-release-manifest.R-180-})
--
api/functions/analysis-snapshot-release-manifest.R-6-# These functions define release IDENTITY and file contracts consumed by
api/functions/analysis-snapshot-release-manifest.R-7-# later tasks (repository persistence, build orchestrator). They must stay
api/functions/analysis-snapshot-release-manifest.R-8-# pure: no DB access, no network, no side effects beyond a scratch tempdir
api/functions/analysis-snapshot-release-manifest.R:9:# used internally by `analysis_release_build_tar_gz()`.
api/functions/analysis-snapshot-release-manifest.R-10-#
api/functions/analysis-snapshot-release-manifest.R-11-# Reuses the EXISTING canonical JSON serializer from
api/functions/analysis-snapshot-release-manifest.R-12-# `analysis-snapshot-presets.R` (`analysis_snapshot_canonical_json()`, sourced
--
api/functions/analysis-snapshot-release-manifest.R-93-
api/functions/analysis-snapshot-release-manifest.R-94-#' Reject an archive-relative file path that could escape the archive root.
api/functions/analysis-snapshot-release-manifest.R-95-#'
api/functions/analysis-snapshot-release-manifest.R:96:#' Defense-in-depth against path traversal: rejects any path that is empty,
api/functions/analysis-snapshot-release-manifest.R-97-#' absolute (leading `/` or a Windows drive), contains a backslash separator, or
api/functions/analysis-snapshot-release-manifest.R-98-#' contains a `..` segment. Called for every materialized file path AND every
api/functions/analysis-snapshot-release-manifest.R:99:#' path written into the tar archive (`analysis_release_build_tar_gz`).
api/functions/analysis-snapshot-release-manifest.R-100-#'
api/functions/analysis-snapshot-release-manifest.R-101-#' @param path chr, an archive-relative file path.
api/functions/analysis-snapshot-release-manifest.R:102:#' @return invisibly TRUE; throws on an unsafe path.
api/functions/analysis-snapshot-release-manifest.R-103-.analysis_release_assert_safe_path <- function(path) {
api/functions/analysis-snapshot-release-manifest.R-104-  p <- as.character(path)[[1]]
api/functions/analysis-snapshot-release-manifest.R-105-  segments <- strsplit(p, "/", fixed = TRUE)[[1]]
--
api/functions/analysis-snapshot-release-manifest.R-108-    grepl("^[A-Za-z]:[\\\\/]", p) ||
api/functions/analysis-snapshot-release-manifest.R-109-    grepl("\\\\", p) ||
api/functions/analysis-snapshot-release-manifest.R-110-    any(segments == "..")) {
api/functions/analysis-snapshot-release-manifest.R:111:    stop(sprintf("unsafe release file path: %s", p), call. = FALSE)
api/functions/analysis-snapshot-release-manifest.R-112-  }
api/functions/analysis-snapshot-release-manifest.R-113-  invisible(TRUE)
api/functions/analysis-snapshot-release-manifest.R-114-}
--
api/functions/analysis-snapshot-release-manifest.R-244-#' @param named_raw_list named list of raw vectors, keyed by archive-relative
api/functions/analysis-snapshot-release-manifest.R-245-#'   path.
api/functions/analysis-snapshot-release-manifest.R-246-#' @return raw vector, the gzip-compressed tar archive bytes.
api/functions/analysis-snapshot-release-manifest.R:247:analysis_release_build_tar_gz <- function(named_raw_list) {
api/functions/analysis-snapshot-release-manifest.R-248-  paths <- names(named_raw_list)
api/functions/analysis-snapshot-release-manifest.R-249-  stopifnot(
api/functions/analysis-snapshot-release-manifest.R-250-    "named_raw_list must be a non-empty named list" = length(paths) > 0 && all(nzchar(paths))
api/functions/analysis-snapshot-release-manifest.R-251-  )
api/functions/analysis-snapshot-release-manifest.R-252-  # Containment: refuse any path that could escape the archive root before it is
api/functions/analysis-snapshot-release-manifest.R:253:  # written under the scratch dir with file.path(src_dir, path).
api/functions/analysis-snapshot-release-manifest.R-254-  for (path in paths) {
api/functions/analysis-snapshot-release-manifest.R-255-    .analysis_release_assert_safe_path(path)
api/functions/analysis-snapshot-release-manifest.R-256-  }
--
api/functions/analysis-snapshot-release-manifest.R-261-  on.exit(unlink(src_dir, recursive = TRUE, force = TRUE), add = TRUE)
api/functions/analysis-snapshot-release-manifest.R-262-
api/functions/analysis-snapshot-release-manifest.R-263-  for (path in paths) {
api/functions/analysis-snapshot-release-manifest.R:264:    full_path <- file.path(src_dir, path)
api/functions/analysis-snapshot-release-manifest.R-265-    dir.create(dirname(full_path), recursive = TRUE, showWarnings = FALSE)
api/functions/analysis-snapshot-release-manifest.R-266-    writeBin(named_raw_list[[path]], full_path)
api/functions/analysis-snapshot-release-manifest.R-267-  }

exec
/bin/bash -lc 'git show origin/master:api/functions/analysis-snapshot-release.R >/dev/null 2>&1; echo $?; git show HEAD:api/functions/analysis-snapshot-release.R | rg -n -C 4 "db_release|commit"; git show HEAD:api/functions/analysis-snapshot-release-manifest.R | rg -n -C 4 "db_release|commit|git"' in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 exited 1 in 0ms:
0
315-
316-  # M1/M2: DB release provenance — carried on each pinned snapshot manifest.
317-  # strict = TRUE: distinct non-empty values that DISAGREE across layers reject
318-  # the build (release_source_version_mismatch -> 400), like source_data_version.
319:  shared_db_release_version <- .analysis_release_consistent_manifest_value(loaded, "db_release_version", strict = TRUE)
320:  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit", strict = TRUE)
321-
322-  # For the correlation layer, pin the actual dependency lineage into its entry.
323-  corr <- loaded[["phenotype_functional_correlations"]]
324-  if (!is.null(corr)) {
--
421-      }
422-    ),
423-    source = list(
424-      source_data_version = shared_source_version,
425:      db_release = list(
426:        version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
427:        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
428-      ),
429-      snapshots = lapply(layer_entries, function(e) {
430-        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
431-      })
--
471-    manifest_sha256 = manifest_sha256,
472-    bundle_sha256 = bundle_sha256,
473-    bundle_gzip = bundle_gzip,
474-    source_data_version = shared_source_version,
475:    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
476:    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
477-    scope_statement = scope_statement,
478-    license = license %||% "CC-BY-4.0",
479-    created_by_user_id = created_by
480-  )

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release.R | sed -n '230,390p'; rg -n -C 4 \"shared_db_release_commit|db_release_commit|current_db_release|git_sha|git sha\" api/functions/analysis-snapshot-release.R api/functions/analysis-snapshot-release-*.R api/functions/*release*.R api/services -g '*.R' | head -n 300" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
   321
   322	  # For the correlation layer, pin the actual dependency lineage into its entry.
   323	  corr <- loaded[["phenotype_functional_correlations"]]
   324	  if (!is.null(corr)) {
   325	    loaded[["phenotype_functional_correlations"]]$dependencies <-
   326	      analysis_snapshot_manifest_dependencies(corr$manifest)
   327	  }
   328
   329	  # --- Step 3/4/5: materialize per-layer files + README, build layer_entries
   330	  artifacts <- list()
   331	  layer_entries <- list()
   332
   333	  for (layer in layers) {
   334	    at <- as.character(layer$analysis_type[[1]])
   335	    entry <- loaded[[at]]
   336	    prefix <- layer$files_prefix %||% at
   337
   338	    payload_bytes <- analysis_release_canonical_bytes(.analysis_release_layer_payload(entry$snapshot, layer))
   339	    artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   340	      paste0(prefix, "/payload.json"), payload_bytes, "application/json"
   341	    )
   342
   343	    if (isTRUE(layer$has_reproducibility)) {
   344	      repro_bytes <- charToRaw(analysis_reproducibility_decode_raw(entry$reproducibility_bundle))
   345	      # H2: the LOCKED equality `sha256(reproducibility.json) == reproducibility_hash`
   346	      # must HOLD, not merely be present — verify the decoded bytes hash to the
   347	      # stored hash (a corrupt/restored bundle whose bytes drifted from its hash
   348	      # is rejected, not published).
   349	      computed_repro_hash <- analysis_release_sha256(repro_bytes)
   350	      if (!identical(computed_repro_hash, entry$reproducibility_hash)) {
   351	        stop(.analysis_release_condition(
   352	          "release_reproducibility_missing",
   353	          sprintf(
   354	            "layer %s reproducibility bytes do not hash to the stored reproducibility_hash (bundle corrupt)",
   355	            at
   356	          ),
   357	          analysis_type = at
   358	        ))
   359	      }
   360	      artifacts[[length(artifacts) + 1L]] <- .analysis_release_artifact(
   361	        paste0(prefix, "/reproducibility.json"), repro_bytes, "application/json"
   362	      )
   363	    }
   364
   365	    layer_entries[[length(layer_entries) + 1L]] <- list(
   366	      analysis_type = at,
   367	      parameter_hash = entry$parameter_hash,
   368	      snapshot_id = entry$snapshot_id,
   369	      input_hash = entry$input_hash,
   370	      payload_hash = entry$payload_hash,
   371	      schema_version = entry$schema_version,
   372	      reproducibility_hash = entry$reproducibility_hash,
   373	      dependencies = entry$dependencies
   374	    )
   375	  }
   376
   377	  # --- Step 6: content_digest -> release_id + idempotency ------------------
   378	  content_digest <- analysis_release_content_digest(
   379	    layer_entries, shared_source_version, ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION
   380	  )
   381	  release_id <- analysis_release_id(content_digest)
   382
   383	  if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
   384	    existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
   385	    if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
   386	      return(list(release = existing, created = FALSE))
   387	    }
   388	    stop(sprintf(
   389	      "release id %s already exists with a different content_digest (identity anomaly)",
   390	      release_id
api/functions/analysis-snapshot-release-repository.R-61-#' @noRd
api/functions/analysis-snapshot-release-repository.R-62-.analysis_release_head_columns <- paste(
api/functions/analysis-snapshot-release-repository.R-63-  "release_id, release_version, title, status, manifest_schema_version,",
api/functions/analysis-snapshot-release-repository.R-64-  "content_digest, manifest_sha256, bundle_sha256, bundle_bytes,",
api/functions/analysis-snapshot-release-repository.R:65:  "source_data_version, db_release_version, db_release_commit, scope_statement,",
api/functions/analysis-snapshot-release-repository.R-66-  "license, file_count, total_bytes, created_by_user_id, created_at,",
api/functions/analysis-snapshot-release-repository.R-67-  "published_at, updated_at, zenodo_record_id, zenodo_record_url,",
api/functions/analysis-snapshot-release-repository.R-68-  "version_doi, concept_doi, last_error_message"
api/functions/analysis-snapshot-release-repository.R-69-)
--
api/functions/analysis-snapshot-release-repository.R-83-#'
api/functions/analysis-snapshot-release-repository.R-84-#' `release_head` is a named list with (at least) `release_id`,
api/functions/analysis-snapshot-release-repository.R-85-#' `manifest_schema_version`, `content_digest`, `manifest_sha256`,
api/functions/analysis-snapshot-release-repository.R-86-#' `bundle_sha256`, `bundle_gzip` (raw), plus optional `release_version`,
api/functions/analysis-snapshot-release-repository.R:87:#' `title`, `source_data_version`, `db_release_version`, `db_release_commit`,
api/functions/analysis-snapshot-release-repository.R-88-#' `scope_statement`, `license` (defaults `"CC-BY-4.0"`),
api/functions/analysis-snapshot-release-repository.R-89-#' `created_by_user_id`. Always inserted with `status = 'draft'` —
api/functions/analysis-snapshot-release-repository.R-90-#' `analysis_release_publish()` is the only way to flip it.
api/functions/analysis-snapshot-release-repository.R-91-#'
--
api/functions/analysis-snapshot-release-repository.R-121-      conn,
api/functions/analysis-snapshot-release-repository.R-122-      "INSERT INTO analysis_snapshot_release (
api/functions/analysis-snapshot-release-repository.R-123-         release_id, release_version, title, status, manifest_schema_version,
api/functions/analysis-snapshot-release-repository.R-124-         content_digest, manifest_sha256, bundle_sha256, bundle_gzip, bundle_bytes,
api/functions/analysis-snapshot-release-repository.R:125:         source_data_version, db_release_version, db_release_commit, scope_statement,
api/functions/analysis-snapshot-release-repository.R-126-         license, file_count, total_bytes, created_by_user_id
api/functions/analysis-snapshot-release-repository.R-127-       ) VALUES (?, ?, ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
api/functions/analysis-snapshot-release-repository.R-128-      params = unname(list(
api/functions/analysis-snapshot-release-repository.R-129-        release_id,
--
api/functions/analysis-snapshot-release-repository.R-136-        list(bundle_gzip),
api/functions/analysis-snapshot-release-repository.R-137-        length(bundle_gzip),
api/functions/analysis-snapshot-release-repository.R-138-        .analysis_release_chr(release_head$source_data_version),
api/functions/analysis-snapshot-release-repository.R-139-        .analysis_release_chr(release_head$db_release_version),
api/functions/analysis-snapshot-release-repository.R:140:        .analysis_release_chr(release_head$db_release_commit),
api/functions/analysis-snapshot-release-repository.R-141-        .analysis_release_chr(release_head$scope_statement),
api/functions/analysis-snapshot-release-repository.R-142-        release_head$license %||% "CC-BY-4.0",
api/functions/analysis-snapshot-release-repository.R-143-        as.integer(file_count),
api/functions/analysis-snapshot-release-repository.R-144-        as.numeric(total_bytes),
--
api/functions/analysis-snapshot-release-repository.R-212-
api/functions/analysis-snapshot-release-repository.R-213-  allowlist <- c(
api/functions/analysis-snapshot-release-repository.R-214-    "release_id", "release_version", "title", "status", "content_digest",
api/functions/analysis-snapshot-release-repository.R-215-    "created_at", "published_at", "source_data_version",
api/functions/analysis-snapshot-release-repository.R:216:    "db_release_version", "db_release_commit", "manifest_sha256",
api/functions/analysis-snapshot-release-repository.R-217-    "bundle_sha256", "license", "file_count", "total_bytes"
api/functions/analysis-snapshot-release-repository.R-218-  )
api/functions/analysis-snapshot-release-repository.R-219-  projected <- head[intersect(allowlist, names(head))]
api/functions/analysis-snapshot-release-repository.R-220-  projected$zenodo <- list(
--
api/functions/analysis-snapshot-release.R-316-  # M1/M2: DB release provenance — carried on each pinned snapshot manifest.
api/functions/analysis-snapshot-release.R-317-  # strict = TRUE: distinct non-empty values that DISAGREE across layers reject
api/functions/analysis-snapshot-release.R-318-  # the build (release_source_version_mismatch -> 400), like source_data_version.
api/functions/analysis-snapshot-release.R-319-  shared_db_release_version <- .analysis_release_consistent_manifest_value(loaded, "db_release_version", strict = TRUE)
api/functions/analysis-snapshot-release.R:320:  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit", strict = TRUE)
api/functions/analysis-snapshot-release.R-321-
api/functions/analysis-snapshot-release.R-322-  # For the correlation layer, pin the actual dependency lineage into its entry.
api/functions/analysis-snapshot-release.R-323-  corr <- loaded[["phenotype_functional_correlations"]]
api/functions/analysis-snapshot-release.R-324-  if (!is.null(corr)) {
--
api/functions/analysis-snapshot-release.R-423-    source = list(
api/functions/analysis-snapshot-release.R-424-      source_data_version = shared_source_version,
api/functions/analysis-snapshot-release.R-425-      db_release = list(
api/functions/analysis-snapshot-release.R-426-        version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
api/functions/analysis-snapshot-release.R:427:        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
api/functions/analysis-snapshot-release.R-428-      ),
api/functions/analysis-snapshot-release.R-429-      snapshots = lapply(layer_entries, function(e) {
api/functions/analysis-snapshot-release.R-430-        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
api/functions/analysis-snapshot-release.R-431-      })
--
api/functions/analysis-snapshot-release.R-472-    bundle_sha256 = bundle_sha256,
api/functions/analysis-snapshot-release.R-473-    bundle_gzip = bundle_gzip,
api/functions/analysis-snapshot-release.R-474-    source_data_version = shared_source_version,
api/functions/analysis-snapshot-release.R-475-    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
api/functions/analysis-snapshot-release.R:476:    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
api/functions/analysis-snapshot-release.R-477-    scope_statement = scope_statement,
api/functions/analysis-snapshot-release.R-478-    license = license %||% "CC-BY-4.0",
api/functions/analysis-snapshot-release.R-479-    created_by_user_id = created_by
api/functions/analysis-snapshot-release.R-480-  )
--
api/functions/analysis-snapshot-release-repository.R-61-#' @noRd
api/functions/analysis-snapshot-release-repository.R-62-.analysis_release_head_columns <- paste(
api/functions/analysis-snapshot-release-repository.R-63-  "release_id, release_version, title, status, manifest_schema_version,",
api/functions/analysis-snapshot-release-repository.R-64-  "content_digest, manifest_sha256, bundle_sha256, bundle_bytes,",
api/functions/analysis-snapshot-release-repository.R:65:  "source_data_version, db_release_version, db_release_commit, scope_statement,",
api/functions/analysis-snapshot-release-repository.R-66-  "license, file_count, total_bytes, created_by_user_id, created_at,",
api/functions/analysis-snapshot-release-repository.R-67-  "published_at, updated_at, zenodo_record_id, zenodo_record_url,",
api/functions/analysis-snapshot-release-repository.R-68-  "version_doi, concept_doi, last_error_message"
api/functions/analysis-snapshot-release-repository.R-69-)
--
api/functions/analysis-snapshot-release-repository.R-83-#'
api/functions/analysis-snapshot-release-repository.R-84-#' `release_head` is a named list with (at least) `release_id`,
api/functions/analysis-snapshot-release-repository.R-85-#' `manifest_schema_version`, `content_digest`, `manifest_sha256`,
api/functions/analysis-snapshot-release-repository.R-86-#' `bundle_sha256`, `bundle_gzip` (raw), plus optional `release_version`,
api/functions/analysis-snapshot-release-repository.R:87:#' `title`, `source_data_version`, `db_release_version`, `db_release_commit`,
api/functions/analysis-snapshot-release-repository.R-88-#' `scope_statement`, `license` (defaults `"CC-BY-4.0"`),
api/functions/analysis-snapshot-release-repository.R-89-#' `created_by_user_id`. Always inserted with `status = 'draft'` —
api/functions/analysis-snapshot-release-repository.R-90-#' `analysis_release_publish()` is the only way to flip it.
api/functions/analysis-snapshot-release-repository.R-91-#'
--
api/functions/analysis-snapshot-release-repository.R-121-      conn,
api/functions/analysis-snapshot-release-repository.R-122-      "INSERT INTO analysis_snapshot_release (
api/functions/analysis-snapshot-release-repository.R-123-         release_id, release_version, title, status, manifest_schema_version,
api/functions/analysis-snapshot-release-repository.R-124-         content_digest, manifest_sha256, bundle_sha256, bundle_gzip, bundle_bytes,
api/functions/analysis-snapshot-release-repository.R:125:         source_data_version, db_release_version, db_release_commit, scope_statement,
api/functions/analysis-snapshot-release-repository.R-126-         license, file_count, total_bytes, created_by_user_id
api/functions/analysis-snapshot-release-repository.R-127-       ) VALUES (?, ?, ?, 'draft', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
api/functions/analysis-snapshot-release-repository.R-128-      params = unname(list(
api/functions/analysis-snapshot-release-repository.R-129-        release_id,
--
api/functions/analysis-snapshot-release-repository.R-136-        list(bundle_gzip),
api/functions/analysis-snapshot-release-repository.R-137-        length(bundle_gzip),
api/functions/analysis-snapshot-release-repository.R-138-        .analysis_release_chr(release_head$source_data_version),
api/functions/analysis-snapshot-release-repository.R-139-        .analysis_release_chr(release_head$db_release_version),
api/functions/analysis-snapshot-release-repository.R:140:        .analysis_release_chr(release_head$db_release_commit),
api/functions/analysis-snapshot-release-repository.R-141-        .analysis_release_chr(release_head$scope_statement),
api/functions/analysis-snapshot-release-repository.R-142-        release_head$license %||% "CC-BY-4.0",
api/functions/analysis-snapshot-release-repository.R-143-        as.integer(file_count),
api/functions/analysis-snapshot-release-repository.R-144-        as.numeric(total_bytes),
--
api/functions/analysis-snapshot-release-repository.R-212-
api/functions/analysis-snapshot-release-repository.R-213-  allowlist <- c(
api/functions/analysis-snapshot-release-repository.R-214-    "release_id", "release_version", "title", "status", "content_digest",
api/functions/analysis-snapshot-release-repository.R-215-    "created_at", "published_at", "source_data_version",
api/functions/analysis-snapshot-release-repository.R:216:    "db_release_version", "db_release_commit", "manifest_sha256",
api/functions/analysis-snapshot-release-repository.R-217-    "bundle_sha256", "license", "file_count", "total_bytes"
api/functions/analysis-snapshot-release-repository.R-218-  )
api/functions/analysis-snapshot-release-repository.R-219-  projected <- head[intersect(allowlist, names(head))]
api/functions/analysis-snapshot-release-repository.R-220-  projected$zenodo <- list(
--
api/functions/analysis-snapshot-release-zenodo-package.R-83-  ".git", ".planning", ".superpowers", ".venv", "__pycache__"
api/functions/analysis-snapshot-release-zenodo-package.R-84-)
api/functions/analysis-snapshot-release-zenodo-package.R-85-.ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS <- c(
api/functions/analysis-snapshot-release-zenodo-package.R-86-  "/home/", "/users/", "bernt-popp", "zenodo_token", "zenodo_access_token",
api/functions/analysis-snapshot-release-zenodo-package.R:87:  "bearer ", "development/sysndd", "development/nddscore", ".env", "git_sha"
api/functions/analysis-snapshot-release-zenodo-package.R-88-)
api/functions/analysis-snapshot-release-zenodo-package.R-89-.ANALYSIS_RELEASE_ZENODO_TEXT_SUFFIXES <- c(".md", ".json", ".sql", ".cff", ".sha256", ".txt")
api/functions/analysis-snapshot-release-zenodo-package.R-90-.ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL <- c(
api/functions/analysis-snapshot-release-zenodo-package.R-91-  "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
--
api/functions/analysis-snapshot-release.R-316-  # M1/M2: DB release provenance — carried on each pinned snapshot manifest.
api/functions/analysis-snapshot-release.R-317-  # strict = TRUE: distinct non-empty values that DISAGREE across layers reject
api/functions/analysis-snapshot-release.R-318-  # the build (release_source_version_mismatch -> 400), like source_data_version.
api/functions/analysis-snapshot-release.R-319-  shared_db_release_version <- .analysis_release_consistent_manifest_value(loaded, "db_release_version", strict = TRUE)
api/functions/analysis-snapshot-release.R:320:  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit", strict = TRUE)
api/functions/analysis-snapshot-release.R-321-
api/functions/analysis-snapshot-release.R-322-  # For the correlation layer, pin the actual dependency lineage into its entry.
api/functions/analysis-snapshot-release.R-323-  corr <- loaded[["phenotype_functional_correlations"]]
api/functions/analysis-snapshot-release.R-324-  if (!is.null(corr)) {
--
api/functions/analysis-snapshot-release.R-423-    source = list(
api/functions/analysis-snapshot-release.R-424-      source_data_version = shared_source_version,
api/functions/analysis-snapshot-release.R-425-      db_release = list(
api/functions/analysis-snapshot-release.R-426-        version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
api/functions/analysis-snapshot-release.R:427:        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
api/functions/analysis-snapshot-release.R-428-      ),
api/functions/analysis-snapshot-release.R-429-      snapshots = lapply(layer_entries, function(e) {
api/functions/analysis-snapshot-release.R-430-        list(analysis_type = e$analysis_type, snapshot_id = e$snapshot_id, parameter_hash = e$parameter_hash)
api/functions/analysis-snapshot-release.R-431-      })
--
api/functions/analysis-snapshot-release.R-472-    bundle_sha256 = bundle_sha256,
api/functions/analysis-snapshot-release.R-473-    bundle_gzip = bundle_gzip,
api/functions/analysis-snapshot-release.R-474-    source_data_version = shared_source_version,
api/functions/analysis-snapshot-release.R-475-    db_release_version = if (is.na(shared_db_release_version)) NULL else shared_db_release_version,
api/functions/analysis-snapshot-release.R:476:    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
api/functions/analysis-snapshot-release.R-477-    scope_statement = scope_statement,
api/functions/analysis-snapshot-release.R-478-    license = license %||% "CC-BY-4.0",
api/functions/analysis-snapshot-release.R-479-    created_by_user_id = created_by
api/functions/analysis-snapshot-release.R-480-  )
--
api/functions/analysis-snapshot-release-zenodo-package.R-83-  ".git", ".planning", ".superpowers", ".venv", "__pycache__"
api/functions/analysis-snapshot-release-zenodo-package.R-84-)
api/functions/analysis-snapshot-release-zenodo-package.R-85-.ANALYSIS_RELEASE_ZENODO_SENSITIVE_TEXT_PATTERNS <- c(
api/functions/analysis-snapshot-release-zenodo-package.R-86-  "/home/", "/users/", "bernt-popp", "zenodo_token", "zenodo_access_token",
api/functions/analysis-snapshot-release-zenodo-package.R:87:  "bearer ", "development/sysndd", "development/nddscore", ".env", "git_sha"
api/functions/analysis-snapshot-release-zenodo-package.R-88-)
api/functions/analysis-snapshot-release-zenodo-package.R-89-.ANALYSIS_RELEASE_ZENODO_TEXT_SUFFIXES <- c(".md", ".json", ".sql", ".cff", ".sha256", ".txt")
api/functions/analysis-snapshot-release-zenodo-package.R-90-.ANALYSIS_RELEASE_ZENODO_EXPECTED_TOP_LEVEL <- c(
api/functions/analysis-snapshot-release-zenodo-package.R-91-  "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
--
api/services/analysis-snapshot-service.R-368-      db_release = list(
api/services/analysis-snapshot-service.R-369-        version = service_analysis_snapshot_json_scalar(
api/services/analysis-snapshot-service.R-370-          service_analysis_snapshot_column_value(row, "db_release_version")),
api/services/analysis-snapshot-service.R-371-        commit  = service_analysis_snapshot_json_scalar(
api/services/analysis-snapshot-service.R:372:          service_analysis_snapshot_column_value(row, "db_release_commit"))
api/services/analysis-snapshot-service.R-373-      )
api/services/analysis-snapshot-service.R-374-    )
api/services/analysis-snapshot-service.R-375-  )
api/services/analysis-snapshot-service.R-376-}

exec
/bin/bash -lc "nl -ba api/endpoints/analysis_endpoints.R | sed -n '430,540p'; rg -n -C 3 \"svc_release_(get|bundle|list)|analysis_release_get\\(\" api/services api/functions -g '*.R' | head -n 280" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
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
api/functions/analysis-snapshot-release.R-381-  release_id <- analysis_release_id(content_digest)
api/functions/analysis-snapshot-release.R-382-
api/functions/analysis-snapshot-release.R-383-  if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
api/functions/analysis-snapshot-release.R:384:    existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/functions/analysis-snapshot-release.R-385-    if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
api/functions/analysis-snapshot-release.R-386-      return(list(release = existing, created = FALSE))
api/functions/analysis-snapshot-release.R-387-    }
--
api/functions/analysis-snapshot-release.R-513-    },
api/functions/analysis-snapshot-release.R-514-    error = function(e) {
api/functions/analysis-snapshot-release.R-515-      if (!is.null(conn) && analysis_release_exists(release_id, conn = conn)) {
api/functions/analysis-snapshot-release.R:516:        existing <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/functions/analysis-snapshot-release.R-517-        if (!is.null(existing) && identical(as.character(existing$content_digest), content_digest)) {
api/functions/analysis-snapshot-release.R-518-          return(FALSE) # idempotent: the concurrent winner stored the identical release
api/functions/analysis-snapshot-release.R-519-        }
--
api/functions/analysis-snapshot-release.R-524-
api/functions/analysis-snapshot-release.R-525-  if (!isTRUE(insert_created)) {
api/functions/analysis-snapshot-release.R-526-    return(list(
api/functions/analysis-snapshot-release.R:527:      release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
api/functions/analysis-snapshot-release.R-528-      created = FALSE
api/functions/analysis-snapshot-release.R-529-    ))
api/functions/analysis-snapshot-release.R-530-  }
--
api/functions/analysis-snapshot-release.R-534-  }
api/functions/analysis-snapshot-release.R-535-
api/functions/analysis-snapshot-release.R-536-  list(
api/functions/analysis-snapshot-release.R:537:    release = analysis_release_get(release_id, include_draft = TRUE, conn = conn),
api/functions/analysis-snapshot-release.R-538-    created = TRUE
api/functions/analysis-snapshot-release.R-539-  )
api/functions/analysis-snapshot-release.R-540-}
--
api/services/analysis-snapshot-release-service.R-27-# DUPLICATE/idempotent build (`created = FALSE`) is NOT an error: the caller
api/services/analysis-snapshot-release-service.R-28-# gets 200 + the existing head instead of 201 + the new head.
api/services/analysis-snapshot-release-service.R-29-#
api/services/analysis-snapshot-release-service.R:30:# PUBLIC SURFACE. `svc_release_list/get/manifest/file/bundle()` are the
api/services/analysis-snapshot-release-service.R-31-# published-only public read surface: every repository call is pinned to
api/services/analysis-snapshot-release-service.R-32-# `status = "published"` / `include_draft = FALSE`, so a draft release (or an
api/services/analysis-snapshot-release-service.R-33-# unknown release id, or an unknown archive file path) is indistinguishable
--
api/services/analysis-snapshot-release-service.R-129-#' @export
api/services/analysis-snapshot-release-service.R-130-svc_release_publish <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R-131-  analysis_release_publish(release_id, conn = conn)
api/services/analysis-snapshot-release-service.R:132:  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/services/analysis-snapshot-release-service.R-133-  if (is.null(head)) {
api/services/analysis-snapshot-release-service.R-134-    stop_for_not_found(sprintf("Release '%s' not found", release_id))
api/services/analysis-snapshot-release-service.R-135-  }
--
api/services/analysis-snapshot-release-service.R-150-#' @export
api/services/analysis-snapshot-release-service.R-151-svc_release_set_doi <- function(release_id, doi_fields, conn = NULL) {
api/services/analysis-snapshot-release-service.R-152-  analysis_release_set_doi(release_id, doi_fields = doi_fields, conn = conn)
api/services/analysis-snapshot-release-service.R:153:  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/services/analysis-snapshot-release-service.R-154-  if (is.null(head)) {
api/services/analysis-snapshot-release-service.R-155-    stop_for_not_found(sprintf("Release '%s' not found", release_id))
api/services/analysis-snapshot-release-service.R-156-  }
--
api/services/analysis-snapshot-release-service.R-168-#' @return `list(deleted = TRUE, release_id = release_id)`.
api/services/analysis-snapshot-release-service.R-169-#' @export
api/services/analysis-snapshot-release-service.R-170-svc_release_delete_draft <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R:171:  head <- analysis_release_get(release_id, include_draft = TRUE, conn = conn)
api/services/analysis-snapshot-release-service.R-172-  if (is.null(head)) {
api/services/analysis-snapshot-release-service.R-173-    stop_for_not_found(sprintf("Release '%s' not found", release_id))
api/services/analysis-snapshot-release-service.R-174-  }
--
api/services/analysis-snapshot-release-service.R-195-#' @return A list of public-projected release-head-plus-layers entries; never
api/services/analysis-snapshot-release-service.R-196-#'   includes drafts.
api/services/analysis-snapshot-release-service.R-197-#' @export
api/services/analysis-snapshot-release-service.R:198:svc_release_list <- function(limit = 50, offset = 0, conn = NULL) {
api/services/analysis-snapshot-release-service.R-199-  limit <- svc_release_clamp_limit(limit)
api/services/analysis-snapshot-release-service.R-200-  offset <- svc_release_clamp_offset(offset)
api/services/analysis-snapshot-release-service.R-201-  rows <- analysis_release_list(status = "published", limit = limit, offset = offset, conn = conn)
--
api/services/analysis-snapshot-release-service.R-232-#' @param conn A real DBIConnection.
api/services/analysis-snapshot-release-service.R-233-#' @return The release head (+ `$manifest`).
api/services/analysis-snapshot-release-service.R-234-#' @export
api/services/analysis-snapshot-release-service.R:235:svc_release_get <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R:236:  head <- analysis_release_get(release_id, include_draft = FALSE, conn = conn)
api/services/analysis-snapshot-release-service.R-237-  if (is.null(head)) {
api/services/analysis-snapshot-release-service.R-238-    stop_for_not_found("Release not found")
api/services/analysis-snapshot-release-service.R-239-  }
--
api/services/analysis-snapshot-release-service.R-279-#' @param conn A real DBIConnection.
api/services/analysis-snapshot-release-service.R-280-#' @return `list(bytes, sha256, filename)`.
api/services/analysis-snapshot-release-service.R-281-#' @export
api/services/analysis-snapshot-release-service.R:282:svc_release_bundle <- function(release_id, conn = NULL) {
api/services/analysis-snapshot-release-service.R-283-  bundle <- analysis_release_get_bundle(release_id, include_draft = FALSE, conn = conn)
api/services/analysis-snapshot-release-service.R-284-  if (is.null(bundle)) {
api/services/analysis-snapshot-release-service.R-285-    stop_for_not_found("Release not found")
--
api/functions/analysis-snapshot-release-repository.R-198-#' `last_error_message`, `updated_at` — that must never reach the public
api/functions/analysis-snapshot-release-repository.R-199-#' list/detail/latest surface. This projects to an explicit allowlist and groups
api/functions/analysis-snapshot-release-repository.R-200-#' the DOI fields under `zenodo`. Public-safe derived members (`layers` from
api/functions/analysis-snapshot-release-repository.R:201:#' `analysis_release_list()`, the parsed `manifest` from `analysis_release_get()`)
api/functions/analysis-snapshot-release-repository.R-202-#' are carried through when present. The ADMIN surface keeps the raw head.
api/functions/analysis-snapshot-release-repository.R-203-#'
api/functions/analysis-snapshot-release-repository.R-204-#' @param head A named list (a raw head from the repository read functions), or NULL.

exec
/bin/bash -lc "rg -n \"git_sha|ZENODO_TOKEN|SYSNDD_ADMIN_TOKEN|bernt-popp|/home/|/users/|development/sysndd|\\.env|\\.git\" api/functions/analysis-snapshot-release-zenodo-* api/scripts/{package,upload}-analysis-release-zenodo.R api/tests/testthat/test-unit-analysis-release-zenodo-* documentation/09-deployment.qmd Makefile" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
Makefile:387:		printf "$(GREEN)✓ analysis-release-zenodo-package complete (see outputs/analysis-release-zenodo/latest.env)$(RESET)\n" || \
Makefile:391:	@if [ -z "$${ZENODO_TOKEN:-}" ]; then \
Makefile:392:		printf "$(RED)✗ ZENODO_TOKEN is not set (export it in your shell or .env before running this target)$(RESET)\n"; \
Makefile:395:	@if [ ! -f "$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env" ]; then \
Makefile:396:		printf "$(RED)✗ outputs/analysis-release-zenodo/latest.env not found -- run 'make analysis-release-zenodo-package' first$(RESET)\n"; \
Makefile:400:	@. "$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env" && \
Makefile:549:#   - Seeds .env and api/config.yml from their committed templates if missing,
Makefile:583:	@# Seed .env from template if missing — needed because docker-compose.yml
Makefile:585:	@# The PLAYWRIGHT_ENV exports below also set these inline, so the .env file
Makefile:587:	@if [ ! -f $(ROOT_DIR)/.env ]; then \
Makefile:588:		printf "$(YELLOW)⚠ Seeding .env from .env.example$(RESET)\n"; \
Makefile:589:		cp $(ROOT_DIR)/.env.example $(ROOT_DIR)/.env; \
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:52:  captured <- new.env()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:85:  captured <- new.env()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:106:  captured <- new.env()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:129:  captured <- new.env()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:152:  captured <- new.env()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:175:  captured <- new.env()
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:418:    "ZENODO_TOKEN"
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:196:test_that("validate_staging: FAILS when a .env file is planted", {
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:198:  writeLines("SECRET=1", file.path(staging, "analysis_snapshot_release", ".env"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:204:  writeLines("built at /home/bernt-popp/development/sysndd on this host", file.path(staging, "README.md"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:210:  writeLines("ZENODO_TOKEN=abc123", file.path(staging, "DATA_CARD.md"))
api/tests/testthat/test-unit-analysis-release-zenodo-package.R:298:  captured <- new.env()
documentation/09-deployment.qmd:12:git clone https://github.com/berntpopp/sysndd.git
documentation/09-deployment.qmd:14:cp .env.example .env
documentation/09-deployment.qmd:15:# edit .env
documentation/09-deployment.qmd:55:# 1. ROTATE the DB password, update the deployed .env / secret, then recreate.
documentation/09-deployment.qmd:124:Increment `CACHE_VERSION` when cached API/worker function behavior or result shape changes and you need invalidation on next startup. The Compose default is `${CACHE_VERSION:-3}` for the `api` and workers that share `api_cache`; MCP has no cache mount or cache fallback. On startup `bootstrap_init_cache_version()` clears every `/app/cache/*.rds` when the stored marker differs. If deployment pins `CACHE_VERSION` explicitly in `.env`, bump it manually when shipping a memoised-shape change.
documentation/09-deployment.qmd:213:./db/scripts/update-db-version.sh 1.1.0 >> .env   # inject, then redeploy
documentation/09-deployment.qmd:323:- `ZENODO_TOKEN` — a Zenodo personal access token (`https://zenodo.org/account/settings/applications/tokens/new/`, scope `deposit:write` + `deposit:actions`). Set it in your shell or a git-ignored `.env`; it is **never** committed and the Makefile never bakes it in as a literal.
documentation/09-deployment.qmd:325:- `SYSNDD_ADMIN_TOKEN` (optional) — a pre-minted SysNDD Administrator bearer token, only needed for the automated DOI record-back in step 6.
documentation/09-deployment.qmd:335:   Downloads the release's `bundle.tar.gz`, verifies its checksum, re-stages the files under `analysis_snapshot_release/`, adds Zenodo-facing `README.md`/`DATA_CARD.md`/`SCHEMA.md`/`CHANGELOG.md`/`CITATION.cff`/`zenodo_metadata.json`/`datapackage.json`, runs the packaging safety validator (rejects any planted `.env`/`.git`/sensitive-text content — defense-in-depth; a release payload has no such content by construction), and writes `outputs/analysis-release-zenodo/<release_id>.tar.gz` + `.sha256` plus a `outputs/analysis-release-zenodo/latest.env` pointer file (`ARCHIVE_PATH`/`METADATA_PATH`/`RELEASE_ID`) so the next step can find the content-addressed archive without a hardcoded, drift-prone filename.
documentation/09-deployment.qmd:343:   Requires `ZENODO_TOKEN` (the target fails fast with a clear message if it is unset) and `outputs/analysis-release-zenodo/latest.env` (fails fast with "run analysis-release-zenodo-package first" if absent). Creates (or reuses, via `--deposition-id`) a Zenodo deposition, sets its metadata, and streams the archive to the deposition bucket — **always a DRAFT**, never published. Prints the reserved DOI and the draft's Zenodo web URL.
documentation/09-deployment.qmd:352:6. **Record the DOI** back onto the SysNDD release head — additive only; it never touches `content_digest`/`manifest_sha256`, so the bytes a consumer already downloaded stay valid. Either automatically, by adding `--record-doi` (with `SYSNDD_ADMIN_TOKEN` set) to the publish command in step 5, or by running the manual `curl` command the script prints when `--record-doi` is omitted (equivalent to the `PATCH .../releases/<release_id>/doi` call documented above).
documentation/09-deployment.qmd:449:3. Set the non-secret `MCP_ADMIN_DB_HOST/PORT/NAME/USER` and exact migration identity `MCP_EXPECTED_VIEW_DEFINER=user@host` in the owner-only `.env`. Never substitute the API credential for administrator authority. The provisioner reads the admin credential only from `MCP_ADMIN_DB_PASSWORD_FILE=/run/secrets/sysndd/mcp-admin-db-password` and writes the generated reader credential only to `MCP_DB_PASSWORD_OUTPUT_FILE=/run/secrets/sysndd/mcp-db-password`.
documentation/09-deployment.qmd:512:- Public clustering submission has a queue-depth cap. `ASYNC_PUBLIC_JOB_CAP` (default `8`) bounds simultaneously queued/running jobs on the `default` queue; over the cap the public submit routes return `503` + `Retry-After: 60` (`CAPACITY_EXCEEDED`). Raise it in the deployed `.env` if the worker fleet can sustain more concurrent STRING-db clustering jobs.
documentation/09-deployment.qmd:530:- Configure the default NDDScore Zenodo source in the production `.env` file. `NDDSCORE_ZENODO_RECORD_ID` defaults to `20258027`, and `NDDSCORE_ZENODO_API_BASE_URL` defaults to `https://zenodo.org/api/records`. The API and worker containers both receive these variables; if they are missing, `api/config.yml` provides the same defaults.
documentation/09-deployment.qmd:610:The production frontend image builds with `VUE_MODE=production` by default so Vite reads `app/.env.production`. Do not build the production image with `VUE_MODE=docker`; that mode is reserved for the local development container.
api/scripts/package-analysis-release-zenodo.R:73:#' Write/overwrite the stable `outputs/analysis-release-zenodo/latest.env`
api/scripts/package-analysis-release-zenodo.R:84:  marker_path <- "outputs/analysis-release-zenodo/latest.env"
api/functions/analysis-snapshot-release-zenodo-package.R:81:.ANALYSIS_RELEASE_ZENODO_FORBIDDEN_FILENAMES <- c(".env", ".env.local", ".envrc")
api/functions/analysis-snapshot-release-zenodo-package.R:83:  ".git", ".planning", ".superpowers", ".venv", "__pycache__"
api/functions/analysis-snapshot-release-zenodo-package.R:86:  "/home/", "/users/", "bernt-popp", "zenodo_token", "zenodo_access_token",
api/functions/analysis-snapshot-release-zenodo-package.R:87:  "bearer ", "development/sysndd", "development/nddscore", ".env", "git_sha"
api/scripts/upload-analysis-release-zenodo.R:19:#     [--token <ZENODO_TOKEN, defaults to env>] [--sandbox] \
api/scripts/upload-analysis-release-zenodo.R:30:# `SYSNDD_ADMIN_TOKEN` env var (a pre-minted SysNDD Administrator bearer
api/scripts/upload-analysis-release-zenodo.R:87:  token <- Sys.getenv("ZENODO_TOKEN", "")
api/scripts/upload-analysis-release-zenodo.R:163:#' credentials (`SYSNDD_ADMIN_TOKEN`) AND the run reached a real, published
api/scripts/upload-analysis-release-zenodo.R:177:  admin_token <- Sys.getenv("SYSNDD_ADMIN_TOKEN", "")
api/scripts/upload-analysis-release-zenodo.R:199:      ". Run with --record-doi and SYSNDD_ADMIN_TOKEN set after publishing, ",
api/functions/analysis-snapshot-release-zenodo-upload.R:175:# `--record-doi` AND `SYSNDD_ADMIN_TOKEN` is set. Otherwise it prints
api/functions/analysis-snapshot-release-zenodo-upload.R:212:#'   (`SYSNDD_ADMIN_TOKEN`). Distinct from the Zenodo `token` used elsewhere
api/functions/analysis-snapshot-release-zenodo-upload.R:238:    "-H 'Authorization: Bearer <SYSNDD_ADMIN_TOKEN>' ",
api/functions/analysis-snapshot-release-zenodo-upload.R:273:    stop("ZENODO_TOKEN not set and --token not provided", call. = FALSE)

exec
/bin/bash -lc "rg -n \"function.*assert_safe_path|\\.analysis_release_assert_safe_path|db_release_commit\" api/functions/analysis-snapshot-release-manifest.R api/functions/analysis-snapshot-*.R | head -n 220; nl -ba api/functions/analysis-snapshot-release-manifest.R | sed -n '88,132p;247,315p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
api/functions/analysis-snapshot-builder.R:520:    db_release_commit  <- if (isTRUE(dbv$available)) dbv$commit  %||% "unknown" else "unknown"
api/functions/analysis-snapshot-builder.R:524:      db_release_commit = db_release_commit
api/functions/analysis-snapshot-builder.R:549:          db_release_commit  = db_release_commit
api/functions/analysis-snapshot-repository.R:118:         validation_json, db_release_version, db_release_commit
api/functions/analysis-snapshot-repository.R:147:        analysis_snapshot_scalar(manifest$db_release_commit,  NA_character_)
api/functions/analysis-snapshot-release.R:320:  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit", strict = TRUE)
api/functions/analysis-snapshot-release.R:427:        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
api/functions/analysis-snapshot-release.R:476:    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
api/functions/analysis-snapshot-release-manifest.R:103:.analysis_release_assert_safe_path <- function(path) {
api/functions/analysis-snapshot-release-manifest.R:255:    .analysis_release_assert_safe_path(path)
api/functions/analysis-snapshot-release-repository.R:65:  "source_data_version, db_release_version, db_release_commit, scope_statement,",
api/functions/analysis-snapshot-release-repository.R:87:#' `title`, `source_data_version`, `db_release_version`, `db_release_commit`,
api/functions/analysis-snapshot-release-repository.R:125:         source_data_version, db_release_version, db_release_commit, scope_statement,
api/functions/analysis-snapshot-release-repository.R:140:        .analysis_release_chr(release_head$db_release_commit),
api/functions/analysis-snapshot-release-repository.R:216:    "db_release_version", "db_release_commit", "manifest_sha256",
api/functions/analysis-snapshot-release-materialize.R:367:  .analysis_release_assert_safe_path(path)
api/functions/analysis-snapshot-release-manifest.R:103:.analysis_release_assert_safe_path <- function(path) {
api/functions/analysis-snapshot-release-manifest.R:255:    .analysis_release_assert_safe_path(path)
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

exec
/bin/bash -lc 'R_HOME_VALUE=$(R RHOME 2>/dev/null || true); printf '"'%s\\n' \""'$R_HOME_VALUE"; rg -n -C 3 "untar|tar" /usr/lib/R/library/utils/R 2>/dev/null | head -n 300; rg -n "function '"\\(.*tar|\\.Internal\\(tar|write\\.tar\" /usr/share/R /usr/lib/R 2>/dev/null | head -n 200" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
/home/bernt-popp/miniforge3/lib/R

exec
/bin/bash -lc "git status --short; git diff --check origin/master...HEAD -- ':(exclude).planning/**'; make -n analysis-release-zenodo-upload-draft | sed -n '1,160p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review.md
command -v R > /dev/null 2>&1 || \
	(printf "\033[0;31mERROR: R is not installed\033[0m\n" && \
	 printf "Install R from: https://www.r-project.org/\n" && \
	 exit 1)
if [ -z "${ZENODO_TOKEN:-}" ]; then \
	printf "\033[0;31m✗ ZENODO_TOKEN is not set (export it in your shell or .env before running this target)\033[0m\n"; \
	exit 1; \
fi
if [ ! -f "/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/outputs/analysis-release-zenodo/latest.env" ]; then \
	printf "\033[0;31m✗ outputs/analysis-release-zenodo/latest.env not found -- run 'make analysis-release-zenodo-package' first\033[0m\n"; \
	exit 1; \
fi
printf "\033[0;36m==> Uploading last-packaged analysis-snapshot release to a Zenodo DRAFT (never publishes)...\033[0m\n"
. "/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/outputs/analysis-release-zenodo/latest.env" && \
	cd /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573 && env LD_LIBRARY_PATH="/home/bernt-popp/miniforge3/lib/mariadb" Rscript --no-init-file api/scripts/upload-analysis-release-zenodo.R \
		--archive "$ARCHIVE_PATH" --metadata "$METADATA_PATH" --release-id "$RELEASE_ID"  && \
	printf "\033[0;32m✓ analysis-release-zenodo-upload-draft complete -- DRAFT only; publishing is a deliberate manual step (see documentation/09-deployment.qmd)\033[0m\n" || \
	(printf "\033[0;31m✗ analysis-release-zenodo-upload-draft failed\033[0m\n" && exit 1)

codex
Two material safety boundaries are now questionable: the packager recursively removes any caller-supplied staging path, and its `latest.env` handoff is later shell-sourced without validating the API-returned release ID. I’m validating those control-flow paths and the existing test coverage before assigning severity.
exec
/bin/bash -lc "Rscript -e 'f <- tempfile(); dir.create(f); d <- file.path(f,\"src\"); dir.create(d); writeLines(\"x\",file.path(d,\"x\")); old<-setwd(d); utils::tar(file.path(f,\"a.tar.gz\"), \"x\", compression=\"gzip\", tar=\"internal\"); setwd(old); Sys.sleep(1); utils::tar(file.path(f,\"b.tar.gz\"), file.path(\"src\",\"x\"), compression=\"gzip\", tar=\"internal\"); print(unname(tools::md5sum(c(file.path(f,\"a.tar.gz\"),file.path(f,\"b.tar.gz\")))) ; unlink(f,recursive=TRUE)'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
exec
/bin/bash -lc "cd api && Rscript -e \"testthat::test_file('tests/testthat/test-unit-analysis-release-zenodo-upload.R')\"" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 exited 2 in 0ms:
Fatal error: creating temporary file for '-e' failed

exec
/bin/bash -lc "Rscript -e 'f <- tempfile(); dir.create(f); x <- file.path(f, \"a\"); dir.create(x); writeLines(\"z\", file.path(x,\"x.txt\")); print(list.files(f, recursive=TRUE, all.files=TRUE, no..=TRUE, full.names=FALSE)); print(list.files(f, recursive=TRUE, all.files=TRUE, no..=TRUE, full.names=TRUE)); unlink(f, recursive=TRUE)'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 exited 2 in 0ms:
Fatal error: creating temporary file for '-e' failed

 exited 2 in 0ms:
Fatal error: creating temporary file for '-e' failed

exec
/bin/bash -lc "sed -n '1,260p' /home/bernt-popp/.codex/superpowers/skills/verification-before-completion/SKILL.md && cd api && Rscript -e \"testthat::test_file('tests/testthat/test-unit-analysis-release-zenodo-package.R')\"" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 exited 2 in 0ms:
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
Fatal error: creating temporary file for '-e' failed

exec
/bin/bash -lc "rg -n \"analysis_snapshot_db_release|db_release.*commit|commit.*db_release\" api/functions api/bootstrap api/core -g '*.R' | head -n 240; nl -ba api/functions/analysis-snapshot-builder.R | sed -n '485,560p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
api/functions/analysis-snapshot-release.R:320:  shared_db_release_commit <- .analysis_release_consistent_manifest_value(loaded, "db_release_commit", strict = TRUE)
api/functions/analysis-snapshot-release.R:427:        commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit
api/functions/analysis-snapshot-release.R:476:    db_release_commit = if (is.na(shared_db_release_commit)) NULL else shared_db_release_commit,
api/functions/analysis-snapshot-release-repository.R:65:  "source_data_version, db_release_version, db_release_commit, scope_statement,",
api/functions/analysis-snapshot-release-repository.R:87:#' `title`, `source_data_version`, `db_release_version`, `db_release_commit`,
api/functions/analysis-snapshot-release-repository.R:125:         source_data_version, db_release_version, db_release_commit, scope_statement,
api/functions/analysis-snapshot-release-repository.R:140:        .analysis_release_chr(release_head$db_release_commit),
api/functions/analysis-snapshot-release-repository.R:216:    "db_release_version", "db_release_commit", "manifest_sha256",
api/functions/analysis-snapshot-builder.R:520:    db_release_commit  <- if (isTRUE(dbv$available)) dbv$commit  %||% "unknown" else "unknown"
api/functions/analysis-snapshot-builder.R:524:      db_release_commit = db_release_commit
api/functions/analysis-snapshot-builder.R:549:          db_release_commit  = db_release_commit
api/functions/analysis-snapshot-repository.R:118:         validation_json, db_release_version, db_release_commit
api/functions/analysis-snapshot-repository.R:147:        analysis_snapshot_scalar(manifest$db_release_commit,  NA_character_)
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

exec
/bin/bash -lc "nl -ba api/functions/analysis-snapshot-release-zenodo-package.R | sed -n '120,220p;480,600p'; nl -ba api/scripts/package-analysis-release-zenodo.R | sed -n '80,155p'; nl -ba Makefile | sed -n '378,407p'" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
   120	}
   121
   122	#' Fetch a published release's head + parsed manifest over the public API.
   123	#'
   124	#' @param api_base_url Base URL of the SysNDD API (e.g. "http://localhost:7778").
   125	#' @param release_id "latest" (default) or an explicit `asr_<16 hex>` id.
   126	#' @param http_get_json Function(url) -> parsed JSON list. Injectable seam.
   127	#' @return The parsed head list (release_id, created_at, license,
   128	#'   source_data_version, bundle_sha256, manifest, ...).
   129	analysis_release_zenodo_fetch_head <- function(
   130	    api_base_url,
   131	    release_id = "latest",
   132	    http_get_json = .analysis_release_zenodo_http_get_json) {
   133	  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
   134	  release_id <- as.character(release_id)[[1]]
   135	  url <- paste0(base_url, "/api/analysis/releases/", release_id)
   136	  http_get_json(url)
   137	}
   138
   139	#' Download a published release's whole `bundle.tar.gz`, verbatim, to `destfile`.
   140	#'
   141	#' @param release_id An EXPLICIT `asr_<16 hex>` id (there is no
   142	#'   `/releases/latest/bundle` route -- callers must resolve the concrete id
   143	#'   via `analysis_release_zenodo_fetch_head()` first).
   144	#' @param http_download Function(url, destfile). Injectable seam.
   145	#' @return `destfile`, invisibly-compatible (returned for chaining).
   146	analysis_release_zenodo_download_bundle <- function(
   147	    api_base_url,
   148	    release_id,
   149	    destfile,
   150	    http_download = .analysis_release_zenodo_http_download) {
   151	  base_url <- sub("/+$", "", as.character(api_base_url)[[1]])
   152	  release_id <- as.character(release_id)[[1]]
   153	  url <- paste0(base_url, "/api/analysis/releases/", release_id, "/bundle")
   154	  http_download(url, destfile)
   155	  if (!file.exists(destfile) || file.size(destfile) == 0) {
   156	    stop("Analysis-snapshot release bundle download produced an empty file", call. = FALSE)
   157	  }
   158	  destfile
   159	}
   160
   161	#' Verify a downloaded bundle against the release head's `bundle_sha256`,
   162	#' extract it, then verify the bundle's OWN inner `checksums.sha256` against
   163	#' every extracted file. Mirrors `nddscore_extract_and_verify()`'s verify
   164	#' loop, but the outer digest is SHA-256 (not MD5), and the release bundle's
   165	#' files sit directly at the archive root (no named top-level subdirectory
   166	#' to search for).
   167	#'
   168	#' @param bundle_path Path to the downloaded `bundle.tar.gz`.
   169	#' @param expected_bundle_sha256 The release head's `bundle_sha256`.
   170	#' @param exdir Optional extraction directory (defaults to a fresh temp dir).
   171	#' @return Path to the extraction directory (== `exdir`).
   172	analysis_release_zenodo_extract_and_verify <- function(
   173	    bundle_path, expected_bundle_sha256, exdir = NULL) {
   174	  if (!file.exists(bundle_path)) {
   175	    stop("Analysis-snapshot release bundle not found for verification", call. = FALSE)
   176	  }
   177	  actual_bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")
   178	  expected <- tolower(as.character(expected_bundle_sha256 %||% "")[[1]])
   179	  if (!identical(tolower(actual_bundle_sha256), expected)) {
   180	    stop(sprintf(
   181	      "Analysis-snapshot release bundle checksum mismatch (expected %s, got %s)",
   182	      expected, actual_bundle_sha256
   183	    ), call. = FALSE)
   184	  }
   185
   186	  if (is.null(exdir)) {
   187	    exdir <- file.path(
   188	      tempdir(), paste0("analysis_release_zenodo_extract_", as.integer(stats::runif(1, 1, 1e9)))
   189	    )
   190	  }
   191	  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
   192	  utils::untar(bundle_path, exdir = exdir)
   193
   194	  sha_file <- file.path(exdir, "checksums.sha256")
   195	  if (!file.exists(sha_file)) {
   196	    stop("Extracted release bundle has no checksums.sha256", call. = FALSE)
   197	  }
   198	  sha_lines <- readLines(sha_file, warn = FALSE)
   199	  sha_lines <- sha_lines[nzchar(trimws(sha_lines))]
   200	  for (line in sha_lines) {
   201	    parts <- strsplit(trimws(line), "\\s+")[[1]]
   202	    expected_sha <- parts[[1]]
   203	    rel_name <- parts[[length(parts)]]
   204	    target <- file.path(exdir, rel_name)
   205	    if (!file.exists(target)) {
   206	      stop(sprintf("checksums.sha256 references missing file '%s'", rel_name), call. = FALSE)
   207	    }
   208	    actual_sha <- digest::digest(file = target, algo = "sha256")
   209	    if (!identical(tolower(actual_sha), tolower(expected_sha))) {
   210	      stop(sprintf("Bundled sha256 mismatch for release file '%s'", rel_name), call. = FALSE)
   211	    }
   212	  }
   213	  exdir
   214	}
   215
   216	# --------------------------------------------------------------------------- #
   217	# Shared public-file iterator -- filter-at-source, reused by every
   218	# builder/checksums/validator step (belt half of belt-and-suspenders).
   219	# --------------------------------------------------------------------------- #
   220
   480	# Orchestrator
   481	# --------------------------------------------------------------------------- #
   482
   483	#' Recursively sort a named list's keys alphabetically (objects only --
   484	#' unnamed lists/arrays are recursed into without reordering). Used for
   485	#' `zenodo_metadata.json`'s "pretty JSON, sorted keys" contract, mirroring
   486	#' Python's `json.dumps(..., sort_keys=True)`.
   487	.analysis_release_zenodo_sort_keys <- function(x) {
   488	  if (is.list(x)) {
   489	    nms <- names(x)
   490	    if (!is.null(nms) && all(nzchar(nms))) {
   491	      x <- x[order(nms)]
   492	    }
   493	    x <- lapply(x, .analysis_release_zenodo_sort_keys)
   494	  }
   495	  x
   496	}
   497
   498	.analysis_release_zenodo_copy_tree <- function(src_dir, dest_dir) {
   499	  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
   500	  rel_paths <- list.files(src_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, full.names = FALSE)
   501	  for (rel_path in rel_paths) {
   502	    dest_path <- file.path(dest_dir, rel_path)
   503	    dir.create(dirname(dest_path), recursive = TRUE, showWarnings = FALSE)
   504	    file.copy(file.path(src_dir, rel_path), dest_path, overwrite = TRUE, copy.date = TRUE)
   505	  }
   506	  invisible(dest_dir)
   507	}
   508
   509	#' Fetch a published release over the public HTTP API and assemble a Zenodo
   510	#' staging directory + deterministic tarball. Mirrors nddscore's
   511	#' `build_zenodo_dataset_package()` top-to-bottom.
   512	#'
   513	#' @return list(staging_dir, archive_path, archive_sha256_path,
   514	#'   zenodo_metadata_path, release_id).
   515	analysis_release_zenodo_package <- function(
   516	    api_base_url,
   517	    release_id = "latest",
   518	    staging_dir,
   519	    archive_dir,
   520	    version = NULL,
   521	    doi = NULL,
   522	    http_get_json = .analysis_release_zenodo_http_get_json,
   523	    http_download = .analysis_release_zenodo_http_download) {
   524	  head <- analysis_release_zenodo_fetch_head(api_base_url, release_id, http_get_json = http_get_json)
   525	  resolved_release_id <- as.character(head$release_id)[[1]]
   526
   527	  bundle_path <- tempfile(fileext = ".tar.gz")
   528	  on.exit(unlink(bundle_path, force = TRUE), add = TRUE)
   529	  analysis_release_zenodo_download_bundle(
   530	    api_base_url, resolved_release_id, bundle_path, http_download = http_download
   531	  )
   532	  extracted_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, head$bundle_sha256)
   533	  on.exit(unlink(extracted_dir, recursive = TRUE, force = TRUE), add = TRUE)
   534
   535	  if (dir.exists(staging_dir)) {
   536	    unlink(staging_dir, recursive = TRUE, force = TRUE)
   537	  }
   538	  dir.create(staging_dir, recursive = TRUE)
   539
   540	  nested_dir <- file.path(staging_dir, .ANALYSIS_RELEASE_ZENODO_NESTED_DIR)
   541	  .analysis_release_zenodo_copy_tree(extracted_dir, nested_dir)
   542
   543	  resolved_version <- as.character(
   544	    (version %||% head$source_data_version %||% resolved_release_id)
   545	  )[[1]]
   546
   547	  .analysis_release_zenodo_write_text(
   548	    file.path(staging_dir, "README.md"), analysis_release_zenodo_build_readme(head, doi)
   549	  )
   550	  .analysis_release_zenodo_write_text(
   551	    file.path(staging_dir, "DATA_CARD.md"), analysis_release_zenodo_build_data_card(head)
   552	  )
   553	  .analysis_release_zenodo_write_text(
   554	    file.path(staging_dir, "SCHEMA.md"), analysis_release_zenodo_build_schema_doc(head)
   555	  )
   556	  .analysis_release_zenodo_write_text(
   557	    file.path(staging_dir, "CHANGELOG.md"),
   558	    analysis_release_zenodo_build_changelog(head, resolved_version)
   559	  )
   560	  .analysis_release_zenodo_write_text(
   561	    file.path(staging_dir, "CITATION.cff"),
   562	    analysis_release_zenodo_build_citation_cff(head, resolved_version, doi)
   563	  )
   564
   565	  metadata <- analysis_release_zenodo_build_metadata(head, version = resolved_version)
   566	  metadata_json <- jsonlite::toJSON(
   567	    .analysis_release_zenodo_sort_keys(metadata), auto_unbox = TRUE, pretty = TRUE, null = "null"
   568	  )
   569	  zenodo_metadata_path <- file.path(staging_dir, "zenodo_metadata.json")
   570	  .analysis_release_zenodo_write_text(zenodo_metadata_path, paste0(as.character(metadata_json), "\n"))
   571
   572	  datapackage <- analysis_release_zenodo_build_datapackage(
   573	    staging_dir,
   574	    name = "sysndd-analysis-snapshot-release",
   575	    version = resolved_version,
   576	    release_id = resolved_release_id
   577	  )
   578	  datapackage_json <- jsonlite::toJSON(datapackage, auto_unbox = TRUE, pretty = TRUE, null = "null")
   579	  .analysis_release_zenodo_write_text(
   580	    file.path(staging_dir, "datapackage.json"), paste0(as.character(datapackage_json), "\n")
   581	  )
   582
   583	  analysis_release_zenodo_write_checksums(staging_dir)
   584
   585	  analysis_release_zenodo_validate_staging(staging_dir)
   586
   587	  archive_path <- file.path(archive_dir, paste0(resolved_release_id, ".tar.gz"))
   588	  tar_result <- analysis_release_zenodo_make_tarball(staging_dir, archive_path)
   589
   590	  list(
   591	    staging_dir = staging_dir,
   592	    archive_path = tar_result$archive_path,
   593	    archive_sha256_path = tar_result$archive_sha256_path,
   594	    zenodo_metadata_path = zenodo_metadata_path,
   595	    release_id = resolved_release_id
   596	  )
   597	}
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
   400		@. "$(ROOT_DIR)/outputs/analysis-release-zenodo/latest.env" && \
   401			cd $(ROOT_DIR) && $(HOST_RSCRIPT) api/scripts/upload-analysis-release-zenodo.R \
   402				--archive "$$ARCHIVE_PATH" --metadata "$$METADATA_PATH" --release-id "$$RELEASE_ID" $(UPLOAD_ARGS) && \
   403			printf "$(GREEN)✓ analysis-release-zenodo-upload-draft complete -- DRAFT only; publishing is a deliberate manual step (see documentation/09-deployment.qmd)$(RESET)\n" || \
   404			(printf "$(RED)✗ analysis-release-zenodo-upload-draft failed$(RESET)\n" && exit 1)
   405
   406	# =============================================================================
   407	# Docker Targets

exec
/bin/bash -lc "find /home/bernt-popp/miniforge3/lib/R/library/utils -maxdepth 3 -type f -printf '%p\\n' 2>/dev/null | head -n 100; rg -a -n \"tar =|internal.*tar|tarfile|mtime\" /home/bernt-popp/miniforge3/lib/R/library/utils 2>/dev/null | head -n 240" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
/home/bernt-popp/miniforge3/lib/R/library/utils/libs/utils.so
/home/bernt-popp/miniforge3/lib/R/library/utils/Meta/links.rds
/home/bernt-popp/miniforge3/lib/R/library/utils/Meta/features.rds
/home/bernt-popp/miniforge3/lib/R/library/utils/Meta/package.rds
/home/bernt-popp/miniforge3/lib/R/library/utils/Meta/hsearch.rds
/home/bernt-popp/miniforge3/lib/R/library/utils/Meta/Rd.rds
/home/bernt-popp/miniforge3/lib/R/library/utils/Meta/nsInfo.rds
/home/bernt-popp/miniforge3/lib/R/library/utils/iconvlist
/home/bernt-popp/miniforge3/lib/R/library/utils/R/utils
/home/bernt-popp/miniforge3/lib/R/library/utils/R/utils.rdx
/home/bernt-popp/miniforge3/lib/R/library/utils/R/sysdata.rdx
/home/bernt-popp/miniforge3/lib/R/library/utils/R/sysdata.rdb
/home/bernt-popp/miniforge3/lib/R/library/utils/R/utils.rdb
/home/bernt-popp/miniforge3/lib/R/library/utils/misc/exDIF.csv
/home/bernt-popp/miniforge3/lib/R/library/utils/misc/exDIF.dif
/home/bernt-popp/miniforge3/lib/R/library/utils/help/AnIndex
/home/bernt-popp/miniforge3/lib/R/library/utils/help/paths.rds
/home/bernt-popp/miniforge3/lib/R/library/utils/help/utils.rdx
/home/bernt-popp/miniforge3/lib/R/library/utils/help/aliases.rds
/home/bernt-popp/miniforge3/lib/R/library/utils/help/utils.rdb
/home/bernt-popp/miniforge3/lib/R/library/utils/doc/Sweave.pdf
/home/bernt-popp/miniforge3/lib/R/library/utils/Sweave/Sweave-test-1.Rnw
/home/bernt-popp/miniforge3/lib/R/library/utils/Sweave/example-1.Rnw
/home/bernt-popp/miniforge3/lib/R/library/utils/NAMESPACE
/home/bernt-popp/miniforge3/lib/R/library/utils/INDEX
/home/bernt-popp/miniforge3/lib/R/library/utils/DESCRIPTION
/home/bernt-popp/miniforge3/lib/R/library/utils/html/00Index.html
/home/bernt-popp/miniforge3/lib/R/library/utils/html/R.css

exec
/bin/bash -lc "find /home/bernt-popp/miniforge3/lib/R -type f \\( -iname '*tar*' -o -iname '*utils*' \\) -printf '%p\\n' 2>/dev/null | head -n 200; rg -a -n \"tar\" /home/bernt-popp/miniforge3/lib/R/library/utils/R 2>/dev/null | head -n 300" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
/home/bernt-popp/miniforge3/lib/R/share/R/tests-startup.R
/home/bernt-popp/miniforge3/lib/R/include/R_ext/RStartup.h
/home/bernt-popp/miniforge3/lib/R/include/R_ext/Utils.h
/home/bernt-popp/miniforge3/lib/R/library/rvest/doc/starwars-dynamic.html
/home/bernt-popp/miniforge3/lib/R/library/rvest/doc/starwars-dynamic.Rmd
/home/bernt-popp/miniforge3/lib/R/library/rvest/doc/starwars.html
/home/bernt-popp/miniforge3/lib/R/library/rvest/doc/starwars.Rmd
/home/bernt-popp/miniforge3/lib/R/library/rvest/doc/starwars.R
/home/bernt-popp/miniforge3/lib/R/library/rvest/doc/starwars-dynamic.R
/home/bernt-popp/miniforge3/lib/R/library/utils/libs/utils.so
/home/bernt-popp/miniforge3/lib/R/library/utils/R/utils
/home/bernt-popp/miniforge3/lib/R/library/utils/R/utils.rdx
/home/bernt-popp/miniforge3/lib/R/library/utils/R/utils.rdb
/home/bernt-popp/miniforge3/lib/R/library/utils/help/utils.rdx
/home/bernt-popp/miniforge3/lib/R/library/utils/help/utils.rdb
/home/bernt-popp/miniforge3/lib/R/library/Matrix/include/Matrix/cholmod-utils.h
/home/bernt-popp/miniforge3/lib/R/library/translations/pt_BR/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/pt_BR/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/zh_TW/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/zh_TW/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/hu/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/hu/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/fr/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/fr/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/hi/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/hi/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/en_GB/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/en_GB/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/fa/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/en@quot/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/en@quot/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/es/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/es/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/pl/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/pl/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/ar/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/ar/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/zh_CN/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/de/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/de/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/da/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/ne/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/ja/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/ko/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/ko/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/it/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/it/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/lt/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/lt/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/ca/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/ca/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/ru/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/ru/LC_MESSAGES/utils.mo
/home/bernt-popp/miniforge3/lib/R/library/translations/tr/LC_MESSAGES/R-utils.mo
/home/bernt-popp/miniforge3/lib/R/library/jsonlite/doc/json-aaquickstart.html
/home/bernt-popp/miniforge3/lib/R/library/jsonlite/doc/json-aaquickstart.Rmd
/home/bernt-popp/miniforge3/lib/R/library/jsonlite/doc/json-aaquickstart.R
/home/bernt-popp/miniforge3/lib/R/library/vroom/extdata/mtcars.csv.tar.gz
/home/bernt-popp/miniforge3/lib/R/library/httr/doc/quickstart.R
/home/bernt-popp/miniforge3/lib/R/library/httr/doc/quickstart.Rmd
/home/bernt-popp/miniforge3/lib/R/library/httr/doc/quickstart.html
/home/bernt-popp/miniforge3/lib/R/library/tzdb/tzdata/antarctica
/home/bernt-popp/miniforge3/lib/R/library/webutils/libs/webutils.so
/home/bernt-popp/miniforge3/lib/R/library/webutils/R/webutils.rdx
/home/bernt-popp/miniforge3/lib/R/library/webutils/R/webutils
/home/bernt-popp/miniforge3/lib/R/library/webutils/R/webutils.rdb
/home/bernt-popp/miniforge3/lib/R/library/webutils/help/webutils.rdx
/home/bernt-popp/miniforge3/lib/R/library/webutils/help/webutils.rdb
/home/bernt-popp/miniforge3/lib/R/library/R.utils/R/R.utils.rdb
/home/bernt-popp/miniforge3/lib/R/library/R.utils/R/R.utils.rdx
/home/bernt-popp/miniforge3/lib/R/library/R.utils/R/R.utils
/home/bernt-popp/miniforge3/lib/R/library/R.utils/help/R.utils.rdb
/home/bernt-popp/miniforge3/lib/R/library/R.utils/help/R.utils.rdx

web search:
web search: site:developers.zenodo.org deposition API files bucket PUT publish action
exec
/bin/bash -lc "rg -n \"analysis_release_zenodo_(validate|extract_and_verify|package|upload|record_doi)|\\.write_package_analysis|run_.*zenodo_cli\" api/tests/testthat/test-unit-analysis-release-zenodo-*.R | wc -l; rg -n \"\\.ENV|\\.GIT|\\.csv|\\.pem|checksums.*empty|checksums.*missing.*entry|\\.\\./|release_id.*invalid|staging.*existing|latest\\.env|record.*draft|--token\" api/tests/testthat/test-unit-analysis-release-zenodo-*.R || true" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
22
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:8:# `../nddscore/tests/test_sysndd_zenodo_upload.py`'s
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:84:test_that("get_or_create_deposition: NULL deposition_id -> POST .../deposit/depositions", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:105:test_that("get_or_create_deposition: explicit deposition_id -> GET .../deposit/depositions/{id}", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:128:test_that("set_metadata: PUTs to .../deposit/depositions/{id} with body {\"metadata\": ...}", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:151:test_that("publish_deposition: POSTs to .../deposit/depositions/{id}/actions/publish", {
api/tests/testthat/test-unit-analysis-release-zenodo-upload.R:174:test_that("record_doi: PATCH .../releases/<id>/doi, admin Bearer token, body has ONLY supplied non-empty fields", {

exec
/bin/bash -lc "git diff --check origin/master...HEAD -- ':(exclude).planning/**'; git diff --numstat origin/master...HEAD -- ':(exclude).planning/**'; git status --short" in /home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573
 succeeded in 0ms:
4	0	.gitignore
1	0	AGENTS.md
11	0	CHANGELOG.md
29	1	Makefile
163	0	api/functions/analysis-snapshot-release-zenodo-docs.R
597	0	api/functions/analysis-snapshot-release-zenodo-package.R
312	0	api/functions/analysis-snapshot-release-zenodo-upload.R
157	0	api/scripts/package-analysis-release-zenodo.R
212	0	api/scripts/upload-analysis-release-zenodo.R
450	0	api/tests/testthat/test-unit-analysis-release-zenodo-package.R
444	0	api/tests/testthat/test-unit-analysis-release-zenodo-upload.R
1	1	api/version_spec.json
2	2	app/package-lock.json
1	1	app/package.json
39	1	documentation/09-deployment.qmd
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-prompt.md
?? .planning/reviews/2026-07-19-573-slice-c-diff-codex-review.md

web search:
web search: site:stat.ethz.ch R utils tar internal modification times tarfile documentation
codex
## BLOCKER

- [analysis-snapshot-release-zenodo-package.R:535](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:535) recursively deletes any existing `--staging-dir` with no containment or ownership guard. An operator typo such as an important existing directory causes irreversible deletion before packaging starts. Refuse existing non-empty paths, or require a narrowly validated owned output directory/sentinel before cleanup. Add a regression test for a non-owned pre-existing directory.

## HIGH

- [analysis-snapshot-release-zenodo-package.R:525](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:525), [package-analysis-release-zenodo.R:88](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/scripts/package-analysis-release-zenodo.R:88), [Makefile:400](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/Makefile:400) trust an API-returned release ID as both a filename/path component and shell-sourced `.env` content. A malformed head ID containing `../` escapes `archive_dir`; one containing a newline/shell syntax becomes executable when the Make target sources `latest.env`. Enforce `^asr_[0-9a-f]{16}$` on the resolved head ID (and allow only `latest` or that pattern for requests), compare explicit requested/resolved IDs, and avoid `source` or shell-quote every marker value. Test traversal and newline payloads.

- [analysis-snapshot-release-zenodo-package.R:406](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:406) and [analysis-snapshot-release-zenodo-package.R:430](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:430) do not meet the locked safety-validator promise. Forbidden names are case-sensitive, so `analysis_snapshot_release/.ENV` or `.GIT/config` passes; sensitive scanning skips non-whitelisted suffixes and binary files, so `secret.csv`, `key.pem`, or an extensionless token file is uploaded untouched. Normalize path components before comparison, reject symlinks/unexpected file types, and scan all regular files as bounded raw bytes with token-pattern matching. Tests cover only lowercase `.env` and selected text suffixes.

## MEDIUM

- [analysis-snapshot-release-zenodo-package.R:192](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:192) extracts before validating archive member paths, and [line 198](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:198) accepts an empty or incomplete inner `checksums.sha256`. Removing a checksum line leaves the corresponding extracted file unstamped yet passes verification; `../` checksum paths are not rejected either. List and validate every tar member before extraction, require exactly one valid SHA-256 entry for every regular non-checksum member, and reject duplicates/traversal/symlinks. Add tests for omitted checksum lines and malicious archive paths.

- [analysis-snapshot-release-zenodo-package.R:385](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:385) claims a deterministic tarball but does not normalize generated files’ mtimes. R’s internal tar records file modification times, so two otherwise-identical package runs can produce different `<release_id>.tar.gz` hashes. Normalize all staged mtimes and gzip metadata to a fixed release-derived epoch, then test two delayed package runs for byte equality. [R’s `tar` documentation](https://stat.ethz.ch/R-manual/R-devel/library/utils/html/tar.html) confirms the archive records modification times.

- [upload-analysis-release-zenodo.R:102](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/scripts/upload-analysis-release-zenodo.R:102) accepts `--token <ZENODO_TOKEN>`. It is not printed by the script, but it leaks through shell history and process arguments. Remove the flag in favor of `ZENODO_TOKEN` or a permission-checked token file.

The normal Zenodo request shapes are otherwise aligned with the official bucket-upload and publish API flow, and the double publish gate is correctly checked before HTTP work. The manual DOI command uses `<SYSNDD_ADMIN_TOKEN>`, not the real token; DOI field filtering correctly drops `NULL`, `NA`, and empty values. [Zenodo API documentation](https://developers.zenodo.org/)

`git diff --check` was clean. The new package helper is 597 lines, under the 600-line ceiling. Targeted R tests and `make code-quality-audit` could not run because this review environment prohibits temporary-file creation.

VERDICT: NO-SHIP
tokens used
153,233
## BLOCKER

- [analysis-snapshot-release-zenodo-package.R:535](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:535) recursively deletes any existing `--staging-dir` with no containment or ownership guard. An operator typo such as an important existing directory causes irreversible deletion before packaging starts. Refuse existing non-empty paths, or require a narrowly validated owned output directory/sentinel before cleanup. Add a regression test for a non-owned pre-existing directory.

## HIGH

- [analysis-snapshot-release-zenodo-package.R:525](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:525), [package-analysis-release-zenodo.R:88](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/scripts/package-analysis-release-zenodo.R:88), [Makefile:400](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/Makefile:400) trust an API-returned release ID as both a filename/path component and shell-sourced `.env` content. A malformed head ID containing `../` escapes `archive_dir`; one containing a newline/shell syntax becomes executable when the Make target sources `latest.env`. Enforce `^asr_[0-9a-f]{16}$` on the resolved head ID (and allow only `latest` or that pattern for requests), compare explicit requested/resolved IDs, and avoid `source` or shell-quote every marker value. Test traversal and newline payloads.

- [analysis-snapshot-release-zenodo-package.R:406](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:406) and [analysis-snapshot-release-zenodo-package.R:430](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:430) do not meet the locked safety-validator promise. Forbidden names are case-sensitive, so `analysis_snapshot_release/.ENV` or `.GIT/config` passes; sensitive scanning skips non-whitelisted suffixes and binary files, so `secret.csv`, `key.pem`, or an extensionless token file is uploaded untouched. Normalize path components before comparison, reject symlinks/unexpected file types, and scan all regular files as bounded raw bytes with token-pattern matching. Tests cover only lowercase `.env` and selected text suffixes.

## MEDIUM

- [analysis-snapshot-release-zenodo-package.R:192](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:192) extracts before validating archive member paths, and [line 198](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:198) accepts an empty or incomplete inner `checksums.sha256`. Removing a checksum line leaves the corresponding extracted file unstamped yet passes verification; `../` checksum paths are not rejected either. List and validate every tar member before extraction, require exactly one valid SHA-256 entry for every regular non-checksum member, and reject duplicates/traversal/symlinks. Add tests for omitted checksum lines and malicious archive paths.

- [analysis-snapshot-release-zenodo-package.R:385](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/functions/analysis-snapshot-release-zenodo-package.R:385) claims a deterministic tarball but does not normalize generated files’ mtimes. R’s internal tar records file modification times, so two otherwise-identical package runs can produce different `<release_id>.tar.gz` hashes. Normalize all staged mtimes and gzip metadata to a fixed release-derived epoch, then test two delayed package runs for byte equality. [R’s `tar` documentation](https://stat.ethz.ch/R-manual/R-devel/library/utils/html/tar.html) confirms the archive records modification times.

- [upload-analysis-release-zenodo.R:102](/home/bernt-popp/development/sysndd/.claude/worktrees/slice-c-573/api/scripts/upload-analysis-release-zenodo.R:102) accepts `--token <ZENODO_TOKEN>`. It is not printed by the script, but it leaks through shell history and process arguments. Remove the flag in favor of `ZENODO_TOKEN` or a permission-checked token file.

The normal Zenodo request shapes are otherwise aligned with the official bucket-upload and publish API flow, and the double publish gate is correctly checked before HTTP work. The manual DOI command uses `<SYSNDD_ADMIN_TOKEN>`, not the real token; DOI field filtering correctly drops `NULL`, `NA`, and empty values. [Zenodo API documentation](https://developers.zenodo.org/)

`git diff --check` was clean. The new package helper is 597 lines, under the 600-line ceiling. Targeted R tests and `make code-quality-audit` could not run because this review environment prohibits temporary-file creation.

VERDICT: NO-SHIP
