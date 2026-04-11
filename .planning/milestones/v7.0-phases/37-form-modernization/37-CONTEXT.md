# Phase 37: Form Modernization - Context

**Gathered:** 2026-01-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract reusable form patterns from curation views and improve form UX for curators. Includes entity search/autocomplete, draft persistence, Review form composable extraction, and entity preview. Does NOT include new form types or backend changes beyond existing APIs.

</domain>

<decisions>
## Implementation Decisions

### Entity Search UX
- Search by entity ID, gene symbol, or disease name — covers all common curator lookup patterns
- Rich preview in dropdown results: Gene badge + Disease name + Category icon + ID (using existing badge components)
- Search triggers after 2 characters typed (balance responsiveness vs flooding)
- Full keyboard navigation: Arrow keys to move, Enter to select, Escape to close

### Draft Persistence
- Store drafts in browser localStorage — persists across sessions, no backend changes needed
- Auto-save on field change with 2-second debounce after user stops typing
- Prompt to restore when draft exists: "You have unsaved changes for Entity X. Restore?" with Yes/No
- Clear draft only on successful form submission (not on navigation away)

### Composable Design
- useReviewForm handles full form lifecycle: validation, submission, draft persistence, loading states, error handling
- Review-specific composable — knows about synopsis, phenotypes, variations fields (not generic)
- ReviewFormFields component tightly coupled with useReviewForm — component uses composable internally for simpler API
- Files located alongside Review view: src/views/curate/composables/useReviewForm.ts and src/views/curate/components/ReviewFormFields.vue

### Preview Behavior
- Rich card preview: Gene badge, Disease badge, Inheritance icon, Category stoplight, NDD status (reuse Phase 35.1 patterns)
- Preview appears immediately on entity selection from search
- Skeleton placeholder while entity data loads (gray animated boxes matching preview layout)
- Preview always visible once entity selected — stays above form, not collapsible

### Claude's Discretion
- Exact skeleton animation implementation
- Debounce timing adjustments if needed
- localStorage key naming convention
- Error state UI for failed entity loads

</decisions>

<specifics>
## Specific Ideas

- Reuse existing GeneBadge, DiseaseBadge, EntityBadge, colorAndSymbols components from Phase 35.1
- Entity preview should match the rich modal headers pattern from ModifyEntity
- Search dropdown should feel like AutocompleteInput pattern already in codebase

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 37-form-modernization*
*Context gathered: 2026-01-26*
