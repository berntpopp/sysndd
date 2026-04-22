# Phase 35: Multi-Select Restoration - Context

**Gathered:** 2026-01-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Restore multi-select capability for phenotypes and variations using Bootstrap-Vue-Next components. Replace deprecated vue3-treeselect with native Bootstrap-Vue-Next patterns. Used in Review form, ModifyEntity, and ApproveReview. Phenotypes use HPO hierarchy, variations use variant type hierarchy.

</domain>

<decisions>
## Implementation Decisions

### Selection Interface
- Interface approach: Claude's discretion based on research of best practices and codebase consistency
- Hierarchy display: Collapsed by default, user expands sections as needed
- Parent node behavior: Parent selection is for navigation only — must explicitly select individual children
- Consistency: Phenotypes and variations use the same interface pattern

### Selected Items Display
- Display format: Chips/tags for selected items
- Overflow handling: Show all chips, field grows as needed (no truncation)
- Chip content: Show item name only, full hierarchy path available on hover via tooltip
- Removal: X button on each chip for quick removal without reopening selector

### Search & Filtering
- Search behavior: Filter tree in place — hide non-matching branches, show matches in context
- Match scope: Search matches both names and codes (HPO IDs like HP:0001250, variation identifiers)
- Context preservation: Keep ancestor nodes visible so user sees where match sits in hierarchy
- Clear search: Visible X button to clear search and restore full tree

### Validation & Limits
- Minimum required: At least 1 selection required
- Maximum limit: No limit — curators work with specific HPO terms relevant to neurodevelopmental disorders
- Validation timing: Errors shown on form submit only, not before
- Error messages: Generic "This field is required"

### Claude's Discretion
- Specific interface pattern (dropdown vs modal) — research best practices and match codebase
- Exact Bootstrap-Vue-Next component choices
- Loading states and performance optimization for large hierarchies
- Keyboard navigation implementation details

</decisions>

<specifics>
## Specific Ideas

- Consistency with existing codebase patterns is important — research current design before implementing
- HPO phenotypes and variation types should feel like the same interface to curators

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 35-multi-select-restoration*
*Context gathered: 2026-01-26*
