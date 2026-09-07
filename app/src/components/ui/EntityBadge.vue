<!-- components/ui/EntityBadge.vue -->
<!-- Professional 3D-styled entity identifier badge -->
<template>
  <component :is="linkTo ? 'BLink' : 'span'" :to="linkTo" class="entity-badge-link">
    <span
      class="entity-badge"
      :class="[`entity-badge--${variant}`, `entity-badge--${size}`]"
      :title="showTitle ? fullTitle : ''"
      role="link"
      :aria-label="ariaLabel"
    >
      <i v-if="showIcon" class="bi bi-collection entity-badge__icon" aria-hidden="true" />
      <span v-if="prefix" class="entity-badge__prefix">{{ prefix }}</span>
      <span class="entity-badge__id">{{ entityId }}</span>
    </span>
  </component>
</template>

<script>
export default {
  name: 'EntityBadge',
  props: {
    /**
     * Entity ID number or label
     */
    entityId: {
      type: [String, Number],
      required: true,
    },
    /**
     * Prefix before ID (defaults to 'sysndd:'). Set to '' for bare label.
     */
    prefix: {
      type: String,
      default: 'sysndd:',
    },
    /**
     * Show collection/folder icon
     */
    showIcon: {
      type: Boolean,
      default: false,
    },
    /**
     * Color variant: primary (blue), success (green for genes), secondary (terracotta for diseases), info (purple for inheritance)
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
      if (this.title) return this.title;
      return this.prefix ? `Entity ${this.prefix}${this.entityId}` : `Entity ${this.entityId}`;
    },
    ariaLabel() {
      return this.prefix ? `${this.prefix}${this.entityId}` : `Entity ${this.entityId}`;
    },
  },
};
</script>

<style scoped>
.entity-badge-link {
  display: inline-flex;
  text-decoration: none !important;
  vertical-align: middle;
}

.entity-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.2rem;
  border-radius: var(--radius-full, 9999px);
  font-family: var(
    --font-family-mono,
    'SF Mono',
    'Monaco',
    'Inconsolata',
    'Roboto Mono',
    monospace
  );
  font-weight: 600;
  color: #fff;
  border-style: solid;
  border-width: 1px;
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

.entity-badge:hover {
  transform: translateY(-1px);
  box-shadow:
    0 3px 6px rgba(16, 24, 40, 0.15),
    inset 0 1px 0 rgba(255, 255, 255, 0.2);
}

.entity-badge__icon {
  font-size: 0.8em;
  opacity: 0.9;
  flex-shrink: 0;
}

.entity-badge__prefix {
  opacity: 0.85;
}

.entity-badge__id {
  font-weight: 700;
}

/* Size variants - unified height and typography across all badges */
.entity-badge--sm {
  height: 24px;
  min-height: 24px;
  max-height: 24px;
  padding: 0 0.45rem;
  font-size: 0.72rem;
  line-height: 22px;
  gap: 0.18rem;
}

.entity-badge--md {
  height: 28px;
  min-height: 28px;
  max-height: 28px;
  padding: 0 0.55rem;
  font-size: 0.78rem;
  line-height: 26px;
  gap: 0.22rem;
}

.entity-badge--lg {
  height: 34px;
  min-height: 34px;
  max-height: 34px;
  padding: 0 0.75rem;
  font-size: 0.9rem;
  line-height: 32px;
  gap: 0.28rem;
}

/* Primary variant - Deep Navy Blue (entities) */
.entity-badge--primary {
  background: linear-gradient(145deg, #1e40af 0%, #0d47a1 100%);
  border-color: #1e3a8a;
}

/* Success variant - Forest Green (genes) */
.entity-badge--success {
  background: linear-gradient(145deg, #16a34a 0%, #15803d 100%);
  border-color: #14532d;
}

/* Secondary variant - Warm Terracotta (diseases/ontology) */
.entity-badge--secondary {
  background: linear-gradient(145deg, #c2410c 0%, #9a3412 100%);
  border-color: #7c2d12;
}

/* Info variant - Royal Purple (inheritance) */
.entity-badge--info {
  background: linear-gradient(145deg, #7c3aed 0%, #6d28d9 100%);
  border-color: #5b21b6;
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
