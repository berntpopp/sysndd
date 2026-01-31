// test-utils/with-setup.ts
/**
 * Helper for testing composables that use Vue lifecycle hooks.
 * Creates a mini Vue app to provide the lifecycle context.
 *
 * Use this for composables that use:
 * - onMounted, onUnmounted, onBeforeMount, etc.
 * - provide/inject
 * - getCurrentInstance
 *
 * For composables using only ref/computed/watch, test them directly.
 *
 * @example
 * import { withSetup } from '@/test-utils';
 * import useModalControls from '@/composables/useModalControls';
 *
 * describe('useModalControls', () => {
 *   it('provides modal methods', () => {
 *     const [result, app] = withSetup(() => useModalControls());
 *     expect(result.showModal).toBeDefined();
 *     app.unmount();
 *   });
 * });
 */

import { createApp, type App } from 'vue';

type ComposableResult<T> = [T, App<Element>];

/**
 * Wraps a composable call in a Vue app context for testing.
 *
 * @param composable - Function that calls the composable
 * @returns Tuple of [composable result, Vue app instance]
 */
export function withSetup<T>(composable: () => T): ComposableResult<T> {
  let result: T;

  const app = createApp({
    setup() {
      result = composable();
      // Return empty render function - we only need the setup context
      return () => {};
    },
  });

  app.mount(document.createElement('div'));

  // result is assigned in setup before mount completes
  return [result!, app];
}

export default withSetup;
