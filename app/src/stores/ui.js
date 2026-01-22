// src/stores/ui.js
// Pinia store for UI state and cross-component communication
// Replaces EventBus for 'update-scrollbar' event

import { defineStore } from 'pinia';

// eslint-disable-next-line import/prefer-default-export
export const useUiStore = defineStore('ui', {
  state: () => ({
    // Counter pattern: increment triggers watchers
    // This replaces EventBus.$emit('update-scrollbar')
    scrollbarUpdateTrigger: 0,
  }),

  actions: {
    /**
     * Request scrollbar update across the application
     * Call this from any component that loads data and needs scrollbar refresh
     * Replaces: EventBus.$emit('update-scrollbar')
     */
    requestScrollbarUpdate() {
      // eslint-disable-next-line no-plusplus
      this.scrollbarUpdateTrigger++;
    },
  },
});
