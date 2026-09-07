<!-- components/ui/InheritanceBadge.vue -->
<!-- Professional 3D-styled inheritance mode badge -->
<template>
  <component :is="linkTo ? 'BLink' : 'span'" :to="linkTo" class="inheritance-badge-link">
    <span
      v-b-tooltip.hover.bottom
      class="inheritance-badge"
      :class="`inheritance-badge--${size}`"
      :title="showTitle ? tooltipTitle : ''"
      role="img"
      :aria-label="`Inheritance: ${fullName}`"
    >
      <i class="bi bi-diagram-3 inheritance-badge__icon" aria-hidden="true" />
      <span class="inheritance-badge__abbrev">{{ abbreviation }}</span>
    </span>
  </component>
</template>

<script>
// Inheritance mode abbreviations - includes both full and short forms
const INHERITANCE_ABBREVIATIONS = {
  // Full HPO names
  'Autosomal dominant inheritance': 'AD',
  'Autosomal recessive inheritance': 'AR',
  'X-linked inheritance': 'XL',
  'X-linked dominant inheritance': 'XLD',
  'X-linked recessive inheritance': 'XLR',
  'Y-linked inheritance': 'YL',
  'Mitochondrial inheritance': 'MT',
  'Somatic mutation': 'Som',
  Sporadic: 'Spo',
  'Semidominant mode of inheritance': 'SD',
  'Digenic inheritance': 'DI',
  'Oligogenic inheritance': 'OI',
  'Multifactorial inheritance': 'MF',
  'Contiguous gene syndrome': 'CGS',
  // Short forms (used in inheritance_filter)
  'Autosomal dominant': 'AD',
  'Autosomal recessive': 'AR',
  'X-linked': 'XL',
  'X-linked dominant': 'XLD',
  'X-linked recessive': 'XLR',
  'Y-linked': 'YL',
  Mitochondrial: 'MT',
  Semidominant: 'SD',
  Digenic: 'DI',
  Oligogenic: 'OI',
  Multifactorial: 'MF',
};

export default {
  name: 'InheritanceBadge',
  props: {
    /**
     * Full inheritance mode name (e.g., "Autosomal dominant inheritance")
     */
    fullName: {
      type: String,
      required: true,
    },
    /**
     * HPO term ID (e.g., HP:0000006)
     */
    hpoTerm: {
      type: String,
      default: '',
    },
    /**
     * Size variant
     */
    size: {
      type: String,
      default: 'md',
      validator: (value) => ['sm', 'md', 'lg'].includes(value),
    },
    /**
     * Optional link destination
     */
    linkTo: {
      type: String,
      default: null,
    },
    /**
     * Show tooltip
     */
    showTitle: {
      type: Boolean,
      default: true,
    },
    /**
     * Use abbreviation (default true). Set to false to show fullName as-is
     */
    useAbbreviation: {
      type: Boolean,
      default: true,
    },
  },
  computed: {
    abbreviation() {
      if (!this.useAbbreviation) {
        return this.fullName;
      }
      return INHERITANCE_ABBREVIATIONS[this.fullName] || this.fullName.substring(0, 3);
    },
    tooltipTitle() {
      if (this.hpoTerm) {
        return `${this.fullName} (${this.hpoTerm})`;
      }
      return this.fullName;
    },
  },
};
</script>

<style scoped>
.inheritance-badge-link {
  display: inline-flex;
  text-decoration: none !important;
  vertical-align: middle;
}

.inheritance-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.2rem;
  border-radius: var(--radius-full, 9999px);
  font-weight: 700;
  letter-spacing: 0.4px;
  color: #fff;
  background: linear-gradient(145deg, #7c3aed 0%, #6d28d9 100%);
  border: 1px solid #5b21b6;
  box-sizing: border-box;
  vertical-align: middle;
  white-space: nowrap;
  box-shadow:
    0 1px 2px rgba(16, 24, 40, 0.1),
    inset 0 1px 0 rgba(255, 255, 255, 0.15);
  cursor: default;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;
}

.inheritance-badge:hover {
  transform: translateY(-1px);
  box-shadow:
    0 3px 6px rgba(16, 24, 40, 0.15),
    inset 0 1px 0 rgba(255, 255, 255, 0.2);
}

.inheritance-badge__icon {
  font-size: 0.8em;
  opacity: 0.9;
  flex-shrink: 0;
}

.inheritance-badge__abbrev {
  font-weight: 700;
}

/* Size variants - unified height and typography across all badges */
.inheritance-badge--sm {
  height: 24px;
  min-height: 24px;
  max-height: 24px;
  padding: 0 0.45rem;
  font-size: 0.72rem;
  line-height: 22px;
  gap: 0.18rem;
}

.inheritance-badge--md {
  height: 28px;
  min-height: 28px;
  max-height: 28px;
  padding: 0 0.55rem;
  font-size: 0.78rem;
  line-height: 26px;
  gap: 0.22rem;
}

.inheritance-badge--lg {
  height: 34px;
  min-height: 34px;
  max-height: 34px;
  padding: 0 0.75rem;
  font-size: 0.9rem;
  line-height: 32px;
  gap: 0.28rem;
}

/* Accessibility - respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  .inheritance-badge {
    transition: none;
  }
  .inheritance-badge:hover {
    transform: none;
  }
}
</style>
