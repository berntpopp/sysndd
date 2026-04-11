# Contributing to SysNDD

Thanks for your interest in contributing. The full developer guide lives in **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)** — start there for requirements, quickstart, daily workflow, parallel-worktree conventions, and common gotchas.

## TL;DR

1. Clone the repo and run `make install-dev` followed by `make doctor`.
2. Create a branch off `master` (or a new worktree via `make worktree-setup NAME=<scope>/<unit>`).
3. Make your change, keeping commits atomic and using conventional-commit style (`feat(...)`, `fix(...)`, `chore(...)`, `docs(...)`).
4. Run `make ci-local` before pushing. CI path filters may skip jobs locally that are triggered in GitHub Actions, so `make ci-local` is the authoritative pre-push check.
5. Open a pull request. Describe the **why**, not just the **what**. Reference the relevant issue, plan file, or review when applicable.

## Ground rules

- **Do not commit secrets.** The repo gitignores `.env`, `config.yml`, and friends — keep it that way.
- **Do not bypass git hooks.** No `--no-verify` / `--no-gpg-sign`. If a hook fails, fix the underlying issue.
- **Prefer new commits over `git commit --amend`.** Keeps review history legible and avoids surprise rewrites.
- **Respect file ownership during parallel work.** The v11.0 phase plans under `.plans/v11.0/` define exclusive write ownership per worktree. If your change needs to cross ownership lines, split it into two PRs or coordinate with the other owner.
- **Docs are a deliverable.** When you change architecture, runtime behavior, or a developer command, update `docs/DEVELOPMENT.md` and/or `CLAUDE.md` in the same PR.

## Reporting bugs

Open a GitHub issue with:

- The command you ran and the output you saw.
- The output of `make doctor` (paste it verbatim).
- Your OS and Docker version if it looks environmental.

## Questions

See `docs/DEVELOPMENT.md` §6 "Getting Help". CI runs are the tiebreaker when behavior differs between your laptop and a PR — link the failing run when you ask.
