# Phase 32: Async Jobs - Context

**Gathered:** 2026-01-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract useAsyncJob composable as a reusable pattern for long-running jobs (HGNC updates, annotations) and improve ManageAnnotations UI with progress visualization, job history table, and error handling. Job cancellation and new job types are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion

User has delegated all implementation decisions to Claude with the following mandate:

**Research and apply:**
- Industry best practices for async job UI patterns
- Existing SysNDD UI/UX stack patterns (Bootstrap-Vue-Next, existing composables)
- Standard conventions for progress indicators, job history, and error handling

**Areas to research and decide:**

1. **Progress visualization**
   - Progress bar style (determinate vs indeterminate based on job type)
   - Elapsed time format and update frequency
   - Status message verbosity and placement
   - Animation and visual feedback patterns

2. **Job history display**
   - Number of jobs to show (pagination or limited list)
   - Sorting approach (newest first is standard)
   - Information density in collapsed vs expanded views
   - GenericTable integration patterns from Phase 28

3. **Error handling UX**
   - Error display method (inline, toast, modal based on severity)
   - Retry button behavior and availability
   - Error detail visibility (expandable vs always shown)
   - Consistent error messaging patterns

4. **Job control actions**
   - Cancel button behavior and confirmation flow
   - UI state during job execution (disabled controls, loading states)
   - Confirmation dialog patterns matching existing admin views

**Approach:** Make senior-level decisions by examining existing codebase patterns (TablesEntities, ManageAnnotations, composables), researching Vue/Bootstrap-Vue-Next best practices, and applying consistent UI/UX standards across the admin panel.

</decisions>

<specifics>
## Specific Ideas

No specific requirements — user trusts Claude to research best practices, check existing implementation patterns, and make informed decisions that fit the established UI/UX stack.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 32-async-jobs*
*Context gathered: 2026-01-25*
