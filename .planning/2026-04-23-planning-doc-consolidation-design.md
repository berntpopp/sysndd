# Planning Doc Consolidation Design

**Date:** 2026-04-23
**Status:** Proposed
**Owner:** Codex

---

## 1. Goal

Consolidate the repository's three planning surfaces, `.planning/`, `.plans/`, and `.plan/`, into a single durable planning home at `.planning/`, while archiving all non-current material and preserving compatibility with the Superpowers workflow already used in this repo.

## 2. Problem

The current planning material is fragmented across three root directories:

- `.planning/` mixes live planning docs, historical milestone records, research notes, stale codebase snapshots, and ad hoc archived material.
- `.plans/` contains a historical v11.0 implementation-plan set that looks like an active planning surface even though it is no longer current.
- `.plan/` contains review artifacts, a legacy plan, and raw data payloads that do not belong in a live planning surface.

This creates three recurring failures:

1. There is no single place to look for current planning state.
2. Historical records remain mixed into the active surface, which makes drift and duplication hard to detect.
3. The repo's planning layout does not clearly distinguish between repo-level planning archives and active Superpowers execution artifacts.

## 3. External Guidance

The consolidation follows three external constraints:

1. Keep the live documentation surface small and current; dead or redundant docs should be removed or archived rather than left beside active docs.
2. Favor a README-led directory structure that tells contributors what belongs in a directory, what to read first, and where active workflows live.
3. Keep all planning artifacts, including Superpowers specs and plans, under `.planning/` so the repository has one planning home.

Sources used:

- Google Documentation Best Practices: https://google.github.io/styleguide/docguide/best_practices.html
- LF Energy Documentation Best Practices: https://tac.lfenergy.org/best_practices/documentation.html
- Superpowers plan convention discussion: https://github.com/obra/superpowers/issues/1192

## 4. Scope

In scope:

- Reorganize `.planning/`, `.plans/`, and `.plan/`
- Define one live planning surface
- Define one archive structure
- Add a `.planning/README.md` explaining structure and usage
- Preserve historical material by moving it into archive locations instead of deleting it

Out of scope:

- Rewriting historical content for accuracy
- Moving planning artifacts back under `docs/`
- Creating a new roadmap or milestone beyond the current repo state

## 5. Target Information Architecture

The root planning directory becomes:

```text
.planning/
  README.md
  PROJECT.md
  STATE.md
  ROADMAP.md
  MILESTONES.md
  config.json
  2026-04-23-planning-doc-consolidation-design.md
  2026-04-23-planning-doc-consolidation-plan.md
  reviews/
  superpowers/
    specs/
    plans/
  todos/
    pending/
  _archive/
    milestones/
    legacy-plans/
    research/
    codebase/
    reviews/
    one-offs/
    data/
```

### 5.1 Live Surface

The live surface is intentionally small:

- `PROJECT.md`
- `STATE.md`
- `ROADMAP.md`
- `MILESTONES.md`
- `config.json`
- `2026-04-23-planning-doc-consolidation-design.md`
- `2026-04-23-planning-doc-consolidation-plan.md`
- `reviews/*`
- `superpowers/specs/*`
- `superpowers/plans/*`
- `todos/pending/*`
- `README.md`

These are the only files that should represent current planning state after the migration.

### 5.2 Archive Surface

Everything not needed for current planning moves under `.planning/_archive/`.

Archive buckets:

- `milestones/`: historical versioned milestone requirements, roadmaps, audits, and milestone subtrees
- `legacy-plans/`: implementation-plan clusters that used to live outside `.planning/`
- `research/`: historical research notes, synthesis docs, topic analyses
- `codebase/`: stale codebase snapshots and architecture/convention notes that no longer represent the current stack
- `reviews/`: review reports, triage reports, UI/UX review artifacts
- `one-offs/`: single historical planning docs that do not belong to a larger family
- `data/`: retained raw payloads that were previously stored under planning folders

## 6. Migration Rules

### 6.1 `.planning/`

Keep live:

- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/ROADMAP.md`
- `.planning/MILESTONES.md`
- `.planning/config.json`
- `.planning/2026-04-23-planning-doc-consolidation-design.md`
- `.planning/2026-04-23-planning-doc-consolidation-plan.md`
- `.planning/todos/pending/*`

Archive:

- `.planning/milestones/**` -> `.planning/_archive/milestones/`
- `.planning/research/**` -> `.planning/_archive/research/`
- `.planning/codebase/**` -> `.planning/_archive/codebase/`
- existing `.planning/_archive/**` -> normalize into the new archive buckets without dropping content

### 6.2 `.plans/`

Archive the historical v11.0 implementation-plan set:

- `.plans/v11.0/**` -> `.planning/_archive/legacy-plans/v11.0/`

After the move, `.plans/` should no longer exist.

### 6.3 `.plan/`

Archive review and plan artifacts:

- review and triage reports -> `.planning/_archive/reviews/`
- `gene-page-enhancement-plan.md` -> `.planning/_archive/one-offs/`
- `.plan/data/*` -> `.planning/_archive/data/`

After the move, `.plan/` should no longer exist.

## 7. Superpowers Compatibility

The consolidation must not compete with or override the active Superpowers workflow.

Rules:

1. Active design specs remain in `docs/superpowers/specs/`.
2. Active implementation plans remain in `docs/superpowers/plans/`.
3. Repo-owned planning artifacts for this repository live in `.planning/`.
4. Active Superpowers design specs live in `.planning/superpowers/specs/`.
5. Active Superpowers implementation plans live in `.planning/superpowers/plans/`.
6. `.planning/README.md` must explicitly describe this boundary so future sessions do not recreate `.plans/`, `.plan/`, or planning specs under `docs/`.

## 8. README Requirements

The new `.planning/README.md` must cover:

- what `.planning/` is for
- what counts as live vs archived material
- where active Superpowers specs and plans belong
- the meaning of each top-level file/folder
- the archive policy: old material gets moved, not left in the live surface

## 9. Success Criteria

The consolidation is complete when:

1. `.planning/` is the only planning directory at repo root.
2. `.plan/` and `.plans/` no longer exist.
3. The live planning surface contains only current planning docs plus the README.
4. Historical materials remain accessible under `.planning/_archive/`.
5. `.planning/README.md` clearly documents the structure and Superpowers location rules.

## 10. Risks and Mitigations

### Risk: accidental loss of historical context

Mitigation: move files instead of deleting them; normalize archive structure without dropping content.

### Risk: future sessions recreate duplicate planning directories

Mitigation: document the policy in `.planning/README.md` and explicitly point active Superpowers work to `.planning/superpowers/`.

### Risk: active docs are archived by mistake

Mitigation: keep the live set intentionally small and explicit; anything ambiguous stays visible only if it represents current state.

## 11. Implementation Notes

This migration is structural, not editorial. Historical documents are preserved as historical records even when they are stale. The cleanup objective is discoverability and a stable contract about where planning artifacts belong.
