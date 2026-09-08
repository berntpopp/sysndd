<!-- components/ui/GeneBadge.vue -->
<!-- Professional 3D-styled gene symbol badge -->
<template>
  <component :is="linkTo ? 'BLink' : 'span'" :to="linkTo" class="gene-badge-link">
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
  display: inline-flex;
  text-decoration: none !important;
  vertical-align: middle;
}

.gene-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.2rem;
  border-radius: var(--radius-full, 9999px);
  font-weight: 600;
  font-style: italic;
  color: #fff;
  background: linear-gradient(145deg, #16a34a 0%, #15803d 100%);
  border: 1px solid #14532d;
  box-sizing: border-box;
  vertical-align: middle;
  white-space: nowrap;
  box-shadow:
    0 1px 2px rgba(16, 24, 40, 0.1),
    inset 0 1px 0 rgba(255, 255, 255, 0.15);
  cursor: pointer;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;
}

.gene-badge:hover {
  transform: translateY(-1px);
  box-shadow:
    0 3px 6px rgba(16, 24, 40, 0.15),
    inset 0 1px 0 rgba(255, 255, 255, 0.2);
}

.gene-badge__icon {
  font-size: 0.8em;
  opacity: 0.9;
  flex-shrink: 0;
}

.gene-badge__symbol {
  font-weight: 700;
}

/* Size variants - unified height and typography across all badges */
.gene-badge--sm {
  height: 24px;
  min-height: 24px;
  max-height: 24px;
  padding: 0 0.45rem;
  font-size: 0.72rem;
  line-height: 22px;
  gap: 0.18rem;
}

.gene-badge--md {
  height: 28px;
  min-height: 28px;
  max-height: 28px;
  padding: 0 0.55rem;
  font-size: 0.78rem;
  line-height: 26px;
  gap: 0.22rem;
}

.gene-badge--lg {
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
  .gene-badge {
    transition: none;
  }
  .gene-badge:hover {
    transform: none;
  }
}
</style>
