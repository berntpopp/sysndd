# Phase 3: Package Management + Docker Modernization - Context

**Gathered:** 2026-01-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Reproducible R environment with modern hybrid development workflow. This phase delivers:
- renv for R package management with lockfile
- Docker Compose dev setup (DB + test DB in containers, API local)
- Docker Compose Watch for file syncing
- External API mocking for PubMed and PubTator
- Dockerfile optimization to reduce build time from ~45min to ~5min

**Out of scope for this phase:**
- Traefik migration (production load balancer) — future phase
- Production hardening (health checks, non-root users, resource limits) — future phase
- WSL2 documentation — dropped

</domain>

<decisions>
## Implementation Decisions

### renv workflow
- PR author updates lockfile: Developer adding a package is responsible for `renv::snapshot()` in their PR
- Track direct dependencies only: Smaller lockfile, packages you explicitly install
- Global cache location: `~/.local/share/renv` — shared across projects, saves disk space
- Merge conflicts: Research best practices during implementation (Claude's discretion)

### Docker dev setup
- Services in docker-compose.dev.yml: Database (dev) + Test Database (separate container)
- Port mapping: Keep port 7654 to match existing config.yml — no config changes needed
- Data persistence: Named Docker volumes (persistent across container restarts)
- Docker Compose Watch: Yes, configure for API code (`api/endpoints/`, `api/functions/`)

### Docker quick wins (from Docker Review Report)
- Add `.dockerignore` files for both `api/` and `app/`
- Remove obsolete `version:` field from docker-compose files
- Use named volumes instead of `../data/` external paths

### Dockerfile optimization (API)
- Use `pak` package manager instead of `devtools::install_version()`
- Use Posit Package Manager (P3M) for pre-compiled Linux binaries
- Consolidate 34 RUN commands into grouped layers
- Use HTTPS for all CRAN repositories
- Target: Reduce build time from ~45min to ~5min

### External API mocking
- Mock PubMed API (via easyPubMed package calls)
- Mock PubTator3 API (NCBI gene/disease annotations)
- Do NOT mock Internet Archive API (low priority)
- Storage: httptest2 fixtures in `tests/testthat/fixtures/`

### Claude's Discretion
- Exact renv lockfile merge conflict resolution strategy
- Specific Docker volume naming conventions
- httptest2 fixture organization structure
- Watch configuration details (rebuild vs sync triggers)

</decisions>

<specifics>
## Specific Ideas

- Build time reduction is a high priority — 45 minute builds are blocking development velocity
- Keep port 7654 for database to avoid config.yml changes
- Follow patterns from `.plan/DOCKER-REVIEW-REPORT.md` for Dockerfile optimization
- renv should integrate with existing R package ecosystem without breaking workflow

</specifics>

<deferred>
## Deferred Ideas

- **Traefik migration**: Replace abandoned dockercloud/haproxy with Traefik v3 — future "Docker Production" phase
- **Non-root users in containers**: Security hardening — future phase
- **Health checks**: Container health monitoring — future phase
- **Node.js 24 upgrade**: Update from EOL Node 16 — future phase
- **Resource limits**: Memory/CPU limits for containers — future phase
- **WSL2 documentation**: Dropped from scope (performance optimization not possible)
- **Internet Archive API mocking**: Low priority, defer

</deferred>

---

*Phase: 03-package-management-docker-modernization*
*Context gathered: 2026-01-21*
