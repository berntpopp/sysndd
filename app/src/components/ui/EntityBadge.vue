<!-- components/ui/EntityBadge.vue -->
<!-- Professional 3D-styled entity identifier badge -->
<template>
  <component :is="linkTo ? 'BLink' : 'span'" :to="linkTo" class="entity-badge-link">
    <span
      class="entity-badge"
      :class="[`entity-badge--${variant}`, `entity-badge--${size}`]"
      :title="showTitle ? fullTitle : ''"
      role="link"
      :aria-label="`sysndd:${entityId}`"
    >
      <span class="entity-badge__prefix">sysndd:</span>
      <span class="entity-badge__id">{{ entityId }}</span>
    </span>
  </component>
</template>

<script>
export default {
  name: 'EntityBadge',
  props: {
    /**
     * Entity ID number
     */
    entityId: {
      type: [String, Number],
      required: true,
    },
    /**
     * Color variant: primary (blue), success (green for genes), secondary (gray for diseases)
     */
    variant: {
      type: String,
      default: 'primary',
      validator: (value) => ['primary', 'success', 'secondary', 'info'].includes(value),
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
     * Show tooltip title
     */
    showTitle: {
      type: Boolean,
      default: true,
    },
    /**
     * Custom title text
     */
    title: {
      type: String,
      default: '',
    },
  },
  computed: {
    fullTitle() {
      return this.title || `Entity sysndd:${this.entityId}`;
    },
  },
};
</script>

<style scoped>
.entity-badge-link {
  text-decoration: none !important;
}

.entity-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.2rem 0.5rem;
  border-radius: var(--radius-full, 9999px);
  font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Roboto Mono', monospace;
  font-weight: 600;
  color: white;
  box-shadow: 0 1px 2px rgba(16, 24, 40, 0.08);
  cursor: pointer;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;
}

.entity-badge:hover {
  transform: translateY(-1px);
  box-shadow: 0 3px 6px rgba(16, 24, 40, 0.12);
}

.entity-badge__prefix {
  opacity: 0.85;
}

.entity-badge__id {
  font-weight: 700;
}

/* Size variants */
.entity-badge--sm {
  padding: 0.2rem 0.45rem;
  font-size: 0.72rem;
}

.entity-badge--md {
  padding: 0.2rem 0.45rem;
  font-size: 0.75rem;
}

.entity-badge--lg {
  padding: 0.3rem 0.55rem;
  font-size: 0.875rem;
}

/* Primary variant - Blue (entities) */
.entity-badge--primary {
  background-color: var(--medical-blue-700, #0d47a1);
  border: 1px solid #0a3880;
}

/* Success variant - Green (genes) */
.entity-badge--success {
  background-color: var(--status-success, #2e7d32);
  border: 1px solid #1b5e20;
}

/* Secondary variant - Gray (diseases/ontology) */
.entity-badge--secondary {
  background-color: var(--neutral-700, #616161);
  border: 1px solid #424242;
}

/* Info variant - Teal (inheritance) */
.entity-badge--info {
  background-color: var(--medical-teal-700, #00796b);
  border: 1px solid #004d40;
}

/* Accessibility - respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  .entity-badge {
    transition: none;
  }
  .entity-badge:hover {
    transform: none;
  }
}
</style>
