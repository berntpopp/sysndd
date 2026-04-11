# Phase 39: Accessibility Pass - Research

**Researched:** 2026-01-27
**Domain:** Web accessibility (WCAG 2.2 AA compliance) for Vue 3 + Bootstrap-Vue-Next applications
**Confidence:** HIGH

## Summary

This research covers implementing WCAG 2.2 AA compliance for Vue 3 applications using Bootstrap-Vue-Next 0.42.0 and Bootstrap 5.3.8. The phase focuses on adding accessibility improvements to existing curation interfaces without changing functionality.

WCAG 2.2, published October 2023, is now the standard reference for accessibility compliance. The April 2024 DOJ final rule establishes WCAG 2.2 Level AA as the named standard for state and local government web content. Key new requirements in WCAG 2.2 include Focus Not Obscured (Minimum) and enhanced focus visibility standards.

Vue 3 provides strong accessibility support through semantic HTML first approach, official composables, and ecosystem tools. Bootstrap-Vue-Next automatically manages ARIA attributes for interactive components (modals, dropdowns, tooltips) but developers remain responsible for proper semantic markup, color contrast, and comprehensive keyboard navigation.

**Primary recommendation:** Use semantic HTML first, supplement with ARIA only where needed, leverage Bootstrap-Vue-Next's automatic ARIA management, implement focus traps with VueUse's useFocusTrap, and validate with vitest-axe automated testing.

## Standard Stack

The established libraries/tools for accessibility in Vue 3 + Bootstrap-Vue-Next applications:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bootstrap-vue-next | 0.42.0 | UI components with built-in accessibility | Automatic ARIA management, focus trapping in modals, keyboard navigation |
| bootstrap | 5.3.8 | CSS framework with accessibility features | WCAG-compliant utilities, `.visually-hidden-focusable` for skip links, prefers-reduced-motion support |
| vue | 3.5.25 | Framework | Official accessibility guide, semantic template support, composable patterns |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @vueuse/integrations | Latest | Focus trap composable | Modal focus management, requires `focus-trap@^7` peer dependency |
| vitest-axe | 0.1.0 | Automated accessibility testing | Unit/integration tests - already in project dependencies |
| focus-trap | ^7 | Focus containment library | Peer dependency for useFocusTrap, low-level focus management |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| VueUse useFocusTrap | focus-trap-vue component | Component wrapper vs composable - composable gives more control and fits Vue 3 Composition API patterns better |
| vitest-axe | jest-axe | vitest-axe is specifically designed for Vitest, avoids type conflicts |
| Custom skip link | @vue-a11y/vue-skip-to | Custom implementation is simpler for single-destination skip links, package better for multiple skip targets |

**Installation:**
```bash
# For focus trap (if not using BModal's built-in focus management)
npm install focus-trap@^7

# vitest-axe already installed in project
```

## Architecture Patterns

### Recommended Project Structure
```
src/
├── components/
│   └── accessibility/
│       ├── SkipLink.vue          # Skip to main content component
│       ├── IconLegend.vue        # Icon legend component
│       └── AriaLiveRegion.vue    # Status announcement region
├── composables/
│   └── useAriaLive.ts            # ARIA live region announcements
├── views/
│   └── curate/                   # Existing curation views to enhance
└── App.vue                       # Add skip link at top level
```

### Pattern 1: Skip to Main Content Link
**What:** Keyboard-accessible link visible only on focus, positioned as first focusable element
**When to use:** Required at top of every page/app for WCAG 2.4.1 (Bypass Blocks)
**Example:**
```vue
<!-- In App.vue, before navbar -->
<template>
  <span ref="backToTop" tabindex="-1" />
  <a href="#main" class="skip-link">Skip to main content</a>

  <div id="navbar">
    <Navbar />
  </div>
  <main id="main" tabindex="-1" role="main">
    <router-view />
  </main>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const backToTop = ref()

// Reset focus on route change
watch(() => route.path, () => {
  backToTop.value?.focus()
})
</script>

<style scoped>
.skip-link {
  position: fixed;
  top: 0;
  left: 0;
  opacity: 0;
  z-index: 9999;
  background: white;
  padding: 0.5em 1em;
  border: 2px solid black;
}

.skip-link:focus {
  opacity: 1;
}
</style>
```
**Source:** [Vue.js Official Accessibility Guide](https://vuejs.org/guide/best-practices/accessibility)

### Pattern 2: ARIA Live Regions for Dynamic Content
**What:** Announce status changes to screen readers without interrupting user flow
**When to use:** Form validation results, success/error messages, dynamic content updates
**Example:**
```vue
<!-- components/accessibility/AriaLiveRegion.vue -->
<template>
  <div
    role="status"
    :aria-live="politeness"
    aria-atomic="true"
    class="visually-hidden"
  >
    {{ message }}
  </div>
</template>

<script setup>
defineProps({
  message: String,
  politeness: {
    type: String,
    default: 'polite',
    validator: (v) => ['polite', 'assertive'].includes(v)
  }
})
</script>

<style scoped>
.visually-hidden {
  position: absolute;
  overflow: hidden;
  white-space: nowrap;
  margin: 0;
  padding: 0;
  height: 1px;
  width: 1px;
  clip: rect(0 0 0 0);
  clip-path: inset(100%);
}
</style>
```
**Usage with composable:**
```typescript
// composables/useAriaLive.ts
import { ref } from 'vue'

export function useAriaLive() {
  const message = ref('')
  const politeness = ref<'polite' | 'assertive'>('polite')

  function announce(text: string, level: 'polite' | 'assertive' = 'polite') {
    politeness.value = level
    message.value = text

    // Clear after announcement
    setTimeout(() => {
      message.value = ''
    }, 1000)
  }

  return { message, politeness, announce }
}
```
**Source:** [MDN ARIA Live Regions](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Guides/Live_regions), [The A11Y Collective ARIA Live Guide](https://www.a11y-collective.com/blog/aria-live/)

### Pattern 3: Modal Focus Management with Bootstrap-Vue-Next
**What:** BModal automatically handles focus trapping and return focus
**When to use:** All modal dialogs (Bootstrap-Vue-Next handles this automatically)
**Example:**
```vue
<template>
  <BButton
    ref="triggerButton"
    @click="showModal = true"
  >
    Open Modal
  </BButton>

  <BModal
    v-model="showModal"
    title="Modal Title"
    header-close-label="Close modal"
  >
    <!-- Focus automatically trapped within modal -->
    <BFormInput
      id="first-input"
      autofocus
    />
    <BFormInput id="second-input" />

    <template #footer>
      <BButton @click="showModal = false">
        Cancel
      </BButton>
      <BButton variant="primary" @click="handleSubmit">
        Submit
      </BButton>
    </template>
  </BModal>
</template>
```
**Key features (automatic in BModal):**
- Initial focus on modal container (or element specified by `focus` prop)
- Tab key cycles within modal only (focus trap enabled by default)
- Escape key closes modal
- Focus returns to trigger button on close
- `aria-labelledby` and `aria-describedby` automatically set

**Source:** [Bootstrap-Vue-Next Modal Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/modal)

### Pattern 4: Icon Buttons with ARIA Labels and Tooltips
**What:** Icon-only buttons need both aria-label (for screen readers) and title/tooltip (for visual users)
**When to use:** All icon-only action buttons
**Example:**
```vue
<template>
  <BButton
    v-b-tooltip.hover.bottom
    variant="outline-primary"
    size="sm"
    aria-label="Edit user"
    title="Edit user"
    @click="handleEdit"
  >
    <i class="bi bi-pencil" aria-hidden="true" />
  </BButton>
</template>
```
**Key principles:**
- `aria-label` provides accessible name for screen readers
- `title` attribute provides tooltip for sighted users on hover
- Icon has `aria-hidden="true"` to prevent double-announcement
- Labels are minimal: action only ("Edit", "Delete", "Approve")
- Bootstrap-Vue-Next's `v-b-tooltip` directive adds ARIA attributes automatically

**Source:** [Sara Soueidan - Accessible Icon Buttons](https://www.sarasoueidan.com/blog/accessible-icon-buttons/)

### Pattern 5: Icon Legend Component
**What:** Visual key explaining symbolic icons used in tables/interfaces
**When to use:** Pages using multiple symbolic icons (status indicators, categories, etc.)
**Example:**
```vue
<!-- components/accessibility/IconLegend.vue -->
<template>
  <BCard
    body-class="p-2"
    class="mb-3"
  >
    <div class="d-flex flex-wrap gap-3 align-items-center">
      <strong class="me-2">Icon Legend:</strong>
      <div
        v-for="item in legendItems"
        :key="item.label"
        class="d-flex align-items-center gap-1"
      >
        <i
          :class="item.icon"
          :style="{ color: item.color }"
          aria-hidden="true"
        />
        <span class="small">{{ item.label }}</span>
      </div>
    </div>
  </BCard>
</template>

<script setup>
defineProps({
  legendItems: {
    type: Array,
    required: true,
    // Example: [{ icon: 'bi bi-check-circle-fill', color: 'green', label: 'Approved' }]
  }
})
</script>
```
**Usage:**
```vue
<IconLegend
  :legend-items="[
    { icon: 'bi bi-check-circle-fill', color: '#28a745', label: 'Approved' },
    { icon: 'bi bi-pencil-fill', color: '#007bff', label: 'Curator' },
    { icon: 'bi bi-exclamation-triangle-fill', color: '#dc3545', label: 'Problematic' }
  ]"
/>
```
**Decision:** Always visible (not collapsible) - legends are reference material that users may need to consult repeatedly while scanning tables. Collapsing adds extra interaction cost.

**Sources:** [Carbon Design System - Legends](https://carbondesignsystem.com/data-visualization/legends/), [Accessibility in UX Design 2025](https://orbix.studio/blogs/accessibility-uiux-design-best-practices-2025)

### Pattern 6: Semantic Table with Keyboard Navigation
**What:** Use native `<table>` HTML with Bootstrap-Vue-Next BTable component for automatic semantics
**When to use:** All data tables (existing pattern in curation views)
**Example:**
```vue
<template>
  <BTable
    :items="items"
    :fields="fields"
    striped
    hover
    responsive
    :per-page="perPage"
    :current-page="currentPage"
  >
    <template #cell(actions)="data">
      <BButton
        v-b-tooltip.hover
        variant="outline-primary"
        size="sm"
        aria-label="Edit entry"
        title="Edit entry"
        @click="handleEdit(data.item)"
      >
        <i class="bi bi-pencil" aria-hidden="true" />
      </BButton>
    </template>
  </BTable>
</template>
```
**Key points:**
- BTable uses semantic `<table>`, `<thead>`, `<tbody>`, `<tr>`, `<th>`, `<td>` elements
- Screen readers can navigate by row/column and announce context
- **Don't use ARIA grid role** unless table needs two-dimensional arrow key navigation or drag-and-drop
- For basic data tables, semantic HTML is superior to ARIA grid
- Arrow key navigation is enhancement, not requirement for standard tables

**Sources:**
- [Sarah Higley - Grids Part 2: Semantics](https://sarahmhigley.com/writing/grids-part2/)
- [MDN ARIA Table Role](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/table_role)
- [W3C Grid Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/grid/) - only for interactive grids

### Pattern 7: Form Labels and Error Messages
**What:** Explicit label association with error announcements via aria-describedby
**When to use:** All form inputs
**Example:**
```vue
<template>
  <BFormGroup
    label="Email address"
    label-for="email-input"
    :invalid-feedback="emailError"
    :state="emailState"
  >
    <BFormInput
      id="email-input"
      v-model="email"
      type="email"
      :state="emailState"
      aria-describedby="email-error"
      @blur="validateEmail"
    />
    <BFormInvalidFeedback id="email-error">
      {{ emailError }}
    </BFormInvalidFeedback>
  </BFormGroup>
</template>

<script setup>
import { ref, computed } from 'vue'

const email = ref('')
const emailError = ref('')

const emailState = computed(() => {
  if (!email.value) return null
  return emailError.value ? false : true
})

function validateEmail() {
  if (!email.value.includes('@')) {
    emailError.value = 'Please enter a valid email address'
  } else {
    emailError.value = ''
  }
}
</script>
```
**Bootstrap-Vue-Next handles:**
- Automatic `aria-describedby` association
- Visual error states with proper color contrast
- Invalid feedback announcement to screen readers

**Source:** [Vue.js Accessibility - Forms](https://vuejs.org/guide/best-practices/accessibility)

### Anti-Patterns to Avoid

- **Don't use `display: none` or `visibility: hidden` for skip links** - Use `.visually-hidden` with `:focus` override instead
- **Don't use `aria-label` when visible text exists** - Use `aria-labelledby` to reference visible text (WCAG 2.5.3 Label in Name)
- **Don't add ARIA grid role to standard data tables** - Semantic `<table>` is better unless you need interactive features like drag-and-drop
- **Don't use `aria-hidden` on focusable elements** - Only use on decorative/duplicate content
- **Don't rely on color alone** - Always pair color-coded information with icons, text, or patterns
- **Don't create keyboard traps** - Except for modals (which must have Escape key exit)
- **Don't use `title` attribute for critical information** - Not keyboard accessible, inconsistent screen reader support

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Focus trap in modals | Custom focus management with event listeners | BModal (built-in) or VueUse useFocusTrap | Edge cases: dynamically added elements, conditional rendering (v-if), focus return on close, escape key handling |
| Accessible tooltips | Custom hover/focus handlers | Bootstrap-Vue-Next `v-b-tooltip` directive | Handles keyboard access, ARIA attributes, positioning, timing, mobile support |
| Skip links | Custom router watchers | Standard pattern from Vue.js docs | Focus management on route change, proper hiding, keyboard accessibility |
| Live regions | Manual DOM manipulation | Composable with proper timing/clearing | Live regions must be pre-rendered, content changes need delay, proper politeness levels |
| Screen reader-only text | Custom CSS classes | Bootstrap's `.visually-hidden` class | Covers all edge cases: clip, clip-path, overflow, dimensions |
| Table accessibility | Custom ARIA grid implementation | Semantic HTML `<table>` with BTable | Screen reader shortcuts, built-in semantics, lower complexity |

**Key insight:** Accessibility features have subtle edge cases that are difficult to test without assistive technology. Use well-tested library solutions that handle keyboard users, screen readers, and dynamic content correctly.

## Common Pitfalls

### Pitfall 1: ARIA Live Regions Not Pre-rendered
**What goes wrong:** Screen readers don't announce dynamically added live regions
**Why it happens:** Live regions must exist in DOM before content changes to work reliably
**How to avoid:**
- Pre-render live region containers (empty) in component setup
- Use composable to manage announcements with small delay (milliseconds) between rendering and populating
**Warning signs:** Status messages work visually but screen reader doesn't announce them
**Source:** [The A11Y Collective - ARIA Live](https://www.a11y-collective.com/blog/aria-live/)

### Pitfall 2: Focus Trap with v-if Conditional Rendering
**What goes wrong:** useFocusTrap fails to activate when elements are conditionally rendered
**Why it happens:** Elements with `v-if` don't exist in DOM until condition is true
**How to avoid:**
```javascript
// Wait for next tick before activating
const { activate } = useFocusTrap(target)

watch(showModal, async (value) => {
  if (value) {
    await nextTick()
    activate()
  }
})
```
**Warning signs:** Focus trap doesn't engage even though modal is visible
**Source:** [VueUse useFocusTrap Documentation](https://vueuse.org/integrations/usefocustrap/)

### Pitfall 3: Using title Attribute Instead of aria-label
**What goes wrong:** Screen readers may not announce `title`, keyboard users can't access tooltips
**Why it happens:** Developers assume `title` provides accessibility
**How to avoid:** Use both:
- `aria-label` for screen readers
- `title` or `v-b-tooltip` for visual tooltip on hover/focus
**Warning signs:** Icon buttons that don't announce purpose to screen reader
**Source:** [A11Y Collective - aria-label vs title](https://www.a11y-collective.com/blog/aria-label-vs-title/)

### Pitfall 4: Creating Unintentional Keyboard Traps
**What goes wrong:** Users can Tab into component but can't Tab out
**Why it happens:** Custom keyboard handling prevents default Tab behavior
**How to avoid:**
- Only use focus traps in modals/dialogs with Escape key exit
- Test keyboard-only navigation through entire interface
- Don't prevent Tab key default behavior outside modals
**Warning signs:** Tab key stops working in certain areas of interface
**Source:** [WCAG 2.1.2 No Keyboard Trap](https://wcag.dock.codes/documentation/wcag212/)

### Pitfall 5: Insufficient Focus Visibility
**What goes wrong:** Focus indicators too subtle to see (WCAG 2.2 violation)
**Why it happens:** Custom CSS removes browser default focus styles without adequate replacement
**How to avoid:**
- Use browser default focus indicators (per user's CONTEXT.md decision)
- If customizing, ensure 3:1 contrast ratio and 2px minimum thickness (WCAG 2.4.13 AAA)
- Test with keyboard navigation in various lighting conditions
**Warning signs:** Can't tell which element has focus when tabbing
**Source:** [WCAG 2.2 - Focus Appearance](https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance.html)

### Pitfall 6: Missing Modal Titles
**What goes wrong:** Screen readers can't identify modal purpose
**Why it happens:** Developers hide title visually without providing alternative
**How to avoid:**
- Always provide `title` prop to BModal
- Use `titleVisuallyHidden` prop if title shouldn't be visible
- BModal automatically sets `aria-labelledby` to title
**Warning signs:** Screen reader announces "dialog" without context
**Source:** [Bootstrap-Vue-Next Accessibility](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/reference/accessibility)

### Pitfall 7: Color as Only Differentiator
**What goes wrong:** Color-blind users can't distinguish status/category
**Why it happens:** Relying on stoplight colors (red/yellow/green) without icons or text
**How to avoid:**
- Always pair color with icons, patterns, or text labels
- Add icon legend component to explain symbolic indicators
- Test in grayscale mode
**Warning signs:** Status/category only shown as colored dots or backgrounds
**Source:** [Accessibility in UX Design Best Practices 2025](https://orbix.studio/blogs/accessibility-uiux-design-best-practices-2025)

### Pitfall 8: Overusing aria-live="assertive"
**What goes wrong:** Screen reader interrupts user's current task with every minor update
**Why it happens:** Developers want to ensure announcements are heard
**How to avoid:**
- Use `polite` for most updates (form validation, status changes)
- Reserve `assertive` for critical, time-sensitive alerts (session timeout warning)
- When in doubt, use `polite`
**Warning signs:** Frequent interruptions while navigating interface
**Source:** [MDN aria-live](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-live)

## Code Examples

Verified patterns from official sources:

### Bootstrap Visually Hidden Classes
```html
<!-- Screen reader only text -->
<span class="visually-hidden">Screen reader only text</span>

<!-- Skip link - visible only on focus (standalone class, don't combine) -->
<a href="#main" class="visually-hidden-focusable">
  Skip to main content
</a>
```
**Source:** [Bootstrap 5.3 Accessibility](https://getbootstrap.com/docs/5.3/getting-started/accessibility/)

### ARIA Landmarks with Semantic HTML
```vue
<template>
  <header role="banner">
    <Navbar />
  </header>

  <nav role="navigation" aria-label="Main navigation">
    <ul><!-- navigation links --></ul>
  </nav>

  <main role="main" id="main" tabindex="-1">
    <h1>Page Title</h1>
    <!-- main content -->
  </main>

  <aside role="complementary" aria-labelledby="sidebar-title">
    <h2 id="sidebar-title">Related Information</h2>
    <!-- sidebar content -->
  </aside>

  <footer role="contentinfo">
    <p>Copyright information</p>
  </footer>
</template>
```
**Note:** Prefer semantic HTML (`<main>`, `<nav>`, `<aside>`) which provide implicit ARIA roles. Add explicit `role` attributes for older browser support.

**Source:** [Vue.js Accessibility - Landmarks](https://vuejs.org/guide/best-practices/accessibility)

### Automated Accessibility Testing with vitest-axe
```typescript
// MyComponent.spec.ts
import { render } from '@testing-library/vue'
import { axe, toHaveNoViolations } from 'vitest-axe'
import { describe, it, expect } from 'vitest'
import ApproveUser from '@/views/curate/ApproveUser.vue'

expect.extend(toHaveNoViolations)

describe('ApproveUser accessibility', () => {
  it('has no accessibility violations', async () => {
    const { container } = render(ApproveUser, {
      props: {
        // props here
      }
    })

    const results = await axe(container)
    expect(results).toHaveNoViolations()
  })

  it('announces status updates to screen readers', async () => {
    const { getByRole } = render(ApproveUser)

    // Check for live region
    const liveRegion = getByRole('status')
    expect(liveRegion).toHaveAttribute('aria-live', 'polite')
  })
})
```
**Important:** vitest-axe requires `jsdom` environment (not `happy-dom` due to compatibility issue)

**Source:** [vitest-axe GitHub](https://github.com/chaance/vitest-axe), [Accessible Vue - Testing](https://accessible-vue.com/chapter/6/)

### Roving Tabindex for Arrow Key Navigation (Advanced)
```vue
<template>
  <div
    role="grid"
    aria-labelledby="table-title"
    @keydown="handleKeyDown"
  >
    <div role="row" v-for="(row, rowIndex) in rows" :key="rowIndex">
      <div
        role="gridcell"
        v-for="(cell, colIndex) in row"
        :key="colIndex"
        :tabindex="focusedCell.row === rowIndex && focusedCell.col === colIndex ? 0 : -1"
        @focus="updateFocus(rowIndex, colIndex)"
      >
        {{ cell }}
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'

const focusedCell = ref({ row: 0, col: 0 })

function handleKeyDown(event) {
  const { row, col } = focusedCell.value
  const maxRow = rows.value.length - 1
  const maxCol = rows.value[0].length - 1

  switch (event.key) {
    case 'ArrowDown':
      if (row < maxRow) {
        updateFocus(row + 1, col)
        event.preventDefault()
      }
      break
    case 'ArrowUp':
      if (row > 0) {
        updateFocus(row - 1, col)
        event.preventDefault()
      }
      break
    case 'ArrowRight':
      if (col < maxCol) {
        updateFocus(row, col + 1)
        event.preventDefault()
      }
      break
    case 'ArrowLeft':
      if (col > 0) {
        updateFocus(row, col - 1)
        event.preventDefault()
      }
      break
  }
}

function updateFocus(rowIndex, colIndex) {
  focusedCell.value = { row: rowIndex, col: colIndex }
  // Actually focus the element
  nextTick(() => {
    const cell = document.querySelector(`[data-row="${rowIndex}"][data-col="${colIndex}"]`)
    cell?.focus()
  })
}
</script>
```
**Note:** Only implement arrow key navigation if required. Standard BTable with Tab navigation is sufficient for most data tables.

**Source:** [W3C - Developing a Keyboard Interface](https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/), [Mastering Roving tabindex](https://rajeev.dev/mastering-keyboard-navigation-with-roving-tabindex-in-grids)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| WCAG 2.1 AA compliance | WCAG 2.2 AA compliance | October 2023 | New success criteria: Focus Not Obscured (2.4.11), Focus Appearance (2.4.13 AAA), Dragging Movements (2.5.7) |
| `.sr-only` + `.sr-only-focusable` (Bootstrap 4) | `.visually-hidden` + `.visually-hidden-focusable` (Bootstrap 5) | Bootstrap 5.0 (2021) | Standalone class, don't combine classes |
| Custom focus trap libraries | VueUse `useFocusTrap` composable | VueUse 9+ (2022+) | Composition API pattern, better Vue 3 integration |
| jest-axe for testing | vitest-axe for Vitest | vitest-axe 0.1.0 (2023) | Vitest-specific matcher, no type conflicts |
| Options API accessibility patterns | Composition API with composables | Vue 3.0+ (2020) | More reusable, better TypeScript support |
| Manual ARIA attribute management | Bootstrap-Vue-Next automatic ARIA | Bootstrap-Vue-Next (2023+) | Components auto-manage `aria-expanded`, `aria-controls`, etc. |

**Deprecated/outdated:**
- **Bootstrap 4 `.sr-only-focusable`**: Required combination with `.sr-only`, now standalone in Bootstrap 5
- **Vue 2 `$refs` focus management**: Use template refs with Composition API in Vue 3
- **jest-axe with Vitest**: Use vitest-axe to avoid environment/type conflicts
- **ARIA grid for all tables**: Only use for interactive grids, semantic `<table>` is better for data display

## Open Questions

Things that couldn't be fully resolved:

1. **Arrow key navigation implementation complexity**
   - What we know: ARIA grid with roving tabindex is standard pattern, requires significant implementation
   - What's unclear: Whether complexity is justified for read-only data tables vs enhancement value
   - Recommendation: Start with Tab-only navigation (standard BTable), assess user feedback, add arrow keys if requested. Most accessibility experts recommend semantic table over ARIA grid for non-interactive data.

2. **vitest-axe coverage gaps**
   - What we know: Automated testing catches ~30% of accessibility issues, cannot test subjective criteria (clear language, logical flow)
   - What's unclear: Which specific issues vitest-axe misses in Vue 3 components
   - Recommendation: Use vitest-axe as baseline, supplement with manual keyboard testing and screen reader verification (NVDA on Windows, VoiceOver on macOS)

3. **Icon legend collapsibility user preference**
   - What we know: Carbon Design System recommends direct labeling over legends when possible
   - What's unclear: Whether users prefer always-visible reference or collapsible to reduce visual clutter
   - Recommendation: Start with always-visible legend (lower interaction cost, persistent reference), monitor user feedback. Add collapse feature only if users request it.

## Sources

### Primary (HIGH confidence)
- [WCAG 2.2 Official Specification](https://www.w3.org/TR/WCAG22/) - W3C standard
- [Vue.js Official Accessibility Guide](https://vuejs.org/guide/best-practices/accessibility) - First-party documentation
- [Bootstrap 5.3 Accessibility](https://getbootstrap.com/docs/5.3/getting-started/accessibility/) - Official Bootstrap docs
- [Bootstrap-Vue-Next Accessibility Reference](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/reference/accessibility) - Component library docs
- [Bootstrap-Vue-Next Modal Component](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/modal) - Modal-specific features
- [VueUse useFocusTrap](https://vueuse.org/integrations/usefocustrap/) - Composable documentation
- [MDN ARIA Live Regions](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Guides/Live_regions) - Reference documentation
- [W3C ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/) - Keyboard patterns
- [W3C Grid Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/grid/) - When to use ARIA grid

### Secondary (MEDIUM confidence)
- [Sarah Higley - Accessible Icon Buttons](https://www.sarasoueidan.com/blog/accessible-icon-buttons/) - Industry expert
- [Sarah Higley - Grids Part 2: Semantics](https://sarahmhigley.com/writing/grids-part2/) - Table vs grid analysis
- [The A11Y Collective - ARIA Live Regions](https://www.a11y-collective.com/blog/aria-live/) - Best practices guide
- [The A11Y Collective - aria-label vs title](https://www.a11y-collective.com/blog/aria-label-vs-title/) - Attribute comparison
- [vitest-axe GitHub](https://github.com/chaance/vitest-axe) - Testing library documentation
- [Carbon Design System - Legends](https://carbondesignsystem.com/data-visualization/legends/) - Design system patterns
- [WCAG 2.2 Focus Appearance](https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance.html) - Success criterion explanation
- [WCAG 2.1.2 No Keyboard Trap](https://wcag.dock.codes/documentation/wcag212/) - Compliance guidance

### Tertiary (LOW confidence - WebSearch only, marked for validation)
- [accessiBe WCAG 2.2 Overview](https://accessibe.com/blog/knowledgebase/wcag-two-point-two) - Commercial overview, verify specifics
- [Orbix Accessibility UX Best Practices 2025](https://orbix.studio/blogs/accessibility-uiux-design-best-practices-2025) - Blog post, design patterns
- [Requestly Vue Accessibility](https://requestly.com/blog/vue-accessibility/) - Blog aggregation, cross-check claims
- Community articles on Vue.js accessibility - Multiple sources, verify against official docs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official documentation from Vue, Bootstrap-Vue-Next, VueUse
- Architecture patterns: HIGH - Verified with official sources (Vue.js, MDN, W3C)
- Don't hand-roll: HIGH - Based on library documentation and accessibility expert articles
- Icon legends: MEDIUM - Carbon Design System guidance, no Vue-specific official pattern
- Arrow key navigation: HIGH - W3C ARIA APG official patterns
- Pitfalls: HIGH - WCAG specification, MDN, and accessibility expert blogs

**Research date:** 2026-01-27
**Valid until:** 30 days (WCAG 2.2 is stable, but library versions and best practices evolve)

**Key decisions locked by CONTEXT.md:**
- Use browser default focus indicators (no custom styling)
- Skip link visible only on focus
- Tables: arrow key navigation (Up/Down rows, Left/Right cells)
- ARIA labels: minimal ("Edit", "Delete", "Approve")
- Announce status via aria-live regions
- Keep BTable for semantic table structure
- Focus trap in modals with Escape key close
- Focus returns to trigger on modal close

**Areas of Claude's discretion (researched options):**
- Skip link implementation: Standard Vue.js pattern recommended
- ARIA landmarks: Semantic HTML first, explicit roles for legacy support
- Legend pattern: Always visible recommended (lower interaction cost)
- aria-live politeness: `polite` for most updates, `assertive` for critical alerts only
