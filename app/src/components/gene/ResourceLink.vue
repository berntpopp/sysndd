<template>
  <!-- Compact badge mode -->
  <component
    :is="isAvailable ? 'a' : 'span'"
    v-if="compact"
    :href="isAvailable ? url : undefined"
    :aria-label="isAvailable ? `Open ${name}` : undefined"
    :aria-disabled="!isAvailable"
    :target="isAvailable ? '_blank' : undefined"
    :rel="isAvailable ? 'noopener noreferrer' : undefined"
    class="resource-badge"
    :class="{ 'resource-badge--unavailable': !isAvailable }"
  >
    <i :class="icon" class="resource-badge__icon" />
    <span class="resource-badge__label">{{ name }}</span>
  </component>

  <!-- Full card mode (default) -->
  <component
    :is="isAvailable ? 'a' : 'div'"
    v-else
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
  compact?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  url: undefined,
  description: undefined,
  icon: 'bi-database',
  available: true,
  compact: false,
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

/* Compact badge mode */
.resource-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.15rem 0.5rem;
  border: 1px solid #dee2e6;
  border-radius: 1rem;
  background: white;
  font-size: 0.75rem;
  text-decoration: none;
  color: #495057;
  transition: background-color 0.15s ease, border-color 0.15s ease;
  cursor: pointer;
  white-space: nowrap;
}

.resource-badge:hover {
  background-color: #e9ecef;
  border-color: #adb5bd;
  text-decoration: none;
  color: #212529;
}

.resource-badge--unavailable {
  opacity: 0.45;
  cursor: default;
  pointer-events: none;
}

.resource-badge__icon {
  font-size: 0.75rem;
  color: #6699cc;
}

.resource-badge__label {
  font-weight: 500;
  line-height: 1;
}

/* Accessibility - respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  .resource-link {
    transition: none;
  }
  .resource-link:hover {
    transform: none;
  }
  .resource-badge {
    transition: none;
  }
}
</style>
