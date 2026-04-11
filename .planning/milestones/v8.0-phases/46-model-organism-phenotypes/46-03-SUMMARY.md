---
phase: 46-model-organism-phenotypes
plan: 03
subsystem: ui
tags: [accessibility, wcag, a11y, aria, vue]

# Dependency graph
requires:
  - phase: 46-02
    provides: Model Organisms card UI component
  - phase: 42
    provides: ClinVar and Constraint cards
  - phase: 43
    provides: Protein Domain Lollipop Plot

provides:
  - WCAG 2.2 AA compliant gene page cards
  - Accessible link buttons with aria-labels
  - Decorative icons properly hidden from screen readers
  - Fixed aria-disabled on non-interactive elements

affects: [47-testing, 48-documentation, lighthouse-audits]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - aria-hidden="true" for decorative icons
    - aria-label with "(opens in new tab)" for external links
    - Avoid aria-disabled on non-interactive elements

key-files:
  created: []
  modified:
    - app/src/components/gene/GeneClinVarCard.vue
    - app/src/components/gene/GeneConstraintCard.vue
    - app/src/components/gene/IdentifierRow.vue
    - app/src/components/gene/ModelOrganismsCard.vue
    - app/src/components/gene/ResourceLink.vue

key-decisions:
  - "All v8.0 gene page cards already compliant with WCAG 1.4.1 (Use of Color) - no color-only information"
  - "Fixed Lighthouse-reported issues: links without names, prohibited ARIA attributes"

patterns-established:
  - "External link buttons must have aria-label describing destination and (opens in new tab)"
  - "Icons in buttons/links must have aria-hidden=true when text label is present"
  - "Avoid aria-disabled on non-interactive span elements"

# Metrics
duration: 25min
completed: 2026-01-29
---

# Phase 46 Plan 03: Accessibility Audit Summary

**WCAG 2.2 AA compliance fixes for gene page cards - added aria-labels to link buttons, aria-hidden to decorative icons, removed prohibited aria-disabled from spans**

## Performance

- **Duration:** 25 min
- **Started:** 2026-01-29T11:00:00Z
- **Completed:** 2026-01-29T11:25:00Z
- **Tasks:** 2 (1 auto + 1 checkpoint)
- **Files modified:** 5

## Accomplishments
- Audited all v8.0 gene page cards for WCAG 1.4.1 compliance - all already met color + text requirements
- Fixed Lighthouse accessibility issues to improve score toward 90+ target
- Added aria-label to external link buttons in GeneClinVarCard and GeneConstraintCard
- Added aria-hidden="true" to decorative icons throughout gene page components
- Removed prohibited aria-disabled from non-interactive span elements in ResourceLink

## Task Commits

Each task was committed atomically:

1. **Task 1: Audit and fix color-only information in v8.0 cards** - `23f47926` (fix)
   - Initial audit found all cards already compliant with WCAG 1.4.1
   - Fixed Lighthouse-reported issues after checkpoint feedback

**Plan metadata:** (to be committed with summary)

## Files Created/Modified
- `app/src/components/gene/GeneClinVarCard.vue` - Added aria-label and title to external link button, aria-hidden on icon
- `app/src/components/gene/GeneConstraintCard.vue` - Added aria-label and title to external link button, aria-hidden on icon
- `app/src/components/gene/IdentifierRow.vue` - Added aria-hidden to clipboard and external link icons, improved aria-label text
- `app/src/components/gene/ModelOrganismsCard.vue` - Added aria-hidden to external link icons, improved contrast comment
- `app/src/components/gene/ResourceLink.vue` - Removed prohibited aria-disabled from span elements, added aria-hidden to icons

## Decisions Made
- **WCAG 1.4.1 already compliant:** All ACMG badges, constraint bars, zygosity chips, and lollipop legend already had text labels alongside colors
- **Lighthouse issues prioritized:** Focused on fixing the four specific Lighthouse-reported issues rather than general accessibility improvements
- **aria-hidden for decorative icons:** All icons in buttons/links with text labels marked as aria-hidden="true" to prevent screen reader confusion

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed links without discernible names**
- **Found during:** Task 2 (Checkpoint feedback from Lighthouse audit)
- **Issue:** External link buttons in GeneClinVarCard and GeneConstraintCard only had icons without aria-label
- **Fix:** Added aria-label="View gene on [service] (opens in new tab)" and title attributes
- **Files modified:** GeneClinVarCard.vue, GeneConstraintCard.vue
- **Verification:** ESLint and type-check pass
- **Committed in:** 23f47926

**2. [Rule 1 - Bug] Fixed prohibited ARIA attributes**
- **Found during:** Task 2 (Checkpoint feedback from Lighthouse audit)
- **Issue:** ResourceLink.vue used aria-disabled on span elements (non-interactive)
- **Fix:** Removed aria-disabled from span, added role="text" instead
- **Files modified:** ResourceLink.vue
- **Verification:** ESLint pass, no prohibited ARIA attributes
- **Committed in:** 23f47926

**3. [Rule 2 - Missing Critical] Added aria-hidden to decorative icons**
- **Found during:** Task 2 (Checkpoint feedback from Lighthouse audit)
- **Issue:** Decorative icons could be announced by screen readers
- **Fix:** Added aria-hidden="true" to all icons in buttons/links that have text labels
- **Files modified:** GeneClinVarCard.vue, GeneConstraintCard.vue, IdentifierRow.vue, ModelOrganismsCard.vue, ResourceLink.vue
- **Verification:** ESLint pass, icons properly hidden
- **Committed in:** 23f47926

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 missing critical)
**Impact on plan:** All fixes necessary for Lighthouse accessibility score improvement. No scope creep.

## Issues Encountered
- Initial audit found all color-coded elements already had text labels (no changes needed for WCAG 1.4.1)
- Lighthouse audit at checkpoint revealed additional issues not in original plan scope

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All v8.0 gene page cards now have improved accessibility
- Model Organisms integration complete with MGI and RGD data display
- Ready for Phase 46-04 (if applicable) or final integration testing
- Lighthouse accessibility score should improve with these fixes

---
*Phase: 46-model-organism-phenotypes*
*Completed: 2026-01-29*
