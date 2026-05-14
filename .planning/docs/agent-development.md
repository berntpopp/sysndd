# Agent and Planning Docs

This folder is for LLM-facing and planning-oriented documentation that should not live in the public human-facing documentation site.

## What lives where

- `AGENTS.md` — canonical shared repository instructions for coding agents
- `CLAUDE.md` — thin Claude compatibility importer for `AGENTS.md`
- `.planning/superpowers/specs/` — active design specs, when present
- `.planning/superpowers/plans/` — active implementation plans, when present
- `.planning/_archive/superpowers/` — completed historical Superpowers specs, plans, and handoffs
- `.planning/reviews/` — codebase and task reviews
- `.planning/docs/` — durable notes about LLM workflow, instruction-file structure, and development-with-LLMs conventions

## Rule of thumb

- Put concise human-facing developer or operator docs in `documentation/`.
- Put agent workflow, planning, and instruction-contract docs in `.planning/`.
- Keep `AGENTS.md` short and focused on durable repository guidance, not broad narrative documentation.
