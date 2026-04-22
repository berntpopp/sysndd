# Phase 16: UI/UX Modernization - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Visual refresh with modern medical web app aesthetics. Improve how the application looks and feels — colors, shadows, spacing, loading states, form styling, table presentation, mobile responsiveness, and accessibility. No functional changes, no new features.

</domain>

<decisions>
## Implementation Decisions

### Visual tone & feel
- Modern scientific aesthetic — contemporary research tool feel with subtle gradients, refined shadows, balanced warmth
- Compact spacing density — more data visible at once, tighter spacing for power users working with data-heavy views
- Subtle color evolution — same color family but modernized hues, improved contrast ratios for accessibility

### Claude's Discretion: Shadows
- Research current implementation and best practices for shadow depth systems
- Propose appropriate shadow levels that fit modern scientific tone

### Loading & empty states
- Loading indicators: Research current implementation and best practices for minimal layout shift and instant-feeling feedback
- Empty states: Illustration + guidance approach using icon-based compositions from Bootstrap Icons
- Empty state messaging: Neutral informative tone (e.g., "No genes match your search criteria.")

### Table presentation
- Row hover: Subtle highlight (light background color change) for tracking across wide tables
- Zebra striping: Yes, subtle alternating row colors
- Sort indicators: Icon + highlight (arrow icon plus background color on active sort column)
- Mobile treatment: Research current behavior, framework capabilities, and best practices

### Form & input styling
- Input sizing: Research best practices and current implementation for appropriate sizing
- Validation display: Inline below field (red text directly under invalid field)
- Focus states: Colored border + glow (primary color border with subtle outer glow)
- Label positioning: Above inputs (stacked) — clear, standard, mobile-friendly

</decisions>

<specifics>
## Specific Ideas

- "Modern scientific" feel — like contemporary research tools, not clinical/sterile
- Compact density is important for data-heavy views (gene tables, entity lists)
- Several areas explicitly deferred to research phase to check current implementation against best practices:
  - Shadow depth system
  - Loading indicator patterns
  - Mobile table treatment
  - Input sizing per context

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 16-ui-ux-modernization*
*Context gathered: 2026-01-23*
