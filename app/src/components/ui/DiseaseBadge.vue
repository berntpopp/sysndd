<!-- components/ui/DiseaseBadge.vue -->
<!-- Professional 3D-styled disease/ontology badge -->
<template>
  <component :is="linkTo ? 'BLink' : 'span'" :to="linkTo" class="disease-badge-link">
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
  display: inline-flex;
  text-decoration: none !important;
  vertical-align: middle;
  max-width: 100%;
}

.disease-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.2rem;
  border-radius: var(--radius-full, 9999px);
  font-weight: 600;
  color: #fff;
  background: linear-gradient(145deg, #c2410c 0%, #9a3412 100%);
  border: 1px solid #7c2d12;
  box-sizing: border-box;
  vertical-align: middle;
  max-width: 100%;
  box-shadow:
    0 1px 2px rgba(16, 24, 40, 0.1),
    inset 0 1px 0 rgba(255, 255, 255, 0.15);
  cursor: pointer;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;
}

.disease-badge:hover {
  transform: translateY(-1px);
  box-shadow:
    0 3px 6px rgba(16, 24, 40, 0.15),
    inset 0 1px 0 rgba(255, 255, 255, 0.2);
}

.disease-badge__icon {
  font-size: 0.8em;
  opacity: 0.9;
  flex-shrink: 0;
}

.disease-badge__name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Size variants - unified height and typography across all badges */
.disease-badge--sm {
  height: 24px;
  min-height: 24px;
  max-height: 24px;
  padding: 0 0.45rem;
  font-size: 0.72rem;
  line-height: 22px;
  gap: 0.18rem;
}

.disease-badge--md {
  height: 28px;
  min-height: 28px;
  max-height: 28px;
  padding: 0 0.55rem;
  font-size: 0.78rem;
  line-height: 26px;
  gap: 0.22rem;
}

.disease-badge--lg {
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
  .disease-badge {
    transition: none;
  }
  .disease-badge:hover {
    transform: none;
  }
}
</style>
