# Agent local files ignore policy

## Goal

Keep shared repository instructions tracked while preventing per-developer Claude
Code and Codex runtime state, hooks, settings, and installed local skills from
appearing as repository changes.

## Scope

- Keep `CLAUDE.md` tracked as shared project documentation.
- Ignore `.claude/` and `.codex/` as local tool state.
- Remove `.claude/settings.local.json` from the Git index without deleting its
  working-tree copy.
- Retain the existing `.git/info/exclude` rules; they remain optional local
  ignores and do not define the shared project policy.

## Implementation

Add scoped root `.gitignore` entries for the two local-tool directories and use
`git rm --cached` for the already tracked local Claude settings file. No
application code, runtime behavior, or secret files are changed.

## Verification

Confirm that the local Claude and Codex paths match `.gitignore`, that
`CLAUDE.md` remains tracked, and that `.claude/settings.local.json` remains on
disk but is no longer in the index.
