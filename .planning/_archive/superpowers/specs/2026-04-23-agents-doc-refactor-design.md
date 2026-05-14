# Multi-Agent Instruction Docs Refactor

**Date:** 2026-04-23
**Design doc for:** refactoring SysNDD's agent-facing repository instructions from a Claude-first `CLAUDE.md` into a shared canonical `AGENTS.md` with a thin `CLAUDE.md` compatibility layer
**Execution tooling:** superpowers skills (brainstorming -> writing-plans -> executing-plans)
**Primary affected docs:** `AGENTS.md`, `CLAUDE.md`, `.gitignore`, `docs/DEVELOPMENT.md`, `docs/DEPLOYMENT.md`, `CONTRIBUTING.md`, `README.md`

---

## 1 — Summary

### 1.1 Problem statement

SysNDD currently has a single root `CLAUDE.md` that carries three different roles at once:

- shared agent context for repository structure, commands, architecture, and gotchas
- Claude-specific bootstrap instructions
- a semi-human architecture reference that other docs point to

That shape was acceptable when Claude Code was the primary target, but it is now the wrong abstraction for a multi-agent workflow using Codex and Claude together. The root `.gitignore` currently ignores `CLAUDE.md`, which also conflicts with the goal of making the shared instructions part of the versioned repository contract.

The repository already has human-facing docs for development and deployment:

- `docs/DEVELOPMENT.md` is the human "start here" guide and currently says `CLAUDE.md` is the agent-facing source of truth.
- `docs/DEPLOYMENT.md` points development readers at `CLAUDE.md`, which is the wrong destination for deployment consumers.
- `CONTRIBUTING.md` tells contributors to update `docs/DEVELOPMENT.md` and/or `CLAUDE.md` when behavior changes.

The refactor therefore is not a file rename. It is a documentation contract rewrite affecting the agent entrypoint, downstream references, and the project's versioned development guidance.

### 1.2 Goal

Adopt a vendor-neutral, versioned, root-level `AGENTS.md` as the canonical repository instruction file for coding agents, while preserving full Claude Code compatibility through a minimal root `CLAUDE.md` importer.

### 1.3 External guidance and constraints

The design is anchored in current official docs as of 2026-04-23:

- OpenAI Codex documents `AGENTS.md` as the project instruction mechanism. Codex reads it before work, supports repository-level plus nested overrides, and truncates combined instruction discovery at a configurable byte limit (default `32 KiB`). This strongly favors concise durable guidance over a giant handbook.
- Anthropic documents that Claude Code reads `CLAUDE.md`, not `AGENTS.md`, and explicitly recommends importing `AGENTS.md` from `CLAUDE.md` when a repository already uses `AGENTS.md` for other coding agents.
- Anthropic's `CLAUDE.md` guidance says always-loaded instruction files work best when they contain persistent repo knowledge that would otherwise be re-explained: workflow rules, commands, architecture decisions, and non-obvious gotchas. Large explanatory material should stay in normal docs.

These constraints imply the shared canonical file should be:

- short enough to stay within discovery limits with room for future nested overrides
- tool-neutral in wording
- limited to durable repository guidance, not session tactics or vendor-specific UI behavior
- explicit about where deeper human docs live

### 1.4 Recommended design

Use a structured split.

#### Root `AGENTS.md`

Create a new root `AGENTS.md` as the canonical shared instruction file. It should be rewritten from the current `CLAUDE.md`, not copied verbatim.

Its section model should be:

1. Repository purpose and top-level layout
2. Primary verification commands
3. Architecture invariants that agents must not violate
4. Stack-specific gotchas and environment quirks
5. Documentation update rules
6. Pointers to deeper docs

The tone should be vendor-neutral:

- say "agents" or "coding agents", not "Claude Code"
- avoid references to Claude-specific commands or UI concepts
- avoid tool-specific memory features

#### Root `CLAUDE.md`

Reduce root `CLAUDE.md` to a compatibility shim:

```md
@AGENTS.md

## Claude-specific notes

- Keep project-shared instructions in `AGENTS.md`.
- Put machine- or user-local overrides in `CLAUDE.local.md`, not here.
```

This matches Anthropic's documented mixed-agent pattern while preserving a single source of truth.

#### Human docs

Update human-facing docs so they no longer imply that `CLAUDE.md` is the primary shared source:

- `docs/DEVELOPMENT.md` should describe `AGENTS.md` as the agent-facing source of truth and note that `CLAUDE.md` exists only as a Claude compatibility importer.
- `docs/DEPLOYMENT.md` should point development/setup readers to `docs/DEVELOPMENT.md`, not the agent file.
- `CONTRIBUTING.md` should require updates to `AGENTS.md` when repo-level architecture, commands, or workflow expectations change.
- `README.md` should be checked for any root-level "where to start" language that now benefits from linking to `docs/DEVELOPMENT.md` and, where relevant, `AGENTS.md`.

#### Git tracking

Remove `CLAUDE.md` from the root `.gitignore`.

`AGENTS.md` must be committed. The root `CLAUDE.md` importer should also be committed. Local personal variations belong in non-versioned local files such as `CLAUDE.local.md`, not in the repository contract.

## 2 — Content decomposition strategy

The current root `CLAUDE.md` should be decomposed into three buckets.

### 2.1 Keep in `AGENTS.md`

This includes durable cross-agent repo context:

- repo layout: `api/`, `app/`, `db/`
- main commands such as `make ci-local`, `make pre-commit`, `make dev`, `make test-api`, `npm run type-check`
- architecture invariants such as:
  - API bootstrap source order matters
  - service functions must keep `svc_` / `service_` prefixes to avoid shadowing repositories
  - mirai daemon code changes require container restart
  - migrations are startup-gated and failures should crash the API
- frontend and backend gotchas that are easy for agents to miss
- host environment notes that materially affect verification

### 2.2 Keep only in `CLAUDE.md`

Only minimal compatibility notes:

- import `@AGENTS.md`
- tell Claude users to keep shared guidance in `AGENTS.md`
- tell users to use local non-versioned files for local overrides

Nothing else should remain here unless it is truly Claude-only and durable.

### 2.3 Move out of always-loaded agent files

Anything that is explanatory rather than directive should be trimmed or relocated to human docs where possible:

- long-form host-environment narrative
- deployment guidance better suited to `docs/DEPLOYMENT.md`
- onboarding wording for humans already covered in `docs/DEVELOPMENT.md`

The agent file can still point to those docs, but should not duplicate them unless the information is a critical execution gotcha.

## 3 — Section design for `AGENTS.md`

The new file should stay compact and scannable. A recommended outline:

### 3.1 Purpose

One short paragraph describing SysNDD and the repo structure.

### 3.2 Worktree map

A short bullet list for:

- `api/` — R/Plumber API
- `app/` — Vue 3 + TypeScript SPA
- `db/` — MySQL schema, prep scripts, migrations

### 3.3 Verify before handoff

Short command list grouped by common tasks:

- full-repo: `make ci-local`
- fast local check: `make pre-commit`
- frontend-only: `cd app && npm run lint && npm run type-check && npm run test:unit`
- API-only: `make lint-api && make test-api`

### 3.4 Non-obvious architecture rules

Only the highest-value rules:

- API source order and service/repository shadowing risk
- background worker restart rule
- migration startup behavior
- container mount limitations for tests

### 3.5 Stack gotchas

Keep the most operationally important ones:

- `dplyr::select` masking
- `inherits(x, "Date")` vs `is.Date`
- plumber scalar arrays / axios parameter gotcha
- `DBI::dbBind()` requiring `unname(params)`

### 3.6 Documentation contract

State that when architecture, commands, or runtime quirks change, agents should update:

- `AGENTS.md` for durable repo-level agent guidance
- `docs/DEVELOPMENT.md` for human dev onboarding and workflow
- `docs/DEPLOYMENT.md` for deployment/runtime operator docs

## 4 — Explicit non-goals

This refactor does not introduce:

- nested `AGENTS.md` files under `api/`, `app/`, or `db/`
- vendor-specific instruction duplication across multiple files
- a personal local memory scheme committed to git
- a large reorganization of human documentation beyond link and ownership corrections

Nested agent docs may be introduced later if path-specific instruction load becomes necessary, but the current repo does not justify that complexity.

## 5 — Acceptance criteria

The design is complete when all of the following are true:

1. Root `AGENTS.md` exists and contains the shared durable guidance previously housed in `CLAUDE.md`, rewritten in tool-neutral language.
2. Root `CLAUDE.md` is a minimal importer that references `AGENTS.md` and contains only a tiny Claude-specific appendix.
3. Root `.gitignore` no longer ignores `CLAUDE.md`.
4. `docs/DEVELOPMENT.md` identifies `AGENTS.md` as the canonical agent-facing repository doc.
5. `docs/DEPLOYMENT.md` no longer points development readers at `CLAUDE.md`.
6. `CONTRIBUTING.md` and any relevant root docs reference `AGENTS.md` where they previously assumed `CLAUDE.md` was canonical.
7. A grep for `CLAUDE.md` across tracked docs leaves only intentional compatibility references.
8. The new `AGENTS.md` is materially shorter and more neutral than the current `CLAUDE.md`, leaving room for future nested overrides under Codex's instruction-size limits.

## 6 — Risks and mitigations

### Risk 1: `AGENTS.md` becomes another oversized handbook

If the current `CLAUDE.md` is copied instead of rewritten, the repo ends up with the same problem under a different filename.

Mitigation:

- rewrite into a compact section model
- trim explanatory prose
- point to deeper docs instead of duplicating them

### Risk 2: human docs and agent docs drift

If `docs/DEVELOPMENT.md` and `AGENTS.md` disagree about commands or environment rules, both humans and agents will make incorrect assumptions.

Mitigation:

- define explicit documentation ownership in the refactor
- update all known references in the same change

### Risk 3: mixed-agent compatibility becomes ambiguous

If `CLAUDE.md` remains substantial, contributors will not know which file is authoritative.

Mitigation:

- keep `CLAUDE.md` minimal
- state directly inside it that `AGENTS.md` is the shared source of truth

## 7 — Sources

- OpenAI Codex, "Custom instructions with AGENTS.md": https://developers.openai.com/codex/guides/agents-md
- Anthropic Claude Code, "How Claude remembers your project": https://code.claude.com/docs/en/memory
- Anthropic Claude Code, "Best practices": https://code.claude.com/docs/en/best-practices
- OpenAI, "How OpenAI uses Codex": https://cdn.openai.com/pdf/6a2631dc-783e-479b-b1a4-af0cfbd38630/how-openai-uses-codex.pdf
