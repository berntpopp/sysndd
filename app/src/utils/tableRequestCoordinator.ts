export type TableRequestSource = 'cache' | 'network' | 'shared';

export interface TableRequestResult {
  handled: boolean;
  source: TableRequestSource;
}

interface TableRequestOptions<T> {
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

  async function request({
    params,
    fetcher,
    apply,
    onError,
    isCurrent,
    now = () => Date.now(),
  }: TableRequestOptions<T>): Promise<TableRequestResult> {
    if (inFlightParams === params && inFlightPromise) {
      const source: TableRequestSource = 'shared';
      // Borrow the in-flight promise but capture the current generation so a
      // newer request (even same params) supersedes this borrower.
      const myGen = generation;
      const shared = inFlightPromise;
      try {
        const data = await shared;
        if (myGen !== generation || !isCurrent(params)) return { handled: false, source };
        apply(data, source);
        return { handled: true, source };
      } catch (error) {
        if (myGen !== generation || !isCurrent(params)) return { handled: false, source };
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
      if (!isCurrent(params)) return { handled: false, source };
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
      if (myGen !== generation || !isCurrent(params)) return { handled: false, source };
      apply(data, source);
      return { handled: true, source };
    } catch (error) {
      if (inFlightGen === myGen) {
        inFlightPromise = null;
        inFlightParams = null;
        lastResponse = null;
        lastResponseParams = null;
      }
      if (myGen !== generation || !isCurrent(params)) return { handled: false, source };
      onError(error, source);
      return { handled: true, source };
    }
  }

  return { request };
}
