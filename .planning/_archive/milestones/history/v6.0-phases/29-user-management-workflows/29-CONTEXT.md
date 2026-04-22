# Phase 29: User Management Workflows - Context

**Gathered:** 2026-01-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement bulk actions (approve, delete, role assignment) with cross-page selection and filter presets for the user management table. This extends ManageUser from Phase 28 with workflow enhancements. Does NOT include new user fields, profile editing, or authentication changes.

</domain>

<decisions>
## Implementation Decisions

### Selection behavior
- Selections persist across page navigation (stored in component state)
- Selection count badge appears in table header alongside title
- "Select all matching filter" option appears when all on current page are selected
- Maximum selection limit: 20 users (prevents accidental mass operations)

### Confirmation UX
- Destructive actions (delete): Modal lists ALL usernames being deleted in scrollable list
- Destructive actions require typing "DELETE" to enable confirm button
- Non-destructive actions (approve, role assign): Simple confirmation dialog with count
- Success feedback: Toast notification + automatic table refresh

### Bulk action constraints
- All-or-nothing transactions: If any operation fails, entire batch rolls back
- Admin users cannot be bulk-deleted (blocked with clear message)
- If selection contains admins, entire delete action is blocked ("Cannot delete: selection contains admin users")
- All roles (Curator, Reviewer, Admin) can be bulk-assigned

### Filter presets
- Quick filter buttons appear above the table (e.g., "Pending", "Curators")
- Presets are user-specific (not shared across admins)
- Save flow: Set filters → click "Save as preset" → enter name
- Storage: Browser localStorage (no backend changes needed)

### Claude's Discretion
- Exact button placement and styling in table header
- Loading states during bulk operations
- Toast notification duration and position
- Quick button styling (pills, tabs, or standard buttons)

</decisions>

<specifics>
## Specific Ideas

- Selection badge in table header (like Gmail's "5 selected" next to checkbox)
- Type-to-confirm pattern for deletes (like GitHub's dangerous settings)
- Quick filter buttons similar to Jira's sprint board filters

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 29-user-management-workflows*
*Context gathered: 2026-01-25*
