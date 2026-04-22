# Phase 28: Table Foundation - Context

**Gathered:** 2026-01-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Modernize ManageUser and ManageOntology with TablesEntities pattern (search, pagination, URL sync). Users can search, filter, paginate, and export data from admin tables. Bulk actions and user workflows are separate phases (Phase 29).

</domain>

<decisions>
## Implementation Decisions

### Search behavior
- Instant search (as you type) with 300ms debounce
- Search across all text fields: name, email, institution, ORCID, comments
- Highlight matching text in table cells (bold or background-color)
- Full URL sync: search term, filters, page all persist in URL for bookmarking

### Filter UI layout
- Match TablesEntities design at `/Entities` — consistent horizontal filter bar layout
- Active filters displayed as removable pills/chips below filter bar
- "Clear all filters" button always visible
- Role filter uses multi-select dropdown (users can filter by multiple roles at once)
- Approval status filter for users (pending/approved/rejected)

### Table density & columns
- Compact row density (tight rows, more data visible)
- ManageUser default columns: Name, Email, Role, Status, Institution, Last Login (6 columns)
- Fixed columns — no column toggle menu
- All columns sortable (click header to sort asc/desc)

### Empty & loading states
- Spinner overlay during data fetch (match other table views)
- Simple "No users found" message when search returns no results
- Result count always visible: "Showing 1-20 of 156 users"
- Toast notification for API errors (not inline), table shows stale data

### Claude's Discretion
- Exact debounce timing (300ms suggested)
- Highlight styling (bold vs background)
- Spinner positioning and styling details
- Toast notification duration and styling
- ManageOntology specific column selection

</decisions>

<specifics>
## Specific Ideas

- Match TablesEntities design at `/Entities` for consistent UX
- Follow enterprise filtering best practices: multi-select for additive filtering, instant feedback, filter pills for clarity

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 28-table-foundation*
*Context gathered: 2026-01-25*
