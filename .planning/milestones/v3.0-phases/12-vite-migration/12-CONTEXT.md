# Phase 12: Build Tool Migration (Vite) - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Migrate from Vue CLI/Webpack to Vite build tooling. This phase covers build configuration, dev server setup, environment variable migration, and Docker integration. Does not include TypeScript conversion (Phase 14) or testing infrastructure (Phase 15).

</domain>

<decisions>
## Implementation Decisions

### Environment Variables
- Migrate VUE_APP_* to VITE_* naming convention
- All values baked in at build time — no runtime config needed
- Use mode-based env files: .env.development, .env.production, .env.local
- Claude investigates: current env var inventory during research
- Claude investigates: security audit for any exposed secrets

### Dev Server Setup
- Use non-default port to avoid conflicts with other services (Claude picks appropriate port)
- HTTP only — no HTTPS for local development
- Proxy /api/* requests to backend service
- No auto-open browser on dev server start

### Docker Integration
- Hot reload (HMR) must work inside Docker containers — primary dev workflow
- Separate Dockerfiles: Dockerfile.dev for development, Dockerfile for production
- Use current LTS Node.js version for base image (Claude researches latest)
- Shared node_modules via volume mount for faster rebuilds

### Build Output
- Vendor chunk + route-based code splitting for optimal caching and lazy loading
- Use Vite's default asset naming strategy (content hash)
- Output directory: dist/
- Claude investigates: production source map best practices

### Claude's Discretion
- Exact port number selection (avoiding common defaults)
- Source map strategy for production (research-based decision)
- Current LTS Node.js version determination
- Specific proxy configuration details based on existing API patterns
- Vite plugin selection and configuration

</decisions>

<specifics>
## Specific Ideas

- Should work alongside existing Vue CLI setup initially for comparison testing
- HMR in Docker is critical — this is the primary development workflow
- Keep things simple — Vite defaults where reasonable

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-vite-migration*
*Context gathered: 2026-01-23*
