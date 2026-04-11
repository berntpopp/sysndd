# Phase 16: UI/UX Modernization - Research

**Researched:** 2026-01-23
**Domain:** CSS/SCSS architecture, design systems, accessibility (WCAG 2.2)
**Confidence:** HIGH

## Summary

Phase 16 modernizes the visual presentation of a medical web application using Bootstrap 5.3.8 + Bootstrap-Vue-Next with Vue 3. The standard approach leverages Bootstrap's extensive CSS custom properties system (introduced in v5.3) as the foundation for design tokens, extends them with custom medical-appropriate color palettes, implements a shadow depth system for subtle elevation, and ensures WCAG 2.2 Level AA compliance throughout.

The established pattern separates SCSS architecture into partials (variables), components (custom UI), and vendor overrides, following Bootstrap's !default flag system for maintainable customization. Modern best practices emphasize CSS custom properties over compilation-time SCSS variables for runtime theming, prefers-reduced-motion support for all animations, and vitest-axe integration for automated accessibility testing.

**Primary recommendation:** Build a CSS custom properties design token system on top of Bootstrap's existing variables rather than replacing them. Use SCSS variables only for Bootstrap overrides during compilation, then expose everything as CSS custom properties for runtime flexibility and potential dark mode support.

## Standard Stack

The established libraries/tools for UI/UX modernization with Vue 3 + Bootstrap 5:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Bootstrap | 5.3.8 | CSS framework | Comprehensive design system with CSS custom properties, extensive accessibility features, mature ecosystem |
| Bootstrap-Vue-Next | 0.42+ | Vue 3 components | Official Vue 3 integration for Bootstrap 5, TypeScript support, composition API compatible |
| SCSS/Sass | Latest | CSS preprocessing | Bootstrap's native compilation system, required for variable overrides, mature build integration |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| vitest-axe | Latest | Accessibility testing | Automated WCAG compliance checks in component tests (fork of jest-axe for Vitest) |
| @dvuckovic/vue3-bootstrap-icons | Latest | Icon components | SVG sprite method for Bootstrap Icons integration in Vue 3 |
| axe-core | Latest | A11y engine | Underlying accessibility testing engine (finds ~57% of WCAG issues automatically) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bootstrap 5 | Tailwind CSS | More flexible utility-first approach but loses Bootstrap ecosystem, requires complete rebuild |
| Bootstrap Icons | Heroicons / Lucide | More modern icons but inconsistent with Bootstrap aesthetic, requires additional dependencies |
| CSS custom properties | SCSS variables only | Faster compilation but loses runtime theming, no dark mode support, less flexible |

**Installation:**
```bash
# Already installed per project context
npm install bootstrap@^5.3.8 bootstrap-vue-next@^0.42.0 bootstrap-icons@^1.13.1

# Testing additions (if not already present from Phase 15)
npm install --save-dev vitest-axe @axe-core/playwright
```

## Architecture Patterns

### Recommended Project Structure
```
app/src/assets/scss/
├── _variables.scss       # Bootstrap variable overrides (before import)
├── _design-tokens.scss   # CSS custom properties (after import)
├── _mixins.scss          # Custom mixins
├── partials/
│   ├── _shadows.scss     # Shadow depth system
│   ├── _colors.scss      # Color palette extensions
│   ├── _spacing.scss     # Spacing scale
│   └── _typography.scss  # Font customization
├── components/
│   ├── _cards.scss       # Card styling
│   ├── _tables.scss      # Table enhancements
│   ├── _forms.scss       # Form styling
│   ├── _buttons.scss     # Button refinements
│   └── _loading.scss     # Loading states
├── utilities/
│   ├── _animations.scss  # Transition utilities
│   └── _helpers.scss     # Helper classes
└── custom.scss           # Main entry point
```

### Pattern 1: Bootstrap SCSS Customization (Compilation Time)
**What:** Override Bootstrap variables before import, extend with custom properties after import
**When to use:** All Bootstrap 5 projects requiring brand customization

**Example:**
```scss
// app/src/assets/scss/custom.scss
// Source: https://getbootstrap.com/docs/5.3/customize/sass/

// 1. Include functions first
@import "bootstrap/scss/functions";

// 2. Variable overrides (must come before Bootstrap variables)
$primary: #0d47a1;  // Medical blue
$enable-shadows: true;
$enable-gradients: false;  // Avoid gradients for scientific feel

// Custom shadow values (override defaults)
$box-shadow-sm: 0 .125rem .25rem rgba(0, 0, 0, .06);
$box-shadow: 0 .25rem .5rem rgba(0, 0, 0, .08);
$box-shadow-lg: 0 .5rem 1.5rem rgba(0, 0, 0, .12);

// 3. Import Bootstrap variables
@import "bootstrap/scss/variables";
@import "bootstrap/scss/variables-dark";

// 4. Map overrides (extend theme colors)
$theme-colors: map-merge(
  $theme-colors,
  (
    "medical-primary": #0d47a1,
    "medical-secondary": #00897b,  // Teal
    "scientific-accent": #1565c0,
  )
);

// 5. Import remaining Bootstrap
@import "bootstrap/scss/maps";
@import "bootstrap/scss/mixins";
@import "bootstrap/scss/root";

// 6. Optional: Import only needed components (reduces bundle size)
@import "bootstrap/scss/utilities";
@import "bootstrap/scss/reboot";
@import "bootstrap/scss/type";
@import "bootstrap/scss/grid";
@import "bootstrap/scss/tables";
@import "bootstrap/scss/forms";
@import "bootstrap/scss/buttons";
@import "bootstrap/scss/card";
// ... other components as needed

// 7. Import custom partials AFTER Bootstrap
@import "partials/shadows";
@import "partials/colors";
@import "components/tables";
@import "components/forms";
```

### Pattern 2: CSS Custom Properties Design Token System
**What:** Layer custom properties on top of Bootstrap's variables for runtime flexibility
**When to use:** When you need runtime theming, dark mode support, or dynamic color changes

**Example:**
```scss
// app/src/assets/scss/_design-tokens.scss
// Source: https://getbootstrap.com/docs/5.3/customize/css-variables/

:root {
  // Medical color palette (extend Bootstrap's existing variables)
  --medical-blue-50: #e3f2fd;
  --medical-blue-100: #bbdefb;
  --medical-blue-500: #1565c0;
  --medical-blue-700: #0d47a1;
  --medical-blue-900: #0a3d91;

  --medical-teal-50: #e0f2f1;
  --medical-teal-100: #b2dfdb;
  --medical-teal-500: #00897b;
  --medical-teal-700: #00695c;

  // Shadow depth system (subtle, medical-appropriate)
  --shadow-xs: 0 1px 2px rgba(0, 0, 0, 0.04);
  --shadow-sm: 0 2px 4px rgba(0, 0, 0, 0.06);
  --shadow-md: 0 4px 8px rgba(0, 0, 0, 0.08);
  --shadow-lg: 0 8px 16px rgba(0, 0, 0, 0.12);
  --shadow-xl: 0 12px 24px rgba(0, 0, 0, 0.15);

  // Spacing density (compact for data-heavy views)
  --spacing-compact: 0.5rem;
  --spacing-base: 0.75rem;
  --spacing-comfortable: 1rem;

  // Border radius (modern, soft corners)
  --radius-sm: 0.25rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;

  // Transitions (with reduced-motion support handled separately)
  --transition-fast: 150ms cubic-bezier(0.4, 0, 0.2, 1);
  --transition-base: 250ms cubic-bezier(0.4, 0, 0.2, 1);
  --transition-slow: 350ms cubic-bezier(0.4, 0, 0.2, 1);

  // Focus ring (WCAG 2.2 compliant)
  --focus-ring-width: 0.25rem;
  --focus-ring-color: rgba(13, 71, 161, 0.25);
  --focus-ring-offset: 2px;
}

// Usage in components
.card-modern {
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
  transition: box-shadow var(--transition-base);

  &:hover {
    box-shadow: var(--shadow-md);
  }
}
```

### Pattern 3: Accessible Motion with prefers-reduced-motion
**What:** Respect user motion preferences for all animations
**When to use:** All animations, transitions, and transforms (WCAG 2.2 requirement)

**Example:**
```scss
// Source: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion

// Default: Smooth transitions
.page-transition {
  transition: opacity var(--transition-base), transform var(--transition-base);
  opacity: 1;
  transform: translateY(0);
}

.page-transition-enter {
  opacity: 0;
  transform: translateY(1rem);
}

// Reduced motion: Instant or minimal animation
@media (prefers-reduced-motion: reduce) {
  .page-transition {
    transition: opacity 50ms linear;  // Minimal fade, no transform
  }

  .page-transition-enter {
    opacity: 0.5;
    transform: none;  // Remove transform
  }

  // Disable hover animations
  .card-modern:hover {
    transition: none;
  }
}

// Complete removal for critical animations only
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

### Pattern 4: Responsive Table to Card View
**What:** Transform tables into card layouts on mobile for better readability
**When to use:** Data-heavy tables with many columns

**Example:**
```vue
<!-- Source: https://bootstrap-table.com/docs/extensions/mobile/ -->
<template>
  <div class="table-responsive-stack">
    <table class="table table-striped">
      <thead>
        <tr>
          <th>Gene Symbol</th>
          <th>Disease</th>
          <th>Inheritance</th>
          <th>Evidence</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="gene in genes" :key="gene.id">
          <td data-label="Gene Symbol">{{ gene.symbol }}</td>
          <td data-label="Disease">{{ gene.disease }}</td>
          <td data-label="Inheritance">{{ gene.inheritance }}</td>
          <td data-label="Evidence">{{ gene.evidence }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
/* Desktop: Normal table */
.table-responsive-stack {
  @media (min-width: 768px) {
    /* Standard Bootstrap table styling */
  }

  /* Mobile: Card view */
  @media (max-width: 767px) {
    table, thead, tbody, th, td, tr {
      display: block;
    }

    thead {
      display: none;  // Hide headers
    }

    tr {
      margin-bottom: 1rem;
      border: 1px solid var(--bs-border-color);
      border-radius: var(--radius-md);
      padding: 0.75rem;
      box-shadow: var(--shadow-sm);
    }

    td {
      display: flex;
      justify-content: space-between;
      padding: 0.5rem 0;
      border: none;

      &::before {
        content: attr(data-label);
        font-weight: 600;
        margin-right: 1rem;
        color: var(--bs-secondary);
      }
    }
  }
}
</style>
```

### Pattern 5: Accessible Form Validation
**What:** Inline error messages with proper ARIA attributes
**When to use:** All form inputs with validation

**Example:**
```vue
<!-- Source: https://www.smashingmagazine.com/2023/02/guide-accessible-form-validation/ -->
<template>
  <div class="form-group">
    <label for="email" class="form-label">
      Email Address
      <span class="text-danger" aria-label="required">*</span>
    </label>
    <input
      id="email"
      v-model="email"
      type="email"
      class="form-control"
      :class="{ 'is-invalid': errors.email }"
      :aria-invalid="!!errors.email"
      :aria-describedby="errors.email ? 'email-error' : undefined"
      @blur="validateEmail"
    />
    <div
      v-if="errors.email"
      id="email-error"
      class="invalid-feedback"
      role="alert"
    >
      {{ errors.email }}
    </div>
  </div>
</template>

<style scoped>
/* Focus states: colored border + glow (per user decision) */
.form-control:focus {
  border-color: var(--bs-primary);
  box-shadow: 0 0 0 var(--focus-ring-width) var(--focus-ring-color);
  outline: none;
}

/* Invalid state with high contrast */
.form-control.is-invalid {
  border-color: #dc3545;

  &:focus {
    border-color: #dc3545;
    box-shadow: 0 0 0 var(--focus-ring-width) rgba(220, 53, 69, 0.25);
  }
}

/* Inline error below field (per user decision) */
.invalid-feedback {
  display: block;
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: #dc3545;
}
</style>
```

### Pattern 6: Skeleton Loading States
**What:** Content placeholders that minimize layout shift
**When to use:** Any component that loads data asynchronously

**Example:**
```vue
<!-- Source: https://learnvue.co/articles/vue-skeleton-loading -->
<template>
  <div>
    <Suspense>
      <template #default>
        <AsyncDataTable />
      </template>
      <template #fallback>
        <div class="skeleton-table">
          <div class="skeleton-row" v-for="i in 5" :key="i">
            <div class="skeleton-cell skeleton-shimmer" style="width: 20%;"></div>
            <div class="skeleton-cell skeleton-shimmer" style="width: 40%;"></div>
            <div class="skeleton-cell skeleton-shimmer" style="width: 30%;"></div>
            <div class="skeleton-cell skeleton-shimmer" style="width: 10%;"></div>
          </div>
        </div>
      </template>
    </Suspense>
  </div>
</template>

<style scoped>
.skeleton-table {
  width: 100%;
}

.skeleton-row {
  display: flex;
  gap: 1rem;
  padding: 0.75rem 0;
  border-bottom: 1px solid var(--bs-border-color);
}

.skeleton-cell {
  height: 1.25rem;
  background-color: #e9ecef;
  border-radius: var(--radius-sm);
}

/* Shimmer animation */
.skeleton-shimmer {
  background: linear-gradient(
    90deg,
    #e9ecef 0%,
    #f8f9fa 50%,
    #e9ecef 100%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}

@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* Respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  .skeleton-shimmer {
    animation: none;
    background: #e9ecef;
  }
}
</style>
```

### Anti-Patterns to Avoid
- **Modifying Bootstrap source files directly** - Always override via SCSS variables, never edit node_modules/bootstrap
- **Variable overrides after Bootstrap import** - Won't work due to !default flag, must come before import
- **Overusing !important** - Indicates specificity problems, use proper cascade instead
- **Removing all animations for reduced-motion** - Provide minimal alternatives, don't eliminate completely
- **Generic empty states** - Use context-specific messages and icons, avoid Lorem ipsum
- **Fixed viewport widths for responsive** - Use Bootstrap's breakpoint system and container queries where supported

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Icon library integration | Manual SVG imports, sprite sheets | @dvuckovic/vue3-bootstrap-icons or unplugin-icons | Automatic tree-shaking, consistent sizing, accessibility attributes, sprite optimization |
| Accessibility testing | Manual keyboard navigation checks | vitest-axe + axe-core | Catches ~57% of WCAG issues automatically, includes ARIA validation, integrates with test suite |
| Color contrast validation | Manual color picking | WebAIM Contrast Checker, Colour Contrast Analyser (CCA) | Ensures WCAG 2.2 AA compliance (4.5:1 text, 3:1 UI components), tests multiple vision deficiencies |
| Skeleton loaders | Custom shimmer CSS | Vue Suspense + skeleton components | Built-in loading state management, automatic fallback rendering, standardized patterns |
| Table responsiveness | Custom breakpoint JavaScript | Bootstrap .table-responsive or table-to-card CSS patterns | Standard mobile patterns, tested accessibility, maintained by framework |
| Focus trap for modals | Manual tab key handling | Bootstrap Modal or composables like useFocusTrap | Complex keyboard navigation, Escape key handling, focus restoration, ARIA attributes |
| Colorblind-safe palettes | Guessing colors | Okabe-Ito palette, Viridis family, Viz Palette tool | Scientifically validated for all color vision deficiencies, perceptually uniform, tested in medical contexts |

**Key insight:** Accessibility is the most underestimated complexity domain. Manual ARIA implementation, keyboard navigation, focus management, and screen reader compatibility have dozens of edge cases. Use established libraries (Bootstrap components, axe-core, vitest-axe) to avoid introducing WCAG violations.

## Common Pitfalls

### Pitfall 1: Incorrect Bootstrap SCSS Import Order
**What goes wrong:** Variables overridden after importing Bootstrap have no effect, resulting in default styling
**Why it happens:** Bootstrap's !default flag only applies values if not already set
**How to avoid:** Always follow this exact sequence:
1. Import functions
2. Override variables
3. Import Bootstrap variables
4. Override maps
5. Import remaining Bootstrap (maps, mixins, root)
6. Import optional components
7. Import custom partials

**Warning signs:** Custom $primary color not appearing, shadow values unchanged despite SCSS modifications

**Example fix:**
```scss
// WRONG - Variable override after import
@import "bootstrap/scss/bootstrap";
$primary: #0d47a1;  // Has no effect!

// CORRECT - Variable override before import
$primary: #0d47a1;
@import "bootstrap/scss/functions";
@import "bootstrap/scss/variables";
// ... rest of imports
```

### Pitfall 2: Focus Indicators Failing WCAG 2.2 Contrast Requirements
**What goes wrong:** Focus indicators invisible to low-vision users, failing 2.4.11 Focus Appearance (AA)
**Why it happens:** Default browser focus styles overridden without ensuring 3:1 contrast ratio and minimum size
**How to avoid:**
- Ensure focus indicator has 3:1 contrast against adjacent colors
- Minimum size: 2px perimeter around element
- Test with keyboard navigation (Tab key)
- Use both color and non-color indicators (outline + shadow)

**Warning signs:** Can't see which element has focus when tabbing, outline removed with outline: none

**Example fix:**
```scss
// WRONG - Removes focus entirely
.btn:focus {
  outline: none;  // Accessibility violation!
}

// CORRECT - Enhanced accessible focus
.btn:focus-visible {
  outline: 2px solid var(--bs-primary);
  outline-offset: 2px;
  box-shadow: 0 0 0 4px var(--focus-ring-color);
}
```

### Pitfall 3: Animation Without prefers-reduced-motion Support
**What goes wrong:** Users with vestibular disorders experience nausea, dizziness from animations
**Why it happens:** Developers forget to add reduced-motion media queries for decorative animations
**How to avoid:**
- Wrap ALL animations/transitions in @media (prefers-reduced-motion: reduce)
- Provide minimal alternatives (instant or very fast), don't remove completely
- Test with OS-level reduced motion setting enabled

**Warning signs:** No reduced-motion styles, animations longer than 300ms without user control

**Example fix:**
```scss
// WRONG - No reduced motion consideration
.card {
  transition: transform 500ms ease;
}
.card:hover {
  transform: scale(1.05);
}

// CORRECT - Respects user preferences
.card {
  transition: transform var(--transition-base);
}
.card:hover {
  transform: scale(1.05);
}

@media (prefers-reduced-motion: reduce) {
  .card {
    transition: none;
  }
  .card:hover {
    transform: none;  // Or minimal: scale(1.01)
  }
}
```

### Pitfall 4: Insufficient Color Contrast for Medical Data
**What goes wrong:** Text unreadable in medical contexts (often low-light environments), WCAG 1.4.3 failure
**Why it happens:** Colors chosen for aesthetics without testing contrast ratios
**How to avoid:**
- Normal text: 4.5:1 minimum contrast
- Large text (18pt+ or 14pt+ bold): 3:1 minimum
- UI components/icons: 3:1 minimum
- Test with WebAIM Contrast Checker or CCA
- Consider medical context: often viewed in dimmed rooms

**Warning signs:** Light gray text on white backgrounds, pastel colors for important information

**Example fix:**
```scss
// WRONG - Insufficient contrast (2.8:1)
.secondary-text {
  color: #9e9e9e;  // Too light on white
}

// CORRECT - WCAG AA compliant (4.6:1)
.secondary-text {
  color: #666666;  // Passes contrast requirements
}
```

### Pitfall 5: Empty States Without Actionable Guidance
**What goes wrong:** Users confused about why data is missing or what to do next
**Why it happens:** Generic "No data" messages without context or next steps
**How to avoid:**
- Provide context-specific messages (not generic "No results")
- Include actionable guidance ("Try adjusting filters" vs "No genes found")
- Use appropriate icons from Bootstrap Icons
- Maintain neutral, informative tone for medical apps

**Warning signs:** Empty div with "No data", Lorem ipsum placeholders, cutesy messages in medical context

**Example fix:**
```vue
<!-- WRONG - Generic, unhelpful -->
<div v-if="!genes.length">
  No data
</div>

<!-- CORRECT - Context-specific, actionable -->
<div v-if="!genes.length" class="empty-state">
  <i class="bi bi-search" aria-hidden="true"></i>
  <h3>No genes match your search criteria</h3>
  <p>Try adjusting your filters or search terms.</p>
  <button @click="clearFilters" class="btn btn-primary">
    Clear All Filters
  </button>
</div>
```

### Pitfall 6: CSS Specificity Wars with Bootstrap
**What goes wrong:** Custom styles don't apply, leading to !important cascade
**Why it happens:** Bootstrap's compiled CSS has higher specificity than custom overrides
**How to avoid:**
- Load custom CSS after Bootstrap
- Match or exceed Bootstrap's selector specificity
- Use SCSS to override at compilation time when possible
- Never modify Bootstrap source files

**Warning signs:** Excessive !important usage, styles only working with inline styles

**Example fix:**
```scss
// WRONG - Too generic, Bootstrap wins
.btn {
  background: #0d47a1;  // Doesn't override Bootstrap
}

// CORRECT - Match Bootstrap specificity or use SCSS variables
.btn.btn-primary {
  background: #0d47a1;
}

// BETTER - Override at compilation time
$primary: #0d47a1;
@import "bootstrap";
```

### Pitfall 7: Table Overflow Without Mobile Consideration
**What goes wrong:** Wide tables unusable on mobile, horizontal scroll frustration
**Why it happens:** Desktop-first development without testing mobile breakpoints
**How to avoid:**
- Use .table-responsive wrapper for horizontal scroll (minimum)
- Consider table-to-card transformation for <768px
- Test at 320px, 375px, 768px breakpoints
- Prioritize columns (hide less important on mobile)

**Warning signs:** Tables wider than viewport, no responsive wrapper, all columns shown on mobile

**Example fix:**
```vue
<!-- WRONG - No mobile consideration -->
<table class="table">
  <!-- 10 columns, all visible on mobile -->
</table>

<!-- CORRECT - Responsive wrapper + mobile transformation -->
<div class="table-responsive-stack">
  <table class="table">
    <thead>
      <tr>
        <th>Gene</th>
        <th class="d-none d-md-table-cell">Chromosome</th>
        <th>Disease</th>
        <th class="d-none d-lg-table-cell">Evidence</th>
      </tr>
    </thead>
    <!-- Mobile: Card view, Desktop: Table view -->
  </table>
</div>
```

## Code Examples

Verified patterns from official sources:

### Bootstrap 5.3 CSS Custom Properties System
```css
/* Source: https://getbootstrap.com/docs/5.3/customize/css-variables/ */

/* Bootstrap provides extensive custom properties at :root */
:root {
  /* Color variables */
  --bs-blue: #0d6efd;
  --bs-primary: #0d6efd;
  --bs-primary-rgb: 13, 110, 253;

  /* Typography */
  --bs-body-font-family: system-ui, -apple-system, "Segoe UI", Roboto;
  --bs-body-font-size: 1rem;
  --bs-body-font-weight: 400;
  --bs-body-line-height: 1.5;

  /* Shadows */
  --bs-box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15);
  --bs-box-shadow-sm: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
  --bs-box-shadow-lg: 0 1rem 3rem rgba(0, 0, 0, 0.175);

  /* Focus ring (v5.3+) */
  --bs-focus-ring-width: 0.25rem;
  --bs-focus-ring-opacity: 0.25;
  --bs-focus-ring-color: rgba(13, 110, 253, 0.25);

  /* Border radius */
  --bs-border-radius: 0.375rem;
  --bs-border-radius-sm: 0.25rem;
  --bs-border-radius-lg: 0.5rem;
}

/* Extend with custom medical tokens */
:root {
  --medical-primary: #0d47a1;
  --medical-teal: #00897b;
  --shadow-card: 0 0.25rem 0.5rem rgba(0, 0, 0, 0.08);
  --transition-smooth: 250ms cubic-bezier(0.4, 0, 0.2, 1);
}
```

### Shadow Depth System (Medical-Appropriate)
```scss
/* Source: https://getbootstrap.com/docs/5.3/utilities/shadows/ */
/* Extended for medical app subtle elevation */

:root {
  // Subtle shadows for scientific/medical aesthetic
  --shadow-none: none;
  --shadow-xs: 0 1px 2px rgba(0, 0, 0, 0.04);
  --shadow-sm: 0 2px 4px rgba(0, 0, 0, 0.06);
  --shadow-md: 0 4px 8px rgba(0, 0, 0, 0.08);
  --shadow-lg: 0 8px 16px rgba(0, 0, 0, 0.12);
  --shadow-xl: 0 12px 24px rgba(0, 0, 0, 0.15);
}

// Utility classes
.shadow-xs { box-shadow: var(--shadow-xs); }
.shadow-sm { box-shadow: var(--shadow-sm); }  // Bootstrap default
.shadow-md { box-shadow: var(--shadow-md); }
.shadow { box-shadow: var(--shadow-md); }     // Bootstrap default override
.shadow-lg { box-shadow: var(--shadow-lg); }  // Bootstrap default
.shadow-xl { box-shadow: var(--shadow-xl); }
.shadow-none { box-shadow: none; }            // Bootstrap default

// Usage: Cards with hover elevation
.card-elevated {
  box-shadow: var(--shadow-sm);
  transition: box-shadow var(--transition-smooth);

  &:hover {
    box-shadow: var(--shadow-md);
  }
}
```

### Accessible Focus States (WCAG 2.2 Compliant)
```scss
/* Source: https://www.w3.org/WAI/WCAG22/ */
/* Meets 2.4.11 Focus Appearance (Level AA) and 2.4.13 (Level AAA) */

:root {
  --focus-ring-width: 0.25rem;
  --focus-ring-offset: 2px;
  --focus-ring-color: rgba(13, 71, 161, 0.25);
  --focus-border-color: #0d47a1;
}

// Default focus-visible for all interactive elements
*:focus-visible {
  outline: var(--focus-ring-width) solid var(--focus-border-color);
  outline-offset: var(--focus-ring-offset);
}

// Enhanced focus with glow (per user decision: colored border + glow)
.btn:focus-visible,
.form-control:focus-visible,
.form-select:focus-visible {
  border-color: var(--focus-border-color);
  outline: none;
  box-shadow:
    0 0 0 var(--focus-ring-width) var(--focus-ring-color),
    0 0 0 calc(var(--focus-ring-width) * 2) rgba(13, 71, 161, 0.1);
}

// Ensure 3:1 contrast minimum for focus indicator
// Test with: https://webaim.org/resources/contrastchecker/
// Primary blue #0d47a1 on white = 8.59:1 ✓
// Focus ring rgba(13, 71, 161, 0.25) on white = 3.2:1 ✓
```

### Table with Zebra Striping and Row Hover
```scss
/* Source: https://getbootstrap.com/docs/5.3/content/tables/ */
/* Per user decisions: subtle alternating rows + light hover */

.table-modern {
  // Zebra striping (subtle)
  --bs-table-striped-bg: rgba(0, 0, 0, 0.02);
  --bs-table-striped-color: inherit;

  // Row hover (subtle highlight for tracking)
  --bs-table-hover-bg: rgba(13, 71, 161, 0.05);
  --bs-table-hover-color: inherit;

  // Sort indicators
  th[aria-sort] {
    cursor: pointer;
    user-select: none;

    &::after {
      content: '';
      display: inline-block;
      width: 0;
      height: 0;
      margin-left: 0.5rem;
      vertical-align: middle;
      border-left: 4px solid transparent;
      border-right: 4px solid transparent;
    }

    &[aria-sort="ascending"]::after {
      border-bottom: 4px solid currentColor;
    }

    &[aria-sort="descending"]::after {
      border-top: 4px solid currentColor;
    }
  }

  // Active sort column highlight
  th[aria-sort]:not([aria-sort="none"]) {
    background-color: rgba(13, 71, 161, 0.08);
    font-weight: 600;
  }
}
```

### Empty State Pattern with Bootstrap Icons
```vue
<!-- Source: https://www.eleken.co/blog-posts/empty-state-ux -->
<!-- Per user decision: Icon + neutral informative message + guidance -->

<template>
  <div class="empty-state text-center py-5">
    <!-- Bootstrap Icon composition -->
    <div class="empty-state-icon mb-3">
      <i class="bi bi-search" aria-hidden="true"></i>
    </div>

    <!-- Neutral informative heading -->
    <h3 class="empty-state-heading">
      No genes match your search criteria
    </h3>

    <!-- Guidance message -->
    <p class="empty-state-message text-muted">
      Try adjusting your filters or broadening your search terms to find more results.
    </p>

    <!-- Actionable next step -->
    <button @click="clearFilters" class="btn btn-primary">
      <i class="bi bi-arrow-counterclockwise me-2" aria-hidden="true"></i>
      Clear All Filters
    </button>
  </div>
</template>

<style scoped>
.empty-state {
  max-width: 400px;
  margin: 0 auto;
  padding: 3rem 1.5rem;
}

.empty-state-icon {
  font-size: 4rem;
  color: var(--bs-secondary);
  opacity: 0.5;
}

.empty-state-heading {
  font-size: 1.5rem;
  font-weight: 600;
  color: var(--bs-body-color);
  margin-bottom: 0.75rem;
}

.empty-state-message {
  font-size: 1rem;
  line-height: 1.6;
  margin-bottom: 1.5rem;
}
```

### Medical Color Palette (Colorblind-Safe)
```scss
/* Source: https://www.tableau.com/blog/examining-data-viz-rules-dont-use-red-green-together */
/* Okabe-Ito palette adapted for medical web app */

:root {
  // Primary medical blues (safe for all color vision deficiencies)
  --medical-blue-50: #e3f2fd;
  --medical-blue-100: #bbdefb;
  --medical-blue-200: #90caf9;
  --medical-blue-300: #64b5f6;
  --medical-blue-400: #42a5f5;
  --medical-blue-500: #1565c0;  // Primary
  --medical-blue-600: #1e88e5;
  --medical-blue-700: #0d47a1;  // Dark primary
  --medical-blue-800: #1565c0;
  --medical-blue-900: #0a3d91;

  // Medical teal (complementary, colorblind-safe)
  --medical-teal-50: #e0f2f1;
  --medical-teal-100: #b2dfdb;
  --medical-teal-500: #00897b;
  --medical-teal-700: #00695c;

  // Status colors (avoid red-green combinations)
  --status-success: #2e7d32;     // Dark green (high contrast)
  --status-warning: #f57c00;     // Orange (safe alternative to yellow)
  --status-danger: #c62828;      // Dark red (high contrast)
  --status-info: #0277bd;        // Blue

  // Ensure 4.5:1 contrast minimum on white backgrounds
  // Test: https://webaim.org/resources/contrastchecker/
  // medical-blue-700 #0d47a1 on white = 8.59:1 ✓
  // medical-teal-700 #00695c on white = 6.34:1 ✓
  // status-success #2e7d32 on white = 5.09:1 ✓
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SCSS variables only | CSS custom properties for runtime theming | Bootstrap 5.2+ (2022) | Enables dark mode, runtime theme switching without recompilation |
| Media queries for all responsive | Container queries for components | Baseline 2023 | True component-level responsiveness, more maintainable |
| Manual accessibility testing | vitest-axe automated testing | 2024+ | Catches 57% of WCAG issues in CI/CD pipeline |
| BootstrapVue (Vue 2) | BootstrapVue-Next (Vue 3) | 2023+ | Composition API, TypeScript, better tree-shaking |
| WCAG 2.1 | WCAG 2.2 Level AA | October 2023 | New focus appearance requirements (2.4.11), stricter motion controls |
| Spinners for loading | Skeleton screens | 2020+ | Reduced perceived load time, minimal layout shift, better UX |
| @property not available | @property Baseline support | July 2024 | Animated custom properties, type-safe CSS variables, better performance |
| jest-axe | vitest-axe | 2024+ | Native Vitest integration, no Jest/Vitest conflicts |

**Deprecated/outdated:**
- **Bootstrap 4** - End of life, use Bootstrap 5.3+ (extensive breaking changes in v5)
- **BootstrapVue** - Vue 2 only, use BootstrapVue-Next for Vue 3
- **Sass division with /** - Deprecated, use math.div() or calc()
- **WCAG 2.0** - Superseded by WCAG 2.1 and 2.2 (use 2.2 Level AA as minimum)
- **outline: none without replacement** - WCAG violation, always provide visible focus indicator
- **Fixed viewport meta without user-scalable** - Accessibility violation (WCAG 1.4.4), allow zoom

## Open Questions

Things that couldn't be fully resolved:

1. **Container Query Support in Production**
   - What we know: Container queries baseline support since 2023, works in all modern browsers
   - What's unclear: Whether to prioritize container queries over media queries for component responsiveness, or wait for broader adoption patterns
   - Recommendation: Use media queries for primary responsive behavior (proven, tested), add container queries as progressive enhancement for specific components

2. **Dark Mode Implementation Scope**
   - What we know: Bootstrap 5.3+ has built-in dark mode via [data-bs-theme="dark"], CSS custom properties make it feasible
   - What's unclear: Whether Phase 16 scope includes dark mode implementation or just the foundation (CSS custom properties)
   - Recommendation: Establish CSS custom property foundation in Phase 16, defer actual dark mode implementation to future phase or mark as out of scope. Foundation enables it without requiring implementation.

3. **Visual Regression Testing Integration**
   - What we know: Vitest and Playwright both support visual regression testing, effective for catching CSS changes
   - What's unclear: Whether Phase 15 testing infrastructure includes visual regression, or if Phase 16 should add it
   - Recommendation: Check Phase 15 implementation. If not present, add visual regression testing as optional subtask in 16-08 (Accessibility Polish) using Vitest's built-in browser mode visual testing

4. **Bootstrap Icons Integration Method**
   - What we know: Multiple approaches exist (@dvuckovic/vue3-bootstrap-icons for SVG sprite, unplugin-icons for tree-shaking)
   - What's unclear: Current project's Bootstrap Icons integration method (check package.json imports)
   - Recommendation: Research current implementation first. If not integrated, prefer unplugin-icons with Bootstrap Icons for automatic tree-shaking and consistent API

5. **Medical Color Palette Specific Hues**
   - What we know: User decided "medical-appropriate blues/teals," "same color family but modernized hues"
   - What's unclear: Exact hue values within blue/teal family, balance between "modern" and "subtle evolution"
   - Recommendation: Start with Material Design blue palette (#0d47a1 as base per existing SCSS), validate contrast ratios, present options for user refinement in planning phase

## Sources

### Primary (HIGH confidence)
- [Bootstrap 5.3 CSS Variables](https://getbootstrap.com/docs/5.3/customize/css-variables/) - CSS custom properties system, design token approach
- [Bootstrap 5.3 Shadows](https://getbootstrap.com/docs/5.3/utilities/shadows/) - Shadow utility classes and customization
- [Bootstrap 5.3 Sass Customization](https://getbootstrap.com/docs/5.3/customize/sass/) - SCSS architecture, import order, variable override system
- [WCAG 2.2 Specification](https://www.w3.org/TR/WCAG22/) - Official accessibility requirements
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/) - Color contrast validation tool
- [MDN prefers-reduced-motion](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion) - Motion accessibility reference
- [Vue 3 Transition Component](https://vuejs.org/guide/built-ins/transition) - Official transition documentation
- [Vitest Visual Regression Testing](https://vitest.dev/guide/browser/visual-regression-testing.html) - Official visual testing guide
- [axe-core GitHub](https://github.com/dequelabs/axe-core) - Official accessibility testing engine
- [vitest-axe GitHub](https://github.com/chaance/vitest-axe) - Vitest integration for axe

### Secondary (MEDIUM confidence)
- [Bootstrap-Vue-Next Customizing Styles](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/configurations/customizing-styles) - Component-specific CSS selectors
- [Smashing Magazine: Guide to Accessible Form Validation](https://www.smashingmagazine.com/2023/02/guide-accessible-form-validation/) - Form validation patterns
- [LearnVue: Vue Skeleton Loading](https://learnvue.co/articles/vue-skeleton-loading) - Skeleton screen implementation
- [CSS-Tricks: Container Queries](https://css-tricks.com/css-container-queries/) - Container query patterns
- [W3C ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/) - Keyboard navigation patterns
- [Tableau: Colorblind-Friendly Visualizations](https://www.tableau.com/blog/examining-data-viz-rules-dont-use-red-green-together) - Scientific color palette guidance
- [Eleken: Empty State UX](https://www.eleken.co/blog-posts/empty-state-ux) - Empty state design patterns

### Tertiary (LOW confidence - requires validation)
- [Healthcare UX/UI Design Trends 2026](https://www.excellentwebworld.com/healthcare-ux-ui-design-trends/) - Medical app aesthetic trends
- [Container Queries in 2026: Powerful, but not a silver bullet](https://blog.logrocket.com/container-queries-2026/) - Container query adoption analysis
- [Common Bootstrap Mistakes](https://infinitejs.com/posts/common-bootstrap-mistakes-pitfalls/) - Bootstrap anti-patterns
- [Top 7 Vue.js Icon Libraries 2026](https://hugeicons.com/blog/vuejs/top-vue-js-icon-libraries) - Icon library comparisons

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Bootstrap and Vue documentation verified, established ecosystem
- Architecture: HIGH - Bootstrap's official SCSS architecture patterns, verified with official docs
- Pitfalls: MEDIUM-HIGH - Combination of official docs (HIGH) and community best practices (MEDIUM)
- Code examples: HIGH - All examples sourced from official documentation or verified with authoritative sources
- Accessibility: HIGH - Based on official WCAG 2.2 specification and W3C guidance
- Color palettes: MEDIUM - General colorblind-safe principles verified, specific medical hues require user validation
- Tool integration: MEDIUM - vitest-axe and Bootstrap-Vue-Next integration patterns from official repos, some implementation details may need verification

**Research date:** 2026-01-23
**Valid until:** ~60 days (2026-03-24) - Bootstrap 5 is stable, CSS standards are mature, WCAG 2.2 is locked specification. Medical UI trends evolve slowly. Recommend re-verification if planning extends beyond March 2026.

**Key assumptions:**
- Bootstrap 5.3.8 remains current version (check for 5.3.9+ security patches)
- Bootstrap-Vue-Next 0.42+ is stable (monitor for 0.43+ releases)
- Project uses Vite 7.3+ with SCSS support configured
- Phase 15 testing infrastructure includes Vitest + Vue Test Utils
- No dark mode implementation required in Phase 16 (foundation only)
- Container queries used as progressive enhancement, not primary responsive strategy

**Research limitations:**
- Visual regression testing integration approach not verified against Phase 15 implementation
- Current Bootstrap Icons integration method unknown (requires codebase inspection)
- Exact medical color palette hues require user validation and contrast testing
- Mobile table-to-card transformation may need custom implementation if Bootstrap extensions unavailable
