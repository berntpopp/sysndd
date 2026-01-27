<!-- components/ui/NddIcon.vue -->
<!-- NDD (Neurodevelopmental Disorder) status indicator -->
<template>
  <span
    class="ndd-icon"
    :class="[`ndd-icon--${variant}`, { 'ndd-icon--small': size === 'sm' }]"
    :title="title"
    role="img"
    :aria-label="ariaLabel"
  >
    <i :class="iconClass" />
  </span>
</template>

<script>
export default {
  name: 'NddIcon',
  props: {
    /**
     * NDD status: 'Yes' or 'No'
     */
    status: {
      type: String,
      required: true,
      validator: (value) => ['Yes', 'No'].includes(value),
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
     * Show tooltip title
     */
    showTitle: {
      type: Boolean,
      default: true,
    },
  },
  computed: {
    variant() {
      return this.status === 'Yes' ? 'yes' : 'no';
    },
    iconClass() {
      return this.status === 'Yes' ? 'bi bi-check-lg' : 'bi bi-x-lg';
    },
    title() {
      if (!this.showTitle) return '';
      return this.status === 'Yes' ? 'Associated with NDD' : 'Not associated with NDD';
    },
    ariaLabel() {
      return this.status === 'Yes' ? 'Associated with NDD' : 'Not associated with NDD';
    },
  },
};
</script>

<style scoped>
.ndd-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.5rem;
  height: 1.5rem;
  border-radius: 50%;
  font-size: 0.85rem;
  font-weight: 700;
}

.ndd-icon--small {
  width: 1.25rem;
  height: 1.25rem;
  font-size: 0.75rem;
}

/* Yes - Green checkmark */
.ndd-icon--yes {
  background: linear-gradient(145deg, #4caf50 0%, #2e7d32 100%);
  border: 2px solid #1b5e20;
  color: white;
  box-shadow:
    0 2px 4px rgba(0, 0, 0, 0.15),
    inset 0 1px 2px rgba(255, 255, 255, 0.2);
}

/* No - Amber/Orange X */
.ndd-icon--no {
  background: linear-gradient(145deg, #ff9800 0%, #f57c00 100%);
  border: 2px solid #e65100;
  color: white;
  box-shadow:
    0 2px 4px rgba(0, 0, 0, 0.15),
    inset 0 1px 2px rgba(255, 255, 255, 0.2);
}

.ndd-icon--small {
  border-width: 1.5px;
}

/* Accessibility */
@media (prefers-reduced-motion: reduce) {
  .ndd-icon {
    transition: none;
  }
}

/* Mobile fix - prevent flex stretching (mirrors CategoryIcon pattern) */
@media (max-width: 767px) {
  .ndd-icon {
    flex: 0 0 auto !important;
    width: 1.5rem !important;
    height: 1.5rem !important;
    min-width: 1.5rem !important;
    max-width: 1.5rem !important;
  }

  .ndd-icon--small {
    width: 1.25rem !important;
    height: 1.25rem !important;
    min-width: 1.25rem !important;
    max-width: 1.25rem !important;
  }
}
</style>
