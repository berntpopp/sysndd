<!-- components/ui/CategoryIcon.vue -->
<!-- Accessible category indicator with distinct icons and color-blind friendly colors -->
<!-- Icons and colors follow WCAG guidelines: never rely on color alone -->
<!-- Color palette: Wong/Okabe-Ito (Nature Methods 8:441, 2011) -->
<template>
  <span
    class="category-icon"
    :class="[`category-icon--${variant}`, `category-icon--${size}`]"
    :title="title"
    role="img"
    :aria-label="ariaLabel"
  >
    <i :class="iconClass" class="category-icon__symbol" />
  </span>
</template>

<script>
export default {
  name: 'CategoryIcon',
  props: {
    /**
     * Category name: Definitive, Moderate, Limited, Refuted, not applicable, not listed
     */
    category: {
      type: String,
      required: true,
      validator: (value) =>
        ['Definitive', 'Moderate', 'Limited', 'Refuted', 'not applicable', 'not listed'].includes(
          value
        ),
    },
    /**
     * Size variant: 'sm' for small (tables), default for normal
     */
    size: {
      type: String,
      default: 'md',
      validator: (value) => ['sm', 'md', 'lg'].includes(value),
    },
    /**
     * Show tooltip title
     */
    showTitle: {
      type: Boolean,
      default: true,
    },
  },
  computed: {
    variant() {
      const variants = {
        Definitive: 'definitive',
        Moderate: 'moderate',
        Limited: 'limited',
        Refuted: 'refuted',
        'not applicable': 'na',
        'not listed': 'notlisted',
      };
      return variants[this.category] || 'na';
    },
    /**
     * Different icons for each category - accessibility best practice
     * Ensures categories are distinguishable without relying on color alone
     */
    iconClass() {
      const icons = {
        Definitive: 'bi bi-check-circle-fill', // Checkmark = confirmed/validated
        Moderate: 'bi bi-dash-circle-fill', // Dash = moderate/partial
        Limited: 'bi bi-exclamation-circle-fill', // Exclamation = caution/limited
        Refuted: 'bi bi-x-circle-fill', // X = rejected/refuted
        'not applicable': 'bi bi-slash-circle', // Slash = not applicable
        'not listed': 'bi bi-circle', // Empty circle = not listed/absent
      };
      return icons[this.category] || 'bi bi-circle';
    },
    title() {
      return this.showTitle ? this.category : '';
    },
    ariaLabel() {
      return `Category: ${this.category}`;
    },
  },
};
</script>

<style scoped>
/*
 * Color palette: Wong/Okabe-Ito (Nature Methods 8:441, 2011)
 * Optimized for color blindness accessibility
 * Each category also has a distinct icon shape for redundant encoding
 */

.category-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  position: relative;
}

.category-icon__symbol {
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
}

/* Size variants */
.category-icon--sm .category-icon__symbol {
  font-size: 1.1rem;
}

.category-icon--md .category-icon__symbol {
  font-size: 1.4rem;
}

.category-icon--lg .category-icon__symbol {
  font-size: 1.8rem;
}

/*
 * Definitive - Okabe-Ito Bluish Green (#009E73)
 * Icon: check-circle-fill (✓)
 * High confidence, validated
 */
.category-icon--definitive .category-icon__symbol {
  color: #009E73;
}

/*
 * Moderate - Okabe-Ito Blue (#0072B2)
 * Icon: dash-circle-fill (-)
 * Medium confidence
 */
.category-icon--moderate .category-icon__symbol {
  color: #0072B2;
}

/*
 * Limited - Okabe-Ito Orange (#E69F00)
 * Icon: exclamation-circle-fill (!)
 * Low confidence, needs more evidence
 */
.category-icon--limited .category-icon__symbol {
  color: #E69F00;
}

/*
 * Refuted - Okabe-Ito Vermilion (#D55E00)
 * Icon: x-circle-fill (✗)
 * Rejected/disproven
 */
.category-icon--refuted .category-icon__symbol {
  color: #D55E00;
}

/*
 * Not applicable - Gray (#757575)
 * Icon: slash-circle (∅)
 * Category doesn't apply
 */
.category-icon--na .category-icon__symbol {
  color: #757575;
}

/*
 * Not listed - Light Gray (#BDBDBD)
 * Icon: circle (○) - empty/outline
 * Gene not present in this source
 */
.category-icon--notlisted .category-icon__symbol {
  color: #BDBDBD;
}

/* Accessibility - respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  .category-icon {
    transition: none;
  }
}

/* Mobile fix - prevent flex stretching */
@media (max-width: 767px) {
  .category-icon {
    flex: 0 0 auto !important;
  }
}
</style>
