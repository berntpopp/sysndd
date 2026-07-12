export type TableRequestSource = 'cache' | 'network' | 'shared';

export interface TableRequestResult {
  handled: boolean;
  source: TableRequestSource;
}

/** Instance-local intent ownership for module-coordinated table transports. */
export function createTableRequestOwner() {
  let generation = 0;
  let disposed = false;

  return {
    beginIntent: (): number => ++generation,
    isCurrent: (intent: number): boolean => !disposed && generation === intent,
    isDisposed: (): boolean => disposed,
    dispose: (): void => {
      disposed = true;
      generation += 1;
    },
  };
}

interface TableRequestOptions<T> {
  // The coordinator is module-scoped so it can preserve a short response
  // cache across a route remount.  Each composable instance must still own
  // its own response application: a request from table B cannot make an
  // in-flight table A response stale merely because it started later.
  consumer?: object;
  params: string;
  fetcher: () => Promise<T>;
  apply: (data: T, source: TableRequestSource) => void;
  onError: (error: unknown, source: TableRequestSource) => void;
  isCurrent: (params: string) => boolean;
  now?: () => number;
}

export function createTableRequestCoordinator<T>(recentWindowMs = 500) {
  let lastParams: string | null = null;
  let lastCallTime = 0;
  let lastResponse: T | null = null;
  let lastResponseParams: string | null = null;
  let inFlightPromise: Promise<T> | null = null;
  let inFlightParams: string | null = null;
  // Monotonic request-instance identity. The `params` string alone cannot
  // distinguish the original request A from a later A2 after an A→B→A sequence
  // (an A-B-A race), so a generation stamps every network request; only the
  // latest generation may apply, and only the owning generation may clear the
  // in-flight slot (#535 P1-7).
  let inFlightGen = 0;
  let generation = 0;
  const defaultConsumer = {};
  const consumerGenerations = new WeakMap<object, number>();

  async function request({
    consumer = defaultConsumer,
    params,
    fetcher,
    apply,
    onError,
    isCurrent,
    now = () => Date.now(),
  }: TableRequestOptions<T>): Promise<TableRequestResult> {
    const sharedRequest = inFlightParams === params && inFlightPromise;
    const priorConsumerGeneration = consumerGenerations.get(consumer);
    // Repeated same-parameter requests from one consumer join its existing
    // intent; a different consumer still receives its own ownership token.
    const reusesConsumerIntent =
      Boolean(sharedRequest) && priorConsumerGeneration !== undefined && isCurrent(params);
    const consumerGeneration = reusesConsumerIntent
      ? priorConsumerGeneration
      : (priorConsumerGeneration ?? 0) + 1;
    if (!reusesConsumerIntent) {
      consumerGenerations.set(consumer, consumerGeneration);
    }
    const isConsumerCurrent = () =>
      consumerGenerations.get(consumer) === consumerGeneration && isCurrent(params);

    if (sharedRequest) {
      const source: TableRequestSource = 'shared';
      const shared = inFlightPromise;
      if (!shared) return { handled: false, source };
      try {
        const data = await shared;
        if (!isConsumerCurrent()) return { handled: false, source };
        apply(data, source);
        return { handled: true, source };
      } catch (error) {
        if (!isConsumerCurrent()) return { handled: false, source };
        onError(error, source);
        return { handled: true, source };
      }
    }

    if (
      lastParams === params &&
      now() - lastCallTime < recentWindowMs &&
      lastResponse !== null &&
      lastResponseParams === params
    ) {
      const source: TableRequestSource = 'cache';
      if (!isConsumerCurrent()) return { handled: false, source };
      apply(lastResponse, source);
      return { handled: true, source };
    }

    const source: TableRequestSource = 'network';
    const myGen = ++generation;
    lastParams = params;
    lastCallTime = now();
    lastResponse = null;
    lastResponseParams = null;

    const promise = fetcher();
    inFlightPromise = promise;
    inFlightParams = params;
    inFlightGen = myGen;

    try {
      const data = await promise;
      // Only the owning generation may clear the in-flight slot / record the
      // recent-response cache — an older A must not clobber a newer A2's slot.
      if (inFlightGen === myGen) {
        inFlightPromise = null;
        inFlightParams = null;
        lastResponse = data;
        lastResponseParams = params;
      }
      if (!isConsumerCurrent()) return { handled: false, source };
      apply(data, source);
      return { handled: true, source };
    } catch (error) {
      if (inFlightGen === myGen) {
        inFlightPromise = null;
        inFlightParams = null;
        lastResponse = null;
        lastResponseParams = null;
      }
      if (!isConsumerCurrent()) return { handled: false, source };
      onError(error, source);
      return { handled: true, source };
    }
  }

  return { request };
}
