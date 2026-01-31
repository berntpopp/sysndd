// src/stores/ui.ts
// Pinia store for UI state and cross-component communication
// Replaces EventBus for 'update-scrollbar' event

import { defineStore } from 'pinia';
import { ref } from 'vue';
import type { Ref } from 'vue';

/**
 * UI Store for cross-cutting UI concerns
 * Uses setup syntax for better TypeScript inference
 */
export const useUiStore = defineStore('ui', () => {
  // State
  // Counter pattern: increment triggers watchers
  // This replaces EventBus.$emit('update-scrollbar')
  const scrollbarUpdateTrigger: Ref<number> = ref(0);

  // Actions
  /**
   * Request scrollbar update across the application
   * Call this from any component that loads data and needs scrollbar refresh
   * Replaces: EventBus.$emit('update-scrollbar')
   */
  function requestScrollbarUpdate(): void {
    scrollbarUpdateTrigger.value++;
  }

  return {
    // State
    scrollbarUpdateTrigger,
    // Actions
    requestScrollbarUpdate,
  };
});

// Export type for component usage
export type UIStoreType = ReturnType<typeof useUiStore>;
