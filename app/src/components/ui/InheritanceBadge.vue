<!-- components/ui/InheritanceBadge.vue -->
<!-- Professional 3D-styled inheritance mode badge -->
<template>
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
.inheritance-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.15rem;
  padding: 0.2rem 0.4rem;
  border-radius: 1rem;
  font-weight: 600;
  color: white;
  background: linear-gradient(145deg, #0dcaf0 0%, #0aa2c0 100%);
  border: 1.5px solid #087990;
  text-shadow: 0 1px 1px rgba(0, 0, 0, 0.15);
  box-shadow:
    0 2px 4px rgba(0, 0, 0, 0.15),
    inset 0 1px 2px rgba(255, 255, 255, 0.25);
  cursor: default;
}

.inheritance-badge__icon {
  font-size: 0.8em;
  opacity: 0.9;
}

.inheritance-badge__abbrev {
  font-weight: 700;
  letter-spacing: 0.5px;
}

/* Size variants */
.inheritance-badge--sm {
  padding: 0.125rem 0.35rem;
  font-size: 0.7rem;
  border-width: 1.5px;
  gap: 0.1rem;
}

.inheritance-badge--sm .inheritance-badge__icon {
  font-size: 0.65em;
}

.inheritance-badge--md {
  padding: 0.2rem 0.45rem;
  font-size: 0.75rem;
  border-width: 2px;
}

.inheritance-badge--lg {
  padding: 0.3rem 0.55rem;
  font-size: 0.875rem;
  border-width: 2px;
}
</style>
