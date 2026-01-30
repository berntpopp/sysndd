<!-- components/ui/GeneBadge.vue -->
<!-- Professional 3D-styled gene symbol badge -->
<template>
  <component :is="linkTo ? 'BLink' : 'span'" :href="linkTo" class="gene-badge-link">
    <span
      v-b-tooltip.hover.bottom
      class="gene-badge"
      :class="`gene-badge--${size}`"
      :title="showTitle ? tooltipTitle : ''"
      role="link"
      :aria-label="`Gene ${symbol}`"
    >
      <i class="bi bi-file-earmark-medical gene-badge__icon" aria-hidden="true" />
      <span class="gene-badge__symbol">{{ symbol }}</span>
    </span>
  </component>
</template>

<script>
export default {
  name: 'GeneBadge',
  props: {
    /**
     * Gene symbol (e.g., MECP2, SCN1A)
     */
    symbol: {
      type: String,
      required: true,
    },
    /**
     * HGNC ID for tooltip and linking
     */
    hgncId: {
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
  },
  computed: {
    tooltipTitle() {
      return this.hgncId ? `${this.symbol} (${this.hgncId})` : this.symbol;
    },
  },
};
</script>

<style scoped>
.gene-badge-link {
  text-decoration: none !important;
}

.gene-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.2rem;
  padding: 0.2rem 0.45rem;
  border-radius: 1rem;
  font-weight: 600;
  font-style: italic;
  color: white;
  background: linear-gradient(145deg, #198754 0%, #146c43 100%);
  border: 1.5px solid #0f5132;
  text-shadow: 0 1px 1px rgba(0, 0, 0, 0.2);
  box-shadow:
    0 2px 4px rgba(0, 0, 0, 0.15),
    inset 0 1px 2px rgba(255, 255, 255, 0.2);
  cursor: pointer;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;
}

.gene-badge:hover {
  transform: translateY(-1px);
  box-shadow:
    0 4px 8px rgba(0, 0, 0, 0.2),
    inset 0 1px 2px rgba(255, 255, 255, 0.25);
}

.gene-badge__icon {
  font-size: 0.85em;
  opacity: 0.9;
}

.gene-badge__symbol {
  font-weight: 700;
}

/* Size variants */
.gene-badge--sm {
  padding: 0.125rem 0.35rem;
  font-size: 0.7rem;
  border-width: 1.5px;
  gap: 0.1rem;
}

.gene-badge--sm .gene-badge__icon {
  font-size: 0.7em;
}

.gene-badge--md {
  padding: 0.25rem 0.5rem;
  font-size: 0.8125rem;
  border-width: 2px;
}

.gene-badge--lg {
  padding: 0.35rem 0.65rem;
  font-size: 0.9375rem;
  border-width: 2px;
}

/* Accessibility - respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  .gene-badge {
    transition: none;
  }
  .gene-badge:hover {
    transform: none;
  }
}
</style>
