// composables/useAriaLive.ts

/**
 * Composable for managing ARIA live region announcements
 *
 * Provides a reactive interface for announcing status messages to screen readers
 * without interrupting the user's current workflow.
 *
 * Usage:
 * ```typescript
 * import { useAriaLive } from '@/composables'
 *
 * const { message, politeness, announce } = useAriaLive()
 *
 * // In template: <AriaLiveRegion :message="message" :politeness="politeness" />
 *
 * // Announce polite message (waits for pause in screen reader)
 * announce('Form submitted successfully')
 *
 * // Announce assertive message (interrupts immediately)
 * announce('Error: Invalid input', 'assertive')
 * ```
 *
 * @returns UseAriaLiveReturn object with message, politeness refs, and announce function
 */

import { ref } from 'vue';

/**
 * Return type for useAriaLive composable
 */
export interface UseAriaLiveReturn {
  /**
   * Current announcement message text
   * Bound to AriaLiveRegion component
   */
  message: import('vue').Ref<string>;

  /**
   * Current politeness level
   * - 'polite': Wait for screen reader pause (default, for most updates)
   * - 'assertive': Interrupt immediately (for critical alerts only)
   */
  politeness: import('vue').Ref<'polite' | 'assertive'>;

  /**
   * Announce a message to screen readers
   * Message is automatically cleared after 1000ms
   *
   * @param text - Message text to announce
   * @param level - Politeness level ('polite' | 'assertive')
   */
  announce: (text: string, level?: 'polite' | 'assertive') => void;
}

/**
 * Composable for ARIA live region announcements
 */
export function useAriaLive(): UseAriaLiveReturn {
  const message = ref('');
  const politeness = ref<'polite' | 'assertive'>('polite');

  /**
   * Announce a message to screen readers via ARIA live region
   * Updates politeness level and message, then auto-clears after timeout
   */
  function announce(text: string, level: 'polite' | 'assertive' = 'polite') {
    politeness.value = level;
    message.value = text;

    // Clear message after announcement
    setTimeout(() => {
      message.value = '';
    }, 1000);
  }

  return {
    message,
    politeness,
    announce,
  };
}
