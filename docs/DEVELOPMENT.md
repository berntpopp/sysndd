# Development Guide

This is the human-facing "start here" doc for SysNDD developers. For the agent-facing companion (used by Claude Code and other coding agents), see `CLAUDE.md` at the repository root.

## 1. Requirements

You need the following on your host machine:

| Tool | Minimum version | Notes |
|---|---|---|
| **Docker** | Docker Desktop / Engine with `compose` v2 | Used for the dev stack and the test MySQL instances. `docker info` must succeed. |
| **git** | >= 2.5 | Needed for `git worktree` support used by the parallel phase workflow. |
| **GNU Make** | 4.x | Drives every developer command. |
| **Node.js** | Major pinned in `app/.nvmrc` (currently `24`) | Use `nvm`, `fnm`, `asdf`, or `mise` to match the `.nvmrc`. CI uses `actions/setup-node` with the same major. |
| **R** | 4.5.x | Needed only for host-side API work (lint, tests, starting the API outside Docker). If you only touch the frontend, Docker is enough. |

Optional but recommended:

- `jq` — handy for poking at API responses.
- `gh` — the GitHub CLI, required if you want to open PRs from the command line or poll CI with `gh pr checks`.
- A MySQL client (`mysql` or `mycli`) — useful for inspecting the dev/test databases on ports 7654/7655.

If you are on Ubuntu 25.10 "questing" with a Conda/miniforge R, read the **"Host-Env Workaround"** section at the bottom of `CLAUDE.md` before trying to run R tests on the host. The gating CI job for dev-env health is `make doctor` on `ubuntu-latest`. macOS is supported for development but is currently **not** gated in CI — see the comment header on the `make-doctor` job in `.github/workflows/ci.yml` for the reasoning and the linked lockfile-refresh follow-up.

## 2. Quickstart

From a fresh clone:

```bash
git clone https://github.com/<org>/sysndd.git
cd sysndd
make install-dev      # Installs R + frontend dependencies (idempotent, safe to re-run)
make doctor           # Verifies the host is healthy
make dev              # Starts the full Docker dev stack
```

After `make dev` the stack is available at:

| Service | URL |
|---|---|
| App (via Traefik) | `http://localhost` |
| App (direct Vite) | `http://localhost:5173` |
| API (via Traefik) | `http://localhost/api` |
| API (direct Plumber) | `http://localhost:7778` |
| Traefik dashboard | `http://localhost:8090` |
| MySQL dev | `localhost:7654` |
| MySQL test | `localhost:7655` |

Tear it all down with `make docker-down`.

## 3. Daily Workflow

The commands you will reach for every day:

```bash
make dev              # Start everything in Docker
make docker-dev-db    # Only the databases, if you run the API/frontend on the host
make serve-app        # Host-side Vue dev server with hot reload
make pre-commit       # Fast pre-push check: R lint + frontend lint + R tests
make ci-local         # Full CI parity run (lint + type-check + tests + DB) — run before pushing
```

Single-test shortcuts:

```bash
# R — single file (host)
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-entity-creation.R')"

# R — single file (inside the running container; tests/ is NOT bind-mounted, docker cp if needed)
docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-xyz.R')"

# Frontend — single spec or test name
cd app && npx vitest run src/components/AppFooter.spec.ts
cd app && npx vitest run -t "match name pattern"
```

Formatting helpers:

```bash
make format-api       # styler on api/
make format-app       # eslint --fix on app/
```

## 4. Parallel Worktree Workflow

v11.0 and newer milestones use `git worktree` so multiple agents (or humans) can work on disjoint chunks of the codebase in parallel without stepping on each other.

Create a new worktree:

```bash
make worktree-setup NAME=phase-a/my-unit
# Creates worktrees/phase-a/my-unit on branch v11.0/phase-a/my-unit (branched off master)
cd worktrees/phase-a/my-unit
make install-dev      # Idempotent — each worktree has its own node_modules and renv library
make doctor           # Verify this worktree's env
```

Rules of the road:

1. **Pick a unique ownership set.** Each worktree in a phase owns an explicit, disjoint list of files. See the phase plans under `.plans/v11.0/` for the table. Two worktrees never write the same file in the same phase.
2. **Branch off `master`, not each other.** `make worktree-setup` branches from `master` for this reason.
3. **Prune as you go.** After a branch merges, use `git worktree remove`. Once Phase A6 lands in your branch, the `make worktree-prune` convenience target is available as well. The `/worktrees/` directory is gitignored at repo root.
4. **Sticky Makefile.** When three sibling worktrees all touch `Makefile`, each owner adds a new, non-overlapping section — never edits another unit's block.

See `.plans/v11.0/phase-a.md` for a concrete example of the parallel dispatch and ownership table.

## 5. Common Gotchas

This is the short list that bites humans. The full, continuously-updated list (including masking pitfalls inside R workers, Plumber JSON scalar quirks, and `DBI::dbBind` placeholder footguns) lives in `CLAUDE.md` — agents read it automatically, humans should skim it once.

- **`config.yml not found`** — you forgot to start the DBs. Run `make docker-dev-db`, or export `MYSQL_HOST` / `MYSQL_PORT` / `MYSQL_DATABASE` / `MYSQL_USER` / `MYSQL_PASSWORD`.
- **Tests pass locally but fail in CI** — CI uses MySQL on `:3306`, `make ci-local` uses `:7655`. Always run `make ci-local` before pushing.
- **Changes in `api/functions/*` don't take effect in background jobs** — the `mirai` workers source files once via `everywhere()` at startup. Restart the API container after editing code that runs inside a worker.
- **`dplyr::select()` masking** — `biomaRt`, `AnnotationDbi`, and `MASS` all mask `select`. Always namespace it (`dplyr::select(...)`) in API code.
- **`lintr` not in the production container** — lint from the host with `make lint-api`. The production Dockerfile intentionally skips dev tooling.
- **Node version drift** — match `app/.nvmrc`. `make doctor` will tell you when the running Node major differs.
- **Conda R on Ubuntu 25.10** — known-broken combination for source-building R packages. See `CLAUDE.md` §"Host-Env Workaround" for the bypass. Short answer: use `Rscript --no-init-file api/scripts/lint-check.R` for lint, and rely on CI for the full test matrix.

For anything more exotic (async job shadows, Plumber array-wrapping, `DBI::dbBind` name-binding), read the full "Common Issues & Gotchas" block in `CLAUDE.md`.

## 6. Getting Help

- **Project docs.** `docs/DEPLOYMENT.md` for production deploys, `db/migrations/README.md` for the schema runner, `.plans/v11.0/` for the active roadmap.
- **Agent context.** `CLAUDE.md` at the root is the single source of truth for architecture, source-order invariants, and runtime quirks. Read it once even if you never use an agent.
- **Reviews and specs.** `docs/reviews/` and `docs/superpowers/specs/` hold the most recent full-codebase reviews and the locked design decisions behind each milestone.
- **CI is the tiebreaker.** When a behavior differs between your laptop and a PR run, the CI job is the source of truth. Post the failing run URL rather than a local log when you ask for help.
- **Before opening an issue** — run `make doctor`. If it prints `Environment healthy` the problem is likely code-level; if it prints a red line, fix that first.
