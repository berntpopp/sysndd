# Phase 39: Accessibility Pass - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Ensure WCAG 2.2 AA compliance across all curation interfaces. This includes keyboard navigation, screen reader support, proper ARIA attributes, icon legends, and focus management in modals. The phase covers existing curation views (ApproveUser, ApproveReview, ApproveStatus, ModifyEntity, ManageReReview, Review) — no new features, just accessibility improvements to existing UI.

</domain>

<decisions>
## Implementation Decisions

### Keyboard navigation
- Use browser default focus indicators (no custom focus ring styling)
- Add "Skip to main content" link, visible only on focus (hidden until Tab pressed)
- Tables support arrow key navigation: Up/Down moves between rows, Left/Right between cells
- Automatic focus progression in workflows: focus moves to modal when opened, returns to trigger on close

### Screen reader experience
- Aria-labels on action buttons are minimal: "Edit", "Delete", "Approve" — action only, no entity context
- Announce all status changes via aria-live regions (success and error messages)
- Keep current BTable implementation for table semantics (Bootstrap-Vue handles this)
- Landmarks: Claude researches Vue 3 / Bootstrap-Vue-Next best practices and implements appropriate pattern

### Icon legends & visual cues
- Inline legend on page near tables that use icons
- Legend visibility: Claude researches best practices for collapsible vs always-visible patterns
- Legend covers all symbolic icons: category stoplight, inheritance, NDD status, approval status
- Individual icon tooltips in addition to legend (legend for overview, tooltips for quick reference)

### Focus management in modals
- Initial focus goes to first focusable element in modal
- Focus trapped within modal (Tab/Shift+Tab cycles within, not to page)
- On modal close, focus returns to trigger element
- Escape key always closes modal (no unsaved changes warning)

### Claude's Discretion
- Exact implementation of skip link component
- Which ARIA landmark approach (semantic HTML vs explicit roles) after research
- Legend collapsibility pattern after research
- Specific aria-live region politeness levels (polite vs assertive)

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard accessible patterns that match Vue 3 / Bootstrap-Vue-Next ecosystem.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 39-accessibility-pass*
*Context gathered: 2026-01-27*
