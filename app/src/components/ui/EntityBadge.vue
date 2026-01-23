<!-- components/ui/EntityBadge.vue -->
<!-- Professional 3D-styled entity identifier badge -->
<template>
  <component
    :is="linkTo ? 'BLink' : 'span'"
    :href="linkTo"
    class="entity-badge-link"
  >
    <span
      class="entity-badge"
      :class="[`entity-badge--${variant}`, `entity-badge--${size}`]"
      :title="showTitle ? fullTitle : ''"
      role="link"
      :aria-label="`Entity ${entityId}`"
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
  padding: 0.25rem 0.5rem;
  border-radius: 1rem;
  font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Roboto Mono', monospace;
  font-weight: 600;
  color: white;
  text-shadow: 0 1px 1px rgba(0, 0, 0, 0.2);
  box-shadow:
    0 2px 4px rgba(0, 0, 0, 0.15),
    inset 0 1px 2px rgba(255, 255, 255, 0.2);
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.entity-badge:hover {
  transform: translateY(-1px);
  box-shadow:
    0 4px 8px rgba(0, 0, 0, 0.2),
    inset 0 1px 2px rgba(255, 255, 255, 0.25);
}

.entity-badge__prefix {
  opacity: 0.85;
  font-size: 0.85em;
}

.entity-badge__id {
  font-weight: 700;
}

/* Size variants */
.entity-badge--sm {
  padding: 0.125rem 0.35rem;
  font-size: 0.7rem;
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
  background: linear-gradient(145deg, #0d6efd 0%, #0a58ca 100%);
  border: 1.5px solid #084298;
}

/* Success variant - Green (genes) */
.entity-badge--success {
  background: linear-gradient(145deg, #198754 0%, #146c43 100%);
  border: 1.5px solid #0f5132;
}

/* Secondary variant - Gray (diseases/ontology) */
.entity-badge--secondary {
  background: linear-gradient(145deg, #6c757d 0%, #565e64 100%);
  border: 1.5px solid #41464b;
}

/* Info variant - Cyan (inheritance) */
.entity-badge--info {
  background: linear-gradient(145deg, #0dcaf0 0%, #0aa2c0 100%);
  border: 1.5px solid #087990;
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
