# Contributing to SysNDD

Thanks for your interest in contributing. The concise developer guide lives in **[documentation/08-development.qmd](documentation/08-development.qmd)** — start there for requirements, quickstart, daily workflow, and common gotchas.

## TL;DR

1. Clone the repo and run `make install-dev` followed by `make doctor`.
2. Create a branch off `master` (or a new worktree via `make worktree-setup NAME=<scope>/<unit>`).
3. Make your change, keeping commits atomic and using conventional-commit style (`feat(...)`, `fix(...)`, `chore(...)`, `docs(...)`).
4. Run `make code-quality-audit` for the fast source-size ratchet, then `make ci-local` before pushing. GitHub Actions CI may skip some jobs based on path filters, so `make ci-local` is the authoritative pre-push check.
5. Open a pull request. Describe the **why**, not just the **what**. Reference the relevant issue, plan file, or review when applicable.

## Ground rules

- **Do not commit secrets.** The repo gitignores `.env`, `config.yml`, and friends — keep it that way.
- **Do not bypass git hooks.** No `--no-verify` / `--no-gpg-sign`. If a hook fails, fix the underlying issue.
- **Prefer new commits over `git commit --amend`.** Keeps review history legible and avoids surprise rewrites.
- **Respect file ownership during parallel work.** The v11.0 phase plans under `.planning/_archive/legacy-plans/v11.0/` define exclusive write ownership per worktree. If your change needs to cross ownership lines, split it into two PRs or coordinate with the other owner.
- **Keep large files from growing.** The 600-line source-size rule is a soft ceiling with a committed legacy baseline. Extract cohesive code from touched oversized files instead of increasing the baseline by default.
- **Docs are a deliverable.** When you change architecture, runtime behavior, or a developer command, update `AGENTS.md` and/or the relevant human docs in the same PR (`documentation/08-development.qmd`, `documentation/09-deployment.qmd`, `README.md`).

## Reporting bugs

Open a GitHub issue with:

- The command you ran and the output you saw.
- The output of `make doctor` (paste it verbatim).
- Your OS and Docker version if it looks environmental.

## Questions

See [documentation/08-development.qmd](documentation/08-development.qmd) for the developer workflow baseline. CI runs are the tiebreaker when behavior differs between your laptop and a PR — link the failing run when you ask.
