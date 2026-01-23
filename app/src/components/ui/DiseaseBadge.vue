<!-- components/ui/DiseaseBadge.vue -->
<!-- Professional 3D-styled disease/ontology badge -->
<template>
  <component
    :is="linkTo ? 'BLink' : 'span'"
    :href="linkTo"
    class="disease-badge-link"
  >
    <span
      v-b-tooltip.hover.bottom
      class="disease-badge"
      :class="`disease-badge--${size}`"
      :title="showTitle ? tooltipTitle : ''"
      role="link"
      :aria-label="`Disease ${name}`"
    >
      <i class="bi bi-clipboard2-pulse disease-badge__icon" aria-hidden="true" />
      <span class="disease-badge__name">{{ truncatedName }}</span>
    </span>
  </component>
</template>

<script>
export default {
  name: 'DiseaseBadge',
  props: {
    /**
     * Disease/ontology name
     */
    name: {
      type: String,
      required: true,
    },
    /**
     * Ontology ID (e.g., OMIM:123456)
     */
    ontologyId: {
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
     * Maximum characters before truncation (0 = no truncation)
     */
    maxLength: {
      type: Number,
      default: 30,
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
    truncatedName() {
      if (this.maxLength === 0 || this.name.length <= this.maxLength) {
        return this.name;
      }
      return `${this.name.substring(0, this.maxLength)}…`;
    },
    tooltipTitle() {
      if (this.ontologyId) {
        return `${this.name} (${this.ontologyId})`;
      }
      return this.name;
    },
  },
};
</script>

<style scoped>
.disease-badge-link {
  text-decoration: none !important;
}

.disease-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.2rem;
  padding: 0.2rem 0.45rem;
  border-radius: 1rem;
  font-weight: 500;
  color: white;
  background: linear-gradient(145deg, #6c757d 0%, #565e64 100%);
  border: 1.5px solid #41464b;
  text-shadow: 0 1px 1px rgba(0, 0, 0, 0.2);
  box-shadow:
    0 2px 4px rgba(0, 0, 0, 0.15),
    inset 0 1px 2px rgba(255, 255, 255, 0.2);
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
  max-width: 100%;
}

.disease-badge:hover {
  transform: translateY(-1px);
  box-shadow:
    0 4px 8px rgba(0, 0, 0, 0.2),
    inset 0 1px 2px rgba(255, 255, 255, 0.25);
}

.disease-badge__icon {
  font-size: 0.85em;
  opacity: 0.9;
  flex-shrink: 0;
}

.disease-badge__name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Size variants */
.disease-badge--sm {
  padding: 0.125rem 0.35rem;
  font-size: 0.7rem;
  border-width: 1.5px;
  gap: 0.1rem;
}

.disease-badge--sm .disease-badge__icon {
  font-size: 0.7em;
}

.disease-badge--md {
  padding: 0.25rem 0.5rem;
  font-size: 0.8125rem;
  border-width: 2px;
}

.disease-badge--lg {
  padding: 0.35rem 0.65rem;
  font-size: 0.9375rem;
  border-width: 2px;
}

/* Accessibility - respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  .disease-badge {
    transition: none;
  }
  .disease-badge:hover {
    transform: none;
  }
}
</style>
