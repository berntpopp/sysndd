<template>
  <component
    :is="isAvailable ? 'a' : 'div'"
    :href="isAvailable ? url : undefined"
    :aria-label="isAvailable ? `Open ${name}` : undefined"
    :aria-disabled="!isAvailable"
    :target="isAvailable ? '_blank' : undefined"
    :rel="isAvailable ? 'noopener noreferrer' : undefined"
    class="resource-link"
    :class="{ 'resource-link--unavailable': !isAvailable }"
  >
    <div class="resource-link__icon">
      <i :class="icon" />
    </div>
    <div class="resource-link__content">
      <div class="resource-link__name">{{ name }}</div>
      <div v-if="description" class="resource-link__description">
        {{ description }}
      </div>
      <div v-if="!isAvailable" class="resource-link__status">
        No entry
      </div>
    </div>
  </component>
</template>

<script setup lang="ts">
import { computed } from 'vue';

interface Props {
  name: string;
  url?: string;
  description?: string;
  icon?: string;
  available?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  url: undefined,
  description: undefined,
  icon: 'bi-database',
  available: true,
});

// A resource is available if the 'available' prop is true AND url is provided
const isAvailable = computed(() => props.available && !!props.url);
</script>

<style scoped>
.resource-link {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.875rem 1rem;
  border-radius: 0.5rem;
  background: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  transition: box-shadow 0.2s ease, transform 0.2s ease;
  text-decoration: none;
  color: inherit;
  cursor: pointer;
}

.resource-link:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  transform: translateY(-1px);
  text-decoration: none;
  color: inherit;
}

.resource-link--unavailable {
  opacity: 0.5;
  cursor: default;
  pointer-events: none;
}

.resource-link--unavailable:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  transform: none;
}

.resource-link__icon {
  flex-shrink: 0;
  width: 2.5rem;
  height: 2.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 0.375rem;
  background: linear-gradient(145deg, #6699cc 0%, #5580b0 100%);
  color: white;
  font-size: 1.25rem;
}

.resource-link__content {
  flex: 1;
  min-width: 0;
}

.resource-link__name {
  font-weight: 600;
  font-size: 0.9375rem;
  margin-bottom: 0.125rem;
  color: #333;
}

.resource-link__description {
  font-size: 0.8125rem;
  color: #666;
  line-height: 1.4;
}

.resource-link__status {
  font-size: 0.8125rem;
  color: #999;
  font-style: italic;
}

/* Accessibility - respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  .resource-link {
    transition: none;
  }
  .resource-link:hover {
    transform: none;
  }
}
</style>
