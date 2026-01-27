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
watch(() => route.path, () => {
  backToTop.value?.focus();
});
</script>

<style scoped>
.skip-link {
  position: fixed;
  top: 0;
  left: 0;
  opacity: 0;
  z-index: 9999;
  background: white;
  padding: 0.5em 1em;
  border: 2px solid black;
}

.skip-link:focus {
  opacity: 1;
}
</style>
