<!-- components/ui/CategoryIcon.vue -->
<!-- Professional stoplight-style category indicator for medical data visualization -->
<template>
  <span
    class="category-icon"
    :class="[`category-icon--${variant}`, `category-icon--${size}`]"
    :title="title"
    role="img"
    :aria-label="ariaLabel"
  >
    <i class="bi bi-stoplights-fill category-icon__symbol" />
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
        'not listed': 'na',
      };
      return variants[this.category] || 'na';
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
.category-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.5rem;
  height: 1.5rem;
  border-radius: 50%;
  box-shadow:
    0 2px 4px rgba(0, 0, 0, 0.2),
    inset 0 1px 2px rgba(255, 255, 255, 0.3);
  position: relative;
}

.category-icon__symbol {
  color: white;
  font-size: 0.7rem;
  text-shadow: 0 1px 1px rgba(0, 0, 0, 0.3);
}

/* Size variants */
.category-icon--sm {
  width: 1.25rem;
  height: 1.25rem;
}

.category-icon--sm .category-icon__symbol {
  font-size: 0.6rem;
}

.category-icon--lg {
  width: 2rem;
  height: 2rem;
}

.category-icon--lg .category-icon__symbol {
  font-size: 1rem;
}

/* Definitive - Green (success) */
.category-icon--definitive {
  background: linear-gradient(145deg, #4caf50 0%, #2e7d32 100%);
  border: 2px solid #1b5e20;
}

/* Moderate - Blue (primary) */
.category-icon--moderate {
  background: linear-gradient(145deg, #2196f3 0%, #1565c0 100%);
  border: 2px solid #0d47a1;
}

/* Limited - Amber/Yellow (warning) */
.category-icon--limited {
  background: linear-gradient(145deg, #ff9800 0%, #f57c00 100%);
  border: 2px solid #e65100;
}

/* Refuted - Red (danger) */
.category-icon--refuted {
  background: linear-gradient(145deg, #f44336 0%, #c62828 100%);
  border: 2px solid #b71c1c;
}

/* Not applicable - Gray */
.category-icon--na {
  background: linear-gradient(145deg, #9e9e9e 0%, #616161 100%);
  border: 2px solid #424242;
}

/* Small size border adjustment */
.category-icon--sm {
  border-width: 1.5px;
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
    width: 1.5rem !important;
    height: 1.5rem !important;
    min-width: 1.5rem !important;
    max-width: 1.5rem !important;
  }

  .category-icon--sm {
    width: 1.25rem !important;
    height: 1.25rem !important;
    min-width: 1.25rem !important;
    max-width: 1.25rem !important;
  }

  .category-icon--lg {
    width: 2rem !important;
    height: 2rem !important;
    min-width: 2rem !important;
    max-width: 2rem !important;
  }
}
</style>
