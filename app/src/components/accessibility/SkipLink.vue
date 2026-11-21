<!-- components/accessibility/SkipLink.vue -->
<!-- Skip to main content link for keyboard navigation - WCAG 2.4.1 Bypass Blocks -->
<template>
  <span ref="backToTop" tabindex="-1" />
  <a href="#main" class="skip-link">Skip to main content</a>
</template>

<script setup>
import { ref, watch } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const backToTop = ref();

// Reset focus to top of page on route change
watch(
  () => route.path,
  () => {
    backToTop.value?.focus();
  }
);
</script>

<style scoped>
.skip-link {
  position: absolute;
  top: 0;
  left: 0;
  /* Fully off-screen whatever its wrapped height, so it never peeks on phones. */
  transform: translateY(-100%);
  white-space: nowrap;
  background: var(--medical-blue-700, #0d47a1);
  color: white;
  padding: 0.5rem 1rem;
  text-decoration: none;
  z-index: 9999;
  border-radius: 0 0 0.25rem 0;
  transition: transform 0.15s ease-in-out;
  pointer-events: none;
}

.skip-link:focus {
  transform: none;
  pointer-events: auto;
  outline: 3px solid white;
  outline-offset: -0.25rem;
}

@media (prefers-reduced-motion: reduce) {
  .skip-link {
    transition: none;
  }
}
</style>
