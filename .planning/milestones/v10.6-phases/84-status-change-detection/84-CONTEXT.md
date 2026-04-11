# Phase 84: Status Change Detection - Context

**Gathered:** 2026-02-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Add frontend change detection to skip status/review creation when user didn't change anything. Make the "pending change" indicators (exclamation-triangle badge) consistent across all curation views. Prevent unnecessary database records from being created when curators save without modifications.

</domain>

<decisions>
## Implementation Decisions

### Detection scope
- Track all three editable status form fields: **category_id** (dropdown), **problematic** (removal flag), **comment** (textarea)
- Exact comparison — any change counts, including whitespace in comments
- Apply change detection to **both status AND review forms** across all three components: ModifyEntity, ApproveReview, ApproveStatus
- Follow the same pattern already used for review change detection in the codebase
- Must be fully tested with no regressions

### Change indicators across curation views
- The "Status change pending" exclamation-triangle badge (already in ApproveReview) must appear in **all curation views**: ModifyEntity, ApproveReview, ApproveStatus
- Backend already calculates both `status_change` (in review endpoint) and `review_change` (in status endpoint)
- ApproveStatus currently receives `review_change` data but doesn't render it — must fix this gap
- Indicators show **database state**: whether an entity has an unapproved status or review pending (active != newest)
- Small icon next to the status/review action icon with border around the action icon

### Save behavior
- Silent skip: Save button stays enabled, clicking it closes modal without API call when nothing changed
- No toast or message for skipped saves — seamless experience
- Successful saves keep current behavior (existing success toast)

### Unsaved changes warning
- Show confirmation dialog if user tries to close modal with unsaved changes
- Discard form state on close — no draft persistence (clean slate each time)
- Follow the `hasChanges` computed property pattern from LlmPromptEditor

### Claude's Discretion
- Exact implementation of `hasChanges()` comparison logic in composables
- How to structure the change tracking across the three components (shared composable vs per-component)
- Confirmation dialog styling/wording
- Test structure and organization

</decisions>

<specifics>
## Specific Ideas

- Use the existing `hasChanges` pattern from `LlmPromptEditor.vue` (computed property comparing edited values to loaded values)
- The exclamation-triangle-fill icon overlaid on stoplights is the established pattern — replicate it where missing
- Backend already provides the data (`status_change`, `review_change`) — frontend just needs to render consistently
- Research best practices for form change detection as a senior full-stack dev would approach it

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 84-status-change-detection*
*Context gathered: 2026-02-10*
