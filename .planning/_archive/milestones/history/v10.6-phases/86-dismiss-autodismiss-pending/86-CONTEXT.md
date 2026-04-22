# Phase 86: Dismiss & Auto-Dismiss Pending Statuses/Reviews - Context

**Gathered:** 2026-02-10
**Status:** Complete

<domain>
## Phase Boundary

Add dismiss/reject capability for pending statuses and reviews, and auto-dismiss sibling pending items when one is approved. Curators currently have no way to clean up unwanted pending statuses/reviews that accumulate from testing or corrections. The existing API reject path (`status_ok=false`) sets `approving_user_id` but keeps `status_approved=0`, yet dismissed items still appear in the pending queue because the query doesn't filter on `approving_user_id`.

</domain>

<decisions>
## Implementation Decisions

### State model (no schema changes)
- **Use existing `approving_user_id` column** as dismissal marker — no database migration needed
- State matrix: `status_approved=0 + approving_user_id IS NULL` = truly pending; `status_approved=0 + approving_user_id=curator_id` = dismissed; `status_approved=1 + approving_user_id=curator_id` = approved
- **Filter dismissed from pending**: Add `AND approving_user_id IS NULL` to all pending queries

### Auto-dismiss siblings
- When approving status A for an entity with pending statuses B, C — automatically set `approving_user_id` on B and C
- Same pattern for reviews
- Cross-entity isolation: auto-dismiss only affects same entity_id

### Frontend UX
- Add dismiss button (red X icon, `bi-x-circle`) to every row in ApproveStatus and ApproveReview
- Add confirmation modal with danger theme before dismissal
- Add duplicate warning icon (yellow triangle, `bi-exclamation-triangle-fill`) for entities with multiple pending items
- Enhance approve modal with info alert when entity has duplicates: "Other pending statuses/reviews for this entity will be automatically dismissed"
- Update legend with dismiss and duplicate icons

### Claude's Discretion
- Exact SQL for auto-dismiss UPDATE statements
- Modal styling and icon choices
- Integration test structure and test IDs

</decisions>

<specifics>
## Specific Ideas

- Entity 304 (GRIN2B) had accumulated 6 pending statuses from testing — curators had no way to clean them up
- The `status_ok=false` / `review_ok=false` API path already existed but dismissed items were never filtered out
- Approval service "approve all" batch queries also needed the filter to skip dismissed items
- `duplicate` field already existed in API response (`yes`/`no`) — used to drive the warning icon display
- Both sync and async approval paths (individual and batch) needed the filter

</specifics>

<deferred>
## Deferred Ideas

None — implementation stayed within phase scope

</deferred>

---

*Phase: 86-dismiss-autodismiss-pending*
*Context gathered: 2026-02-10*
