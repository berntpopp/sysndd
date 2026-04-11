# Phase 38: Re-Review System Overhaul - Context

**Gathered:** 2026-01-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable dynamic batch creation and gene-specific assignment for re-review workflow. Replace the hardcoded pre-computed batch system with a flexible, criteria-based batch management system while maintaining backward compatibility with existing batches. Admins can create batches with custom criteria, assign to users, reassign freely, and manage batch lifecycle.

</domain>

<decisions>
## Implementation Decisions

### Batch creation flow
- Single form interface (all options on one screen — name, criteria, assignment together)
- Optional preview of matching entities (Preview button available but not mandatory)
- Auto-generated batch ID by default, optional custom name can be added
- New dynamic batch system replaces hardcoded 2020-01-01 filter completely
- Backward compatible with existing pre-computed batches (can coexist)
- Old batches can be deleted or recomputed through the new system

### Assignment mechanics
- Both workflows supported: create batch then assign, OR assign during creation
- One user per batch (clear ownership model)
- Batches can be freely reassigned to another user at any time
- Manual entity selection available during batch creation (add/remove specific entities from criteria results)

### Criteria flexibility
- Full flexibility for batch criteria: date range + status + gene list + disease + any combination
- Oldest entries prioritized using simple age sort (oldest review date first)
- Configurable batch size limit (default 20, admin can adjust during creation)
- System prevents entity overlap between batches (entity can only be in one active batch)

### Batch lifecycle
- Simple 3-state lifecycle: Created → Assigned → Completed
- Soft delete only (archived/inactive, data preserved for audit)
- Recalculation allowed only before assignment (assigned batches locked)
- Auto-complete when all entities have been reviewed and approved

### Claude's Discretion
- API endpoint structure and naming
- Database schema modifications for new batch system
- Exact UI layout and field ordering
- Form validation messages and error handling
- How to migrate/coexist with legacy batches

</decisions>

<specifics>
## Specific Ideas

- Batches should be created by importance — oldest entries without new curation should be preferred
- "Rich and intuitive" batch creation system — clear, easy to use for curators
- Need complete removal of hardcoded/bad legacy system while maintaining compatibility with existing data
- Current system has pre-computed batches of 20 genes each, assigned via `re_review_assignment` table
- Current `re_review_entity_connect` table tracks: `re_review_review_saved`, `re_review_status_saved`, `re_review_submitted`, `re_review_approved`

</specifics>

<deferred>
## Deferred Ideas

- Batch notifications/reminders to assigned users — could be future enhancement
- Batch analytics/reporting dashboard — could be separate phase
- Collaborative batch review (multiple users per batch) — explicitly decided against for now

</deferred>

---

*Phase: 38-re-review-system-overhaul*
*Context gathered: 2026-01-26*
