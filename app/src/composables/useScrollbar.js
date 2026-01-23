// composables/useScrollbar.js

import { nextTick } from 'vue';

/**
 * Composable for scrollbar update utility
 *
 * Provides a helper function to update scrollbar references after DOM updates.
 * Note: This mixin was present in the original codebase but appears to be unused.
 * Converted for completeness during mixin-to-composable migration.
 *
 * @returns {Object} Object containing updateScrollbar function
 */
export default function useScrollbar() {
  /**
   * Update scrollbar after next DOM update tick
   * @param {Object} scrollRef - Optional ref to the scroll element
   */
  const updateScrollbar = (scrollRef = null) => {
    nextTick(() => {
      console.log('1');
      if (scrollRef && scrollRef.value) {
        console.log('2');
        scrollRef.value.update();
      }
    });
  };

  return { updateScrollbar };
}
