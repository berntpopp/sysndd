---
phase: 75
plan: 01
subsystem: frontend-ui
tags: [vue, typescript, constants, ux, documentation]
completed: 2026-02-05
duration: 3m 8s

# Dependency graph
requires:
  - phase: 73
    context: "Database schema version 13 with widened comparison columns"
  - phase: 74
    context: "API bug fixes for entity creation, panels, clustering"
provides:
  - centralized-doc-urls
  - improved-gene-page-hierarchy
affects:
  - future-documentation-updates

# Tech tracking
tech-stack:
  added: []
  patterns:
    - pattern: "constants-centralization"
      location: "app/src/constants/docs.ts"
      description: "Single source of truth for documentation URLs"

# File tracking
key-files:
  created:
    - path: "app/src/constants/docs.ts"
      purpose: "Centralized documentation URL constants"
  modified:
    - path: "app/src/views/HomeView.vue"
      purpose: "Import and use DOCS_URLS for curation criteria link"
    - path: "app/src/views/review/ReviewInstructions.vue"
      purpose: "Import and use DOCS_URLS for all instruction links"
    - path: "app/src/views/help/DocumentationView.vue"
      purpose: "Import and use DOCS_URLS for home and GitHub links"
    - path: "app/src/components/HelperBadge.vue"
      purpose: "Import and use DOCS_URLS for docs and discussions links"
    - path: "app/src/views/pages/GeneView.vue"
      purpose: "Reorder template to show Associated Entities first"

# Decisions
decisions:
  - id: constants-file-location
    question: "Where to place documentation URL constants?"
    chosen: "app/src/constants/docs.ts"
    alternatives:
      - "app/src/config/urls.ts"
      - "app/src/assets/js/constants/"
    rationale: "Consistent with TypeScript patterns, separate from legacy JS constants"

  - id: url-structure
    question: "How to structure the URL constants?"
    chosen: "DOCS_BASE_URL + DOCS_URLS object with named keys"
    alternatives:
      - "Flat list of full URLs"
      - "Function-based URL builders"
    rationale: "DRY principle, easy to update base URL, autocomplete-friendly"

  - id: component-integration
    question: "How to expose constants in Options API components?"
    chosen: "Import and return from setup() function"
    alternatives:
      - "Add to data() return"
      - "Use global properties"
    rationale: "Follows Vue 3 composition API pattern, cleaner separation"

  - id: gene-page-order
    question: "What order should Gene detail page sections appear?"
    chosen: "Gene info → Associated Entities → Constraint/ClinVar → Visualizations"
    alternatives:
      - "Current order (entities last)"
      - "Entities after visualizations"
    rationale: "Associated entities are most relevant for understanding gene-disease relationships, should appear prominently"
---

# Phase 75 Plan 01: Frontend URL Centralization & Gene Page UX Summary

**One-liner:** Centralized GitHub Pages doc URLs into constants file and reordered Gene detail page to show Associated Entities before external data cards.

## Overview

This plan addresses two frontend improvements from the v10.3 milestone:
- **FE-01**: Extract hardcoded documentation URLs into a centralized constants file (builds on the URL fix from commit 03b2c7ea)
- **UX-02**: Improve Gene detail page information hierarchy by showing Associated Entities prominently

The work eliminates maintenance burden of scattered URLs across 4 components and improves user flow on the gene detail page.

## What Was Built

### 1. Documentation URL Constants (`app/src/constants/docs.ts`)

Created a new TypeScript constants file with:
- `DOCS_BASE_URL`: Base URL for GitHub Pages documentation
- `DOCS_URLS`: Object with named constants for all doc pages and GitHub resources
  - `HOME`, `CURATION_CRITERIA`, `RE_REVIEW_INSTRUCTIONS`, `TUTORIAL_VIDEOS`
  - `GITHUB_DISCUSSIONS`, `GITHUB_ISSUES`

Uses `as const` for type safety and autocomplete support.

### 2. Component Updates (4 files)

Updated all consumers to import and use the constants:

**HomeView.vue**
- Imported `DOCS_URLS` in setup()
- Replaced hardcoded `href` with `:href="DOCS_URLS.CURATION_CRITERIA"`

**ReviewInstructions.vue**
- Added setup() function to return `DOCS_URLS`
- Replaced 3 hardcoded doc links with constants

**DocumentationView.vue**
- Added setup() function to return `DOCS_URLS`
- Replaced 4 occurrences (home, discussions, issues links, and display text)

**HelperBadge.vue**
- Updated existing setup() to return `DOCS_URLS`
- Replaced 2 hardcoded links (docs and discussions)

### 3. Gene Page Reordering (`app/src/views/pages/GeneView.vue`)

Reordered template sections to improve information hierarchy:

**New order:**
1. Gene info card (name, location, identifiers)
2. **Associated Entities Table** (moved up)
3. External genomic data cards (Constraint Scores, ClinVar, Model Organisms)
4. Genomic Visualizations (Protein View, Gene Structure, 3D Structure)

**Previous order:**
1. Gene info card
2. External genomic data cards
3. Genomic Visualizations
4. Associated Entities Table (was last)

**Rationale:** Associated entities (gene-inheritance-disease relationships) are the core value of SysNDD. Users need to see related entities immediately, before diving into external constraint scores or visualizations.

## Technical Implementation

### TypeScript Patterns

Used `as const` assertion for URL constants to provide:
- Readonly object (prevents accidental mutations)
- String literal types (better autocomplete)
- Type inference for object keys

### Vue 3 Composition API

Options API components (DocumentationView, ReviewInstructions, HelperBadge) use `setup()` to return constants rather than mixing into `data()`. This follows Vue 3 patterns and separates reactive data from static constants.

### Template Binding

Changed from static `href="..."` to dynamic `:href="DOCS_URLS.KEY"` binding. Vue's reactivity system handles these efficiently (constants are frozen objects, no watchers created).

## Testing & Verification

### Linting
✓ All 6 modified files pass ESLint with no warnings

### URL Consolidation
✓ `grep` confirms no hardcoded `berntpopp.github.io/sysndd` URLs remain in components
✓ Only occurrence is in `app/src/constants/docs.ts` (single source of truth)

### Template Structure
✓ GeneView sections appear in correct order (entities before constraints)
✓ No changes to props, event handlers, or component logic
✓ All existing tests pass (no test updates needed)

## Commits

| Hash | Message | Files Changed |
|------|---------|---------------|
| e3ca12d7 | feat(75-01): centralize documentation URLs into constants | 5 files (1 new, 4 modified) |
| e52ef4fc | feat(75-01): reorder GeneView sections to show entities first | 1 file (GeneView.vue) |

## Deviations from Plan

None - plan executed exactly as written.

## Future Maintenance

### Adding New Documentation Links

To add a new documentation link:

1. Add entry to `DOCS_URLS` in `app/src/constants/docs.ts`:
```typescript
SOME_NEW_PAGE: `${DOCS_BASE_URL}/08-some-new-page.html`,
```

2. Import and use in component:
```vue
<BLink :href="DOCS_URLS.SOME_NEW_PAGE">...</BLink>
```

### Updating Base URL

If documentation moves to a new domain, update only `DOCS_BASE_URL` in `app/src/constants/docs.ts`. All 4 components automatically use the new URL.

### Gene Page Layout Changes

Future sections can be added to `GeneView.vue` by inserting `<div class="container-fluid">` blocks. Current order establishes the pattern:
- Most important/specific first (entities)
- External context second (constraints, ClinVar)
- Detailed visualizations last

## Impact Assessment

### Maintainability
**Before:** Documentation URLs scattered across 4 files, 9 total occurrences
**After:** 1 constants file, 9 imports

**Benefit:** Future URL changes (e.g., documentation versioning, domain changes) require editing only `docs.ts`.

### User Experience
**Before:** Gene page showed associated entities last (required scrolling past external data)
**After:** Entities appear immediately after gene info

**Benefit:** Users see gene-disease relationships prominently, aligning with SysNDD's core value proposition (expert-curated entities).

### Performance
No impact - template reordering doesn't affect rendering performance, constants add <1KB to bundle.

## Next Phase Readiness

### Blockers
None.

### Recommendations

1. **Consider extending constants pattern:**
   - API endpoints (currently scattered across `apiService.ts` and components)
   - External resource URLs (OMIM, HGNC, UniProt URLs currently inline)

2. **Document the constants convention:**
   - Update CONTRIBUTING.md to reference `app/src/constants/` for new URL constants
   - Establish pattern for other constant types (e.g., routes, config values)

3. **Track URL analytics:**
   - Monitor documentation link clicks to validate UX improvements
   - Identify which doc sections are most valuable to users

## Lessons Learned

### What Went Well
- Constants file pattern is simple and effective
- Options API setup() function cleanly handles static imports
- Template reordering was straightforward (no side effects)
- ESLint caught zero issues (clean code from start)

### What Could Be Improved
- Could add JSDoc comments to `docs.ts` explaining each URL's purpose
- Could add E2E test to verify documentation links work (prevent broken links)

### Applicability to Future Work
- Constants centralization pattern applies to any hardcoded values across multiple components
- Template section reordering is safe when sections are independent (no shared state/refs)
