# Phase 14: TypeScript Introduction - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable TypeScript across the codebase with type safety for API responses, props, and stores. This phase covers infrastructure conversion (main, router, stores, services, composables) — component conversion happens in a later phase.

</domain>

<decisions>
## Implementation Decisions

### Strictness strategy
- Start with `strict: false` in tsconfig — relaxed mode
- Enable individual strict checks incrementally as codebase matures
- Tighten to full strict mode after all files converted
- Single tsconfig (no project references) — simpler setup for this project size

### 'any' handling
- Claude to research best practices for Vue/TypeScript migrations
- Document approach based on research findings

### Migration approach
- Rename `.js` → `.ts` files in place (git tracks history)
- Core infrastructure first: main.ts → router → stores → services → composables
- Components NOT converted in this phase — infrastructure only
- Vue SFCs use `<script setup lang="ts">` — modern Vue 3 style

### Type definitions
- Dedicated `src/types/` directory with organized files (models.ts, api.ts, components.ts)
- Use branded types for IDs: `type GeneId = string & { __brand: 'GeneId' }` — prevents mixing ID types
- Install @types/* packages from DefinitelyTyped for third-party libraries

### API type generation
- Claude to research best practices and analyze existing API to determine optimal approach (manual, OpenAPI generation, or runtime inference)

### Linting & formatting
- ESLint 9+ flat config (`eslint.config.js`) — modern format
- Rules as 'warn' initially — doesn't block builds during migration
- Pre-commit hooks with husky + lint-staged — auto-format on commit

### Prettier configuration
- Claude to research modern Vue/TypeScript best practices and configure accordingly

### Claude's Discretion
- Exact tsconfig compiler options beyond strict flag
- ESLint rule selection and severity levels
- API type generation method (after research)
- Prettier exact configuration (after research)
- 'any' handling strategy (after research)
- File conversion order within each category

</decisions>

<specifics>
## Specific Ideas

- Infrastructure-only scope keeps Phase 14 focused — components can stay JavaScript until a dedicated conversion phase
- Branded types for medical domain IDs (GeneId, EntityId, etc.) add meaningful type safety for a healthcare application

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 14-typescript-introduction*
*Context gathered: 2026-01-23*
