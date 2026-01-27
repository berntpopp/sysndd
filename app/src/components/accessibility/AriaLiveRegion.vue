<!-- components/accessibility/AriaLiveRegion.vue -->
<!-- Screen reader status announcement region - WCAG 4.1.3 Status Messages -->
<template>
  <div
    role="status"
    :aria-live="politeness"
    aria-atomic="true"
    class="visually-hidden"
  >
    {{ message }}
  </div>
</template>

<script setup>
/**
 * AriaLiveRegion component for screen reader announcements
 *
 * CRITICAL: This component must be pre-rendered in DOM BEFORE content changes.
 * The component always exists; only its text content changes.
 *
 * Usage:
 *   <AriaLiveRegion :message="statusMessage" :politeness="politeness" />
 *
 * Props:
 * - message: Text to announce to screen readers
 * - politeness: 'polite' (default, waits for pause) or 'assertive' (interrupts immediately)
 */
defineProps({
  message: {
    type: String,
    default: '',
  },
  politeness: {
    type: String,
    default: 'polite',
    validator: (value) => ['polite', 'assertive'].includes(value),
  },
});
</script>
