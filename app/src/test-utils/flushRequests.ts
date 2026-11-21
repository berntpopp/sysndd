// app/src/test-utils/flushRequests.ts
import { flushPromises } from '@vue/test-utils';

// MSW 3 intercepts Node `fetch` at the socket layer, so a mocked response
// arrives one or more event-loop turns later and a single `flushPromises()`
// no longer settles it. Count the fetches in flight (axios uses the fetch
// adapter in tests) instead of guessing a number of turns. Counting from the
// call, not from MSW's `request:start`, also covers the gap before MSW sees it.
let inFlight = 0;
const realFetch = globalThis.fetch;
globalThis.fetch = (...args: Parameters<typeof fetch>) => {
  inFlight += 1;
  return realFetch(...args).finally(() => {
    inFlight -= 1;
  });
};

/**
 * Settle MSW-mocked requests, including requests that later requests depend on
 * (entity -> sub-resources, mutation -> refresh): returns once no request has
 * been in flight for `idleTurns` consecutive turns.
 *
 * ponytail: gives up after `timeoutMs` so a deliberately gated handler cannot
 * hang the test; the caller's assertions then see the unsettled state.
 */
export async function flushRequests(timeoutMs = 2000, idleTurns = 10): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  let idle = 0;
  while (idle < idleTurns && Date.now() < deadline) {
    await flushPromises();
    idle = inFlight === 0 ? idle + 1 : 0;
  }
}
