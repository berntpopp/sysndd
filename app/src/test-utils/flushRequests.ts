// app/src/test-utils/flushRequests.ts
import { flushPromises } from '@vue/test-utils';

/**
 * Settle MSW-mocked requests, including requests that later requests depend on.
 *
 * MSW 3 intercepts Node `fetch` at the socket layer, so each mocked response
 * resolves one event-loop turn later instead of within the microtask queue.
 * A single `flushPromises()` therefore settles only the first request of a
 * chain (entity -> sub-resources, mutation -> refresh).
 *
 * ponytail: fixed turn budget; raise `turns` if a view chains more requests.
 */
export async function flushRequests(turns = 10): Promise<void> {
  for (let i = 0; i < turns; i += 1) {
    await flushPromises();
  }
}
