// composables/useScrollbar.ts

import { nextTick } from 'vue';
import type { Ref } from 'vue';

/**
 * Composable for scrollbar update utility
 *
 * Provides a helper function to update scrollbar references after DOM updates.
 * Note: This mixin was present in the original codebase but appears to be unused.
 * Converted for completeness during mixin-to-composable migration.
 *
 * @returns Object containing updateScrollbar function
 */

interface ScrollbarControls {
  updateScrollbar: (scrollRef?: Ref<{ update: () => void }> | null) => void;
}

export default function useScrollbar(): ScrollbarControls {
  /**
   * Update scrollbar after next DOM update tick
   * @param scrollRef - Optional ref to the scroll element
   */
  const updateScrollbar = (scrollRef: Ref<{ update: () => void }> | null = null): void => {
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
