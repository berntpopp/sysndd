// src/stores/ui.js
// Pinia store for UI state and cross-component communication
// Replaces EventBus for 'update-scrollbar' event

import { defineStore } from 'pinia';

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
      this.scrollbarUpdateTrigger++;
    },
  },
});
