# Agent Docs Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current Claude-first agent doc setup with a canonical root `AGENTS.md`, a minimal `CLAUDE.md` importer, and aligned human-facing documentation.

**Architecture:** Shared cross-agent repository guidance moves into a concise, vendor-neutral root `AGENTS.md`. Root `CLAUDE.md` becomes a thin compatibility layer that imports `AGENTS.md`. Human docs are updated so `docs/DEVELOPMENT.md` owns developer onboarding while `AGENTS.md` owns durable agent-facing repo guidance.

**Tech Stack:** Markdown docs, gitignore, repo documentation conventions, Codex and Claude Code instruction discovery

---

### File map

**Create:**
- `AGENTS.md`
- `.planning/superpowers/specs/2026-04-23-agents-doc-refactor-design.md`
- `.planning/superpowers/plans/2026-04-23-agents-doc-refactor.md`

**Modify:**
- `CLAUDE.md`
- `.gitignore`
- `docs/DEVELOPMENT.md`
- `docs/DEPLOYMENT.md`
- `CONTRIBUTING.md`
- `README.md` if its top-level onboarding text benefits from the new contract

**Verify:**
- repo-wide grep for `CLAUDE.md` and `AGENTS.md`
- simple line review of all changed docs

### Task 1: Audit and content decomposition

**Files:**
- Read: `CLAUDE.md`
- Read: `docs/DEVELOPMENT.md`
- Read: `docs/DEPLOYMENT.md`
- Read: `CONTRIBUTING.md`
- Read: `README.md`

- [ ] **Step 1: Extract shared durable guidance from `CLAUDE.md`**

Review the current file and classify each section into:

- shared repo guidance for `AGENTS.md`
- Claude-only compatibility material for `CLAUDE.md`
- explanatory material that belongs in human docs instead

Expected output:

- a working section list for `AGENTS.md`
- a list of `CLAUDE.md` references that need replacement across the repo

- [ ] **Step 2: Confirm downstream docs that depend on the old contract**

Run:

```bash
rg -n "CLAUDE\\.md|AGENTS\\.md" README.md CONTRIBUTING.md docs .gitignore
```

Expected:

- exact list of references to fix
- no hidden nested agent-doc files beyond the root

### Task 2: Write the new root `AGENTS.md`

**Files:**
- Create: `AGENTS.md`
- Source: `CLAUDE.md`

- [ ] **Step 1: Draft a concise, vendor-neutral structure**

Create `AGENTS.md` with sections for:

- repo purpose and layout
- verification commands
- architecture invariants
- stack gotchas
- documentation update rules
- deeper-doc pointers

The content should preserve critical execution knowledge from the current `CLAUDE.md` but remove Claude-specific framing and unnecessary narrative.

- [ ] **Step 2: Keep the file compact**

Apply these constraints during the rewrite:

- prefer short bullets over long paragraphs
- keep only durable repo-level rules
- replace long explanations with links to `docs/DEVELOPMENT.md` or `docs/DEPLOYMENT.md`
- avoid vendor-specific wording such as "Claude Code"

Expected outcome:

- `AGENTS.md` is clearly the canonical shared instruction file
- `AGENTS.md` is materially shorter than the current `CLAUDE.md`

### Task 3: Reduce `CLAUDE.md` to a compatibility shim

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Replace the body with an import-first shim**

Rewrite `CLAUDE.md` to:

- import `@AGENTS.md`
- state that shared repository guidance lives in `AGENTS.md`
- reserve local/personal customization for `CLAUDE.local.md`

Suggested target structure:

```md
# CLAUDE.md

@AGENTS.md

## Claude-specific notes

- `AGENTS.md` is the shared source of truth for repository instructions.
- Keep machine- or user-local overrides in `CLAUDE.local.md`, not here.
```

- [ ] **Step 2: Ensure no duplicate shared guidance remains**

Review the rewritten `CLAUDE.md` and remove any repo-level instructions that already exist in `AGENTS.md`.

Expected:

- `CLAUDE.md` is intentionally minimal
- future contributors cannot mistake it for the canonical shared file

### Task 4: Update version control and documentation references

**Files:**
- Modify: `.gitignore`
- Modify: `docs/DEVELOPMENT.md`
- Modify: `docs/DEPLOYMENT.md`
- Modify: `CONTRIBUTING.md`
- Modify: `README.md` if needed

- [ ] **Step 1: Stop ignoring the shared shim**

Edit `.gitignore` to remove the `CLAUDE.md` ignore rule while keeping genuinely local-only entries intact.

Expected:

- root `CLAUDE.md` becomes a tracked repository file

- [ ] **Step 2: Update development docs**

Edit `docs/DEVELOPMENT.md` so it:

- identifies `AGENTS.md` as the canonical agent-facing file
- explains `CLAUDE.md` is a Claude compatibility importer
- preserves the useful cross-references to runtime gotchas where appropriate

- [ ] **Step 3: Update deployment docs**

Edit `docs/DEPLOYMENT.md` so it points development readers to `docs/DEVELOPMENT.md` rather than to `CLAUDE.md`.

- [ ] **Step 4: Update contribution guidance**

Edit `CONTRIBUTING.md` so durable repo-level architecture or workflow changes require updating `AGENTS.md` and/or the relevant human docs.

- [ ] **Step 5: Adjust root README only if it improves onboarding clarity**

If `README.md` currently implies the wrong doc entrypoint, add or adjust a short pointer to `docs/DEVELOPMENT.md`. Do not expand scope beyond a minimal consistency fix.

### Task 5: Verification and closeout

**Files:**
- Verify: all changed files

- [ ] **Step 1: Verify references**

Run:

```bash
rg -n "CLAUDE\\.md|AGENTS\\.md" README.md CONTRIBUTING.md docs .gitignore AGENTS.md CLAUDE.md
```

Expected:

- only intentional `CLAUDE.md` references remain
- `AGENTS.md` appears wherever the canonical shared file should be named

- [ ] **Step 2: Review the new instruction contract**

Manually confirm:

- `AGENTS.md` is vendor-neutral
- `CLAUDE.md` is import-first and thin
- human docs point to the right owners
- `.gitignore` no longer blocks the committed shim

- [ ] **Step 3: Check git diff**

Run:

```bash
git diff -- AGENTS.md CLAUDE.md .gitignore docs/DEVELOPMENT.md docs/DEPLOYMENT.md CONTRIBUTING.md README.md .planning/superpowers/specs/2026-04-23-agents-doc-refactor-design.md .planning/superpowers/plans/2026-04-23-agents-doc-refactor.md
```

Expected:

- one coherent documentation-only refactor
- no accidental changes outside the planned files
