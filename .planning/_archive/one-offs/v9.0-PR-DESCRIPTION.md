# v9.0: Production-Ready SysNDD

## Summary

This PR completes the modernization of SysNDD from a legacy codebase to a production-ready, enterprise-grade application. It encompasses **9 milestones** delivered over 11 days, transforming the entire stack while maintaining backward compatibility.

**Key achievements:**
- Complete Vue 2 → Vue 3 migration with TypeScript
- 66 SQL injection vulnerabilities fixed
- Argon2id password hashing (OWASP 2025 recommended)
- Modern Docker infrastructure with security hardening
- Automated database migrations with health checks
- WCAG 2.2 AA accessibility compliance

## Stats

| Metric | Value |
|--------|-------|
| Commits | 1,227 |
| Files Changed | 1,177 |
| Lines Added | +311,772 |
| Lines Removed | -58,284 |
| Milestones | 9 (v1.0 - v9.0) |
| Phases | 54 |
| Plans | 220+ |

---

## Changelog

### Added

**Frontend**
- Vue 3.5.25 with Composition API (pure mode, no compat layer)
- TypeScript 5.9.3 with branded domain types (GeneId, EntityId)
- Bootstrap-Vue-Next 0.42.0 replacing Bootstrap-Vue
- Vite 7.3.1 build tooling (164ms dev startup vs ~30s webpack)
- 29 Vue 3 composables for reusable logic
- Vitest testing infrastructure with 144+ tests
- WCAG 2.2 AA compliance with vitest-axe accessibility tests
- Custom TreeMultiSelect component (replaced vue3-treeselect dependency)

**Gene Page & Genomic Data (v8)**
- Backend proxy layer for 6 external APIs (gnomAD, UniProt, Ensembl, AlphaFold, MGI, RGD)
- gnomAD constraint scores display (pLI, LOEUF, missense Z)
- ClinVar variant summary with ACMG 5-class colored badges
- D3.js protein domain lollipop plot with variant mapping
- Gene structure visualization with exon/intron display
- NGL Viewer for 3D AlphaFold structures with variant highlighting
- Model organism phenotype cards (MGI mouse, RGD rat)

**Analysis (v5)**
- Cytoscape.js network visualization with fcose layout
- /api/analysis/network_edges endpoint (66k+ PPI edges)
- Biologist-friendly wildcard search (PKD*, BRCA?)
- URL-synced filter state with bookmarkable views

**Admin Panel (v6)**
- Bulk user operations (approve, delete, role assignment)
- Statistics dashboard with Chart.js visualizations
- CMS-style About page editor with draft/publish workflow
- Advanced log filtering with detail drawer

**Curation Workflows (v7)**
- Complete re-review batch management system (6 API endpoints)
- GeneBadge, DiseaseBadge, EntityBadge preview components
- Form composables (useReviewForm, useStatusForm, useFormDraft)

**Backend (v4)**
- mirai-based async job manager with 8-worker daemon pool
- 8 domain repositories with 131 parameterized database calls
- 7 service layers with dependency injection
- require_auth middleware with AUTH_ALLOWLIST pattern
- RFC 9457 error format across all endpoints

**Production Readiness (v9)**
- Automated migration system with schema_version tracking
- Backup management API and ManageBackups admin UI
- Mailpit integration for development email capture
- /api/health/ready endpoint with DB and migration checks
- `make preflight` for production validation
- Batch assignment email notifications
- Self-service profile editing (email/ORCID)

**Infrastructure (v1, v2)**
- API modularization: 21 endpoint files, 94 endpoints
- testthat framework with 687+ tests (20.3% coverage)
- Traefik v3.6 reverse proxy with Docker auto-discovery
- Docker Compose Watch for hot-reload development
- Makefile with 13 automation targets

### Changed

- R upgraded from 4.1.2 to 4.4.3 with clean renv.lock (281 packages)
- Clustering algorithm: Walktrap → Leiden (2-3x faster)
- OMIM data source: genemap2 → mim2gene.txt + JAX API + MONDO
- API build time reduced from 45 min to ~10 min cold / ~2 min warm
- Bundle size optimized to ~600 KB gzipped
- All containers run as non-root users

### Fixed

- 66 SQL injection vulnerabilities (parameterized queries)
- 4 critical curation bugs (ApproveUser crash, dropdown issues, modal staleness)
- 1,240 → 0 lintr issues
- 29 → 0 TODO comments
- Memory leaks in Cytoscape.js (cy.destroy() on navigation)

### Security

- Argon2id password hashing with progressive migration (OWASP 2025)
- 66 SQL injection vulnerabilities eliminated
- Non-root container execution (API uid 1001, nginx user)
- Docker security hardening:
  - `security_opt: no-new-privileges:true` on all services
  - CPU resource limits on all services
  - Log rotation with max-size and max-file
  - Pinned base images (no `:latest` tags)
- Brotli compression with proper Cache-Control headers

### Removed

- Legacy `api/_old/` directory
- 1,226-line `database-functions.R` god file (decomposed into repositories)
- vue3-treeselect dependency (replaced with custom component)
- @vue/compat compatibility layer

---

## Breaking Changes

None. This PR maintains full backward compatibility with the existing API contract.

---

## Migration Notes

### Database
- Migrations auto-apply on API startup
- 4 migrations will be applied automatically:
  - 001_initial_schema.sql
  - 002_add_genomic_annotations.sql (idempotent)
  - 003_fix_hgnc_column_schema.sql
  - 004_add_schema_version.sql

### Environment
- New optional env var: `DB_POOL_SIZE` (default: 5)
- Mailpit available at localhost:8025 in development

### Docker
- Production uses `fholzer/nginx-brotli:v1.28.0` (supersedes nginx:1.27.4)
- All services have resource limits configured

---

## Test Plan

- [x] `make test-api` - 687+ R tests passing
- [x] `npm run test` - 144+ frontend tests passing
- [x] `make lint-api` - 0 lintr issues
- [x] `make lint-app` - 0 ESLint issues
- [x] `make preflight` - Production Docker validation
- [x] E2E user lifecycle tests with Mailpit
- [x] Accessibility tests with vitest-axe

---

## Milestones Included

| Version | Name | Shipped |
|---------|------|---------|
| v1.0 | Developer Experience | 2026-01-21 |
| v2.0 | Docker Infrastructure | 2026-01-22 |
| v3.0 | Frontend Modernization | 2026-01-23 |
| v4.0 | Backend Overhaul | 2026-01-24 |
| v5.0 | Analysis Modernization | 2026-01-25 |
| v6.0 | Admin Panel Modernization | 2026-01-26 |
| v7.0 | Curation Workflow Modernization | 2026-01-27 |
| v8.0 | Gene Page & Genomic Data | 2026-01-29 |
| v9.0 | Production Readiness | 2026-01-31 |

---

Closes #109
